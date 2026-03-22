import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/settings/settings_form_data.dart';
import 'package:privault/features/settings/settings_state.dart';
import 'package:privault/services/autofill_service.dart';
import 'package:privault/services/biometric_service.dart';
import 'package:privault/services/config_service.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';
import 'package:privault/services/web_service.dart';
import 'package:url_launcher/url_launcher.dart';

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});

class SettingsNotifier extends Notifier<SettingsState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

  late final AutofillService _autofillService;
  late final BiometricService _biometricService;
  late final ConfigService _configService;
  late final CryptoService _cryptoService;
  late final DatabaseService _databaseService;
  late final SessionService _sessionService;
  late final WebService _webService;

  // ------------------------------------------------------------------------
  // --- Interne Variablen (nicht reaktiv, nicht UI‑relevant) ---
  // ------------------------------------------------------------------------

  /// Die Datenbank-Entität.
  SettingsEntity? _settings;

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert einen Notifier.
  ///
  /// Die Verwendung von `Ref.watch` oder `Ref.listen` innerhalb dieser Methode ist unbedenklich.
  /// Ändert sich eine Abhängigkeit dieses Notifiers (bei Verwendung von `Ref.watch`), wird der Build-Prozess erneut ausgeführt. Der Notifier selbst wird jedoch nicht neu erstellt. Seine Instanz bleibt zwischen den Build-Ausführungen erhalten.
  @override
  SettingsState build() {
    // Dienste aus getIt holen
    _autofillService = getIt<AutofillService>();
    _biometricService = getIt<BiometricService>();
    _configService = getIt<ConfigService>();
    _cryptoService = getIt<CryptoService>();
    _databaseService = getIt<DatabaseService>();
    _sessionService = getIt<SessionService>();
    _webService = getIt<WebService>();

    // Initialer State
    return SettingsState();
  }

  /// Lädt die Daten für die Anzeige.
  Future<void> load() async {
    if (state.isBusy) return;

    // Status zurücksetzen
    state = const SettingsState().copyWith(status: SettingsActionStatus.loading, error: FormError.none());


    try {
      // Daten aus der Datenbank laden
      _settings = await _databaseService.getSettings();
      if (_settings == null) throw Exception('Settings nicht gefunden.'); // wird bereits direkt nach dem Login angelegt

      // Freundesliste laden
      final friends = await _databaseService.getNotHiddenFriends();
      final fingerprints = _getFingerprints(friends);
      final friendNeedsRekeying = await _getFriendNeedsRekeying(friends);

      // Theme aus ConfigService laden
      final theme = ThemeMode.values.firstWhere((t) => t.name == _configService.theme, orElse: () => ThemeMode.system);

      // UI-State aktualisieren
      final formData = SettingsFormData(
        vaultName: _sessionService.vaultName,
        useBiometric: _settings!.useBiometric,
        userName: _sessionService.user?.name ?? '',
        host: _settings!.host,
        apiToken: _settings!.apiToken,
        pwLength: _settings!.pwLength,
        pwSpecialChars: _settings!.pwSpecialChars,
        pwAvoidIlO0: _settings!.pwAvoidIlO0,
        categoryPlaceholder: _settings!.categoryPlaceholder.isEmpty ? 'Allgemein' : _settings!.categoryPlaceholder,
      );
      state = state.copyWith(
        vaultStoragePath: _configService.vaultStoragePath,
        formData: formData,
        originalFormData: formData,
        isRegistered: _settings!.lastSyncAt.year > 1970,
        friends: friends,
        fingerprints: fingerprints,
        friendNeedsRekeying: friendNeedsRekeying,
        themeMode: theme,
        status: SettingsActionStatus.loaded,
      );

    } catch (e, st) {
      Logger().fatal('Fehler beim Laden: $e', stack: st);
      state = state.copyWith(status: SettingsActionStatus.failure, error: FormError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Bereich "Tresor" ---
  // ------------------------------------------------------------------------

  /// Benennt den Tresor um und aktualisiert die Session.
  ///
  /// Das Master-Passwort wurde zuvor von der UI abgefragt.
  Future<void> renameVault(String password) async {
    if (state.isBusy) return;
    Uint8List? masterKey;
    final oldVaultName = state.originalFormData.vaultName;

    // 1. Benutzereingabe bereinigen
    // Ungültige Zeichen für Dateinamen entfernen
    final vaultName = state.formData.vaultName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();

    // 2. Benutzereingabe validieren
    if (vaultName.isEmpty) {
      state = state.copyWith(error: FormError(ErrorCode.valueRequired, field: 'vaultName'));
      return;
    }
    if (vaultName == oldVaultName) {
      state = state.copyWith(error: FormError(ErrorCode.valueNotChanged, field: 'vaultName'));
      return;
    }
    if (await _databaseService.databaseExists(vaultName)) {
      state = state.copyWith(error: FormError(ErrorCode.vaultAlreadyExists, field: 'vaultName'));
      return;
    }

    // 3. Status auf saving setzen
    state = state.copyWith(status: SettingsActionStatus.saving, error: FormError.none());

    try {
      if (_settings == null) throw Exception("Settings ist nicht initialisiert.");
      if (_settings!.encryptedPrivateKey.isEmpty) throw Exception("`encryptedPrivateKey` ist in Settings leer");
      if (_settings!.salt.isEmpty) throw Exception("Das Salt ist nicht in Settings gespeichert.");
      if (_sessionService.privateKey == null) throw Exception("Der privater Schlüssel ist nicht entpackt.");
      if (state.isRegistered) throw Exception("Dieser Tresor wurde bereits synchronisiert und kann daher nicht mehr umbenannt werden.");

      // Kurze Pause für Lade-Indikator, bevor Argon2 blockiert
      await Future.delayed(const Duration(milliseconds: 50));

      // 4. MasterKey ableiten (Argon2id)
      final salt = base64Decode(_settings!.salt);
      masterKey = await _cryptoService.deriveKey(password, salt);

      // 5. Passwort validieren
      try {
        await _cryptoService.decrypt(_settings!.encryptedPrivateKey, masterKey);
      } catch (_) {
        state = state.copyWith(status: SettingsActionStatus.failure, error: FormError(ErrorCode.wrongPassword, field: 'password'));
        return;
      }

      // 6. Physisches Datenbank-Backup erstellen
      await _databaseService.createBackup();
      try {
        // --- Start Kritische Logik ---

        // 7. Verbindung trennen & Umbenennen
        await _databaseService.close();
        await _databaseService.renameDatabaseAndSaltFile(oldVaultName, vaultName);

        // 8. Konfiguration (Login-Liste / Config) aktualisieren
        if (_configService.lastVaultName == oldVaultName) {
          _configService.lastVaultName = vaultName;
        }

        // 9. Neue Verbindung zur umbenannten Datei herstellen
        await _databaseService.initialize(vaultName, masterKey);

        // 10. Master-Key im SecureStore umziehen
        if (await _biometricService.containsMasterKey(oldVaultName)) {
          await _biometricService.removeMasterKey(oldVaultName);
          if (_settings!.useBiometric) {
            await _biometricService.saveMasterKey(vaultName, masterKey);
          }
        }

        // 11. Session aktualisieren
        _sessionService.setSession(
          user: _sessionService.user!,
          privateKey: _sessionService.privateKey!,
          vaultName: vaultName,
          settings: _settings!,
        );

        // --- Ende Kritische Logik ---

        // 12. Erfolg: Backup löschen
        await _databaseService.removeBackup();

        // 13. State aktualisieren
        final formData = state.formData.copyWith(vaultName: vaultName);
        final originalFormData = state.originalFormData.copyWith(vaultName: vaultName);
        state = state.copyWith(
          formData: formData,
          originalFormData: originalFormData,
          status: SettingsActionStatus.saved,
        );

      } catch (_) {
        // Fehler während der Operation -> Rollback
        try {
          await _databaseService.close();
          await _databaseService.restoreBackup();
          await _databaseService.initialize(_sessionService.vaultName, masterKey);
        } catch (_) {}
        rethrow;
      }

    } catch (e, st) {
      Logger().fatal('Fehler beim Umbenennung des Tresors: $e', stack: st);
      state = state.copyWith(status: SettingsActionStatus.failure, error: FormError(ErrorCode.unknown));

    } finally {
      // Master-Key aus dem RAM löschen
      if (masterKey != null) _cryptoService.wipeKey(masterKey);
    }
  }

  /// Löscht den aktuellen Tresor lokal vom Gerät.
  Future<void> deleteVault() async {
    if (state.isBusy) return;

    // 1. Status auf `deleting` setzen
    state = state.copyWith(status: SettingsActionStatus.deleting, error: FormError.none());

    // 2. Datenbank löschen
    await _databaseService.deleteCurrentDatabaseAndSaltFile();

    // 3. SecureStore leeren
    await _biometricService.removeMasterKey(_sessionService.vaultName);

    // 4. Konfiguration bereinigen
    if (_configService.lastVaultName == _sessionService.vaultName) {
      _configService.lastVaultName = '';
    }

    // 5. Session zurücksetzen
    _sessionService.clearSession();

    // 6. UI-State zurücksetzen
    state = SettingsState().copyWith(
      status: SettingsActionStatus.deleted,
    );
  }

  // ------------------------------------------------------------------------
  // --- Bereich "Login" ---
  // ------------------------------------------------------------------------

  /// Speichert die Biometrie-Einstellung.
  Future<void> saveBiometricSettings(bool useBiometric) async {
    if (state.isBusy) return;

    // 1. Benutzereingabe übernehmen
    final useBiometric = state.formData.useBiometric;

    // 2. Benutzereingabe validieren
    final oldUseBiometric = state.originalFormData.useBiometric;
    if (useBiometric == oldUseBiometric) {
      state = state.copyWith(error: FormError(ErrorCode.valueNotChanged, field: 'useBiometric'));
      return;
    }

    // 3. Status auf saving setzen
    state = state.copyWith(status: SettingsActionStatus.saving, error: FormError.none());

    try {
      if (_settings == null || _sessionService.settings == null) throw Exception("Die Settings sind nicht geladen.");
      if (_sessionService.user == null) throw Exception("Der Benutzer ist nicht geladen.");
      if (_sessionService.privateKey == null) throw Exception("Der privater Schlüssel ist nicht entpackt.");

      // 4. Falls Biometrie deaktiviert wurde, SecureStore leeren
      if (_settings!.useBiometric && !useBiometric) {
        await _biometricService.removeMasterKey(_sessionService.vaultName);
        Logger().info("Biometrie-Key entfernt, da Option deaktiviert wurde.");
      }

      // 5. Basiskonfiguration in der DB speichern.
      final updatedSettings = _settings!.copyWith(useBiometric: useBiometric);
      _settings = await _databaseService.saveSettings(updatedSettings);

      // 6. Session aktualisieren
      _sessionService.setSession(
        user: _sessionService.user!,
        privateKey: _sessionService.privateKey!,
        vaultName: _sessionService.vaultName,
        settings: _settings!,
      );

      // 7. State aktualisieren
      final formData = state.formData.copyWith(useBiometric: useBiometric);
      final originalFormData = state.originalFormData.copyWith(useBiometric: useBiometric);
      state = state.copyWith(
        formData: formData,
        originalFormData: originalFormData,
        status: SettingsActionStatus.saved,
      );

    } catch (e, st) {
      Logger().fatal("Fehler beim Speichern: $e", stack: st);
      state = state.copyWith(status: SettingsActionStatus.failure, error: FormError(ErrorCode.unknown));
    }
  }

  /// Generiert ein neuen Salt, verschlüsselt die sqLite-Datei mit dem neuen Master-Schlüssel und aktualisiert die Salt-Datei.
  Future<void> changeMasterPassword(String newPassword, String password) async {
    if (state.isBusy) return;
    Uint8List? masterKey; // bisheriger Master-Key
    Uint8List? newMasterKey;

    // 1. Benutzereingabe validieren
    if (newPassword.isEmpty) {
      state = state.copyWith(error: FormError(ErrorCode.valueRequired, field: 'password'));
      return;
    }
    if (newPassword == password) {
      state = state.copyWith(error: FormError(ErrorCode.equalPassword, field: 'password'));
      return;
    }

    // 2. Status auf progress setzen
    state = state.copyWith(status: SettingsActionStatus.progress, error: FormError.none());

    try {
      if (_settings == null) throw Exception("Settings ist nicht initialisiert.");
      if (_settings!.encryptedPrivateKey.isEmpty) throw Exception("`encryptedPrivateKey` ist in Settings leer");
      if (_settings!.salt.isEmpty) throw Exception("Das Salt ist nicht in Settings gespeichert.");
      if (_sessionService.privateKey == null) throw Exception("Der privater Schlüssel ist nicht entpackt.");

      // Kurze Pause für Lade-Indikator, bevor Argon2 blockiert
      await Future.delayed(const Duration(milliseconds: 50));

      // 3. MasterKey ableiten (Argon2id)
      final salt = base64Decode(_settings!.salt);
      masterKey = await _cryptoService.deriveKey(password, salt);

      // 4. Passwort validieren
      try {
        await _cryptoService.decrypt(_settings!.encryptedPrivateKey, masterKey);
      } catch (_) {
        state = state.copyWith(status: SettingsActionStatus.failure, error: FormError(ErrorCode.wrongPassword, field: 'password'));
        return;
      }

      // 5. Physisches Datenbank-Backup erstellen
      await _databaseService.createBackup();

      try {
        // --- Start Kritische Logik ---

        // 6. Neues Salt generieren, neuen Master-Key ableiten und damit den Private-Key neu verschlüsseln
        final newSalt = _cryptoService.generateSalt();
        newMasterKey = await _cryptoService.deriveKey(newPassword, newSalt);
        final newEncryptedPrivKey = await _cryptoService.encrypt(_sessionService.privateKey!, newMasterKey);

        // 7. Datenbankdatei mit dem neuen Master-Key umschlüsseln
        await _databaseService.rekey(newMasterKey);

        // 8. Salt-Datei aktualisieren
        await _databaseService.saveSalt(_sessionService.vaultName, newSalt);

        // 9. Master-Key im SecureStore aktualisieren
        if (_settings!.useBiometric) {
          await _biometricService.saveMasterKey(_sessionService.vaultName, newMasterKey);
        }

        // 10. Settings in DB aktualisieren
        final updatedSettings = _settings!.copyWith(
          salt: base64Encode(newSalt),
          encryptedPrivateKey: newEncryptedPrivKey,
        );
        _settings = await _databaseService.saveSettings(updatedSettings);

        // 11. Session aktualisieren
        _sessionService.setSession(
          user: _sessionService.user!,
          privateKey: _sessionService.privateKey!,
          vaultName: _sessionService.vaultName,
          settings: _settings!,
        );

        // --- Ende Kritische Logik ---

        // 12. Erfolg: Backup löschen
        await _databaseService.removeBackup();

        // 13. State aktualisieren
        state = state.copyWith(
          status: SettingsActionStatus.saved,
        );

      } catch (_) {
        // Fehler während der Operation -> Rollback
        try {
          await _databaseService.close();
          await _databaseService.restoreBackup();
          await _databaseService.initialize(_sessionService.vaultName, masterKey);
        } catch (_) {}
        rethrow;
      }

    } catch (e, st) {
      Logger().fatal('Fehler beim Ändern des Passworts: $e', stack: st);
      state = state.copyWith(status: SettingsActionStatus.failure, error: FormError(ErrorCode.unknown));

    } finally {
      // Master-Key aus dem RAM löschen
      if (masterKey != null) _cryptoService.wipeKey(masterKey);
      if (newMasterKey != null) _cryptoService.wipeKey(newMasterKey);
    }
  }

  // ------------------------------------------------------------------------
  // --- Bereich "Sync-Server" ---
  // ------------------------------------------------------------------------

  /// Speichert den neune Benutzernamen.
  Future<void> saveUsername() async {
    if (state.isBusy) return;

    // 1. Benutzereingabe bereinigen
    final userName = state.formData.userName.trim();

    // 2. Benutzereingabe validieren
    if (userName.isEmpty) {
      state = state.copyWith(error: FormError(ErrorCode.valueRequired, field: 'userName'));
      return;
    }
    if (userName == state.originalFormData.userName) {
      state = state.copyWith(error: FormError(ErrorCode.valueNotChanged, field: 'userName'));
      return;
    }

    // 3. Status auf saving setzen
    state = state.copyWith(status: SettingsActionStatus.saving, error: FormError.none());

    try {
      if (_sessionService.settings == null) throw Exception("Die Settings sind nicht geladen.");
      if (_sessionService.user == null) throw Exception("Der Benutzer ist nicht geladen.");
      if (_sessionService.privateKey == null) throw Exception("Der privater Schlüssel ist nicht entpackt.");

      // 4. Benutzername in der DB aktualisieren (falls nicht registriert)
      var user = _sessionService.user!;
      if (!state.isRegistered && userName != user.name) {
        user = user.copyWith(name: userName);
        await _databaseService.saveUser(user);
      }

      // 5. Session aktualisieren
      _sessionService.setSession(
        user: user,
        privateKey: _sessionService.privateKey!,
        vaultName: _sessionService.vaultName,
        settings: _sessionService.settings!,
      );

      // 6. State aktualisieren
      final formData = state.formData.copyWith(userName: userName);
      final originalFormData = state.originalFormData.copyWith(userName: userName);
      state = state.copyWith(
        formData: formData,
        originalFormData: originalFormData,
        status: SettingsActionStatus.saved,
      );

    } catch (e, st) {
      Logger().fatal("Fehler beim Speichern: $e", stack: st);
      state = state.copyWith(status: SettingsActionStatus.failure, error: FormError(ErrorCode.unknown));
    }
  }

  /// Speichert die Einstellungen für den Sync-Server.
  Future<void> saveSyncServer() async {
    if (state.isBusy) return;

    // 1. Benutzereingabe bereinigen
    final host = _normalizeUrl(state.formData.host);
    final apiToken = state.formData.apiToken.trim();

    // 2. Benutzereingabe validieren
    if (host.isEmpty) {
      state = state.copyWith(error: FormError(ErrorCode.valueRequired, field: 'host'));
      return;
    }

    // 3. Status auf saving setzen
    state = state.copyWith(status: SettingsActionStatus.saving, error: FormError.none());

    try {

      if (_settings == null) throw Exception("Die Settings sind nicht geladen.");
      if (_sessionService.user == null) throw Exception("Der Benutzer ist nicht geladen.");
      if (_sessionService.privateKey == null) throw Exception("Der privater Schlüssel ist nicht entpackt.");

      // 4. Basiskonfiguration in der DB speichern.
      final updatedSettings = _settings!.copyWith(host: host, apiToken: apiToken);
      _settings = await _databaseService.saveSettings(updatedSettings);

      // 5. Session aktualisieren
      _sessionService.setSession(
        user: _sessionService.user!,
        privateKey: _sessionService.privateKey!,
        vaultName: _sessionService.vaultName,
        settings: _settings!,
      );

      // 6. State aktualisieren
      final formData = state.formData.copyWith(host:host, apiToken: apiToken);
      final originalFormData = state.originalFormData.copyWith(host: host, apiToken: apiToken);
      state = state.copyWith(
        formData: formData,
        originalFormData: originalFormData,
        status: SettingsActionStatus.saved,
      );

    } catch (e, st) {
      Logger().fatal("Fehler beim Speichern: $e", stack: st);
      state = state.copyWith(status: SettingsActionStatus.failure, error: FormError(ErrorCode.unknown));
    }
  }

  /// Testet die Verbindung zum Sync-Server.
  Future<void> testConnection() async {
    if (state.isBusy) return;

    // 1. Benutzereingabe bereinigen
    final host = _normalizeUrl(state.formData.host);
    final apiToken = state.formData.apiToken.trim();

    // 2. Benutzereingabe validieren
    if (host.isEmpty) {
      state = state.copyWith(error: FormError(ErrorCode.valueRequired, field: 'host'));
      return;
    }
    if (apiToken.isEmpty) {
      state = state.copyWith(error: FormError(ErrorCode.valueRequired, field: 'apiToken'));
      return;
    }

    // 3. Busy setzen, Fehler zurücksetzen
    state = state.copyWith(status: SettingsActionStatus.testing, error: FormError.none());

    try {
      // 4. WebService mit den aktuell sichtbaren Einstellungen konfigurieren
      _webService.updateConfig(host: host, apiToken: apiToken);

      // 5. Verbindung testen, indem die Version abgefragt wird
      final response = await _webService.getServerVersion();
      final successful = response.service.contains("PriVault");
      state = state.copyWith(status: successful ? SettingsActionStatus.testSuccessful : SettingsActionStatus.testFailed);

    } on DioException catch (de) {
      // Exception des HTTP-Clients
      state = state.copyWith(status: SettingsActionStatus.failure, error: _convertDioError(de));

    } catch (e) {
      state = state.copyWith(status: SettingsActionStatus.failure, error: FormError(ErrorCode.networkError, text: 'Verbindung fehlgeschlagen.'));
    }
  }

  /// Entfernt ein Slash-Zeichen am Ende der URL.
  String _normalizeUrl(String url) {
    return url.trim().replaceAll(RegExp(r'/+$'), '');
  }

  /// Wandelt den Verbindungsfehler in ein FormError um.
  FormError _convertDioError(DioException de) {
    if (de.response?.statusCode == 404) {
      return FormError(ErrorCode.unauthorized, text: 'Die Host-URL ist ungültig.');
    }
    if (de.response?.statusCode == 401 && (de.response?.statusMessage ?? '').contains('API-Token')) {
      return FormError(ErrorCode.unauthorized, text: 'Die Host-URL ist korrekt, aber API-Token ist ungültig.');
    }
    final text = '${de.response?.statusMessage ?? 'Verbindungsfehler'} (Code ${de.response?.statusCode}).';
    return FormError(ErrorCode.unauthorized, text: text);
  }

// ------------------------------------------------------------------------
  // --- Bereich "Passwort-Generator" ---
  // ------------------------------------------------------------------------

  /// Speichert Einstellungen für den Passwort-Generator.
  Future<void> savePasswortGeneratorSettings() async {
    if (state.isBusy) return;

    // 1. Benutzereingabe bereinigen und im UI-State übernehmen
    final pwLength = state.formData.pwLength;
    final pwSpecialChars = state.formData.pwSpecialChars; //.trim(); darf Leerzeichen am Ende haben
    final pwAvoidIlO0 = state.formData.pwAvoidIlO0;

    // 2. Benutzereingabe validieren
    if (pwLength < 1) {
      state = state.copyWith(error: FormError(ErrorCode.valueInvalid, field: 'pwLength'));
      return;
    }

    // 3. Status auf saving setzen
    state = state.copyWith(status: SettingsActionStatus.saving, error: FormError.none());

    try {
      if (_settings == null) throw Exception("Die Settings sind nicht geladen.");
      if (_sessionService.user == null) throw Exception("Der Benutzer ist nicht geladen.");
      if (_sessionService.privateKey == null) throw Exception("Der privater Schlüssel ist nicht entpackt.");

      // 3. Basiskonfiguration in der DB speichern.
      final updatedSettings = _settings!.copyWith(
        pwLength: pwLength,
        pwSpecialChars: pwSpecialChars,
        pwAvoidIlO0: pwAvoidIlO0,
      );
      _settings = await _databaseService.saveSettings(updatedSettings);

      // 4. Session aktualisieren
      _sessionService.setSession(
        user: _sessionService.user!,
        privateKey: _sessionService.privateKey!,
        vaultName: _sessionService.vaultName,
        settings: _settings!,
      );

      // 6. State aktualisieren
      final formData = state.formData.copyWith(pwLength: pwLength, pwSpecialChars: pwSpecialChars, pwAvoidIlO0: pwAvoidIlO0);
      final originalFormData = state.originalFormData.copyWith(pwLength: pwLength, pwSpecialChars: pwSpecialChars, pwAvoidIlO0: pwAvoidIlO0);
      state = state.copyWith(
        formData: formData,
        originalFormData: originalFormData,
        status: SettingsActionStatus.saved,
      );

    } catch (e, st) {
      Logger().fatal("Fehler beim Speichern: $e", stack: st);
      state = state.copyWith(status: SettingsActionStatus.failure, error: FormError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Bereich "Freunde" ---
  // ------------------------------------------------------------------------

  /// Fügt den einen Freund über den angegebenen Namen hinzu.
  Future<void> addFriend(String name) async {
    if (state.isBusy) return;

    // 1. Benutzereingabe validieren

    // Name muss angegeben sein
    name = name.trim();
    if (name.isEmpty) {
      state = state.copyWith(error: FormError(ErrorCode.valueRequired, field: 'name'));
      return;
    }

    // Du kannst dich nicht selbst als Freund hinzufügen
    final lowerName = name.toLowerCase();
    if (lowerName == _sessionService.user?.name.toLowerCase()) {
      state = state.copyWith(error: FormError(ErrorCode.userSelfAdd));
      return;
    }

    // Prüfen ob bereits in der Liste
    if (state.friends.any((f) => f.name.toLowerCase() == lowerName)) {
      state = state.copyWith(error: FormError(ErrorCode.userAlreadyAdded));
      return;
    }

    // Host und API-Token müssen angegeben sein
    final host = _normalizeUrl(state.formData.host);
    final apiToken = state.formData.apiToken.trim();
    if (host.isEmpty) {
      state = state.copyWith(error: FormError(ErrorCode.valueRequired, field: 'host'));
      return;
    }
    if (apiToken.isEmpty) {
      state = state.copyWith(error: FormError(ErrorCode.valueRequired, field: 'apiToken'));
      return;
    }

    // 2. Status auf loading setzen
    state = state.copyWith(status: SettingsActionStatus.loading, error: FormError.none());

    try {
      // 3. Benutzer auf dem Server suchen
      _webService.updateConfig(host: host, apiToken: apiToken);
      final userResponse = await _webService.findUser(_sessionService.vaultName, name);
      if (userResponse == null) {
        state = state.copyWith(status: SettingsActionStatus.failure, error: FormError(ErrorCode.userNotFound));
        return;
      }

      // 4. Benutzer neu anlegen bzw. wieder einblenden, falls ausgeblendet ist
      await _databaseService.saveUser(UserEntity(
        id: 0,
        uuid: userResponse.userUuid,
        name: name,
        publicKey: userResponse.publicKey,
        isVerified: false, isHidden: false,
        updatedAt: DateTime.now().toUtc(),
      ));

      // 5. UI-State aktualisieren
      final friends = await _databaseService.getNotHiddenFriends();
      final fingerprints = _getFingerprints(friends);
      final friendNeedsRekeying = await _getFriendNeedsRekeying(friends);
      state = state.copyWith(
        friends: friends,
        fingerprints: fingerprints,
        friendNeedsRekeying: friendNeedsRekeying,
        status: SettingsActionStatus.friendAdded,
      );

    } on DioException catch (de) {
      // Exception des HTTP-Clients
      state = state.copyWith(status: SettingsActionStatus.failure, error: _convertDioError(de));

    } catch (e, st) {
      Logger().fatal("Suche fehlgeschlagen: $e", stack: st);
      state = state.copyWith(status: SettingsActionStatus.failure, error: FormError(ErrorCode.unknown));
    }
  }

  /// Berechnet die SHA-256 Fingerprints der Freunde basierend auf dem PublicKey.
  /// Nutzt ein unsichtbares Leerzeichen (\u200B) nach den Doppelpunkten für bessere Zeilenumbrüche in der UI.
  Map<int, String> _getFingerprints(List<UserEntity> friends) {
    final map = <int, String>{};
    for (var f in friends) {
      map[f.id] = _cryptoService.fingerprint(f.publicKey).replaceAll(":", ":\u200B");
    }
    return map;
  }

  /// Ermittelt für jeden Freund, ob dieser Zugriff auf Einträge mit geleerten  Entry-Key hat.
  /// Zurückgegeben wird ein Mapping UserID -> true/false
  Future<Map<int, bool>> _getFriendNeedsRekeying(List<UserEntity> friends) async {
    final idsWithMissingKeys = await _databaseService.getUserIdsWithEmptyEntryKeys();
    final map = <int, bool>{};
    for (var f in friends) {
      map[f.id] = idsWithMissingKeys.contains(f.id);
    }
    return map;
  }

  /// Speichert den aktualisierten Verifizierungsstatus des Freundes.
  Future<void> toggleVerification(UserEntity friend) async {
    if (state.isBusy) return;

    final isVerified = !friend.isVerified;
    final needsRekeying = state.friendNeedsRekeying; // todo muss friendNeedsRekeying im State sein?

    // 1. Status auf loading setzen
    state = state.copyWith(status: SettingsActionStatus.loading, error: FormError.none());

    try {
      // 2. Wenn verifiziert wird, fehlende Entry-Keys generieren.
      if (isVerified) {
        await _rekeyEntriesForFriend(friend);
        if (state.friendNeedsRekeying[friend.id] ?? false) {
          needsRekeying[friend.id] = false;
        }
      }

      // 3. Änderung speichern
      final updatedUser = friend.copyWith(isVerified: isVerified, updatedAt: DateTime.now().toUtc());
      await _databaseService.saveUser(updatedUser);

      // 4. UI-State aktualisieren
      state = state.copyWith(
        friendNeedsRekeying: needsRekeying,
        status: SettingsActionStatus.friendVerified,
      );

    } catch (e, st) {
      Logger().fatal("Fehler beim Speichern der Verifizierung: $e", stack: st);
      state = state.copyWith(status: SettingsActionStatus.failure, error: FormError(ErrorCode.unknown));
    }
  }

  /// Verschlüsselt alle Entry-Keys, die aufgrund eines Identitätswechsels geleert wurden.
  ///
  /// Diese Methode wird aufgerufen, wenn ein Freund verifiziert wird.
  Future<void> _rekeyEntriesForFriend(UserEntity friend) async {
    if (_sessionService.privateKey == null) throw Exception("PrivateKey nicht initialisiert.");

    // 1. Die geleerten Berechtigungen des Freundes laden
    final dirtyPermissions = await _databaseService.getPermissionsWithoutKeyByUserId(friend.id);

    for (var perm in dirtyPermissions) {
      // 2. Wir brauchen meine eigene Berechtigung für diesen Eintrag, um an den AES-Entry-Key zu kommen
      final myPerm = await _databaseService.getPermissionByEntryIdAndUserId(perm.entryId, 1); // 1 = Me
      if (myPerm == null) continue;

      // 3. Entry-Key mit meinem Private-Key entschlüsseln
      final entryKey = await _cryptoService.decryptRsa(myPerm.encryptedKey, utf8.decode(_sessionService.privateKey!));

      // 4. Entry-Key mit dem NEUEN Public-Key des Freundes verschlüsseln
      final encryptedKey = await _cryptoService.encryptRsa(entryKey, friend.publicKey);

      // 5. In DB speichern (wird beim nächsten Sync hochgeladen)
      perm = perm.copyWith(encryptedKey: encryptedKey);
      await _databaseService.savePermission(perm);
    }
  }

  /// Entfernt einen Freund aus der Liste.
  ///
  /// Der Datensatz wird gelöscht, wenn keine Verknüpfungen bestehen, ansonsten wird er ausgeblendet.
  Future<void> deleteFriend(UserEntity friend) async {
    if (state.isBusy) return;

    // 1. Status auf `deleting` setzen
    state = state.copyWith(status: SettingsActionStatus.deleting, error: FormError.none());

    try {
      // 2. Freund löschen bzw. ausblenden
      final perms = await _databaseService.getPermissionsByUserId(friend.id);
      if (perms.isEmpty) {
        // Es werden keine Einträge mit dem Freund geteilt, daher kann er gelöscht werden.
        await _databaseService.deleteUser(friend.id);
      } else {
        // Der Freund wird nicht gelöscht, sondern ausgeblendet, damit beim Synchronisieren alle geteilten Einträge entfernt werden können.
        await _databaseService.hideUser(friend.id);
      }

      // 3. UI-State zurücksetzen
      final friends = await _databaseService.getNotHiddenFriends();
      final fingerprints = _getFingerprints(friends);
      final friendNeedsRekeying = await _getFriendNeedsRekeying(friends);
      state = state.copyWith(
        friends: friends,
        fingerprints: fingerprints,
        friendNeedsRekeying: friendNeedsRekeying,
        status: SettingsActionStatus.friendDeleted,
      );

    } catch (e, st) {
      Logger().fatal('Löschen fehlgeschlagen: $e', stack: st);
      state = state.copyWith(status: SettingsActionStatus.failure, error: FormError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Bereich "Design" ---
  // ------------------------------------------------------------------------

  /// Setter für das Farbschema.
  ///
  /// `PriVaultApp` (siehe `main.dart`) beobachtet das Farbschema indirekt über
  /// das `MaterialApp`-Widget und reagiert auf diese Änderungen.
  void setThemeMode(ThemeMode value) {
    final error = state.error.field == 'themeMode' ? FormError.none() : null;
    state = state.copyWith(themeMode: value, error: error);
    if (_configService.theme == value.name) return;
    _configService.theme = value.name;
  }

  /// Speichert den Platzhalter für eine leere Kategorie.
  Future<void> saveCategoryPlaceholder(String categoryPlaceholder) async {
    if (state.isBusy) return;

    // 1. Benutzereingabe bereinigen
    final categoryPlaceholder = state.formData.categoryPlaceholder.trim();

    // 2. Benutzereingabe validieren
    if (categoryPlaceholder.isEmpty) {
      state = state.copyWith(error: FormError(ErrorCode.valueRequired, field: 'categoryPlaceholder'));
      return;
    }
    if (categoryPlaceholder == state.originalFormData.categoryPlaceholder) {
      state = state.copyWith(error: FormError(ErrorCode.valueNotChanged, field: 'categoryPlaceholder'));
      return;
    }

    // 3. Status auf saving setzen
    state = state.copyWith(status: SettingsActionStatus.saving, error: FormError.none());

    try {
      if (_settings == null || _sessionService.settings == null) throw Exception("Die Settings sind nicht geladen.");
      if (_sessionService.user == null) throw Exception("Der Benutzer ist nicht geladen.");
      if (_sessionService.privateKey == null) throw Exception("Der privater Schlüssel ist nicht entpackt.");

      // 4. Basiskonfiguration in der DB speichern.
      final updatedSettings = _settings!.copyWith(categoryPlaceholder: categoryPlaceholder);
      _settings = await _databaseService.saveSettings(updatedSettings);

      // 5. Session aktualisieren
      _sessionService.setSession(
        user: _sessionService.user!,
        privateKey: _sessionService.privateKey!,
        vaultName: _sessionService.vaultName,
        settings: _settings!,
      );

      // 6. State aktualisieren
      final formData = state.formData.copyWith(categoryPlaceholder: categoryPlaceholder);
      final originalFormData = state.originalFormData.copyWith(categoryPlaceholder: categoryPlaceholder);
      state = state.copyWith(
        formData: formData,
        originalFormData: originalFormData,
        status: SettingsActionStatus.saved,
      );

    } catch (e, st) {
      Logger().fatal("Fehler beim Speichern: $e", stack: st);
      state = state.copyWith(status: SettingsActionStatus.failure, error: FormError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Bereich "Systemeinstellungen" ---
  // ------------------------------------------------------------------------

  /// Öffnet die Systemeinstellungen für Biometrie.
  Future<void> openBiometricSettings() async {
    await _biometricService.openSystemSettings();
  }

  /// Öffnet die Systemeinstellungen (oder eine Hilfeseite) für den Autofill-Dienst.
  Future<void> openAutofillSettings() async {
    await _autofillService.openSystemSettings();
  }

  /// Öffnet die App-Info-Seite in den Systemeinstellungen.
  Future<void> openAppSettings() async {
    // todo Die Platform-Weiche möchte ich hier nicht haben. Daher auslagern in einen Service.
    if (Platform.isWindows) {
      // Unter Windows gibt es keinen direkten Weg in die Detail-Ansicht einer fremden MSIX/EXE via URI.
      // Der Standardweg öffnet "ms-settings:appsfeatures-app".
      // Man kann versuchen, direkt auf die Windows-App-Einstellungen für *diese* App zu zielen.
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        final pfn = packageInfo.packageName;
        final advancedUri = Uri.parse('ms-settings:appsfeatures-app?PFN=$pfn');

        if (await canLaunchUrl(advancedUri)) {
          await launchUrl(advancedUri);
          return;
        }
      } catch (_) {}

      // Fallback: Die allgemeine Liste der installierten Apps
      await launchUrl(Uri.parse('ms-settings:appsfeatures'));
    } else if (Platform.isAndroid) {
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        final packageName = packageInfo.packageName;
        await launchUrl(Uri.parse('intent:package:$packageName#Intent;action=android.settings.APPLICATION_DETAILS_SETTINGS;end'));
      } catch (_) {
        await launchUrl(Uri.parse('intent:#Intent;action=android.settings.APPLICATION_SETTINGS;end'));
      }
    } else if (Platform.isIOS || Platform.isMacOS) {
      await launchUrl(Uri.parse('app-settings:'));
    }
  }

  // ------------------------------------------------------------------------
  // --- Setter für den UI-State (synchron) ---
  // ------------------------------------------------------------------------

  // todo

  /// Setter für Tresorname.
  void setVaultName(String value) {
    // Ungültige Zeichen für Dateinamen entfernen
    final vaultName = value.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    final error = state.error.field == 'vaultName' ? FormError.none() : null;
    final formData = state.formData.copyWith(vaultName: vaultName);
    state = state.copyWith(formData: formData, error: error);
  }

  /// Setter für "Biometrie erlauben".
  void setUseBiometric(bool value) {
    final error = state.error.field == 'useBiometric' ? FormError.none() : null;
    final formData = state.formData.copyWith(useBiometric: value);
    state = state.copyWith(formData: formData, error: error);
  }

  /// Setter für den Benutzername.
  void setUserName(String value) {
    final error = state.error.field == 'userName' ? FormError.none() : null;
    final formData = state.formData.copyWith(userName: value.trim());
    state = state.copyWith(formData: formData, error: error);
  }

  /// Setter für den Host.
  void setHost(String value) {
    final error = state.error.field == 'host' ? FormError.none() : null;
    final formData = state.formData.copyWith(host: value.trim());
    state = state.copyWith(formData: formData, error: error);
  }

  /// Setter für den API-Token.
  void setApiToken(String value) {
    final error = state.error.field == 'apiToken' ? FormError.none() : null;
    final formData = state.formData.copyWith(apiToken: value.trim());
    state = state.copyWith(formData: formData, error: error);
  }

  /// Setter für Passwortlänge
  void setPwLength(int value) {
    final error = state.error.field == 'pwLength' ? FormError.none() : null;
    final formData = state.formData.copyWith(pwLength: value);
    state = state.copyWith(formData: formData, error: error);
  }

  /// Setter für Passwort-Sonderzeichen
  void setPwSpecialChars(String value) {
    final error = state.error.field == 'pwSpecialChars' ? FormError.none() : null;
    final formData = state.formData.copyWith(pwSpecialChars: value);
    state = state.copyWith(formData: formData, error: error);
  }

  /// Setzt keine Passwort-Sonderzeichen
  void setNonePwSpecialChars() {
    setPwSpecialChars('');
  }

  /// Setzt empfohlene Passwort-Sonderzeichen.
  void setDefaultPwSpecialChars() {
    setPwSpecialChars('!@#\$%^&*()_+-=[]{}|;:,.<>?');
  }

  /// Setzt alle Passwort-Sonderzeichen.
  void setAllPwSpecialChars() {
    setPwSpecialChars('!"#\$%&\'()*+,-./:;<=>?@[\\]^_`{|}~');
  }

  /// Setter für "verwechselbare Zeichen auslassen".
  void setPwAvoidIlO0(bool value) {
    final error = state.error.field == 'pwAvoidIlO0' ? FormError.none() : null;
    final formData = state.formData.copyWith(pwAvoidIlO0: value);
    state = state.copyWith(formData: formData, error: error);
  }

  /// Setter für das Farbschema.
  ///
  /// Das Theme wird sofort übernommen (ohne auf "Speichern" zu klicken).
  /// `PriVaultApp` (siehe `main.dart`) beobachtet das Farbschema indirekt über
  /// das `MaterialApp`-Widget und reagiert auf Änderungen.
  void setThemeMode2(ThemeMode value) {
    final error = state.error.field == 'themeMode' ? FormError.none() : null;
    state = state.copyWith(themeMode: value, error: error);
    if (_configService.theme == value.name) return;
    _configService.theme = value.name;
  }

  /// Setter für die Kategorie.
  void setCategoryPlaceholder(String value) {
    final error = state.error.field == 'category' ? FormError.none() : null;
    final formData = state.formData.copyWith(categoryPlaceholder: value);
    state = state.copyWith(formData: formData, error: error);
  }
}
