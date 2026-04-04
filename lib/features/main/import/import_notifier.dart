import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/helper.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/main/import/import_form_data.dart';
import 'package:privault/features/main/import/parser.dart';
import 'package:privault/features/main/import/import_state.dart';
import 'package:privault/features/main/import/parser/bitwarden_json_parser.dart';
import 'package:privault/features/main/import/parser/keepass_xml_parser.dart';
import 'package:privault/models/payloads/attachment_meta_payload.dart';
import 'package:privault/models/payloads/entry_payload.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';
import 'package:uuid/uuid.dart';

final importProvider = NotifierProvider<ImportNotifier, ImportState>(() {
  return ImportNotifier();
});

class ImportNotifier extends Notifier<ImportState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

  late final CryptoService _cryptoService;
  late final DatabaseService _databaseService;
  late final SessionService _sessionService;

  // ------------------------------------------------------------------------
  // --- Interne Variablen (nicht reaktiv, nicht UI‑relevant) ---
  // ------------------------------------------------------------------------

  // keine

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert einen Notifier.
  ///
  /// Die Verwendung von `Ref.watch` oder `Ref.listen` innerhalb dieser Methode ist unbedenklich.
  /// Ändert sich eine Abhängigkeit dieses Notifiers (bei Verwendung von `Ref.watch`), wird der Build-Prozess erneut ausgeführt. Der Notifier selbst wird jedoch nicht neu erstellt. Seine Instanz bleibt zwischen den Build-Ausführungen erhalten.
  @override
  ImportState build() {
    // Dienste aus getIt holen
    _cryptoService = getIt<CryptoService>();
    _databaseService = getIt<DatabaseService>();
    _sessionService = getIt<SessionService>();

    // Initialer State
    return const ImportState();
  }

  /// Lädt die Daten für die Anzeige.
  Future<void> load() async {
    if (state.isBusy) return;

    // UI-State zurücksetzen
    state = const ImportState();
  }

  // ------------------------------------------------------------------------
  // --- Import ---
  // ------------------------------------------------------------------------

  /// Startet den Importprozess.
  Future<void> import() async {
    if (state.isBusy) return;

    final formData = state.formData;

    // 1. UI-State aktualisieren
    state = state.copyWith(
      formData: formData,
      status: ImportActionStatus.progress, error: AppError.none(),
    );

    try {

      // 2. Benutzereingabe validieren
      if (formData.format == ImportFileFormat.none) {
        state = state.copyWith(status: ImportActionStatus.failure, error: AppError(ErrorCode.valueRequired, field: 'format'));
        return;
      }
      if (formData.file.isEmpty) {
        state = state.copyWith(status: ImportActionStatus.failure, error: AppError(ErrorCode.valueRequired, field: 'file'));
        return;
      }

      // 3. Datei parsen
      Parser parser;
      switch (formData.format) {
        case ImportFileFormat.keepassXml:
          parser = KeepassXmlParser(formData.file);
          break;
        case ImportFileFormat.bitwardenJson:
          parser = BitwardenJsonParser(formData.file);
          break;
        default:
          state = state.copyWith(status: ImportActionStatus.failure, error: AppError(ErrorCode.valueInvalid, field: 'format'));
          return;
      }
      final parsedPayload = await parser.parse();
      if (parsedPayload == null) {
        state = state.copyWith(status: ImportActionStatus.failure, error: AppError(ErrorCode.unknown, text: parser.errorText));
        return;
      }

      // Daten für den Import aufbereiten...

      if (_sessionService.user == null) throw Exception("Der Benutzer liegt nicht in der Session.");
      final user = _sessionService.user!;

      final List<({EntryEntity entry, String encryptedEntryKey, List<({String uuid, String encryptedMeta, String encryptedContent})> attachments})> batch = [];
      for (final parsedEntry in parsedPayload) {

        // 4. Daten validieren
        // Prüfen, ob Titel gesetzt ist
        if (parsedEntry.title.isEmpty) {
          state = state.copyWith(status: ImportActionStatus.failure, error: AppError(ErrorCode.valueRequired, text: 'Titel des Eintrags fehlt${parsedEntry.lineNumber != null ? ' (Zeile $parsedEntry.lineNumber)' : ''}.'));
          return;
        }
        // Prüfen, ob die UUID des Eintrag bereits existiert
        if (parsedEntry.uuid.isNotEmpty) {
          final existing = await _databaseService.getEntryByUuid(parsedEntry.uuid);
          if (existing != null) {
            state = state.copyWith(status: ImportActionStatus.failure, error: AppError(ErrorCode.vaultAlreadyExists, text: "UUID des Eintrags existiert bereits${parsedEntry.lineNumber != null ? ' (Zeile $parsedEntry.lineNumber)' : ''}."));
            return;
          }
        }

        // 5. Favicon laden, falls URL sich geändert hat
        String favicon = parsedEntry.favicon;
        if (favicon.isEmpty && parsedEntry.url.isNotEmpty) {
          final icon = await downloadFavicon(parsedEntry.url);
          if (icon != null) favicon = icon;
        }

        // 6. Payload für den verschlüsselten Eintrag bauen
        final payload = EntryPayload(
          category: parsedEntry.category,
          title: parsedEntry.title,
          username: parsedEntry.username,
          password: parsedEntry.password,
          passwordTimestamp: parsedEntry.passwordTimestamp,
          url: parsedEntry.url,
          notes: parsedEntry.notes,
          favicon: favicon,
        );

        // 7. AES-Key generieren und per RSA verschlüsseln
        final entryKey = _cryptoService.generateAesKey();
        final encryptedEntryKey = await _cryptoService.encryptRsa(entryKey, user.publicKey);

        // 8. Payload per AES-Key verschlüsseln
        final payloadBytes = Uint8List.fromList(utf8.encode(json.encode(payload.toJson())));
        final encryptedData = await _cryptoService.encrypt(payloadBytes, entryKey);

        // 9. Entität für den Eintrag bauen
        final entry = EntryEntity(
          id: 0,
          uuid: parsedEntry.uuid.isEmpty ? const Uuid().v4() : parsedEntry.uuid,
          category: parsedEntry.category,
          title: parsedEntry.title,
          url: parsedEntry.url,
          notes: parsedEntry.notes,
          favicon: favicon,
          encryptedData: encryptedData,
          creatorId: user.id,
          updaterId: user.id,
          updatedAt: parsedEntry.updatedAt ?? DateTime.now().toUtc(),
        );

        // Dateianhänge durchlaufen...
        final List<({String uuid, String encryptedMeta, String encryptedContent})> attachments = [];
        for (final attachment in parsedEntry.attachments) {
          final mimeType = attachment.mime.isNotEmpty ? attachment.mime : getMimeType(attachment.filename);

          // 10. Thumbnail erzeugen (wenn es ein Bild ist)
          String? thumbnailBase64;
          if (mimeType.startsWith('image/')) {
            thumbnailBase64 = await createThumbnail(attachment.blob);
          }

          // 11. Metadaten der Datei zusammenstellen
          final metaPayload = AttachmentMetaPayload(
            filename: attachment.filename,
            mime: mimeType,
            size: attachment.blob.length,
            thumbnail: thumbnailBase64,
            timestamp: attachment.timestamp ?? DateTime.now().toUtc(),
          );

          // 12. Metadaten und Dateiinhalt verschlüsseln (AES)
          final encryptedMeta = await _cryptoService.encrypt(Uint8List.fromList(utf8.encode(json.encode(metaPayload.toJson()))), entryKey);
          final encryptedContent = await _cryptoService.encrypt(attachment.blob, entryKey);

          attachments.add((
            uuid: const Uuid().v4(),
            encryptedMeta: encryptedMeta,
            encryptedContent: encryptedContent,
          ));
        }

        // 13. Alles zusammen in eine Batch hinzufügen
        batch.add((
          entry: entry,
          encryptedEntryKey: encryptedEntryKey,
          attachments: attachments
        ));
      }

      // 14. Batch in Datenbank schreiben
      await _databaseService.import(batch);

      // 15. State aktualisieren
      state = state.copyWith(
        formData: const ImportFormData(),
        addedCount: batch.length,
        status: ImportActionStatus.success,
      );

    } catch (e, st) {
      Logger().fatal("Fehler beim Importieren: $e", stack: st);
      state = state.copyWith(status: ImportActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Setter für den UI-State (synchron) ---
  // ------------------------------------------------------------------------

  /// Setter für neues Passwort
  void setFormat(ImportFileFormat value) {
    final error = state.error.field == 'format' ? AppError.none() : null;
    final formData = state.formData.copyWith(format: value);
    state = state.copyWith(formData: formData, status: ImportActionStatus.initial, error: error);
  }

  /// Setter für bisheriges Passwort
  void setFile(String value) {
    final error = state.error.field == 'file' ? AppError.none() : null;
    var formData = state.formData.copyWith(file: value);

    // Automatische Formaterkennung, wenn noch keins gewählt wurde
    if (formData.format == ImportFileFormat.none) {
      final extension = value.split('.').last.toLowerCase();
      if (extension == 'xml') {
        formData = formData.copyWith(format: ImportFileFormat.keepassXml);
      } else if (extension == 'json') {
        formData = formData.copyWith(format: ImportFileFormat.bitwardenJson);
      }
    }

    state = state.copyWith(formData: formData, status: ImportActionStatus.initial, error: error);
  }
}
