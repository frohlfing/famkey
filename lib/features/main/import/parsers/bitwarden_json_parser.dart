import 'dart:convert';
import 'package:path/path.dart' as p;
import '../../../../core/app_file.dart';
import '../../../../core/app_file_factory.dart';
import '../parser.dart';

/// Ein Parser für unverschlüsselte Bitwarden JSON-Exportdateien.
///
/// Spezifikation: https://gist.github.com/ctrlcmdshft/fe6baead7be858ca08666f34da028163
/// - Die Datei ist mit UTF-8 (Unicode) kodiert.
/// - UUID sind Standard-UUIDs (Format: 8-4-4-4-12, z.B. "3a0b4a0c-2b8c-4b0c-9a3e-1f4b2a9c7e12").
/// - Datums-/Zeitangaben sind im ISO 8601-Format [@!RFC3339] angegeben (`YYYY-MM-DDTHH:mm:ss` bzw `YYYY-MM-DDTHH:mm:ssZ`).
/// - Die JSON-Datei ist unverschlüsselt.
/// - Die Dateianhänge sind im Unterordner "files" abgelegt.
///
class BitwardenJsonParser implements Parser {
  /// JSON-Datei
  final AppFile _file;

  /// Zeilennummern der Item-IDs
  Map<String, int> _itemIdLineMap = {};

  /// Ordner
  Map<String, String> _folders = {};

  /// Konstruktor
  BitwardenJsonParser(this._file);

  /// Lädt die Daten aus der Datei.
  ///
  /// Gibt im Erfolgsfall eine [ParsedPayload] zurück.
  /// Im Fehlerfall wird ein [ParserError] geworfen.
  ///
  /// Struktur der JSON-Datei (nur die relevanten Teile):
  /// ```json
  /// {
  ///   "folders": [ ... ],
  ///   "items": [ ... ]
  /// }
  /// ```
  @override
  Future<ParsedPayload> parse() async {
    // Datei öffnen und Inhalt lesen
    String fileContent;
    try {
      fileContent = await _file.readAsString();
    } catch (e) {
      throw ParserError('Die Datei konnte nicht geöffnet werden.', path: _file.path, originalErrorMessage: e.toString());
    }

    // Einmaliger Scan der Datei, um eine Map der Item-IDs zu ihrer Zeilennummer zu erstellen.
    _itemIdLineMap = await _createItemIdLineMap(fileContent);

    // JSON parsen
    Map<String, dynamic> json;
    try {
      json = jsonDecode(fileContent);
    } on FormatException catch (e) {
      throw ParserError('Die JSON-Struktur der Datei ist fehlerhaft.', path: _file.path, originalErrorMessage: e.message);
    }

    // Ordner (Kategorien) in eine Map (id-> name) laden
    _folders = _parseFolders(json);

    // Alle "items" aus der JSON-Datei verarbeiten
    final items = json['items'] as List?;
    if (items == null) {
      throw ParserError('Die Bitwarden-Datei ist fehlerhaft. `items` fehlt.', path: _file.path);
    }
    return await Future.wait(items.map((itemData) { // Future.wait, da das Laden von Anhängen asynchron ist
      if (itemData is! Map<String, dynamic>) {
        throw ParserError('Die Bitwarden-Datei ist fehlerhaft. `items` beinhaltet ungültige Daten.', path: _file.path);
      }
      return _parseItem(itemData);
    }));
  }

  /// Erstellt eine Map von Item-IDs zu ihrer Zeilennummer, indem die Datei einmalig am Anfang durchlaufen wird.
  Future<Map<String, int>> _createItemIdLineMap(String fileContent) async {
    final map = <String, int>{};
    final lines = const LineSplitter().convert(fileContent);
    final idRegex = RegExp(r'"id":\s*"(.*?)"'); // Sucht nach "id" gefolgt von einem Doppelpunkt und einem String-Wert
    for (int i = 0; i < lines.length; i++) {
      final match = idRegex.firstMatch(lines[i]);
      if (match != null && match.groupCount > 0) {
        final id = match.group(1)!;
        // Fügt nur hinzu, wenn es noch nicht existiert, da die ID eines Items die erste ist, die wir wollen.
        map.putIfAbsent(id, () => i + 1); // Zeilennummern sind 1-basiert
      }
    }
    return map;
  }

