import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/cupertino.dart';
import '../../../../core/app_file.dart';
import '../../../../core/app_file_factory.dart';
import '../parser.dart';

/// Ein Parser für PriVault ZIP-Exportdateien.
///
/// Das ZIP-Archiv kann optional mit AES-256 (AE-1) verschlüsselt sein.
///
/// Archivstruktur:
/// ```
/// zip-file/
///   ├── files/{entry_uuid}/{filename}  # Dateianhänge
///   ├── export.csv                     # CSV-Datei (RFC-4180)
///   └── export.md                      # Markdown-Datei (wird ignoriert)
/// ```
///
/// CSV-Spalten:
/// ```
///   0  uuid
///   1  category
///   2  title
///   3  username
///   4  password
///   5  password_timestamp
///   6  url
///   7  notes
///   8  favicon
///   9  updated_at
///   10 attachments  → Sub-Format: {att_uuid};{filename};{timestamp}|...
///   11 shared_with  → Sub-Format: {user_uuid};{username};{access_level};{public_key}|...
/// ```
///
/// Sub-Escaping: `\` → `\\`, `|` → `\|`, `;` → `\;`
///
class PrivaultZipParser implements Parser {
  final AppFile _file;
  final String? _password;

  PrivaultZipParser(this._file, {String? password})
    : _password = (password ?? '').isEmpty ? null : password; // Leeres Passwort → null

  // -------------------------------------------------------------------------
  // --- Öffentliche API ---
  // -------------------------------------------------------------------------

