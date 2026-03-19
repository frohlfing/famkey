import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/edit/edit_state.dart';
import 'package:privault/models/payloads/entry_payload.dart';
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

  /// Objekt für HTTP-Anfragen (wird hier zum Download des Favicons benötigt)
  final Dio _dio = Dio();

  /// Die aktuell geladene Datenbank-Entität. Ist null bei einem neuen Eintrag.
  EntryEntity? _entry;

  /// Der entschlüsselte 32-Byte AES-Schlüssel für diesen spezifischen Eintrag.
  ///
  /// Wird benötigt, um Daten und Anhänge zu ver- und zu entschlüsseln.
  Uint8List? _entryKey;

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

    // Status zurücksetzen
    state = const EditState().copyWith(status: EditActionStatus.loading, error: FormError.none());

    try {
      if (_sessionService.privateKey == null) throw Exception('Der private Schlüssel ist nicht entpackt.');

      // Vorhandene Kategorien für Vorschlagsliste laden
      final categories = await _databaseService.getCategories();
      state = state.copyWith(existingCategories: categories);

      if (id != null) {
        // Edit-Modus
        _entry = await _databaseService.getEntry(id);
        if (_entry == null) {
          // Parameter user ist nicht korrekt!
          state = state.copyWith(error: FormError(ErrorCode.valueInvalid, text: 'Eintrag $id zum Laden nicht gefunden.'));
          return;
        }

        // Berechtigung prüfen und Entry-Key mittels RSA entschlüsseln
        final perm = await _databaseService.getPermissionByEntryIdAndUserId(_entry!.id, 1);
        if (perm == null) throw Exception('Eintrag $id konnte nicht entschlüsselt werden.');

        _entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, utf8.decode(_sessionService.privateKey!));

        // Payload mittels AES entschlüsseln
        final decrypted = await _cryptoService.decrypt(_entry!.encryptedData, _entryKey!);
        final jsonStr = utf8.decode(decrypted);
        final payload = EntryPayload.fromJson(json.decode(jsonStr));

        // UI-State aktualisieren
        state = state.copyWith(
          entryId: _entry!.id,
          category: payload.category,
          title: payload.title,
          username: payload.username,
          password: payload.password,
          passwordStrength: _passwordService.estimateStrength(payload.password),
          url: payload.url,
          notes: payload.notes,
          originalPayload: payload,
          status: EditActionStatus.loaded,
        );

      } else {
        // Insert-Modus -> Payload ind alle UI-Felder leeren
        state = state.copyWith(
          entryId: 0,
          category: '',
          title: '',
          username: '',
          password: '',
          passwordStrength: 0,
          url: '',
          notes: '',
          originalPayload: null,
          status: EditActionStatus.loaded,
        );
      }

    } catch (e, st) {
      Logger().fatal('Fehler beim Laden: $e', stack: st);
      state = state.copyWith(status: EditActionStatus.failure, error: FormError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Speichern ---
  // ------------------------------------------------------------------------

  /// Speichert den aktuellen Eintrag in der Datenbank.
  /// Verschlüsselt dabei alle sensiblen Felder.
  Future<void> save() async {
    if (state.isBusy) return;

    // Benutzereingabe validieren
    if (state.title.trim().isEmpty) {
      state = state.copyWith(error: FormError(ErrorCode.valueRequired, field: 'title'));
      return;
    }

    // Status auf saving setzen
    final status = state.isEditMode ? EditActionStatus.updating : EditActionStatus.creating;
    state = state.copyWith(status: status, error: FormError.none());

    try {
      // 1. Key-Management: Neuen AES-Key generieren, falls nicht vorhanden
      _entryKey ??= Uint8List.fromList(List.generate(32, (_) => Random.secure().nextInt(256)));

      // 2. Favicon laden, falls URL sich geändert hat
      String favicon = _entry?.favicon ?? '';
      if (state.url.trim().isNotEmpty && (state.originalPayload == null || state.url != state.originalPayload!.url)) {
        final icon = await _downloadFavicon(state.url.trim());
        if (icon != null) favicon = icon;
      }

      // 3. Payload bauen und verschlüsseln (AES)
      final payload = EntryPayload(
        category: state.category.trim(),
        title: state.title.trim(),
        username: state.username.trim(),
        password: state.password,
        url: state.url.trim(),
        notes: state.notes.trim(),
        favicon: favicon,
      );

      final payloadBytes = Uint8List.fromList(utf8.encode(json.encode(payload.toJson())));
      final encryptedData = await _cryptoService.encrypt(payloadBytes, _entryKey!);

      // 4. Entry-Key für den Eigenbedarf verschlüsseln (RSA)
      final encryptedEntryKey = await _cryptoService.encryptRsa(_entryKey!, _sessionService.user!.publicKey);

      // 5. Entity erstellen und speichern
      final entity = EntryEntity(
        id: _entry?.id ?? 0,
        uuid: _entry?.uuid ?? const Uuid().v4(),
        category: state.category.trim(),
        title: state.title.trim(),
        url: state.url.trim(),
        notes: state.notes.trim(),
        favicon: favicon,
        encryptedData: encryptedData,
        creatorId: _sessionService.user!.id,
        updaterId: _sessionService.user!.id,
        updatedAt: DateTime.now().toUtc(),
      );
      _entry = await _databaseService.saveEntryWithPermissions(entity, 1, encryptedEntryKey);

      // 6. State aktualisieren
      state = state.copyWith(
        entryId: _entry!.id,
        originalPayload: payload,
        status: EditActionStatus.saved,
      );

    } catch (e, st) {
      Logger().fatal("Fehler beim Speichern: $e", stack: st);
      state = state.copyWith(status: EditActionStatus.failure, error: FormError(ErrorCode.unknown));
    }
  }

  /// Lädt das Favicon einer Website über den Google-Dienst.
  Future<String?> _downloadFavicon(String url) async {
    try {
      final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
      final faviconUrl = 'https://www.google.com/s2/favicons?domain=${uri.host}&sz=64';
      final response = await _dio.get<List<int>>(faviconUrl, options: Options(responseType: ResponseType.bytes));
      if (response.data != null) return base64.encode(response.data!);
    } catch (_) {}
    return null;
  }

  // ------------------------------------------------------------------------
  // --- Löschen ---
  // ------------------------------------------------------------------------

  /// Löscht den aktuellen Eintrag.
  Future<void> deleteEntry() async {
    if (state.isBusy) return;

    // Status auf deleting setzen
    state = state.copyWith(status: EditActionStatus.deleting, error: FormError.none());

    try {
      // Eintrag löschen
      if (_entry == null) throw Exception('Kein Eintrag zum Löschen geladen.');
      await _databaseService.deleteEntry(_entry!.id);
      _entry = null;

      // UI-Felder leeren
      state = state.copyWith(
        category: '',
        title: '',
        username: '',
        password: '',
        url: '',
        notes: '',
        originalPayload: null,
      );

    } catch (e, st) {
      Logger().fatal('Fehler beim Löschen: $e', stack: st);
      state = state.copyWith(status: EditActionStatus.failure, error: FormError(ErrorCode.unknown));
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
      settings.pwLength,
      settings.pwAvoidIlO0,
      settings.pwSpecialChars,
    );

    state = state.copyWith(password: pw);
  }

  // ------------------------------------------------------------------------
  // --- Setter ---
  // ------------------------------------------------------------------------

  /// Setter für die Kategorie.
  void setCategory(String value) {
    final error = state.error.field == 'category' ? FormError.none() : null;
    state = state.copyWith(category: value, error: error);
  }

  /// Setter für den Titel des Eintrags.
  void setTitle(String value) {
    final error = state.error.field == 'title' ? FormError.none() : null;
    state = state.copyWith(title: value, error: error);
  }

  /// Setter für den Benutzernamen des Eintrags.
  void setUsername(String value) {
    final error = state.error.field == 'username' ? FormError.none() : null;
    state = state.copyWith(username: value, error: error);
  }

  /// Setter für das Passwort des Eintrags.
  void setPassword(String value) {
    final error = state.error.field == 'password' ? FormError.none() : null;
    state = state.copyWith(
        password: value,
        passwordStrength: _passwordService.estimateStrength(value),
        error: error,
    );
  }

  /// Setter für die URL des Eintrags.
  void setUrl(String value) {
    final error = state.error.field == 'url' ? FormError.none() : null;
    state = state.copyWith(url: value, error: error);
  }

  /// Setter für Notizen des Eintrags.
  void setNotes(String value) {
    final error = state.error.field == 'notes' ? FormError.none() : null;
    state = state.copyWith(notes: value, error: error);
  }
}