  /// Lädt die Ordnernamen aus dem Root-Element in eine Map.
  ///
  /// Struktur der JSON-Datei (nur die relevanten Teile):
  /// ```json
  /// "folders": [
  ///   {
  ///     "id": "08bd40c7-5430-07ad-06e4-fce31618f6ec",
  ///     "name": "Account"
  ///   },
  ///   ...
  /// ]
  /// ```
  Map<String, String> _parseFolders(Map<String, dynamic> json) {
    final map = <String, String>{};
    if (json['folders'] is List) {
      for (final folder in json['folders']) {
        if (folder is Map && folder['id'] != null && folder['name'] != null) {
          map[folder['id']] = folder['name'];
        }
      }
    }
    return map;
  }

  /// Parst ein einzelnes JSON-Item in ein [ParsedEntry]-Objekt.
  ///
  /// Struktur der JSON-Datei (nur die relevanten Teile):
  /// ```json
  /// {
  ///   "id": "5d6f7937-90dc-d0b9-905d-cda65905da65",
  ///   "login": {
  ///     "username": "hans",
  ///     "password": "geheim",
  ///     "uris": [],
  ///     "totp": null
  ///     "fido2Credentials": [],
  ///   },
  ///   "passwordHistory": [ ... ],
  ///   "folderId": "d41d8cd9-8f00-b204-e980-0998ecf8427e",
  ///   "revisionDate": "2025-08-25T02:01:43.000Z",
  ///   "creationDate": "2025-08-25T02:01:43.000Z",
  ///   "attachments": [ ... ],
  ///   "notes": "Meine Notiz.",
  ///   ...
  /// }
  /// ```
  Future<ParsedEntry> _parseItem(Map<String, dynamic> item) async {

    // UUID und ihre Zeilennummer ermitteln
    final (uuid, lineNumber) = _parseUuid(item);

    // Login für Benutzername und Passwort nehmen
    final login = item['login'] as Map<String, dynamic>?;

    // Zeitstempel der letzten Passwortänderung ermitteln
    final passwordTimestamp = _parsePasswordTimestamp(item['passwordHistory'] as List?);

    // Ordner für die Kategorie nehmen
    final folderId = item['folderId'] as String?;
    final category = _folders[folderId]?.trim();

    // Zeitstempel der letzten Änderung ermitteln
    final updatedAt = _parseUpdatedAt(item);

    // Anhänge des Eintrags verarbeiten
    final attachments = await _parseAttachments(item['attachments'] as List?);

    return ParsedEntry(
      uuid,
      category: category,
      title: item['name']?.trim() as String?,
      username: login?['username']?.trim() as String?,
      password: login?['password'] as String?, // Passwort nicht trimmen!
      passwordTimestamp: passwordTimestamp,
      url: (login?['uris'] as List?)?.firstOrNull?['uri']?.trim() as String?,
      notes: _buildNotes(item['notes'] as String?, login?['totp'] as String?),
      updatedAt: updatedAt,
      attachments: attachments,
      lineNumber: lineNumber,
    );
  }

  /// Ermittelt die UUID des Eintrags und gibt sie zusammen mit ihrer Zeilennummer zurück.
  ///
  /// Struktur der JSON-Datei (nur die relevanten Teile):
  /// ```json
  /// {
  ///   "id": "5d6f7937-90dc-d0b9-05da-cda65905da65",
  ///   ...
  /// }
  (String uuid, int? lineNumber) _parseUuid(Map<String, dynamic> item) {
    final id = item['id'] as String?;
    final lineNumber = _itemIdLineMap[id];
    if (id == null || id.isEmpty) { // ID ist obligatorisch
      throw ParserError('Die Bitwarden-Datei ist fehlerhaft. Ein Eintrag hat keine ID.', path: _file.path, lineNumber: lineNumber);
    }

    /// Es wird eine gültige UUID erwartet (Format: 8-4-4-4-12, z.B. "3a0b4a0c-2b8c-4b0c-9a3e-1f4b2a9c7e12").
    // UUID-Prüfung
    // - Länge (36 Zeichen).
    // - Nur Hex-Zeichen (0-9, a-f) enthalten.
    // - Position der Bindestriche (9, 14, 19, 24).
    // - Aber: Versions- und Varianten-Bits werden ignoriert
    if (!_isValidFUuid(id)) {
      throw ParserError('Die Bitwarden-Datei ist fehlerhaft. Die ID "$id" ist keine gültige UUID.', path: _file.path, lineNumber: lineNumber);
    }

    return (id, lineNumber);
  }