  @override
  Future<ParsedPayload> parse() async {

    // 1. Datei lesen
    final Uint8List bytes;
    try {
      bytes = await createAppFile(_file.path).readAsBytes();
    } catch (e) {
      throw ParserError('Die Datei konnte nicht geöffnet werden.', path: _file.path, originalErrorMessage: e.toString());
    }

    final isPasswordProtected = _isZipPasswordProtected(bytes);
    if (isPasswordProtected && _password == null) {
      throw ParserError('Passwort erforderlich.', path: _file.path, field: 'password');
    }
    else if (!isPasswordProtected && _password != null) {
      throw ParserError('Kein Passwort erforderlich. Die Datei ist unverschlüsselt.', path: _file.path, field: 'password');
    }

    // 2. ZIP entpacken (ggf. mit Passwort)
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, password: _password);
    } on ArchiveException catch (e) {
      final msg = '${isPasswordProtected ? 'Passwort korrekt? ' : ''}Die Datei konnte nicht entpackt werden.';
      throw ParserError(msg, path: _file.path, originalErrorMessage: e.message, field: isPasswordProtected ? 'password' : null);
    }

    // 3. export.csv suchen
    final csvEntry = archive.findFile('export.csv');
    if (csvEntry == null) {
      throw ParserError('Die PriVault-Exportdatei ist ungültig. `export.csv` fehlt im Archiv.', path: _file.path);
    }

    // 4. CSV-Inhalt dekodieren (löst ZIP-Entschlüsselung aus)
    final String csvContent;
    try {
      csvContent = utf8.decode(csvEntry.content);
    } catch (e) {
      final msg = '${isPasswordProtected ? 'Passwort korrekt? ' : ''}Die Datei konnte nicht gelesen werden.';
      throw ParserError(msg, path: _file.path, originalErrorMessage: e.toString(), field: isPasswordProtected ? 'password' : null);
    }

    // 5. CSV parsen
    final rows = _parseCsv(csvContent);
    if (rows.isEmpty) return [];

    // 6. Header validieren
    const expectedHeader = [
      'uuid', 'category', 'title', 'username', 'password', 'password_timestamp', 'url', 'notes', 'favicon', 'updated_at', 'attachments', 'shared_with',
    ];
    if (!_headersMatch(rows.first, expectedHeader)) {
      throw ParserError('Die PriVault-Exportdatei ist ungültig. `export.csv` hat einen unbekannten Header.',
        path: _file.path, lineNumber: 1,
      );
    }

    // 7. Datenzeilen verarbeiten
    final entries = <ParsedEntry>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length != expectedHeader.length) {
        final msg = 'Die PriVault-Exportdatei ist ungültig. Zeile ${i + 1} enthält nicht die erwartete Anzahl Felder.';
        throw ParserError(msg, path: _file.path, lineNumber: i + 1);
      }

      final uuid           = row[0];
      final category       = row[1];
      final title          = row[2];
      final username       = row[3];
      final password       = row[4];
      final pwTimestampRaw = row[5];
      final url            = row[6];
      final notes          = row[7];
      final favicon        = row[8];
      final updatedAtRaw   = row[9];
      final attachmentsRaw = row[10];
      final sharedWithRaw  = row[11];

      entries.add(ParsedEntry(
        uuid,
        category: category,
        title: title,
        username: username,
        password: password,
        passwordTimestamp: pwTimestampRaw.isNotEmpty ? DateTime.tryParse(pwTimestampRaw)?.toUtc() : null,
        url: url,
        notes: notes,
        favicon: favicon.isNotEmpty ? favicon : null,
        updatedAt: updatedAtRaw.isNotEmpty ? DateTime.tryParse(updatedAtRaw)?.toUtc() : null,
        attachments: _parseAttachments(attachmentsRaw, uuid, archive),
        sharedWith: _parseSharedWith(sharedWithRaw),
        lineNumber: i + 1,
      ));
    }

    return entries;
  }

  /// Prüft, ob eine ZIP-Datei verschlüsselt ist.
  bool _isZipPasswordProtected(Uint8List bytes) {

    // Eine ZIP-Datei hat folgende Struktur:
    // Offset  Länge  Inhalt
    // 0       4      Signatur: 0x04034b50 ("PK\003\004")
    // 4       2      Version
    // 6       2      General Purpose Bit Flags  ← FLAG FÜR DIE VERSCHLÜSSELUNG
    // 8       2      Compression Method
    // ...

    // Scannt alle Local File Header (Signatur 0x04034b50) und prüft Bit 0 der General Purpose Bit Flags.
    // Dieses Bit wird sowohl bei klassischer ZipCrypto als auch bei AES-256 (AE-1) gesetzt.

    if (bytes.length < 30) return false; // ZIP Header ist mindestens 30 Bytes

    // Überprüfe die lokalen File Header
    // ZIP beginnt mit "PK" (0x504B)
    if (bytes[0] != 0x50 || bytes[1] != 0x4B) {
      return false; // Keine gültige ZIP
    }

    // Suche nach lokalen File Headern (0x04034b50)
    for (int i = 0; i < bytes.length - 25; i++) {
      if (bytes[i] == 0x50 && bytes[i + 1] == 0x4B &&
          bytes[i + 2] == 0x03 && bytes[i + 3] == 0x04) {
        // Gefunden! Jetzt schaue auf das Flag-Byte (Offset +6, +7)
        int flags = bytes[i + 6] | (bytes[i + 7] << 8); // Little Endian

        // Bit 0 prüfen (Flag für Verschlüsselung)
        if ((flags & 0x0001) != 0) {
          return true; // Mindestens eine Datei ist verschlüsselt
        }
      }
    }

    return false;
  }

  // -------------------------------------------------------------------------
  // --- Dateianhänge ---
  // -------------------------------------------------------------------------

  /// Liest die Dateianhänge eines Eintrags aus dem Archiv.
  /// Gibt eine leere Liste zurück, wenn das Feld leer ist oder Dateien fehlen.
  List<ParsedAttachment>? _parseAttachments(String raw, String entryUuid, Archive archive) {
    if (raw.isEmpty) return null;
    final result = <ParsedAttachment>[];
    for (final record in _splitOn(raw, ';')) {
      if (record.isEmpty) continue;
      final parts = _splitOn(record, '|');
      if (parts.length < 2) continue;

      // parts[0] = Attachment-UUID (wird beim Import neu vergeben)
      final filename  = _subUnescape(parts[1]);
      final timestamp = parts.length > 2 ? DateTime.tryParse(parts[2])?.toUtc() : null;
      if (filename.isEmpty) continue;

      final archiveFile = archive.findFile('files/$entryUuid/$filename');
      if (archiveFile == null) continue; // Datei fehlt → still überspringen

      result.add(ParsedAttachment(
        archiveFile.content,
        filename: filename,
        timestamp: timestamp,
      ));
    }
    return result.isEmpty ? null : result;
  }

  // -------------------------------------------------------------------------
  // --- Freigaben (shared_with) ---
  // -------------------------------------------------------------------------

  /// Parst die `shared_with`-Spalte.
  ///
  /// Format: `{user_uuid}|{username}|{access_level}|{public_key}`
  ///
  /// Datensätze mit fehlendem UUID oder Public Key werden still übersprungen –
  /// der Import kann ohne sie fortgesetzt werden.
  List<ParsedSharedUser>? _parseSharedWith(String raw) {
    if (raw.isEmpty) return null;
    final result = <ParsedSharedUser>[];
    for (final record in _splitOn(raw, ';')) {
      if (record.isEmpty) continue;
      final parts = _splitOn(record, '|');
      if (parts.length < 4) continue;

      final userUuid    = parts[0].trim();
      final username    = _subUnescape(parts[1]);
      final accessLevel = int.tryParse(parts[2]) ?? 1;
      final publicKey   = _subUnescape(parts[3]);

      if (userUuid.isEmpty || publicKey.isEmpty) continue;

      result.add(ParsedSharedUser(
        uuid: userUuid,
        username: username,
        accessLevel: accessLevel,
        publicKey: publicKey,
      ));
    }
    return result.isEmpty ? null : result;
  }

  // -------------------------------------------------------------------------
  // --- RFC-4180 CSV-Parser ---
  // -------------------------------------------------------------------------

  /// Parst einen RFC-4180-konformen CSV-String in eine Liste von Zeilen.
  ///
  /// Jede Zeile ist eine Liste von Feldern (Strings). Die Methode verarbeitet:
  /// - Gequotete Felder (`"..."`) mit eingebetteten Kommas und Zeilenumbrüchen
  /// - Escaped Quotes innerhalb gequoteter Felder (`""` → `"`)
  /// - CRLF (`\r\n`) und LF (`\n`) als Zeilenenden
  /// - Leere Felder (`,,`)
  List<List<String>> _parseCsv(String content) {
    final rows   = <List<String>>[];
    var   fields = <String>[];
    final buffer = StringBuffer();
    bool  inQuotes = false;
    int   i = 0;

    void commitField() { fields.add(buffer.toString()); buffer.clear(); }
    void commitRow()   { commitField(); if (fields.isNotEmpty) rows.add(List.from(fields)); fields = []; }

    while (i < content.length) {
      final ch = content[i];
      if (inQuotes) {
        if (ch == '"' && i + 1 < content.length && content[i + 1] == '"') {
          buffer.write('"'); i += 2; // escaped quote
        } else if (ch == '"') {
          inQuotes = false; i++; // end of quoted field
        } else {
          buffer.write(ch); i++;
        }
      } else {
        switch (ch) {
          case '"':  inQuotes = true; i++;
          case ',':  commitField(); i++;
          case '\r':
            final crlf = i + 1 < content.length && content[i + 1] == '\n';
            commitRow(); i += crlf ? 2 : 1;
          case '\n': commitRow(); i++;
          default:   buffer.write(ch); i++;
        }
      }
    }
    if (buffer.isNotEmpty || fields.isNotEmpty) commitRow();
    return rows;
  }

  /// Prüft, ob die Kopfzeile der CSV-Datei den erwarteten Spalten entspricht.
  ///
  /// Der Vergleich ist case-insensitiv.
  bool _headersMatch(List<String> actual, List<String> expected) {
    debugPrint('${actual.length} != ${expected.length}');
    if (actual.length != expected.length) return false;
    for (int i = 0; i < expected.length; i++) {
      debugPrint('${actual[i]} != ${expected[i]}');
      if (actual[i].trim().toLowerCase() != expected[i]) return false;
    }
    return true;
  }

  // -------------------------------------------------------------------------
  // --- Sub-Encoding (Semikolon / Pipe mit Backslash-Escaping) ---
  // -------------------------------------------------------------------------

  /// Teilt [value] an einem einzelnen Trennzeichen [sep] auf.
  ///
  /// Im Gegensatz zu `String.split()` berücksichtigt diese Methode das
  /// Backslash-Escaping: Ein mit `\` maskiertes Trennzeichen wird **nicht**
  /// als Trenner gewertet, sondern als Teil des Feldinhalts durchgereicht.
  /// Das Auflösen der Escape-Sequenzen obliegt [_subUnescape].
  ///
  /// Beispiel:
  /// ```
  /// _splitOn('a;b\\;c;d', ';') → ['a', 'b\\;c', 'd']
  /// ```
  List<String> _splitOn(String value, String sep) {
    final parts  = <String>[];
    final buffer = StringBuffer();
    int i = 0;
    while (i < value.length) {
      if (value[i] == '\\' && i + 1 < value.length) {
        buffer.write(value[i]); buffer.write(value[i + 1]); i += 2;
      } else if (value[i] == sep) {
        parts.add(buffer.toString()); buffer.clear(); i++;
      } else {
        buffer.write(value[i]); i++;
      }
    }
    if (buffer.isNotEmpty) parts.add(buffer.toString());
    return parts;
  }

  /// Sub-Escaping für die Felder mit Semikolon/Pipe-Struktur (attachments, shared_with).
  String _subUnescape(String value) {
    final buffer = StringBuffer();
    int i = 0;
    while (i < value.length) {
      if (value[i] == '\\' && i + 1 < value.length) {
        switch (value[i + 1]) {
          case '\\': buffer.write('\\'); i += 2;
          case '|':  buffer.write('|');  i += 2;
          case ';':  buffer.write(';');  i += 2;
          default:   buffer.write(value[i]); i++;
        }
      } else {
        buffer.write(value[i]); i++;
      }
    }
    return buffer.toString();
  }
}