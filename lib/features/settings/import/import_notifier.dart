import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/settings/import/import_form_data.dart';
import 'package:privault/features/settings/import/import_parser.dart';
import 'package:privault/features/settings/import/import_state.dart';
import 'package:privault/features/settings/import/import_statistics.dart';
import 'package:privault/features/settings/import/parser/bitwarden_json_parser.dart';
import 'package:privault/features/settings/import/parser/keepass_xml_parser.dart';
import 'package:privault/models/payloads/attachment_meta_payload.dart';
import 'package:privault/models/payloads/entry_payload.dart';
import 'package:privault/models/payloads/import_payload.dart';
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

  /// Temporärer Speicher für die geparsten Daten vor dem Import.
  ImportPayload? _parsedPayload;

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
    _parsedPayload = null;
    state = const ImportState();
  }

  // ------------------------------------------------------------------------
  // --- Speichern ---
  // ------------------------------------------------------------------------

  /// Startet den Importprozess.
  Future<void> import() async {
    if (state.isBusy) return;

    final formData = state.formData;

    // 1. UI-State aktualisieren
    state = state.copyWith(
      formData: formData,
      status: ImportActionStatus.parse, error: AppError.none(),
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

      // todo 3. Sicherheitsabfrage: "Der Tresor wird in eine unverschlüsselte Datei exportiert. Fortfahren?"

      // 4. Parser auswählen
      ImportParser parser;
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

      // 5. Datei parsen
      _parsedPayload = await parser.parse();
      if (_parsedPayload == null) {
        state = state.copyWith(status: ImportActionStatus.failure, error: AppError(ErrorCode.validationFailed, text: parser.errorText ?? "Die Datei entspricht nicht dem Format", field: 'file'));
        return;
      }

      // 6. Daten importieren
      await _executeImport();

    } catch (e, st) {
      Logger().fatal("Fehler beim Importieren: $e", stack: st);
      state = state.copyWith(status: ImportActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  /// Führt den Import der vorbereiteten Daten durch.
  Future<void> _executeImport({List<String>? skipUuids}) async {
    if (_parsedPayload == null) return;

    state = state.copyWith(status: ImportActionStatus.import, error: AppError.none());

    try {
      final currentUser = _sessionService.user;
      if (currentUser == null) throw Exception("Kein Benutzer angemeldet.");

      final List<({EntryEntity entry, PermissionEntity permission, List<AttachmentEntity> attachments})> itemsToImport = [];

      for (final importEntry in _parsedPayload!) {
        // Überspringen, wenn gewünscht (Konfliktbehandlung)
        if (skipUuids != null && skipUuids.contains(importEntry.uuid)) continue;

        // 1. Validierung

        // Prüfen, ob Titel gesetzt ist
        if (importEntry.title.isEmpty) {
          state = state.copyWith(
            status: ImportActionStatus.failure,
            error: AppError(ErrorCode.valueRequired, text: "Titel fehlt (Zeile ${importEntry.lineIndex + 1})."),
          );
          return;
        }

        // Prüfen, ob die UUID des Eintrag bereits existiert
        final existing = await _databaseService.getEntryByUuid(importEntry.uuid);
        if (existing != null) {
          state = state.copyWith(
            status: ImportActionStatus.failure,
            error: AppError(ErrorCode.vaultAlreadyExists, text: "UUID des Eintrags '${importEntry.title}' existiert bereits (Zeile ${importEntry.lineIndex + 1})."),
          );
          return;
        }

        // 2. Daten vorbereiten

        // Payload bauen
        final payload = EntryPayload(
          category: importEntry.category,
          title: importEntry.title,
          username: importEntry.username,
          password: importEntry.password,
          passwordTimestamp: importEntry.passwordTimestamp,
          url: importEntry.url,
          notes: importEntry.notes,
          favicon: importEntry.favicon,
        );

        // AES-Key generieren und per RSA verschlüsseln
        final entryKey = _cryptoService.generateAesKey();
        final encryptedEntryKey = await _cryptoService.encryptRsa(entryKey, currentUser.publicKey);

        // Payload per AES-Key verschlüsseln
        final payloadBytes = Uint8List.fromList(utf8.encode(json.encode(payload.toJson())));
        final encryptedData = await _cryptoService.encrypt(payloadBytes, entryKey);

        final entry = EntryEntity(
          id: 0,
          uuid: importEntry.uuid.isEmpty ? const Uuid().v4() : importEntry.uuid,
          category: importEntry.category,
          title: importEntry.title,
          url: importEntry.url,
          notes: importEntry.notes,
          favicon: importEntry.favicon,
          encryptedData: encryptedData,
          creatorId: currentUser.id,
          updaterId: currentUser.id,
          updatedAt: importEntry.updatedAt,
        );

        final permission = PermissionEntity(
          id: 0,
          entryId: 0,
          userId: 1,
          encryptedKey: encryptedEntryKey,
          accessLevel: 3, // Besitzer
        );

        // 3. Anhänge vorbereiten (wie in DetailNotifier)
        final List<AttachmentEntity> attachments = [];
        for (final importAtt in importEntry.attachments) {
          final metaPayload = AttachmentMetaPayload(
            filename: importAtt.filename,
            mime: importAtt.mime ?? 'application/octet-stream', // todo aus helper_dart Funktion nutzen, um Mime zu bestimmen
            size: importAtt.blob.length,
            thumbnail: null, // todo Thumbnail-Generierung hinzufügen
            timestamp: importAtt.timestamp ?? DateTime.now().toUtc(),
          );

          final encryptedMeta = await _cryptoService.encrypt(Uint8List.fromList(utf8.encode(json.encode(metaPayload.toJson()))), entryKey);
          final encryptedContent = await _cryptoService.encrypt(importAtt.blob, entryKey);

          attachments.add(AttachmentEntity(
            id: 0,
            uuid: const Uuid().v4(),
            entryId: 0,
            encryptedMeta: encryptedMeta,
            encryptedContent: encryptedContent,
            isSynced: false,
          ));
        }

        itemsToImport.add((entry: entry, permission: permission, attachments: attachments)); // todo statt permission brauchen wir nur encryptedEntryKey
      }

      // 4. In Datenbank schreiben
      await _databaseService.import(itemsToImport);

      // 5. State aktualisieren
      state = state.copyWith(
        formData: const ImportFormData(),
        statistics: ImportStatistics(
          added: itemsToImport.length,
          skipped:  skipUuids?.length ?? 0,
        ),
        status: ImportActionStatus.success,
      );

    } catch (e, st) {
      Logger().fatal("Fehler beim Importieren: $e", stack: st);
      state = state.copyWith(status: ImportActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  /// Überspringt den aktuellen Konflikt und setzt den Import fort.
  Future<void> skipConflict() async {
    if (state.status != ImportActionStatus.failure || state.error.field == null) return;
    
    final conflictUuid = state.error.field!;
    await _executeImport(skipUuids: [conflictUuid]);
  }

  // ------------------------------------------------------------------------
  // --- Setter für den UI-State (synchron) ---
  // ------------------------------------------------------------------------

  /// Setter für neues Passwort
  void setFormat(ImportFileFormat value) {
    final error = state.error.field == 'format' ? AppError.none() : null;
    final formData = state.formData.copyWith(format: value);
    state = state.copyWith(formData: formData, error: error);
  }

  /// Setter für bisheriges Passwort
  void setFile(String value) {
    final error = state.error.field == 'file' ? AppError.none() : null;
    final formData = state.formData.copyWith(file: value);
    state = state.copyWith(formData: formData, error: error);
  }
}
