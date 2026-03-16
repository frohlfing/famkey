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
import 'package:privault/features/settings/settings_snapshot.dart';
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

  /// Wird für Dirty Check beim Abbrechen benötigt.
  SettingsSnapshot? _orig; // todo evtl. State _orig; verwenden

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

    // Theme aus ConfigService laden
    final theme = ThemeMode.values.firstWhere((t) => t.name == _configService.theme, orElse: () => ThemeMode.system);

    // Initialer State
    return SettingsState(themeMode: theme); // todo warum themeMode übergeben?
  }

  /// Lädt die Daten für die Anzeige.
  Future<void> load() async {
    // Busy setzen, Fehler zurücksetzen
    state = state.copyWith(isBusy: true, error: FormError.none());

    try {
      // Daten aus der Datenbank laden
      _settings = await _databaseService.getSettings();

      // UI-State aktualisieren
      if (_settings != null) {
        state = state.copyWith(
          vaultName: _sessionService.vaultName,
          userName: _sessionService.user?.name ?? '',
          useBiometric: _settings!.useBiometric,
          isRegistered: _settings!.lastSyncAt.year > 1970,
          host: _settings!.host,
          apiToken: _settings!.apiToken,
          pwLength: _settings!.pwLength,
          pwSpecialChars: _settings!.pwSpecialChars,
          pwAvoidIlO0: _settings!.pwAvoidIlO0,
          categoryPlaceholder: _settings!.categoryPlaceholder.isEmpty ? 'Allgemein' : _settings!.categoryPlaceholder,
        );

      } else {
        state = state.copyWith(
          vaultName: _sessionService.vaultName,
          userName: _sessionService.user?.name ?? '',
          useBiometric: false,
          isRegistered: false,
          host: '',
          apiToken: '',
          pwLength: 16,
          pwSpecialChars: '',
          pwAvoidIlO0: true,
          categoryPlaceholder: 'Allgemein',
        );
      }

      // Snapshot für Dirty-Check
      _orig = SettingsSnapshot(  // können wir als Snapshot nicht einfach eine Kopie von state machen?
        vaultName: state.vaultName,
        useBiometric: state.useBiometric,
        userName: state.userName,
        host: state.host,
        apiToken: state.apiToken,
        pwLength: state.pwLength,
        pwSpecialChars: state.pwSpecialChars,
        pwAvoidIlO0: state.pwAvoidIlO0,
        categoryPlaceholder: state.categoryPlaceholder,
      );

      // Freundesliste laden
      await _loadFriends();

    } catch (e, st) {
      Logger().fatal('Fehler beim Laden: $e', stack: st);
      state = state.copyWith(error: FormError(ErrorCode.unknown));

    } finally {
      // Busy zurücksetzen
      state = state.copyWith(isBusy: false);
    }
  }

  // ------------------------------------------------------------------------
  // --- Dirty-Check ---
  // ------------------------------------------------------------------------

  /// Gibt an, ob der Benutzer ein Feld verändert hat.
  bool isDirty() {
    return _orig == null || // sollte hier nicht vorkommen, da Settings bereits mit dem Login angelegt wird
        state.vaultName != _orig!.vaultName ||
        state.useBiometric != _orig!.useBiometric ||
        state.userName != _orig!.userName ||
        state.host != _orig!.host ||
        state.apiToken != _orig!.apiToken ||
        state.pwLength != _orig!.pwLength ||
        state.pwSpecialChars != _orig!.pwSpecialChars ||
        state.pwAvoidIlO0 != _orig!.pwAvoidIlO0 ||
        state.categoryPlaceholder != _orig!.categoryPlaceholder;
  }

  // ------------------------------------------------------------------------
  // --- Speichern ---
  // ------------------------------------------------------------------------

  /// Speichert alle geänderten Einstellungen (mit Ausnahme des Tresornamens)
  /// in der Datenbank und aktualisiert die Session.
  Future<bool> save() async {
    // Busy setzen, Fehler zurücksetzen
    state = state.copyWith(isBusy: true, error: FormError.none());

    try {

      if (_settings == null) throw Exception("Settings nicht aus initialisiert.");

      // 1. Falls Biometrie deaktiviert wurde, SecureStore leeren
      if (_settings!.useBiometric && !state.useBiometric) {
        await _biometricService.removeMasterKey(_sessionService.vaultName);
        Logger().info("Biometrie-Key entfernt, da Option deaktiviert wurde.");
      }

      // 2. Alle Basis-Einstellungen in der DB speichern (Host, API, PW-Gen).
      final updated = _settings!.copyWith(
        host: state.host,
        apiToken: state.apiToken,
        useBiometric: state.useBiometric,
        pwLength: state.pwLength,
        pwSpecialChars: state.pwSpecialChars,
        pwAvoidIlO0: state.pwAvoidIlO0,
        categoryPlaceholder: state.categoryPlaceholder,
      );
      await _databaseService.saveSettings(updated);

      // 3. Benutzername aktualisieren (falls nicht registriert)
      var user = _sessionService.user!;
      if (!state.isRegistered && state.userName != user.name) {
        user = user.copyWith(name: state.userName);
        await _databaseService.saveUser(user);
      }

      // 4. Session aktualisieren
      _sessionService.setSession(
        user: user,
        privateKey: _sessionService.privateKey!,
        vaultName: state.vaultName,
        settings: updated,
      );

      // 5. Snapshot aktualisieren
      _orig = SettingsSnapshot(
        vaultName: state.vaultName,
        useBiometric: state.useBiometric,
        userName: state.userName,
        host: state.host,
        apiToken: state.apiToken,
        pwLength: state.pwLength,
        pwSpecialChars: state.pwSpecialChars,
        pwAvoidIlO0: state.pwAvoidIlO0,
        categoryPlaceholder: state.categoryPlaceholder,
      );

      return true;

    } catch (e, st) {
      Logger().fatal("Fehler beim Speichern: $e", stack: st);
      state = state.copyWith(error: FormError(ErrorCode.unknown));
      return false;

    } finally {
      // Busy zurücksetzen
      state = state.copyWith(isBusy: false);
    }
  }

  // ------------------------------------------------------------------------
  // --- Bereich "Tresor" ---
  // ------------------------------------------------------------------------

  /// Benennt den Tresor um und aktualisiert die Session.
  ///
  /// Das Master-Passwort wurde zuvor von der UI abgefragt.
  Future<bool> renameVault(String password) async {
    final newVaultName = state.vaultName;
    final oldVaultName = _sessionService.vaultName; // bisheriger Name

    // Validierung der Benutzereingabe
    if (newVaultName == oldVaultName) {
      state = state.copyWith(error: FormError(ErrorCode.vaultEqualName, field: 'vaultName'));
      return false;
    }
    if (await _databaseService.databaseExists(newVaultName)) {
      state = state.copyWith(error: FormError(ErrorCode.vaultAlreadyExists, field: 'vaultName'));
      return false;
    }

    Uint8List? masterKey;

    // Busy setzen, Fehler zurücksetzen
    state = state.copyWith(isBusy: true, error: FormError.none());

    try {
      if (_settings == null) throw Exception("Settings ist nicht initialisiert.");
      if (_settings!.encryptedPrivateKey.isEmpty) throw Exception("`encryptedPrivateKey` ist in Settings leer");
      if (_settings!.salt.isEmpty) throw Exception("Das Salt ist nicht in Settings gespeichert.");
      if (_sessionService.privateKey == null) throw Exception("Der privater Schlüssel ist nicht entpackt.");
      if (state.isRegistered) throw Exception("Dieser Tresor wurde bereits synchronisiert und kann daher nicht mehr umbenannt werden.");

      // Kurze Pause für Lade-Indikator, bevor Argon2 blockiert
      await Future.delayed(const Duration(milliseconds: 50));

      // 1. MasterKey ableiten (Argon2id)
      final salt = base64Decode(_settings!.salt);
      masterKey = await _cryptoService.deriveKey(password, salt);

      // 2. Passwort validieren
      try {
        await _cryptoService.decrypt(_settings!.encryptedPrivateKey, masterKey);
      } catch (_) {
        state = state.copyWith(error: FormError(ErrorCode.wrongPassword, field: 'password'));
        return false;
      }

      // 3. Physisches Datenbank-Backup erstellen
      await _databaseService.createBackup();
      try {
        // --- Start Kritische Logik ---

        // 4. Verbindung trennen & Umbenennen
        await _databaseService.close();
        await _databaseService.renameDatabaseAndSaltFile(oldVaultName, newVaultName);

        // 5. Konfiguration (Login-Liste / Config) aktualisieren
        if (_configService.lastVaultName == oldVaultName) {
          _configService.lastVaultName = newVaultName;
        }

        // 6. Neue Verbindung zur umbenannten Datei herstellen
        await _databaseService.initialize(newVaultName, masterKey);

        // 7. Master-Key im SecureStore umziehen
        if (await _biometricService.containsMasterKey(oldVaultName)) {
          await _biometricService.removeMasterKey(oldVaultName);
          if (_settings!.useBiometric) {
            await _biometricService.saveMasterKey(newVaultName, masterKey);
          }
        }

        // 8. Session aktualisieren
        _sessionService.setSession(
          user: _sessionService.user!,
          privateKey: _sessionService.privateKey!,
          vaultName: newVaultName,
          settings: _settings!,
        );

        // --- Ende Kritische Logik ---

        // 9. Erfolg: Backup löschen
        await _databaseService.removeBackup();
        return true;

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
      state = state.copyWith(error: FormError(ErrorCode.unknown));
      return false;

    } finally {
      // Master-Key aus dem RAM löschen
      if (masterKey != null) _cryptoService.wipeKey(masterKey);

      // Busy zurücksetzen
      state = state.copyWith(isBusy: false);
    }
  }

  /// Löscht den aktuellen Tresor lokal vom Gerät.
  Future<bool> deleteVault() async {
    // Datenbank löschen
    await _databaseService.deleteCurrentDatabaseAndSaltFile();

    // SecureStore leeren
    await _biometricService.removeMasterKey(_sessionService.vaultName);

    // Den Konfiguration bereinigen
    if (_configService.lastVaultName == _sessionService.vaultName) {
      _configService.lastVaultName = '';
    }

    // Session zurücksetzen
    _sessionService.clearSession();
    return true;
  }

  // ------------------------------------------------------------------------
  // --- Bereich "Login" ---
  // ------------------------------------------------------------------------

  /// Generiert ein neuen Salt, verschlüsselt die sqLite-Datei mit dem neuen Master-Schlüssel und aktualisiert die Salt-Datei.
  Future<bool> changeMasterPassword(String newPassword, String password) async {
    // Validierung der Benutzereingabe
    if (newPassword == password) {
      state = state.copyWith(error: FormError(ErrorCode.equalPassword, field: 'password'));
      return false;
    }

    Uint8List? masterKey; // bisheriger Master-Key
    Uint8List? newMasterKey;

    // Busy setzen, Fehler zurücksetzen
    state = state.copyWith(isBusy: true, error: FormError.none());

    try {
      if (_settings == null) throw Exception("Settings ist nicht initialisiert.");
      if (_settings!.encryptedPrivateKey.isEmpty) throw Exception("`encryptedPrivateKey` ist in Settings leer");
      if (_settings!.salt.isEmpty) throw Exception("Das Salt ist nicht in Settings gespeichert.");
      if (_sessionService.privateKey == null) throw Exception("Der privater Schlüssel ist nicht entpackt.");

      // Kurze Pause für Lade-Indikator, bevor Argon2 blockiert
      await Future.delayed(const Duration(milliseconds: 50));

      // 1. MasterKey ableiten (Argon2id)
      final salt = base64Decode(_settings!.salt);
      masterKey = await _cryptoService.deriveKey(password, salt);

      // 2. Passwort validieren
      try {
        await _cryptoService.decrypt(_settings!.encryptedPrivateKey, masterKey);
      } catch (_) {
        state = state.copyWith(error: FormError(ErrorCode.wrongPassword, field: 'password'));
        return false;
      }

      // 3. Physisches Datenbank-Backup erstellen
      await _databaseService.createBackup();

      try {
        // --- Start Kritische Logik ---

        // 4. Neues Salt generieren
        final newSalt = _cryptoService.generateSalt();

        // 5. Neuen Master-Key ableiten
        newMasterKey = await _cryptoService.deriveKey(newPassword, newSalt);

        // 6. Private-Key mit dem neuen Master-Key verschlüsseln
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
        return true;

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
      state = state.copyWith(error: FormError(ErrorCode.unknown));
      return false;

    } finally {
      // Master-Key aus dem RAM löschen
      if (masterKey != null) _cryptoService.wipeKey(masterKey);
      if (newMasterKey != null) _cryptoService.wipeKey(newMasterKey);

      // Busy zurücksetzen
      state = state.copyWith(isBusy: false);
    }
  }

  // ------------------------------------------------------------------------
  // --- Bereich "Sync-Server" ---
  // ------------------------------------------------------------------------

  /// Testet die Verbindung zum Sync-Server.
  Future<bool> testConnection() async {
    // Busy setzen, Fehler zurücksetzen
    state = state.copyWith(isBusy: true, error: FormError.none());

    try {
      // WebService mit den aktuell sichtbaren Einstellungen konfigurieren
      _initWebService();

      // Verbindung testen, indem die Version abgefragt wird
      final response = await _webService.getServerVersion();
      return response.service.contains("PriVault");

    } on DioException catch (de) {
      // Exception des HTTP-Clients
      _setDioError(de);
      return false;

    } catch (e) {
      state = state.copyWith(error: FormError(ErrorCode.networkError, text: 'Verbindung fehlgeschlagen.'));
      return false;

    } finally {
      // Busy zurücksetzen
      state = state.copyWith(isBusy: false);
    }
  }

  /// Konfiguriert den WebService mit den aktuell sichtbaren Einstellungen.
  ///
  /// Wirft ein Exception, wenn die Host-URL oder API-Token nicht angegeben sind.
  void _initWebService() {
    if (state.host.isEmpty) {
      throw Exception("Für die Synchronisation muss eine gültige Host-URL hinterlegt sein. Bitte trage sie in den Einstellungen ein.");
    }

    if (state.apiToken.isEmpty) {
      throw Exception("Für die Synchronisation muss ein gültiger API-Token hinterlegt sein. Bitte trage ihn in den Einstellungen ein.");
    }

    _webService.updateConfig(host: state.host, apiToken: state.apiToken);
  }

  /// Wertet den Verbindungsfehler aus und speichert den Fehler im State.
  void _setDioError(DioException de) {
    if (de.response?.statusCode == 404) {
      state = state.copyWith(error: FormError(ErrorCode.unauthorized, text: 'Die Host-URL ist ungültig.'));
    }
    else if (de.response?.statusCode == 401 && (de.response?.statusMessage ?? '').contains('API-Token')) {
      state = state.copyWith(error: FormError(ErrorCode.unauthorized, text: 'Die Host-URL ist korrekt, aber API-Token ist ungültig.'));
    }
    else {
      final text = '${de.response?.statusMessage ?? 'Verbindungsfehler'} (Code ${de.response?.statusCode}).';
      state = state.copyWith(error: FormError(ErrorCode.unauthorized, text: text));
    }
  }

  // ------------------------------------------------------------------------
  // --- Bereich "Passwort-Generator" ---
  // ------------------------------------------------------------------------

  /// Setzt den Zeichensatz für den Passwortgenerator basierend auf vordefinierten Gruppen.
  void setSpecialChars(String type) {
    switch (type) {
      case 'None':
        state = state.copyWith(pwSpecialChars: '');
        break;
      case 'Standard':
        state = state.copyWith(pwSpecialChars: '!@#\$%^&*()_+-=[]{}|;:,.<>?');
        break;
      case 'All':
        state = state.copyWith(pwSpecialChars: '!"#\$%&\'()*+,-./:;<=>?@[\\]^_`{|}~');
        break;
    }
  }

  // ------------------------------------------------------------------------
  // --- Bereich "Freunde" ---
  // ------------------------------------------------------------------------

  /// Lädt die Freundesliste.
  Future<void> _loadFriends() async {
    // Alle Benutzer laden
    final allUsers = await _databaseService.getUsers();

    // Den Benutzer der App und ausgeblendete Benutzer herausfiltern.
    // Übrig bleiben die sichtbaren Freunde.
    final friends = allUsers.where((u) => u.id > 1 && !u.isHidden).toList();

    // Alle Benutzer-IDs ermitteln, die ein Rekeying benötigen
    final idsWithMissingKeys = await _databaseService.getUserIdsWithEmptyEntryKeys();

    // Mapping-Tabelle für die UI aufbauen
    final map = <int, bool>{};
    for (var f in friends) {
      map[f.id] = idsWithMissingKeys.contains(f.id);
    }

    // State aktualisieren
    state = state.copyWith(friends: friends, friendNeedsRekeying: map);
  }

  /// Fügt den einen Freund über den angegebenen Namen hinzu.
  Future<bool> addFriend(String name) async {
    name = name.trim();

    // Validierung der Benutzereingabe

    // Name muss angegeben sein
    if (name.isEmpty) {
      state = state.copyWith(error: FormError(ErrorCode.valueRequired, field: 'name'));
      return false;
    }

    // Du kannst dich nicht selbst als Freund hinzufügen
    final lowerName = name.toLowerCase();
    if (lowerName == _sessionService.user?.name.toLowerCase()) {
      state = state.copyWith(error: FormError(ErrorCode.userSelfAdd));
      return false;
    }

    // Prüfen ob bereits in der Liste
    if (state.friends.any((f) => f.name.toLowerCase() == lowerName)) {
      state = state.copyWith(error: FormError(ErrorCode.userAlreadyAdded));
      return false;
    }

    // WebService mit den aktuell sichtbaren Einstellungen konfigurieren
    _initWebService();

    // Busy setzen, Fehler zurücksetzen
    state = state.copyWith(isBusy: true, error: FormError.none());

    try {
      final userResponse = await _webService.findUser(_sessionService.vaultName, name);
      if (userResponse == null) {
        state = state.copyWith(error: FormError(ErrorCode.userNotFound));
        return false;
      }

      // Benutzer neu anlegen bzw. wieder einblenden, falls ausgeblendet ist
      await _databaseService.saveUser(UserEntity(
        id: 0,
        uuid: userResponse.userUuid,
        name: name,
        publicKey: userResponse.publicKey,
        isVerified: false, isHidden: false,
        updatedAt: DateTime.now().toUtc(),
      ));

      // UI-Liste neu laden
      await _loadFriends();
      return true;

    } on DioException catch (de) {
      // Exception des HTTP-Clients
      _setDioError(de);
      return false;

    } catch (e, st) {
      Logger().fatal("Suche fehlgeschlagen: $e", stack: st);
      state = state.copyWith(error: FormError(ErrorCode.unknown));
      return false;

    } finally {
      // Busy zurücksetzen
      state = state.copyWith(isBusy: false);
    }
  }

  /// Speichert den aktualisierten Verifizierungsstatus des Freundes.
  Future<bool> toggleVerification(UserEntity friend) async {
    final isVerified = !friend.isVerified;

    // Busy setzen, Fehler zurücksetzen
    state = state.copyWith(isBusy: true, error: FormError.none());

    try {
      // Wenn verifiziert wird, fehlende Entry-Keys generieren.
      if (isVerified) {
        await _rekeyEntriesForFriend(friend);
      }

      // Änderung speichern
      final updatedUser = friend.copyWith(isVerified: isVerified, updatedAt: DateTime.now().toUtc());
      await _databaseService.saveUser(updatedUser);

      // UI-Liste aktualisieren
      await _loadFriends();
      return true;

    } catch (e, st) {
      Logger().fatal("Fehler beim Speichern der Verifizierung: $e", stack: st);
      state = state.copyWith(error: FormError(ErrorCode.unknown));
      return false;

    } finally {
      // Busy zurücksetzen
      state = state.copyWith(isBusy: false);
    }
  }

  /// Verschlüsselt alle Entry-Keys, die aufgrund eines Identitätswechsels geleert wurden.
  ///
  /// Diese Methode wird aufgerufen, wenn ein Freund verifiziert wird.
  Future<bool> _rekeyEntriesForFriend(UserEntity friend) async {
    if (_sessionService.privateKey == null) throw Exception("PrivateKey nicht initialisiert.");

    // Busy setzen, Fehler zurücksetzen
    state = state.copyWith(isBusy: true, error: FormError.none());

    try {
      // 1. Die geleerten Berechtigungen des Freundes laden
      var dirtyPermissions = await _databaseService.getPermissionsWithoutKeyByUserId(friend.id);
      for (var perm in dirtyPermissions) {
        // 2. Wir brauchen meine eigene Berechtigung für diesen Eintrag, um an den AES-Entry-Key zu kommen
        var myPerm = await _databaseService.getPermissionByEntryIdAndUserId(perm.entryId, 1); // 1 = Me
        if (myPerm == null) continue;

        // 3. Entry-Key mit meinem Private-Key entschlüsseln
        var entryKey = await _cryptoService.decryptRsa(myPerm.encryptedKey, utf8.decode(_sessionService.privateKey!));

        // 4. Entry-Key mit dem NEUEN Public-Key des Freundes verschlüsseln
        final encryptedKey = await _cryptoService.encryptRsa(entryKey, friend.publicKey);

        // 5. In DB speichern (wird beim nächsten Sync hochgeladen)
        perm = perm.copyWith(encryptedKey: encryptedKey);
        await _databaseService.savePermission(perm);
      }

      // State aktualisieren
      if (state.friendNeedsRekeying[friend.id] ?? false) { // todo muss friendNeedsRekeying im State sein?
        final needsRekeying = state.friendNeedsRekeying;
        needsRekeying[friend.id] = false;
        state = state.copyWith(friendNeedsRekeying: needsRekeying);
      }

      return true;

    } catch (e, st) {
      Logger().fatal("Rekeying fehlgeschlagen: $e", stack: st);
      state = state.copyWith(error: FormError(ErrorCode.unknown));
      return false;

    } finally {
      // Busy zurücksetzen
      state = state.copyWith(isBusy: false);
    }
  }

  /// Entfernt einen Freund aus der Liste.
  ///
  /// Der Datensatz wird gelöscht, wenn keine Verknüpfungen bestehen, ansonsten wird er ausgeblendet.
  Future<bool> deleteFriend(UserEntity? friend) async {
    // Busy setzen, Fehler zurücksetzen
    state = state.copyWith(isBusy: true, error: FormError.none());

    try {
      if (friend == null) throw Exception('Kein Freund zum Löschen angegeben.');

      // Prüfen, ob der User überhaupt Berechtigungen hat
      var perms = await _databaseService.getPermissionsByUserId(friend.id);
      if (perms.isEmpty) {
        // Es werden keine Einträge mit dem Freund geteilt, daher kann er gelöscht werden.
        await _databaseService.deleteUser(friend.id);
      } else {
        // Der Freund wird nicht gelöscht, sondern ausgeblendet, damit beim Synchronisieren alle geteilten Einträge entfernt werden können.
        await _databaseService.hideUser(friend.id);
      }

      // Aus der UI-Liste entfernen
      await _loadFriends();
      return true;

    } catch (e, st) {
      Logger().fatal('Löschen fehlgeschlagen: $e', stack: st);
      state = state.copyWith(error: FormError(ErrorCode.unknown));
      return false;

    } finally {
      // Busy zurücksetzen
      state = state.copyWith(isBusy: false);
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
  // --- Convenience Setter & Getter ---
  // ------------------------------------------------------------------------

  /// Setter für Tresorname.
  void setVaultName(String value) {
    // Ungültige Zeichen für Dateinamen filtern
    final cleaned = value.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    final error = state.error.field == 'vaultName' ? FormError.none() : null;
    state = state.copyWith(vaultName: cleaned, error: error);
  }

  /// Setter für "Biometrie erlauben".
  void setUseBiometric(bool value) {
    final error = state.error.field == 'useBiometric' ? FormError.none() : null;
    state = state.copyWith(useBiometric: value, error: error);
  }

  /// Setter für den Benutzername.
  void setUserName(String value) {
    final error = state.error.field == 'userName' ? FormError.none() : null;
    state = state.copyWith(userName: value.trim(), error: error);
  }

  /// Setter für den Host.
  void setHost(String value) {
    final error = state.error.field == 'host' ? FormError.none() : null;
    state = state.copyWith(host: _normalizeUrl(value), error: error);
  }

  /// Entfernt ein Slash-Zeichen am Ende der URL.
  String _normalizeUrl(String url) {
    return url.trim().replaceAll(RegExp(r'/+$'), '');
  }

  /// Setter für den API-Token.
  void setApiToken(String value) {
    final error = state.error.field == 'apiToken' ? FormError.none() : null;
    state = state.copyWith(apiToken: value.trim(), error: error);
  }

  /// Setter für Passwortlänge
  void setPwLength(int value) {
    final error = state.error.field == 'pwLength' ? FormError.none() : null;
    state = state.copyWith(pwLength: value, error: error);
  }

  /// Setter für Sonderzeichen im Passwort
  void setPwSpecialChars(String value) {
    final error = state.error.field == 'pwSpecialChars' ? FormError.none() : null;
    state = state.copyWith(pwSpecialChars: value.trim(), error: error);
  }

  /// Setter für "verwechselbare Zeichen auslassen".
  void setPwAvoidIlO0(bool value) {
    final error = state.error.field == 'pwAvoidIlO0' ? FormError.none() : null;
    state = state.copyWith(pwAvoidIlO0: value, error: error);
  }

  /// Setter für das Farbschema.
  ///
  /// Das Theme wird sofort übernommen (ohne auf "Speichern" zu klicken).
  /// `PriVaultApp` (siehe `main.dart`) beobachtet das Farbschema indirekt über
  /// das `MaterialApp`-Widget und reagiert auf Änderungen.
  void setThemeMode(ThemeMode value) {
    final error = state.error.field == 'themeMode' ? FormError.none() : null;
    state = state.copyWith(themeMode: value, error: error);
    if (_configService.theme == value.name) return;
    _configService.theme = value.name;
  }

  /// Setter für die Kategorie.
  void setCategoryPlaceholder(String value) {
    final error = state.error.field == 'category' ? FormError.none() : null;
    state = state.copyWith(categoryPlaceholder: value.trim(), error: error);
  }

  /// Gibt den Speicherort der Tresore zurück.
  String getVaultStoragePath() {
    return _configService.vaultStoragePath;
  }

  /// Gibt an, ob der Tresor umbenannt wurde
  bool isVaultRenamed() {
    return state.vaultName != _sessionService.vaultName;
  }

  /// Berechnet den SHA-256 Fingerprint basierend auf dem PublicKey.
  /// Nutzt ein unsichtbares Leerzeichen (\u200B) nach den Doppelpunkten für bessere Zeilenumbrüche in der UI.
  String getFingerprint(String publicKey) {
    return _cryptoService.fingerprint(publicKey).replaceAll(":", ":\u200B");
  }

  /// Gibt an, ob für diesen Freund Einträge neu verschlüsselt werden müssen.
  /// Dies ist der Fall, wenn sein RSA-Key geändert und die lokalen Permission-Keys geleert wurden.
  bool needsRekeying(int userId) {
    return state.friendNeedsRekeying[userId] ?? false;
  }
}
