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

// ---------------------------------------------------------------------------
// ExportNotifier
// ---------------------------------------------------------------------------

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

    // 1. Ladeanzeige einblenden
    state = const ExportState().copyWith(status: ExportActionStatus.loading, error: AppError.none());
    //await WidgetsBinding.instance.endOfFrame; // Warten bis Flutter den Ladeindikator gerendert hat.

    try {

      if (_sessionService.privateKey == null) throw Exception('Der private Schlüssel ist nicht entpackt.');
      if (_sessionService.user == null) throw Exception("Der Benutzer liegt nicht in der Session.");

      // 2. Alle Einträge abfragen
      final entries = await _databaseService.getEntries();
      state = state.copyWith(totalCount: entries.length);

      // 3. Einträge durchlaufen und nach Kategorie sortieren
      int processed = 0;
      final byCategory = <String, List<({EntryPayload payload, List<AttachmentMetaPayload> metas})>>{};
      for (final entry in entries) {

        // Eintrag entschlüsseln
        final perm = await _databaseService.getPermissionByEntryIdAndUserId(entry.id, _sessionService.user!.id);
        if (perm == null) throw Exception('Zum Eintrag ${entry.id} sind keine Zugriffsrechte gespeichert.');
        final entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, _sessionService.privateKey!);
        final raw = await _cryptoService.decrypt(entry.encryptedData, entryKey);
        final payload = EntryPayload.fromJson(json.decode(utf8.decode(raw)));

        // Anhang-Metadaten entschlüsseln
        final metas = <AttachmentMetaPayload>[];
        for (final att in await _databaseService.getAttachmentsByEntryId(entry.id)) {
          final dm = await _cryptoService.decrypt(att.encryptedMeta, entryKey);
          metas.add(AttachmentMetaPayload.fromJson(json.decode(utf8.decode(dm))));
        }

        // Kategorie zuordnen
        (byCategory[payload.category] ??= []).add((payload: payload, metas: metas));

        // Fortschritt aktualisieren
        processed++;
        state = state.copyWith(currentCount: processed);
        await Future.delayed(Duration.zero); // Rendering-Frame freigeben

        // Wurde abgebrochen?
        if (state.isAborting) {
          state = const ExportState().copyWith(status: ExportActionStatus.initial);
          return;
        }
      }

      // 4. Markdown mit den sortierten Einträgen aufbauen
      final md = _buildMarkdown(byCategory, entries.length);

      // 5. UI-State aktualisieren
      final mdBytes = Uint8List.fromList(utf8.encode(md));
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final mdFile = AppFileMemory('${_sessionService.vaultName}-$date.md', mdBytes);
      state = state.copyWith(
        mdFile: mdFile,
        mdBytes: mdBytes,
        status: ExportActionStatus.loaded,
      );

    } catch (e, st) {
      Logger().fatal('Fehler beim Generieren des Exports: $e', stack: st);
      state = state.copyWith(status: ExportActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Markdown generieren ---
  // ------------------------------------------------------------------------

  String _buildMarkdown(Map<String, List<({EntryPayload payload, List<AttachmentMetaPayload> metas})>> byCategory, int totalCount) {
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
        final metas = e.metas;

        writeln('### ${payload.title}');
        if (payload.favicon.isNotEmpty) writeln('![Favicon](data:image/png;base64,${payload.favicon})');
        writeln('');

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
          writeln('');
        }

        if (metas.isNotEmpty) {
          writeln('- **Anhänge**:');
          for (final meta in metas) {
            writeln('  - ${meta.filename} (${formatSize(meta.size)})');
          }
          writeln('');
        }

        // todo "Geteilt mit" auflisten (Name, Zugriffsrecht)

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
  // --- Drucken ---
  // ------------------------------------------------------------------------

  Future<void> print() async {
    if (state.isBusy) return;
    state = state.copyWith(status: ExportActionStatus.progress, error: AppError.none());
    try {
      final bytes = state.mdBytes;
      if (bytes == null || bytes.isEmpty) throw StateError('Keine Daten.');
      await MarkdownRenderer(bytes).print(state.mdFile.name);
      state = state.copyWith(status: ExportActionStatus.loaded);
    } catch (e, st) {
      Logger().fatal('Fehler beim Drucken: $e', stack: st);
      state = state.copyWith(status: ExportActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Export: ZIP-Archiv erstellen ---
  // ------------------------------------------------------------------------

  /// Erstellt ein ZIP-Archiv mit CSV, JSON, Markdown und Anhängen.
  ///
  /// Verschlüsselung: AES-256 (AE-1) via `ZipEncoder(password:)` wenn
  /// [ExportFormData.encrypt] gesetzt ist. archive 4.x schreibt automatisch
  /// AE-1 wenn ein Passwort angegeben wird.
  Future<void> export() async {
    if (state.isBusy) return;

    final formData = state.formData;

    int processed = 0;

    // 1. UI-State aktualisieren
    state = state.copyWith(
      totalCount: 0,
      currentCount: processed,
      isAborting: false,
      status: ExportActionStatus.progress,
      error: AppError.none(),
    );

    try {

      if (_sessionService.privateKey == null) throw Exception('Der private Schlüssel ist nicht entpackt.');
      if (_sessionService.user == null) throw Exception("Der Benutzer liegt nicht in der Session.");

      // 2. Alle Einträge abfragen
      final entries = await _databaseService.getEntries();
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // 3. Gesamtanzahl für die Fortschrittsanzeige im State setzen
      state = state.copyWith(totalCount: entries.length, currentCount: 0);

      // 4. Zieldateien initialisieren
      final archive = Archive();
      final csvRows = <List<String>>[
        ['uuid', 'category', 'title', 'username', 'password', 'password_timestamp', 'url', 'notes', 'attachments', 'shared_with', 'updated_at'],
      ];
      final jsonList = <Map<String, dynamic>>[];

      // 5. Einträge durchlaufen, CSV- und JSON-Datei erstelle, und Attachments extrahieren...
      for (final entry in entries) {

        // Eintrag entschlüsseln
        final perm = await _databaseService.getPermissionByEntryIdAndUserId(entry.id, 1);
        if (perm == null) throw Exception('Zum Eintrag ${entry.id} sind keine Zugriffsrechte gespeichert.');
        final entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, _sessionService.privateKey!);
        final raw = await _cryptoService.decrypt(entry.encryptedData, entryKey);
        final payload = EntryPayload.fromJson(json.decode(utf8.decode(raw)));

        // Anhänge des Eintrags entschlüsseln und ins Archiv packen
        final attachmentNames = <String>[];
        for (final att in await _databaseService.getAttachmentsByEntryId(entry.id)) {
          final dm = await _cryptoService.decrypt(att.encryptedMeta, entryKey);
          final meta = AttachmentMetaPayload.fromJson(json.decode(utf8.decode(dm)));
          final content = await _cryptoService.decrypt(att.encryptedContent, entryKey);
          archive.addFile(ArchiveFile('files/${entry.uuid}/${meta.filename}', content.length, content));
          attachmentNames.add('${att.uuid}:${meta.filename}:${meta.timestamp}');
        }

        // "Geteilt mit" auflisten
        final sharedWith = <String>[];
        final friends = await _databaseService.getNotHiddenFriendsWithAccessLevel(entry.id);
        for (final friend in friends) {
          sharedWith.add('${friend.user.uuid}:${friend.user.name}:${friend.accessLevel}');
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
          _csvEscape(attachmentNames.join('; ')),
          _csvEscape(sharedWith.join('; ')),
          _csvEscape(updatedAt),
        ]);

        // JSON-Eintrag schreiben
        jsonList.add({
          'uuid': entry.uuid,
          'category': payload.category,
          'title': payload.title,
          'username': payload.username,
          'password': payload.password,
          'passwordTimestamp': passwordTimestamp,
          'url': payload.url,
          'notes': payload.notes,
          'favicon': payload.favicon,
          'attachments': attachmentNames,
          'shared_with': sharedWith,
          'updated_at': updatedAt,
        });

        // Fortschritt aktualisieren
        processed++;
        state = state.copyWith(currentCount: processed);
        await Future.delayed(Duration.zero); // Rendering-Frame freigeben

        // Abbruch prüfen
        if (state.isAborting) {
          state = state.copyWith(status: ExportActionStatus.loaded, isAborting: false);
          return;
        }
      }

      // Textdateien ins Archiv
      final vaultName = _sessionService.vaultName;
      final csv = Uint8List.fromList(utf8.encode(csvRows.map((r) => r.join(',')).join('\n')));
      final json_ = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(jsonList)));
      archive.addFile(ArchiveFile('$vaultName-$date.csv',  csv.length,   csv));
      archive.addFile(ArchiveFile('$vaultName-$date.json', json_.length, json_));
      final mdBytes = state.mdBytes;
      if (mdBytes != null) {
        archive.addFile(ArchiveFile('$vaultName-$date.md', mdBytes.length, mdBytes));
      }

      // ZIP kodieren
      // archive 4.x: ZipEncoder(password:) erzeugt AES-256-verschlüsseltes ZIP (AE-1).
      // Kompatibel mit 7-Zip und WinRAR; Windows Explorer unterstützt AES-256-ZIP nicht.
      final password = formData.encrypt && formData.password.isNotEmpty ? formData.password : null;
      final zipBytes = Uint8List.fromList(ZipEncoder(password: password).encode(archive));

      // Datei speichern
      await downloadAppFile(AppFileMemory('$vaultName-$date.zip', zipBytes));

      // UI-State aktualisieren
      state = state.copyWith(status: ExportActionStatus.success);

    } catch (e, st) {
      Logger().fatal('Fehler beim Exportieren: $e', stack: st);
      state = state.copyWith(
        status: ExportActionStatus.failure,
        error: AppError(ErrorCode.unknown),
      );
    }
  }

  // ------------------------------------------------------------------------
  // --- Abbruch ---
  // ------------------------------------------------------------------------

  /// Signalisiert dem laufenden Vorgang, dass er abgebrochen werden soll.
  void cancelOperation() {
    if (state.isBusy) {
      state = state.copyWith(isAborting: true);
    }
  }

  // ------------------------------------------------------------------------
  // --- Setter für den UI-State (synchron) ---
  // ------------------------------------------------------------------------

  /// Setter für Switch "ZIP-Archiv verschlüsseln"
  void setEncrypt(bool value) =>
      state = state.copyWith(formData: state.formData.copyWith(encrypt: value));

  /// Setter für Passwort
  void setPassword(String value) =>
      state = state.copyWith(formData: state.formData.copyWith(password: value));

  // ------------------------------------------------------------------------
  // --- Hilfsmethoden ---
  // ------------------------------------------------------------------------

  /// Maskiert CSV-Trennzeichen und CSV-Feldbegrenzungszeichen
  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""').replaceAll('\n', '\\n')}"';
    }
    return value;
  }

}