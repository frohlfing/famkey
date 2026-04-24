import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/app_file.dart';
import 'package:privault/core/app_file_factory.dart';
import 'package:privault/core/helper.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/renderers/markdown_renderer.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/features/main/export/export_state.dart';
import 'package:privault/models/payloads/attachment_meta_payload.dart';
import 'package:privault/models/payloads/entry_payload.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';

final exportProvider = NotifierProvider<ExportNotifier, ExportState>(() {
  return ExportNotifier();
});

/// Für den Export relevante Informationen über ein Attachment.
typedef ExportAttachment = ({String uuid, String filename, DateTime timestamp, int size});

/// Für den Export relevante Informationen über einen Freund.
typedef ExportFriend = ({String uuid, String username, int accessLevel, String publicKey});

/// Der Notifier für den Export-Prozess.
///
/// Die Exportdatei ist ein Zip-Archiv, optional mit AES-256 (AE-1) verschlüsselt.
///
/// Archivstruktur:
/// ```
/// zip-file/
///   ├── files/{entry_uuid}/{filename}  # Dateianhänge
///   ├── export.csv                     # CSV-Datei (RFC-4180-konform)
///   └── export.md                      # Markdown-Datei (zum Ausdrucken geeignet)
/// ```
///
/// CSV-Spalten (Kopfzeile):
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
///   12 report_excluded
/// ```
/// CSV-Spezifikation RFC-4180:
/// - Feldtrenner (Field Separation): Komma.
/// - Feldbegrenzer (Quoting): `"` (wird gesetzt, wenn der Wert Komma, Quote oder Zeilenumbruch enthält).
/// - Satzende: `\r\n` (auch für die letzte Zeile).
/// - Escaping: Quotes (`"`) im Inhalt werden verdoppelt