  /// Prüft, ob ide UUID gültig ist
  /// - Länge (36 Zeichen).
  /// - Nur Hex-Zeichen (0-9, a-f) enthalten.
  /// - Position der Bindestriche (9, 14, 19, 24).
  /// - Aber: Versions- und Varianten-Bits werden ignoriert
  bool _isValidFUuid(String uuid) {
    // Prüft nur: 8 Hex - 4 Hex - 4 Hex - 4 Hex - 12 Hex
    final regex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
    return regex.hasMatch(uuid);
  }

  /// Ermittelt den Zeitpunkt der letzten Änderung
  ///
  /// Struktur der JSON-Datei (nur die relevanten Teile):
  /// ```json
  /// {
  ///   "revisionDate": "2025-08-25T02:01:43.000Z",
  ///   "creationDate": "2025-08-25T02:01:43.000Z",
  ///   ...
  /// }
  /// ```
  DateTime? _parseUpdatedAt(Map<String, dynamic> item) {
    final revisionDateStr = item['revisionDate'] as String? ?? item['creationDate'] as String?;
    return DateTime.tryParse(revisionDateStr ?? '')?.toUtc();
  }

  /// Kombiniert Notiz und TOTP-Secret zu einem einzigen Notiz-String.
  String? _buildNotes(String? notes, String? totp) {
    if (totp == null || totp.isEmpty) return notes;
    final totpLine = 'TOTP: $totp';
    if (notes == null || notes.isEmpty) return totpLine;
    return '$notes\n$totpLine';
  }

  /// Ermittelt den Zeitstempel der letzten Passwortänderung für einen Eintrag.
  ///
  /// Struktur der JSON-Datei (nur die relevanten Teile):
  /// ```json
  /// "passwordHistory": [
  ///   {
  ///     "lastUsedDate": "2025-06-01T00:00:00.000Z",
  ///     "password": "OldPass123"
  ///   },
  ///   ...
  /// ]
  /// ```
  DateTime? _parsePasswordTimestamp(List? passwordHistory) {
    if (passwordHistory == null || passwordHistory.isEmpty) return null;
    final lastChangeDate = passwordHistory.first['lastUsedDate'] as String?;
    return DateTime.tryParse(lastChangeDate ?? '')?.toUtc();
  }

  /// Parst die Anhänge für einen einzelnen Eintrag.
  ///
  /// Struktur der JSON-Datei (nur die relevanten Teile):
  /// ```json
  /// "attachments": [
  ///   {
  ///     "fileName": "vertrag.pdf",
  ///     ...
  ///   },
  ///   ...
  /// ]
  /// ```
  /// Die Dateianhänge sind im Unterordner "files" abgelegt.
  Future<List<ParsedAttachment>?> _parseAttachments(List? attachmentsMeta) async {
    final attachments = <ParsedAttachment>[];
    if (attachmentsMeta == null) return attachments;

    final baseDir = p.join(p.dirname(_file.path), 'files');

    for (final attachmentData in attachmentsMeta) {
      if (attachmentData is! Map<String, dynamic>) continue;

      final fileName = attachmentData['fileName']?.trim() as String?;
      if (fileName == null) continue;

      var attachmentPath = p.join(baseDir, fileName);
      try {
        final file = createAppFile(attachmentPath);
        if (!await file.exists()) {
          final lineNumber = await _findLineNumberOfText(_file.path, '"fileName": "$fileName"');
          throw ParserError('Anhang "$fileName" nicht gefunden. Datei im Unterordner "files" erwartet.', path: _file.path, lineNumber: lineNumber);
        }
        final binaryData = await file.readAsBytes();
        attachments.add(ParsedAttachment(binaryData, filename: fileName));
      } catch (e) {
        final lineNumber = await _findLineNumberOfText(_file.path, '"fileName": "$fileName"');
        throw ParserError('Anhang "$fileName" konnte nicht gelesen werden.', path: _file.path, lineNumber: lineNumber, originalErrorMessage: e.toString());
      }
    }

    return attachments.isEmpty ? null : attachments;
  }

  /// Sucht in einer Datei nach einem bestimmten Text und gibt die Zeilennummer zurück.
  /// Verwendet einen Stream, um die Datei effizient zu lesen.
  Future<int?> _findLineNumberOfText(String filePath, String searchText) async {
    try {
      final file = createAppFile(filePath);
      int lineNumber = 1;
      await for (final line in file.openReadLines()) {
        if (line.contains(searchText)) return lineNumber;
        lineNumber++;
      }
    } catch (_) {
      // Ignorieren, da dies eine Hilfsfunktion ist. Im Fehlerfall geben wir einfach null zurück.
    }
    return null;
  }
}