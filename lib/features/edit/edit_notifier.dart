import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/helper.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/edit/edit_form_data.dart';
import 'package:privault/features/edit/edit_state.dart';
import 'package:privault/features/main/main_notifier.dart';
import 'package:privault/models/payloads/entry_payload.dart';
import 'package:privault/models/payloads/index_payload.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/password_service.dart';
import 'package:privault/services/session_service.dart';
import 'package:uuid/uuid.dart';

final editProvider = NotifierProvider<EditNotifier, EditState>(() {
  return EditNotifier();
});

class EditNotifier extends Notifier<EditState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

  late final CryptoService _cryptoService;
  late final DatabaseService _databaseService;
  late final PasswordService _passwordService;
  late final SessionService _sessionService;

  // ------------------------------------------------------------------------
  // --- Interne Variablen (nicht reaktiv, nicht UI‑relevant) ---
  // ------------------------------------------------------------------------

  /// Die aktuell geladene Datenbank-Entität. Ist null bei einem neuen Eintrag.
  EntryEntity? _entry;

  /// Der entschlüsselte 32-Byte AES-Schlüssel für diesen spezifischen Eintrag.
  ///
  /// Wird benötigt, um Daten und Anhänge zu ver- und zu entschlüsseln.
  Uint8List? _entryKey;

  /// Der Zeitstempel des Passworts (UTC) im Data-Payload. Ist null bei einem neuen Eintrag.
  DateTime? _passwordTimestamp;

  /// Der Favicon als Base64-String im Data-Payload.
  String? _favicon;

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert einen Notifier.
  ///
  /// Die Verwendung von `Ref.watch` oder `Ref.listen` innerhalb dieser Methode ist unbedenklich.
  /// Ändert sich eine Abhängigkeit dieses Notifiers (bei Verwendung von `Ref.watch`), wird der Build-Prozess erneut ausgeführt. Der Notifier selbst wird jedoch nicht neu erstellt. Seine Instanz bleibt zwischen den Build-Ausführungen erhalten.
  @override
  EditState build() {
    // Dienste aus getIt holen
    _cryptoService = getIt<CryptoService>();
    _databaseService = getIt<DatabaseService>();
    _passwordService = getIt<PasswordService>();
    _sessionService = getIt<SessionService>();

    // Initialer State
    return const EditState();
  }

  /// Lädt entweder einen bestehenden Eintrag oder bereitet die Maske für eine Neuanlage vor.
  Future<void> load(int? id) async {
    if (state.isBusy) return;

    // Ladeanzeige einblenden
    state = const EditState().copyWith(status: EditActionStatus.loading, error: AppError.none());

    try {

      if (_sessionService.privateKey == null) throw Exception('Der private Schlüssel ist nicht entpackt.');

      // Vorhandene Kategorien für Vorschlagsliste laden
      final categories = ref.read(mainProvider).categories;
      state = state.copyWith(existingCategories: categories);

      if (id != null) {
        // Edit-Modus
        _entry = await _databaseService.getEntry(id);
        if (_entry == null) {
          // Parameter user ist nicht korrekt!
          state = state.copyWith(error: AppError(ErrorCode.valueInvalid, text: 'Eintrag $id zum Laden nicht gefunden.'));
          return;
        }

        // Berechtigung prüfen und Entry-Key mittels RSA entschlüsseln
        final perm = await _databaseService.getPermissionByEntryIdAndUserId(_entry!.id, 1);
        if (perm == null) throw Exception('Eintrag $id konnte nicht entschlüsselt werden.');
        _entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, _sessionService.privateKey!);

        // Payload mittels AES entschlüsseln
        final decrypted = await _cryptoService.decrypt(_entry!.encryptedData, _entryKey!);
        final jsonStr = utf8.decode(decrypted);
        final payload = EntryPayload.fromJson(json.decode(jsonStr));

        // Formulardaten aus Payload laden
        final formData = EditFormData(
          category: payload.category,
          title: payload.title,
          username: payload.username,
          password: payload.password,
          url: payload.url,
          notes: payload.notes,
        );

        // brauchen wir später beim Speichern des neuen Payloads
        _passwordTimestamp = payload.passwordTimestamp;
        _favicon = payload.favicon;

        // UI-State aktualisieren
        state = state.copyWith(
          entryId: _entry!.id,
          formData: formData,
          originalFormData: formData,
          passwordStrength: _passwordService.estimateStrength(payload.password),
          status: EditActionStatus.loaded,
        );

      } else {
        // Insert-Modus -> Payload und alle UI-Felder leeren
        _entry = null;
        _entryKey = null;
        final formData = const EditFormData();
        _passwordTimestamp = null;
        state = state.copyWith(
          entryId: 0,
          formData: formData,
          originalFormData: formData,
          passwordStrength: 0,
          status: EditActionStatus.loaded,
        );
      }

    } catch (e, st) {
      Logger().fatal('Fehler beim Laden: $e', stack: st);
      state = state.copyWith(status: EditActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Speichern ---
  // ------------------------------------------------------------------------

  /// Speichert den aktuellen Eintrag in der Datenbank.
  /// Verschlüsselt dabei alle sensiblen Felder.
  Future<void> save() async {
    if (state.isBusy) return;

    // 1. Benutzereingabe bereinigen
    var formData = state.formData;
    formData = formData.copyWith(
      category: formData.category.trim(),
      title: formData.title.trim(),
      username: formData.username.trim(),
      url: formData.url.trim(),
      notes: formData.notes.trim(),
    );

    // 2. Ladeanzeige einblenden
    final status = state.isEditMode ? EditActionStatus.updating : EditActionStatus.creating;
    state = state.copyWith(formData: formData, status: status, error: AppError.none());

    try {

      // 3. Benutzereingabe validieren
      if (formData.title.isEmpty) {
        state = state.copyWith(status: EditActionStatus.failure, error: AppError(ErrorCode.valueRequired, field: 'title'));
        return;
      }

      // 4. Zeitstempel des Passworts aktualisieren, falls Passwort geändert wurde.
      final passwordTimestamp = (formData.password != state.originalFormData.password || _passwordTimestamp == null) ? DateTime.now().toUtc() : _passwordTimestamp!;

      // 5. Favicon herunterladen, falls URL geändert wurde
      final favicon = (formData.url.isNotEmpty && formData.url != state.originalFormData.url ? await downloadFavicon(formData.url) : _favicon) ?? '';

      // 6. Neuen AES-Key speziell für diesen Eintrag generieren und per RSA verschlüsseln, falls _entryKey == null
      _entryKey ??= _cryptoService.generateAesKey();
      final encryptedEntryKey = await _cryptoService.encryptRsa(_entryKey!, _sessionService.user!.publicKey); // todo überspringen, wenn sich nichts geändert hat

      // 7. encryptedData bauen und mit dem entryKey verschlüsseln
      final entryPayload = EntryPayload(
        category: formData.category,
        title: formData.title,
        username: formData.username,
        password: formData.password,
        passwordTimestamp: passwordTimestamp,
        url: formData.url,
        notes: formData.notes,
        favicon: favicon,
      );
      final entryBytes = Uint8List.fromList(utf8.encode(json.encode(entryPayload.toJson())));
      final encryptedData = await _cryptoService.encrypt(entryBytes, _entryKey!);

      // 8. encryptedIndex bauen und mit dem indexKey verschlüsseln
      final indexPayload = IndexPayload(
        category: formData.category,
        title: formData.title,
        url: formData.url,
        notes: formData.notes,
        favicon: favicon,
      );
      final indexBytes = Uint8List.fromList(utf8.encode(json.encode(indexPayload.toJson())));
      final encryptedIndex = await _cryptoService.encrypt(indexBytes, _sessionService.indexKey!);

      // 9. Eintrag in der DB speichern
      final entity = EntryEntity(
        id: _entry?.id ?? 0,
        uuid: _entry?.uuid ?? const Uuid().v4(),
        encryptedIndex: encryptedIndex,
        encryptedData: encryptedData,
        creatorId: _sessionService.user!.id,
        updaterId: _sessionService.user!.id,
        updatedAt: DateTime.now().toUtc(),
      );
      _entry = await _databaseService.saveEntryWithPermissions(entity, 1, encryptedEntryKey);

      // 10. State aktualisieren
      state = state.copyWith(
        entryId: _entry!.id,
        originalFormData: formData,
        status: EditActionStatus.saved,
      );

    } catch (e, st) {
      Logger().fatal("Fehler beim Speichern: $e", stack: st);
      state = state.copyWith(status: EditActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Löschen ---
  // ------------------------------------------------------------------------

  /// Löscht den aktuellen Eintrag.
  Future<void> deleteEntry() async {
    if (state.isBusy) return;

    // 1. Status auf `deleting` setzen
    state = state.copyWith(status: EditActionStatus.deleting, error: AppError.none());

    try {
      // 2. Eintrag löschen
      if (_entry == null) throw Exception('Kein Eintrag zum Löschen geladen.');
      await _databaseService.deleteEntry(_entry!.id);
      _entry = null;

      // 3. UI-State zurücksetzen
      state = EditState().copyWith(
        status: EditActionStatus.deleted,
      );

    } catch (e, st) {
      Logger().fatal('Fehler beim Löschen: $e', stack: st);
      state = state.copyWith(status: EditActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Passwortgenerierung ---
  // ------------------------------------------------------------------------

  /// Generiert ein neues Zufallspasswort basierend auf den Benutzereinstellungen.
  void generatePassword() {
    final settings = _sessionService.settings;
    if (settings == null) return;

    final pw = _passwordService.generatePassword(
      length: settings.pwLength,
      specialChars: settings.pwSpecialChars,
      withUmlauts: true,
      avoidIlO0: settings.pwAvoidIlO0,
    );

    final formData = state.formData.copyWith(password: pw);
    state = state.copyWith(formData: formData);
  }

  // ------------------------------------------------------------------------
  // --- Setter für den UI-State (synchron) ---
  // ------------------------------------------------------------------------

  /// Setter für die Kategorie.
  void setCategory(String value) {
    final error = state.error.field == 'category' ? AppError.none() : null;
    final formData = state.formData.copyWith(category: value);
    state = state.copyWith(formData: formData, error: error);
  }

  /// Setter für den Titel des Eintrags.
  void setTitle(String value) {
    final error = state.error.field == 'title' ? AppError.none() : null;
    final formData = state.formData.copyWith(title: value);
    state = state.copyWith(formData: formData, error: error);
  }

  /// Setter für den Benutzernamen des Eintrags.
  void setUsername(String value) {
    final error = state.error.field == 'username' ? AppError.none() : null;
    final formData = state.formData.copyWith(username: value);
    state = state.copyWith(formData: formData, error: error);
  }

  /// Setter für das Passwort des Eintrags.
  void setPassword(String value) {
    final error = state.error.field == 'password' ? AppError.none() : null;
    final formData = state.formData.copyWith(password: value);
    state = state.copyWith(
      formData: formData,
      passwordStrength: _passwordService.estimateStrength(value),
      error: error,
    );
  }

  /// Setter für die URL des Eintrags.
  void setUrl(String value) {
    final error = state.error.field == 'url' ? AppError.none() : null;
    final formData = state.formData.copyWith(url: value);
    state = state.copyWith(formData: formData, error: error);
  }

  /// Setter für Notizen des Eintrags.
  void setNotes(String value) {
    final error = state.error.field == 'notes' ? AppError.none() : null;
    final formData = state.formData.copyWith(notes: value);
    state = state.copyWith(formData: formData, error: error);
  }
}