/// - Sub-Escaping für `attachments` und `shared_with`:
///   - Feldtrenner: Semikolon
///   - Satztrenner: Pipe-Zeichen (`|`)
///   - Escaping: Backslashes (`\`) werden verdoppelt, Semikolon und Pipe im Inhalt werden mit Backslash maskiert
class ExportNotifier extends Notifier<ExportState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

  late final CryptoService   _cryptoService;
  late final DatabaseService _databaseService;
  late final SessionService  _sessionService;

  // ------------------------------------------------------------------------
  // --- Konstanten ---
  // ------------------------------------------------------------------------

  /// Geschätzte Zeilen pro Seite – steuert den `\pagebreak`-Marker.
  static const int _linesPerPage = 50;

  /// Das Zip-Archiv, das beim Laden erstellt wird.
  final _archive = Archive();

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  @override
  ExportState build() {
    // Dienste aus getIt holen
    _cryptoService   = getIt<CryptoService>();
    _databaseService = getIt<DatabaseService>();
    _sessionService  = getIt<SessionService>();

    // Initialer State
    return ExportState();
  }

  /// Entschlüsselt alle Einträge und generiert eine Markdown-Vorschau.
  Future<void> load() async {
    if (state.isBusy) return;

    // Fortschritt
    int processed = 0;

    // Einträge nach Kategorie sortiert (für die Generierung der Markdown-Datei)
    final byCategory = <String, List<({EntryPayload payload, List<ExportAttachment> attachments, List<ExportFriend> sharedWith})>>{};

    // Zeilen für die CSV-Datei
    //
    // Spaltenreihenfolge (fest, wird vom PrivaultZipParser vorausgesetzt):
    //   0  uuid
    //   1  category
    //   2  title
    //   3  username
    //   4  password
    //   5  password_timestamp
    //   6  url
    //   7  notes
    //   8  favicon
    //   9  updated_at
    //   10 attachments
    //   11 shared_with
    //   12 report_excluded
    final csvRows = <List<String>>[
      ['uuid', 'category', 'title', 'username', 'password', 'password_timestamp', 'url', 'notes', 'favicon', 'updated_at', 'attachments', 'shared_with', 'report_excluded']
    ];

    // 1. Ladeanzeige einblenden
    state = const ExportState().copyWith(status: ExportActionStatus.loading, error: AppError.none());
    await Future.delayed(const Duration(milliseconds: 50));
    //await WidgetsBinding.instance.endOfFrame; // Warten bis Flutter den Ladeindikator gerendert hat.

    try {

      if (_sessionService.privateKey == null) throw Exception('Der private Schlüssel ist nicht entpackt.');
      if (_sessionService.user == null) throw Exception("Der Benutzer liegt nicht in der Session.");

      // 2. Alle Einträge abfragen
      final entries = await _databaseService.getEntries();

      // 3. Gesamtanzahl für die Fortschrittsanzeige im State setzen
      state = state.copyWith(total: entries.length);

      // 4. Einträge durchlaufen, CSV-Datei erstellen, und Attachments extrahieren...
      for (final entry in entries) {

        // Eintrag entschlüsseln
        final perm = await _databaseService.getPermissionByEntryIdAndUserId(entry.id, _sessionService.user!.id);
        if (perm == null) throw Exception('Zum Eintrag ${entry.id} sind keine Zugriffsrechte gespeichert.');
        final entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, _sessionService.privateKey!);
        final raw = await _cryptoService.decrypt(entry.encryptedData, entryKey);
        final payload = EntryPayload.fromJson(json.decode(utf8.decode(raw)));

        // Anhänge des Eintrags entschlüsseln und ins Archiv packen
        final attachments = <ExportAttachment>[];
        for (final att in await _databaseService.getAttachmentsByEntryId(entry.id)) {
          final dm = await _cryptoService.decrypt(att.encryptedMeta, entryKey);
          final meta = AttachmentMetaPayload.fromJson(json.decode(utf8.decode(dm)));
          final content = await _cryptoService.decrypt(att.encryptedContent, entryKey);
          _archive.addFile(ArchiveFile('files/${entry.uuid}/${meta.filename}', content.length, content));
          attachments.add((
            uuid: att.uuid,
            filename: meta.filename,
            timestamp: meta.timestamp,
            size: meta.size,
          ));
        }

        // "Geteilt mit" auflisten
        final sharedWith = <ExportFriend>[];
        final friends = await _databaseService.getNotHiddenFriendsWithAccessLevel(entry.id);
        for (final friend in friends) {
          sharedWith.add((
            uuid: friend.user.uuid,
            username: friend.user.name,
            accessLevel: friend.accessLevel,
            publicKey: friend.user.publicKey,
          ));
        }

        // Datumsfelder zum String umwandeln
        final passwordTimestamp = payload.passwordTimestamp?.toIso8601String();
        final updatedAt = entry.updatedAt.toIso8601String();

        // CSV-Zeile schreiben
        csvRows.add([
          _csvEscape(entry.uuid),
          _csvEscape(payload.category),
          _csvEscape(payload.title),
          _csvEscape(payload.username),
          _csvEscape(payload.password),
          _csvEscape(passwordTimestamp ?? ''),
          _csvEscape(payload.url),
          _csvEscape(payload.notes),
          _csvEscape(payload.favicon),
          _csvEscape(updatedAt),
          _csvEscape(attachments.map((a) => '${a.uuid};${_csvSubEscape(a.filename)};${a.timestamp.toIso8601String()}').join('|')),
          _csvEscape(sharedWith.map((f) => '${f.uuid};${_csvSubEscape(f.username)};${f.accessLevel}').join('|')),
          payload.reportExcluded ? '1' : '',
        ]);

        // Eintrag der Kategorie zuordnen (für Markdown-Datei)
        (byCategory[payload.category] ??= []).add((payload: payload, attachments: attachments, sharedWith: sharedWith));

        // Fortschritt aktualisieren
        processed++;
        state = state.copyWith(processed: processed);
        await Future.delayed(const Duration(milliseconds: 10)); // Rendering-Frame freigeben

        // Wurde abgebrochen?
        if (state.isAborting) {
          state = state.copyWith(status: ExportActionStatus.aborted, isAborting: false);
          return;
        }
      }

      // 5. CSV-Datei in das Archiv legen
      final csv = Uint8List.fromList(utf8.encode('${csvRows.map((r) => r.join(',')).join('\r\n')}\r\n')); // laut RFC-4180 CSV Specification endet jede Zeile mit \r\n
      _archive.addFile(ArchiveFile('export.csv', csv.length, csv));

      // 6. Markdown-Datei erzeugen und in das Archiv legen
      final md = _buildMarkdown(byCategory, entries.length);
      final mdBytes = Uint8List.fromList(utf8.encode(md));
      _archive.addFile(ArchiveFile('export.md', mdBytes.length, mdBytes));

      // 7. UI-State aktualisieren
      state = state.copyWith(
        mdFile: AppFileMemory('export.md', mdBytes),
        mdBytes: mdBytes,
        status: ExportActionStatus.loaded,
      );

    } catch (e, st) {
      Logger().fatal('Fehler beim Generieren des Exports: $e', stack: st);
      state = state.copyWith(status: ExportActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  /// Führt ein Escaping nach der CSV-Spezifikation RFC-4180 durch.
  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\r') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Sub-Escaping für Felder mit Semikolon/Pipe-Struktur (attachments, shared_with).
  String _csvSubEscape(String value) {
    return value
        .replaceAll('\\', '\\\\')  // Backslash verdoppeln (zuerst!)
        .replaceAll('|', '\\|')    // Pipe-Zeichen mit Backslash escapen
        .replaceAll(';', '\\;');   // Semikolon mit Backslash escapen
  }

  /// Generiert eine Markdown-Datei aus den Einträgen.
  String _buildMarkdown(Map<String, List<({EntryPayload payload, List<ExportAttachment> attachments, List<ExportFriend> sharedWith})>> byCategory, int totalCount) {
    final buffer = StringBuffer();
    final date = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now().toLocal());
    final placeholder = _sessionService.settings?.categoryPlaceholder ?? 'Allgemein';
    int lineCount = 0;

    void writeln(String line) {
      buffer.writeln(line);
      lineCount++;
    }

    // --- Titel ---
    writeln('# ${_sessionService.vaultName} – Export vom $date');
    writeln('');
    writeln('Enthält $totalCount Einträge.');
    writeln('');

    // todo placeholder bei der Sortierung berücksichtigen
    final sortedCats = byCategory.keys.toList()..sort();

    for (final category in sortedCats) {
      writeln('---');
      writeln('## ${category.isEmpty ? placeholder : category}');
      writeln('');

      for (final e in byCategory[category]!) {
        final payload = e.payload;
        final attachments = e.attachments;
        final sharedWith = e.sharedWith;

        writeln('### ${payload.title}');

        if (payload.favicon.isNotEmpty) {
          writeln('![Favicon](data:image/png;base64,${payload.favicon})');
        }

        if (payload.username.isNotEmpty) {
          writeln('- **Benutzername**: ${payload.username}');
        }

        if (payload.password.isNotEmpty) {
          writeln('- **Passwort**: ${payload.password}');
        }

        if (payload.url.isNotEmpty) {
          writeln('- **URL**: ${payload.url}');
        }

        if (payload.notes.isNotEmpty) {
          writeln('- **Notizen**:');
          for (final s in payload.notes.split('\n')) {
            final trimmed = s.trim();
            if (trimmed.isNotEmpty) writeln('  - $trimmed');
          }
        }

        if (attachments.isNotEmpty) {
          writeln('- **Anhänge**:');
          for (final attachment in attachments) {
            writeln('  - ${attachment.filename} (${formatSize(attachment.size)})');
          }
        }

        if (sharedWith.isNotEmpty) {
          writeln('- **Geteilt mit**:');
          for (final friend in sharedWith) {
            writeln('  - ${friend.username} (${friend.accessLevel == 2 ? 'Schreibzugriff' : 'Lesezugriff'})');   // todo prüfen: was ist mit AccessLevel == 0 nach Rechteentzug?
          }
        }

        writeln('');

        if (lineCount >= _linesPerPage) {
          writeln(r'\pagebreak');
          writeln('');
          lineCount = 0;
        }
      }
    }

    return buffer.toString();
  }

  // ------------------------------------------------------------------------
  // --- Drucken und Exportieren ---
  // ------------------------------------------------------------------------

  /// Druckt die Markdown-Datei.
  Future<void> print() async {
    if (state.isBusy) return;
    state = state.copyWith(status: ExportActionStatus.progress, error: AppError.none());
    try {

      final bytes = state.mdBytes;
      if (bytes == null || bytes.isEmpty) throw Exception('Keine Markdown-Datei zum Drucken vorhanden.');
      await MarkdownRenderer(bytes).print(state.mdFile.name);
      state = state.copyWith(status: ExportActionStatus.loaded);

    } catch (e, st) {
      Logger().fatal('Fehler beim Drucken: $e', stack: st);
      state = state.copyWith(status: ExportActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }
  /// Speichert das ZIP-Archiv.
  ///
  /// Verschlüsselung: AES-256 (AE-1) via `ZipEncoder(password:)` wenn
  /// [ExportFormData.encrypt] gesetzt ist. archive 4.x schreibt automatisch
  /// AE-1 wenn ein Passwort angegeben wird.
  Future<void> export() async {
    if (state.isBusy) return;
    final formData = state.formData;

    // 1. UI-State aktualisieren
    state = state.copyWith(status: ExportActionStatus.progress, error: AppError.none());

    try {

      // 2. ZIP kodieren
      // archive 4.x: ZipEncoder(password:) erzeugt AES-256-verschlüsseltes ZIP (AE-1).
      // Kompatibel mit 7-Zip und WinRAR; Windows Explorer unterstützt AES-256-ZIP nicht.
      final password = formData.encrypt && formData.password.isNotEmpty ? formData.password : null;
      final zipBytes = Uint8List.fromList(ZipEncoder(password: password).encode(_archive));

      // 3. Datei speichern
      final vaultName = _sessionService.vaultName;
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await downloadAppFile(AppFileMemory('$vaultName-$date.zip', zipBytes));

      // 4. UI-State aktualisieren
      state = state.copyWith(status: ExportActionStatus.success);

    } catch (e, st) {
      Logger().fatal('Fehler beim Exportieren: $e', stack: st);
      state = state.copyWith(
        status: ExportActionStatus.failure,
        error: AppError(ErrorCode.unknown),
      );
    }
  }

  /// Signalisiert dem laufenden Vorgang, dass er abgebrochen werden soll.
  void abortLoading() {
    state = state.copyWith(isAborting: true);
  }

  // ------------------------------------------------------------------------
  // --- Setter für den UI-State (synchron) ---
  // ------------------------------------------------------------------------

  /// Setter für Switch "ZIP-Archiv verschlüsseln"
  void setEncrypt(bool value) {
    if (value == state.formData.encrypt) return;
    final error = state.error.field == 'encrypt' ? AppError.none() : null;
    final formData = state.formData.copyWith(encrypt: value);
    state = state.copyWith(formData: formData, status: ExportActionStatus.loaded, error: error);
  }

  /// Setter für Passwort
  void setPassword(String value) {
    if (value == state.formData.password) return;
    final error = state.error.field == 'password' ? AppError.none() : null;
    final formData = state.formData.copyWith(password: value);
    state = state.copyWith(formData: formData, status: ExportActionStatus.loaded, error: error);
  }
}