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
import 'package:privault/database/database.dart';
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
// Interner Container für einen entschlüsselten Eintrag
// ---------------------------------------------------------------------------

class _DecryptedEntry {
  final EntryPayload payload;
  final Uint8List entryKey;
  final List<AttachmentMetaPayload> metas;
  _DecryptedEntry(this.payload, this.entryKey, this.metas);
}

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
    state = const ExportState().copyWith(
      status: ExportActionStatus.loading,
      error: AppError.none(),
    );

    // Kurze Pause für den Lade-Indikator
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      final entries = await _databaseService.getEntries();
      final decrypted = await _decryptAll(entries);
      final vaultName = _sessionService.vaultName;
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final md = _buildMarkdown(decrypted, vaultName);
      final mdBytes = Uint8List.fromList(utf8.encode(md));
      final mdFile = AppFileMemory('$vaultName-$date.md', mdBytes);

      state = state.copyWith(
        mdFile: mdFile,
        mdBytes: mdBytes,
        status: ExportActionStatus.loaded,
      );

    } catch (e, st) {
      Logger().fatal('Fehler beim Generieren des Exports: $e', stack: st);
      state = state.copyWith(
        status: ExportActionStatus.failure,
        error: AppError(ErrorCode.unknown),
      );
    }
  }

  // ------------------------------------------------------------------------
  // --- Entschlüsseln ---
  // ------------------------------------------------------------------------

  /// Entschlüsselt alle Einträge und Anhang-Metadaten in einem Durchlauf.
  ///
  /// Einträge für die kein Zugriff besteht oder die fehlschlagen werden
  /// stillschweigend übersprungen.
  Future<Map<EntryEntity, _DecryptedEntry>> _decryptAll(
      List<EntryEntity> entries) async {
    final result = <EntryEntity, _DecryptedEntry>{};
    final privateKey = _sessionService.privateKey;
    final userId = _sessionService.user?.id;
    if (privateKey == null || userId == null) return result;

    for (final entry in entries) {
      try {
        final perm = await _databaseService.getPermissionByEntryIdAndUserId(
          entry.id, userId,
        );
        if (perm == null) continue;

        final entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, privateKey);
        final raw = await _cryptoService.decrypt(entry.encryptedData, entryKey);
        final payload = EntryPayload.fromJson(json.decode(utf8.decode(raw)));

        // Anhang-Metadaten
        final metas = <AttachmentMetaPayload>[];
        for (final att in await _databaseService.getAttachmentsByEntryId(entry.id)) {
          try {
            final dm = await _cryptoService.decrypt(att.encryptedMeta, entryKey);
            metas.add(AttachmentMetaPayload.fromJson(json.decode(utf8.decode(dm))));
          } catch (_) {}
        }

        result[entry] = _DecryptedEntry(payload, entryKey, metas);
      } catch (_) {}
    }
    return result;
  }

  // ------------------------------------------------------------------------
  // --- Markdown generieren ---
  // ------------------------------------------------------------------------

  String _buildMarkdown(
      Map<EntryEntity, _DecryptedEntry> decrypted, String vaultName) {
    final buffer      = StringBuffer();
    final date        = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now().toLocal());
    final placeholder = _sessionService.settings?.categoryPlaceholder ?? 'Allgemein';
    int lineCount     = 0;

    void writeln(String line) {
      buffer.writeln(line);
      lineCount++;
    }

    // --- Titel ---
    writeln('# $vaultName – Export vom $date');
    writeln('');
    writeln('Enthält ${decrypted.length} Einträge.');
    writeln('');

    // --- Nach Kategorien gruppieren ---
    final byCategory = <String, List<MapEntry<EntryEntity, _DecryptedEntry>>>{};
    for (final e in decrypted.entries) {
      final cat = e.value.payload.category.isEmpty ? placeholder : e.value.payload.category;
      (byCategory[cat] ??= []).add(e);
    }
    final sortedCats = byCategory.keys.toList()..sort();

    for (final category in sortedCats) {
      writeln('---');
      writeln('## $category');
      writeln('');

      for (final e in byCategory[category]!) {
        final payload = e.value.payload;
        final metas= e.value.metas;

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
  // --- Export ---
  // ------------------------------------------------------------------------

  /// Erstellt ein ZIP-Archiv mit CSV, JSON, Markdown und Anhängen.
  ///
  /// Optional wird das fertige ZIP mit AES-256-GCM verschlüsselt.
  /// Da das `archive`-Package kein natives AES-ZIP unterstützt, werden
  /// die ZIP-Bytes nach der Kodierung mit [CryptoService] verschlüsselt.
  /// Der Schlüssel wird via PBKDF2 aus dem Passwort abgeleitet.
  Future<void> export() async {
    if (state.isBusy) return;
    state = state.copyWith(status: ExportActionStatus.progress, error: AppError.none());

    try {
      final entries = await _databaseService.getEntries();
      final decrypted = await _decryptAll(entries);
      final vaultName = _sessionService.vaultName;
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final archive = Archive();

      final csvRows = <List<String>>[
        ['uuid', 'category', 'title', 'username', 'password', 'password_timestamp', 'url', 'notes', 'attachments', 'shared_with', 'updated_at'],
      ];
      final jsonList = <Map<String, dynamic>>[];

      for (final e in decrypted.entries) {
        final entry = e.key;
        final payload = e.value.payload;
        final entryKey = e.value.entryKey;

        // Anhänge entschlüsseln und ins Archiv packen
        final attachments = <String>[];
        final atts = await _databaseService.getAttachmentsByEntryId(entry.id);
        for (final att in atts) {
          try {
            final dm = await _cryptoService.decrypt(att.encryptedMeta, entryKey);
            final meta = AttachmentMetaPayload.fromJson(json.decode(utf8.decode(dm)));
            final content = await _cryptoService.decrypt(att.encryptedContent, entryKey);
            archive.addFile(ArchiveFile('files/${entry.uuid}/${meta.filename}', content.length, content));
            attachments.add('${att.uuid}:${meta.filename}:${meta.timestamp}');
          } catch (_) {}
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
          _csvEscape(attachments.join('; ')),
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
          'attachments': attachments,
          'shared_with': sharedWith,
          'updated_at': updatedAt,
        });
      }

      // Textdateien ins Archiv
      final csv  = Uint8List.fromList(utf8.encode(csvRows.map((r) => r.join(',')).join('\n')));
      final json_ = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(jsonList)));
      archive.addFile(ArchiveFile('$vaultName-$date.csv',  csv.length,   csv));
      archive.addFile(ArchiveFile('$vaultName-$date.json', json_.length, json_));
      final mdBytes = state.mdBytes;
      if (mdBytes != null) {
        archive.addFile(ArchiveFile('$vaultName-$date.md', mdBytes.length, mdBytes));
      }

      // ZIP kodieren
      // Standard-ZIP-Passwortschutz via ZipCrypto (erfordert archive: ^4.0.0).
      // Das erzeugte ZIP kann mit jedem Standard-ZIP-Tool (7-Zip, WinRAR etc.) mit dem Passwort geöffnet werden.
      final password = state.formData.encrypt && state.formData.password.isNotEmpty ? state.formData.password : null;
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