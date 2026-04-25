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
import 'package:privault/features/main/import/parsers/bitwarden_json_parser.dart';
import 'package:privault/features/main/import/parsers/keepass_xml_parser.dart';
import 'package:privault/features/main/import/parsers/onepassword_1pux_parser.dart';
import 'package:privault/features/main/import/parsers/privault_zip_parser.dart';
import 'package:privault/models/payloads/attachment_meta_payload.dart';
import 'package:privault/models/payloads/entry_payload.dart';
import 'package:privault/models/payloads/index_payload.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app_file.dart';

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

    int added = 0;
    int skipped = 0;

    // 1. UI-State aktualisieren
    state = state.copyWith(
      totalCount: 0,
      addedCount: added,
      skippedCount: skipped,
      isAborting: false,
      status: ImportActionStatus.progress,
      error: AppError.none(),
    );

    try {
      if (_sessionService.user == null) throw Exception("Der Benutzer liegt nicht in der Session.");
      final user = _sessionService.user!;

      // 2. Benutzereingabe validieren
      if (formData.format == ImportFileFormat.none) {
        state = state.copyWith(status: ImportActionStatus.failure, error: AppError(ErrorCode.valueRequired, field: 'format'));
        return;
      }
      if (formData.file == AppFile.none()) {
        state = state.copyWith(status: ImportActionStatus.failure, error: AppError(ErrorCode.valueRequired, field: 'path'));
        return;
      }

      // 3. Datei parsen
      ParsedPayload parsedPayload;
      final parser = _parserFactory(formData.format, formData.file, password: formData.encrypt ? formData.password : null);
      if (parser == null) {
        state = state.copyWith(status: ImportActionStatus.failure, error: AppError(ErrorCode.valueInvalid, field: 'format'));
        return;
      }
      try {
        parsedPayload = await parser.parse();
      }
      on ParserError catch (e) {
        if (e.field == 'password' && !state.formData.encrypt) { // Passwortfehler?
          final formData = state.formData.copyWith(encrypt: true); // Switch auf On schalten, damit das Passwortfeld sichtbar ist
          state = state.copyWith(formData: formData);
        }
        final text = '${e.message}${e.lineNumber != null ? ' (Zeile ${e.lineNumber})' : ''}';
        state = state.copyWith(status: ImportActionStatus.failure, error: AppError(ErrorCode.valueInvalid, text: text, field: e.field));
        Logger().error('ParserError: ${e.message}', context: {'path': e.path, 'line': e.lineNumber, 'error': e.originalErrorMessage});
        return;
      }

      // Gesamtanzahl für die Fortschrittsanzeige im State setzen
      state = state.copyWith(totalCount: parsedPayload.length);

      // Geparsten Einträge durchlaufen und Batch aufbauen...
      final ImportBatch batch = [];
      for (final parsedEntry in parsedPayload) {

        // 4. Daten validieren & bereinigen

        // Wenn die UUID nicht angegeben ist, eine generieren. Andernfalls prüfen, ob sie bereits im Tresor existiert.
        var uuid = parsedEntry.uuid;
        if (uuid.isEmpty) {
          uuid = const Uuid().v4();
        } else {
          final existing = await _databaseService.getEntryByUuid(uuid);
          if (existing != null) {
            skipped++;
            state = state.copyWith(skippedCount: skipped);
            continue; // Springe zum nächsten Eintrag in der Schleife
          }
        }

        // Titel muss angegeben werden (so wie bei der manuellen Eingabe).
        var title = parsedEntry.title?.trim() ?? '';
        if (title.isEmpty) {
          title = 'Ohne Titel';
        }

        // Favicon herunterladen, falls nicht angegeben
        var favicon = parsedEntry.favicon ?? '';
        final url = parsedEntry.url ?? '';
        if (favicon.isEmpty && url.isNotEmpty) {
          try {
            favicon = await downloadFavicon(url) ?? '';
          } catch (_) { }
        }

        // Zeitpunkt der letzten Änderung auf Jetzt setzen, wenn nicht angegeben
        final updatedAt = parsedEntry.updatedAt ?? DateTime.now().toUtc();

        // Neuen AES-Key speziell für diesen Eintrag generieren und per RSA verschlüsseln
        final entryKey = _cryptoService.generateAesKey();
        final encryptedEntryKey = await _cryptoService.encryptRsa(entryKey, user.publicKey);

        // encryptedData bauen und mit dem entryKey verschlüsseln
        final payload = EntryPayload(
          category: parsedEntry.category ?? '',
          title: title,
          username: parsedEntry.username ?? '',
          password: parsedEntry.password ?? '',
          passwordTimestamp: parsedEntry.passwordTimestamp, // optional
          url: url,
          notes: parsedEntry.notes ?? '',
          favicon: favicon,
          reportExcluded: parsedEntry.reportExcluded ?? false,
        );
        final payloadBytes = Uint8List.fromList(utf8.encode(json.encode(payload.toJson())));
        final encryptedData = await _cryptoService.encrypt(payloadBytes, entryKey);

        // encryptedIndex bauen und mit dem indexKey verschlüsseln
        final indexPayload = IndexPayload(
          category: parsedEntry.category ?? '',
          title: title,
          url: url,
          notes: parsedEntry.notes ?? '',
          favicon: favicon,
        );
        final indexBytes = Uint8List.fromList(utf8.encode(json.encode(indexPayload.toJson())));
        final encryptedIndex = await _cryptoService.encrypt(indexBytes, _sessionService.indexKey!);

        // Eintrag in der DB speichern
        final entry = EntryEntity(
          id: 0,
          uuid: uuid,
          encryptedData: encryptedData,
          encryptedIndex: encryptedIndex,
          creatorId: user.id,
          updaterId: user.id,
          updatedAt: updatedAt,
        );

        // Dateianhänge durchlaufen...
        final attachments = <({String uuid, String encryptedMeta, String encryptedContent})>[];
        if (parsedEntry.attachments != null) {
          for (final attachment in parsedEntry.attachments!) {
            final filename = sanitizeFilename(attachment.filename ?? '');

            // Mime-Typ ermitteln (falls nicht angegeben)
            var mime = attachment.mime ?? '';
            if (mime.isEmpty) {
              mime = getMimeType(filename);
            }

            // Zeitstempel der Datei (UTC) auf Jetzt setzen, wenn nicht angegeben.
            final timestamp = attachment.timestamp ?? DateTime.now().toUtc();

            // Thumbnail erzeugen (wenn es ein Bild ist)
            String? thumbnailBase64;
            if (mime.startsWith('image/')) {
              thumbnailBase64 = await createThumbnail(attachment.binary);
            }

            // Metadaten der Datei zusammenstellen
            final metaPayload = AttachmentMetaPayload(
              filename: filename,
              mime: mime,
              size: attachment.binary.length,
              thumbnail: thumbnailBase64,
              timestamp: timestamp,
            );

            // Metadaten und Dateiinhalt verschlüsseln (AES)
            final encryptedMeta = await _cryptoService.encrypt(Uint8List.fromList(utf8.encode(json.encode(metaPayload.toJson()))), entryKey);
            final encryptedContent = await _cryptoService.encrypt(attachment.binary, entryKey);

            attachments.add((
              uuid: const Uuid().v4(),
              encryptedMeta: encryptedMeta,
              encryptedContent: encryptedContent,
            ));
          }
        }

        // 13. Freund-Permissions aufbauen
        //
        // Ablauf pro Freund:
        //   a) User lokal per UUID suchen.
        //      Nicht vorhanden → neu anlegen (isVerified = false).
        //      Der Fingerprint muss nach dem nächsten Sync manuell verifiziert werden.
        //   b) Entry-Key mit dem Public-Key des Freundes RSA-verschlüsseln.
        //   c) Permission in die Liste aufnehmen.
        //
        // Hinweis: Ist der Freund dem Sync-Server unbekannt, löscht _pullFriends() ihn beim
        // nächsten Sync wieder (kaskadierend). Das ist das erwartete Verhalten.
        final friendPermissions = <ImportFriendPermission>[];
        if (parsedEntry.sharedWith != null) {
          for (final friend in parsedEntry.sharedWith!) {

            // a: User lokal suchen oder anlegen
            UserEntity? localUser = await _databaseService.getUserByUuid(friend.uuid);
            if (localUser == null) {
              try {
                localUser = await _databaseService.saveUser(UserEntity(
                  id:         0,
                  uuid:       friend.uuid,
                  name:       friend.username,
                  syncedName: friend.username, // eingefrorener Name beim Import; dient zur Anzeige bei späteren Umbenennungen
                  publicKey:  friend.publicKey,
                  isVerified: false,    // muss nach Sync manuell verifiziert werden
                  isHidden:   false,
                  updatedAt:  DateTime.now().toUtc(),
                ));
              } catch (e) {
                Logger().error('Import: User ${friend.uuid} konnte nicht angelegt werden: $e');
                continue;
              }
            }

            // b: Entry-Key für den Freund verschlüsseln
            final String encryptedFriendKey;
            try {
              encryptedFriendKey = await _cryptoService.encryptRsa(entryKey, localUser.publicKey);
            } catch (e) {
              Logger().error('Import: RSA-Verschlüsselung für ${friend.uuid} fehlgeschlagen: $e');
              continue;
            }

            // c: Permission aufnehmen
            friendPermissions.add((
            userId:       localUser.id,
            encryptedKey: encryptedFriendKey,
            accessLevel:  friend.accessLevel,
            ));
          }
        }

        // Prüfung: Wurde abgebrochen?
        if (state.isAborting) {
          state = state.copyWith(status: ImportActionStatus.initial, isAborting: false);
          return;
        }

        // Alles zusammen in eine Batch hinzufügen
        batch.add((
          entry: entry,
          encryptedEntryKey: encryptedEntryKey,
          attachments: attachments,
          friendPermissions: friendPermissions,
        ));

        // Fortschritt aktualisieren
        added++;
        state = state.copyWith(addedCount: added);
      }

      // 14. Batch in Datenbank schreiben
      await _databaseService.import(batch);

      // 15. State aktualisieren
      state = state.copyWith(
        formData: const ImportFormData(),
        status: ImportActionStatus.success,
      );

    } catch (e, st) {
      Logger().fatal("Fehler beim Importieren: $e", stack: st);
      state = state.copyWith(status: ImportActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  /// Gibt den passenden Parser für das gewählte Format zurück.
  static Parser? _parserFactory(ImportFileFormat format, AppFile file, {String? password}) {
    return switch (format) {
      ImportFileFormat.bitwardenJson => BitwardenJsonParser(file),
      ImportFileFormat.keepassXml => KeepassXmlParser(file),
      ImportFileFormat.onePassword1Pux => OnePassword1PuxParser(file),
      ImportFileFormat.privaultZip => PrivaultZipParser(file, password: password),
      _ => null, // Default-Fall (Catch-all) -> alle unterstützen Formate
    };
  }

  /// Benutzer möchte den Import abbrechen
  void abortImport() {
    state = state.copyWith(isAborting: true);
  }

  // ------------------------------------------------------------------------
  // --- Setter für den UI-State (synchron) ---
  // ------------------------------------------------------------------------

  /// Setter für Dateiformat. Setzt dabei auch Datei und Passwort zurück.
  void setFormat(ImportFileFormat value) {
    if (value == state.formData.format) return;
    final error = state.error.field == 'format' ? AppError.none() : null;
    final formData = state.formData.copyWith(format: value, file: AppFile.none(), password: '');
    state = state.copyWith(formData: formData, status: ImportActionStatus.initial, error: error);
  }

  /// Setter für Datei
  void setFile(AppFile value) {
    if (value.path == state.formData.file.path) return;
    final error = state.error.field == 'path' ? AppError.none() : null;
    var formData = state.formData.copyWith(file: value);

    // Automatische Formaterkennung, wenn noch keins gewählt wurde
    if (formData.format == ImportFileFormat.none) {
      final extension = value.name.split('.').last.toLowerCase();
      formData = formData.copyWith(format: switch (extension) {
        'json' => ImportFileFormat.bitwardenJson,
        'xml'  => ImportFileFormat.keepassXml,
        '1pux' => ImportFileFormat.onePassword1Pux,
        'zip'  => ImportFileFormat.privaultZip,
        _      => ImportFileFormat.none,
      });
    }

    state = state.copyWith(formData: formData, status: ImportActionStatus.initial, error: error);
  }

  /// Setter für Switch "ZIP-Archiv ist verschlüsselt"
  void setEncrypt(bool value) {
    if (value == state.formData.encrypt) return;
    final error = state.error.field == 'encrypt' ? AppError.none() : null;
    final formData = state.formData.copyWith(encrypt: value);
    state = state.copyWith(formData: formData, status: ImportActionStatus.initial, error: error);
  }

  /// Setzt das Passwort (nur relevant für verschlüsselte PriVault-ZIP-Exporte).
  void setPassword(String value) {
    if (value == state.formData.password) return;
    final error = state.error.field == 'password' ? AppError.none() : null;
    final formData = state.formData.copyWith(password: value);
    state = state.copyWith(formData: formData, status: ImportActionStatus.initial, error: error);
  }

}