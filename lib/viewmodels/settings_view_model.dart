import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:privault/core/base_view_model.dart';
import 'package:privault/models/entities/settings_entity.dart';
import 'package:privault/models/entities/user_entity.dart';
import 'package:privault/services/biometric_service.dart';
import 'package:privault/services/config_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';
import 'package:privault/services/web_service.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';

/// Ergebnisse für Tresor-Umbenennung
enum RenameVaultResult { success, identicalNames, alreadyExists, wrongPassword, error }

/// Ergebnisse für Passwort-Änderung
enum ChangePasswordResult { success, identicalPasswords, wrongPassword, error }

/// Ergebnisse für das Hinzufügen von Freunden
enum AddFriendResult { success, notFound, alreadyAdded, selfAdd, error }

/// Verwaltet die Konfiguration des aktuellen Tresors, die Synchronisationsparameter,
/// das Erscheinungsbild sowie die Liste der Freunde.
class SettingsViewModel extends BaseViewModel {
  // ------------------------------------------------------------------------
  // --- Verwendete Dienste ---
  // ------------------------------------------------------------------------

  final DatabaseService _databaseService;
  final SessionService _sessionService;
  final WebService _webService;
  final CryptoService _cryptoService;
  final BiometricService _biometricService;
  final ConfigService _configService;

  // ------------------------------------------------------------------------
  // --- Interne Variablen ---
  // ------------------------------------------------------------------------

  SettingsEntity? _settings;

  //List<SettingsFriendViewModel> _friends = [];
  List<UserEntity> _friends = [];

  /// Signalisiert der UI, ob für diesen Freund Einträge neu verschlüsselt werden müssen.
  /// Dies ist der Fall, wenn sein RSA-Key geändert wurde und die lokalen Permission-Keys geleert wurden.
  final Map<int, bool> _friendNeedsRekeying = {};

  String _vaultName = '';
  String _userName = '';
  String _host = '';
  String _apiToken = '';
  bool _useBiometric = false;
  int _pwLength = 16;
  String _pwSpecialCharSet = '';
  bool _pwAvoidIlO0 = true;
  String _categoryPlaceholder = 'Allgemein';
  ThemeMode _themeMode = ThemeMode.system;
  bool _isTokenHidden = true;
  bool _isRegistered = false;

  // ------------------------------------------------------------------------
  // --- Initialisierung & Menü / Header-Buttons ---
  // ------------------------------------------------------------------------

  /// Konstruktor
  SettingsViewModel(this._databaseService, this._sessionService, this._webService, this._cryptoService, this._biometricService, this._configService) {
    // Theme aus ConfigService laden
    _themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == _configService.theme,
      orElse: () => ThemeMode.system,
    );
  }

  /// Initialisiert die Variablen, bevor der erste Frame gerendert wird.
  ///
  /// Setzt alle Variablen auf die Ausgangswerte zurück.
  void init() {
    clearError(notify: false);
    _settings = null;
    _friends = [];
    _friendNeedsRekeying.clear();
    _vaultName = '';
    _userName = '';
    _host = '';
    _apiToken = '';
    _useBiometric = false;
    _pwLength = 16;
    _pwSpecialCharSet = '';
    _pwAvoidIlO0 = true;
    _categoryPlaceholder = 'Allgemein';
    // _themeMode  // NICHT hart zurücksetzen – kommt aus ConfigService und soll stabil bleiben
    _isTokenHidden = true;
    _isRegistered = false;
  }

  /// Lädt die Daten, nachdem der erste Frame gerendert wurde.
  Future<void> load() async {
    setBusy(true);
    try {
      clearError();
      _settings = await _databaseService.getSettings();
      _vaultName = _sessionService.vaultName;
      _userName = _sessionService.user?.name ?? '';
      if (_settings != null) {
        _host = _settings!.host;
        _apiToken = _settings!.apiToken;
        _useBiometric = _settings!.useBiometric;
        _pwLength = _settings!.pwLength;
        _pwSpecialCharSet = _settings!.pwSpecialChars;
        _pwAvoidIlO0 = _settings!.pwAvoidIlO0;
        _categoryPlaceholder = _settings!.categoryPlaceholder.isEmpty ? 'Allgemein' : _settings!.categoryPlaceholder;
        _isRegistered = _settings!.lastSyncAt.year > 1970;
      }
      await loadFriends();
    } catch (e, st) {
      logError('Fehler beim Initialisieren: $e', st);
      notifyUnexpectedError();
    } finally {
      setBusy(false);
    }
  }

  /// Speichert alle geänderten Einstellungen (mit Ausnahme des Tresornamens)
  /// in der Datenbank und aktualisiert die Session.
  Future<bool> save() async {
    if (_settings == null) throw Exception("Settings nicht initialisiert.");
    setBusy(true);
    try {
      clearError();

      // 1. Falls Biometrie deaktiviert wurde, SecureStore leeren
      if (_settings!.useBiometric && !_useBiometric) {
        await _biometricService.removeMasterKey(_sessionService.vaultName);
        logDebug('Biometrie-Key entfernt, da Option deaktiviert wurde.');
      }

      // 2. Alle Basis-Einstellungen in der DB speichern (Host, API, PW-Gen).
      final normalizedHost = _host.trim().replaceAll(RegExp(r'/+$'), '');
      final updated = _settings!.copyWith(host: normalizedHost, apiToken: _apiToken.trim(), useBiometric: _useBiometric, pwLength: _pwLength, pwSpecialChars: _pwSpecialCharSet, pwAvoidIlO0: _pwAvoidIlO0, categoryPlaceholder: _categoryPlaceholder);
      await _databaseService.saveSettings(updated);

      // 3. Benutzername aktualisieren (falls nicht registriert)
      var user = _sessionService.user!;
      if (!_isRegistered && _userName != _sessionService.user?.name) {
        user = user.copyWith(name: _userName);
        await _databaseService.saveUser(user);
      }

      // 4. Session aktualisieren
      _sessionService.setSession(user: user, privateKey: _sessionService.privateKey!, vaultName: _vaultName, settings: updated);
      return true;
    } catch (e, st) {
      logError('Fehler beim Speichern: $e', st);
      notifyUnexpectedError();
      return false;
    } finally {
      setBusy(false);
    }
  }

  // var save = await _uiService.ConfirmAsync(
  // "Einstellungen speichern",
  // "Möchtest du die Änderungen speichern?",
  // "Ja, speichern",
  // "Nein, verwerfen");

  // ------------------------------------------------------------------------
  // --- Eigenschaften & Methoden für "Identifikation"  ---
  // ------------------------------------------------------------------------

  /// Der Name des Tresors.
  String get vaultName => _vaultName;

  set vaultName(String value) {
    _vaultName = value;
    notifyListeners();
  }

  /// Speicherort der Tresore
  String get vaultStoragePath => _configService.vaultStoragePath;

  // Gibt an, ob der Tresor umbenannt wurde
  bool get isVaultRenamed => _vaultName.trim() != _sessionService.vaultName.trim();

  /// Der Name des angemeldeten Benutzers innerhalb des Tresors.
  String get userName => _userName;

  set userName(String value) {
    _userName = value;
    notifyListeners();
  }

  /// Gibt an, ob der Benutzer bereits mit dem Server synchronisiert wurde (registriert ist).
  bool get isRegistered => _isRegistered;

  /// Testet die Verbindung zum Sync-Server.
  Future<bool> testConnection() async {
    setBusy(true);
    try {
      clearError();

      // WebService mit den aktuell sichtbaren Einstellungen konfigurieren
      initWebService();

      // Verbindung testen, indem die Version abgefragt wird
      final response = await _webService.getServerVersion();
      return response.service.contains("PriVault");
    } on DioException catch (de) {
      // Exception des HTTP-Clients
      if (de.response?.statusCode == 401) {
        notifyError("Die Host-URL ist nicht korrekt oder der API-Token ist ungültig."); // todo genauer auswerten: URL falsch? API-Token falsch?
      } else {
        notifyError("Netzwerkfehler: ${de.message}");
      }
      return false;
    } catch (e) {
      notifyError("Verbindung fehlgeschlagen");
      return false;
    } finally {
      setBusy(false);
    }
  }

  /// Benennt den Tresor um und aktualisiert die Session. Das Master-Passwort wurde zuvor von der UI abgefragt.
  Future<RenameVaultResult> renameVault(String password) async {
    if (_settings == null) throw Exception("Settings nicht initialisiert.");
    if (_settings!.encryptedPrivateKey.isEmpty) throw Exception("Privater Schlüssel fehlt");
    if (_settings!.salt.isEmpty) throw Exception("Salt fehlt");
    if (_sessionService.privateKey == null) throw Exception("Privater Schlüssel nicht entschlüsselt");
    if (_isRegistered) throw Exception("Dieser Tresor wurde bereits synchronisiert und kann daher nicht mehr umbenannt werden.");

    // Bereinigung: Ungültige Zeichen für Dateisysteme entfernen (wie im DatabaseService)
    final currentVaultName = _vaultName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    final oldVaultName = _sessionService.vaultName.trim();

    // Trivial-Check
    if (currentVaultName == oldVaultName) {
      notifyError("Neuer und alter Name sind identisch.");
      return RenameVaultResult.identicalNames;
    }

    if (await _databaseService.databaseExists(currentVaultName)) {
      notifyError("Ein Tresor mit dem Namen '$currentVaultName' existiert bereits auf diesem Gerät.");
      return RenameVaultResult.alreadyExists;
    }

    Uint8List? masterKey;
    setBusy(true);
    try {
      clearError();

      // Kurze Pause für Lade-Indikator, bevor Argon2 blockiert
      await Future.delayed(const Duration(milliseconds: 50));

      // MasterKey ableiten (Argon2id)
      final salt = base64Decode(_sessionService.settings!.salt);
      masterKey = await _cryptoService.deriveKey(password, salt);

      // Passwort validieren
      try {
        await _cryptoService.decrypt(_sessionService.settings!.encryptedPrivateKey, masterKey);
      } catch (_) {
        notifyError("Falsches Master-Passwort");
        return RenameVaultResult.wrongPassword;
      }

      // Physisches Datenbank-Backup erstellen
      await _databaseService.createBackup();
      try {
        // --- Start Kritische Logik  ---

        // 1. Verbindung trennen & Umbenennen
        await _databaseService.close();
        await _databaseService.renameDatabase(oldVaultName, currentVaultName);

        // 2. Session im Speicher aktualisieren
        _sessionService.setSession(user: _sessionService.user!, privateKey: _sessionService.privateKey!, vaultName: currentVaultName, settings: _sessionService.settings!);

        // 3. Konfiguration (Login-Liste / Config) aktualisieren
        if (_configService.lastVaultName == oldVaultName) {
          _configService.lastVaultName = currentVaultName;
        }

        // 4. Neue Verbindung zur umbenannten Datei herstellen
        await _databaseService.initialize(currentVaultName, masterKey);

        // 5. Master-Key im SecureStore umziehen
        if (await _biometricService.containsMasterKey(oldVaultName)) {
          await _biometricService.removeMasterKey(oldVaultName);
          if (_useBiometric) {
            await _biometricService.saveMasterKey(currentVaultName, masterKey);
          }
        }

        // 6. Tresorname merken und Notify-Event auslösen
        _vaultName = currentVaultName;
        _sessionService.setSession(user: _sessionService.user!, privateKey: _sessionService.privateKey!, vaultName: _vaultName, settings: _sessionService.settings!);
        notifyListeners();

        // --- Ende Kritische Logik ---

        // Erfolg: Backup löschen
        await _databaseService.removeBackup();
        return RenameVaultResult.success;
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
      logError('Fehler beim Umbenennung des Tresors: $e', st);
      notifyUnexpectedError();
      return RenameVaultResult.error;
    } finally {
      if (masterKey != null) _cryptoService.wipeKey(masterKey);
      setBusy(false);
    }
  }

  /// Löscht den aktuellen Tresor lokal vom Gerät.
  Future<void> deleteVault() async {
    // Datenbank löschen
    await _databaseService.deleteCurrentDatabase();

    // SecureStore leeren
    await _biometricService.removeMasterKey(_sessionService.vaultName);

    // Den Konfiguration bereinigen
    if (_configService.lastVaultName == _sessionService.vaultName) {
      _configService.lastVaultName = '';
    }

    // Session zurücksetzen
    _sessionService.clearSession();
  }

  /// Generiert ein neuen Salt, verschlüsselt die sqLite-Datei mit dem neuen Master-Schlüssel und aktualisiert die Salt-Datei.
  Future<ChangePasswordResult> changeMasterPassword(String newPassword, String password) async {
    if (_settings == null) throw Exception("Settings nicht initialisiert.");
    if (_settings!.encryptedPrivateKey.isEmpty) throw Exception("Privater Schlüssel fehlt");
    if (_settings!.salt.isEmpty) throw Exception("Salt fehlt");
    if (_sessionService.privateKey == null) throw Exception("Privater Schlüssel nicht entschlüsselt");

    // Trivial-Check
    if (newPassword == password) {
      notifyError("Neues und altes Master-Passwort sind identisch.");
      return ChangePasswordResult.identicalPasswords;
    }

    Uint8List? masterKey;
    Uint8List? newMasterKey;
    setBusy(true);
    try {
      clearError();

      // Kurze Pause für Lade-Indikator, bevor Argon2 blockiert
      await Future.delayed(const Duration(milliseconds: 50));

      // MasterKey ableiten (Argon2id)
      final salt = base64Decode(_sessionService.settings!.salt);
      masterKey = await _cryptoService.deriveKey(password, salt);

      // Passwort validieren
      try {
        await _cryptoService.decrypt(_sessionService.settings!.encryptedPrivateKey, masterKey);
      } catch (_) {
        notifyError("Falsches Master-Passwort");
        return ChangePasswordResult.wrongPassword;
      }

      // Physisches Datenbank-Backup erstellen
      await _databaseService.createBackup();
      try {
        // --- Start Kritische Logik  ---

        // 1. Neues Salt generieren
        final newSalt = _cryptoService.generateSalt();

        // 2. Neuen Master-Key ableiten
        newMasterKey = await _cryptoService.deriveKey(newPassword, newSalt);

        // 3. Private-Key mit dem neuen Key verschlüsseln
        final newEncryptedPrivKey = await _cryptoService.encrypt(_sessionService.privateKey!, newMasterKey);

        // 4. Datenbankdatei mit dem neuen Key umschlüsseln
        await _databaseService.rekey(newMasterKey);

        // 5. Salt-Datei aktualisieren
        await _databaseService.saveSalt(_sessionService.vaultName, newSalt); // todo salt aus DatabaseService entkoppeln (SaltService bauen)

        // 6. Master-Key im SecureStore aktualisieren
        if (_useBiometric) {
          await _biometricService.saveMasterKey(_sessionService.vaultName, newMasterKey);
        }

        // 7. Settings in DB aktualisieren
        final updatedSettings = _settings!.copyWith(salt: base64Encode(newSalt), encryptedPrivateKey: newEncryptedPrivKey);
        await _databaseService.saveSettings(updatedSettings);
        _settings = updatedSettings; // Lokale Kopie im ViewModel aktualisieren

        // 8) Session aktualisieren
        _sessionService.setSession(user: _sessionService.user!, privateKey: _sessionService.privateKey!, vaultName: _vaultName, settings: updatedSettings);

        // Server informieren
        // todo das muss unbedingt erst beim Sync passieren.
        //  => wir fassen PUT /users/{user_uuid}/password und put /users/{user_uuid}/friends zusammen zu PATCH /users/{user_uuid}
        //     und senden das immer, wenn der USER nicht gerade registriert wurde
        if (_isRegistered && _sessionService.user != null && _sessionService.user!.uuid.isNotEmpty) {
          // WebService mit den aktuell sichtbaren Einstellungen konfigurieren
          initWebService();
          // Die Signatur ist für Passwort ändern erforderlich
          _webService.setSignatureData(userUuid: _sessionService.user!.uuid, privateKey: _sessionService.privateKey!);
          // Passwort-Parameter senden
          await _webService.changePassword(_sessionService.user!.uuid, updatedSettings.salt, updatedSettings.encryptedPrivateKey);
        }

        // --- Ende Kritische Logik ---

        // Erfolg: Backup löschen
        await _databaseService.removeBackup();
        return ChangePasswordResult.success;
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
      logError('Fehler beim Ändern des Passworts: $e', st);
      notifyUnexpectedError();
      return ChangePasswordResult.error;
    } finally {
      if (masterKey != null) _cryptoService.wipeKey(masterKey);
      if (newMasterKey != null) _cryptoService.wipeKey(newMasterKey);
      setBusy(false);
    }
  }

  // ------------------------------------------------------------------------
  // --- Eigenschaften & Methoden für "Synchronisation" ---
  // ------------------------------------------------------------------------

  /// Die URL des Servers für die Synchronisation.
  String get host => _host;

  set host(String value) {
    _host = normalizeUrl(value); // Entfernt ein Slash-Zeichen am Ende der URL.
    notifyListeners();
  }

  /// Entfernt ein Slash-Zeichen am Ende der URL.
  String normalizeUrl(String url) {
    return url.trim().replaceAll(RegExp(r'/+$'), '');
  }

  /// Das API-Token für die Authentifizierung gegenüber dem Server.
  String get apiToken => _apiToken;

  set apiToken(String value) {
    _apiToken = value;
    notifyListeners();
  }

  /// Gibt an, ob der APU-Token ausgeblendet ist
  bool get isTokenHidden => _isTokenHidden;

  /// Schaltet die Sichtbarkeit des API-Tokens um.
  void toggleTokenVisibility() {
    _isTokenHidden = !_isTokenHidden;
    notifyListeners();
  }

  // ------------------------------------------------------------------------
  // --- Eigenschaften & Methoden für "Anmeldeoptionen" ---
  // ------------------------------------------------------------------------

  /// Gibt an, ob Fingerabdruck bzw. Gesichtserkennung als Anmeldeoption zur Verfügung steht.
  bool get useBiometric => _useBiometric;

  set useBiometric(bool value) {
    _useBiometric = value;
    notifyListeners();
  }

  // ------------------------------------------------------------------------
  // --- Eigenschaften & Methoden für "Freunde" ---
  // ------------------------------------------------------------------------

  /// Die Liste der Freunde, aufbereitet für die UI-Liste.
  List<UserEntity> get friends => _friends;

  /// Lädt alle Freunde aus der Datenbank und bereitet sie für die Liste vor.
  Future<void> loadFriends() async {
    final allUsers = await _databaseService.getUsers();
    _friends = allUsers.where((u) => (u.id ?? 0) > 1 && !u.isHidden).toList();

    // 1. Alle IDs auf einmal abrufen, die ein Rekeying benötigen
    final idsWithMissingKeys = await _databaseService.getUserIdsWithEmptyEntryKeys();

    _friendNeedsRekeying.clear();
    for (var f in _friends) {
      if (f.id != null) {
        _friendNeedsRekeying[f.id!] = idsWithMissingKeys.contains(f.id);
        // _friendNeedsRekeying[f.id!] = await _databaseService.hasPermissionsWithoutKeyByUserId(f.id!);
      }
    }
    notifyListeners();
  }

  /// Berechnet den SHA-256 Fingerprint basierend auf dem PublicKey.
  /// Nutzt ein unsichtbares Leerzeichen (\u200B) nach den Doppelpunkten für bessere Zeilenumbrüche in der UI.
  String getFingerprint(String publicKey) {
    return _cryptoService.fingerprint(publicKey).replaceAll(":", ":\u200B");
  }

  /// Signalisiert, ob für diesen Freund Einträge neu verschlüsselt werden müssen.
  /// Dies ist der Fall, wenn sein RSA-Key geändert und die lokalen Permission-Keys geleert wurden.
  bool needsRekeying(int userId) => _friendNeedsRekeying[userId] ?? false;

  /// Fügt den einen Freund über den angegebenen Namen hinzu.
  Future<AddFriendResult> addFriend(String name) async {
    if (name.isEmpty) return AddFriendResult.error;
    final trimmedName = name.trim();

    // Du kannst dich nicht selbst als Freund hinzufügen
    if (trimmedName.toLowerCase() == _sessionService.user?.name.trim().toLowerCase()) {
      notifyError("Das bist du selbst.");
      return AddFriendResult.selfAdd;
    }

    // Prüfen ob bereits in der Liste
    if (_friends.any((f) => f.name.toLowerCase() == trimmedName.toLowerCase())) {
      notifyError("Person bereits hinzugefügt.");
      return AddFriendResult.alreadyAdded;
    }

    // WebService mit den aktuell sichtbaren Einstellungen konfigurieren
    initWebService();

    setBusy(true);
    try {
      clearError();

      final userResponse = await _webService.findUser(_sessionService.vaultName, trimmedName);
      if (userResponse == null) {
        notifyError("Person nicht gefunden.");
        return AddFriendResult.notFound;
      }

      // Benutzer neu anlegen bzw. wieder einblenden, falls ausgeblendet ist
      final newUser = UserEntity(uuid: userResponse.userUuid, name: trimmedName, publicKey: userResponse.publicKey, isVerified: false, isHidden: false, updatedAt: DateTime.now().toUtc());
      await _databaseService.saveUser(newUser);

      // UI-Liste neu laden
      await loadFriends();
      return AddFriendResult.success;
    } on DioException catch (de) {
      // Exception des HTTP-Clients
      if (de.response?.statusCode == 401) {
        notifyError("Die Host-URL ist nicht korrekt oder der API-Token ist ungültig."); // todo genauer auswerten: URL falsch? API-Token falsch?
      } else {
        notifyError("Netzwerkfehler: ${de.message}");
      }
      return AddFriendResult.error;
    } catch (e, st) {
      logError("Suche fehlgeschlagen: $e", st);
      notifyUnexpectedError();
      return AddFriendResult.error;
    } finally {
      setBusy(false);
    }
  }

  /// Speichert den aktualisierten Verifizierungsstatus des Freundes.
  void toggleVerification(UserEntity friend) async {
    final isVerified = !friend.isVerified;
    setBusy(true);
    try {
      clearError();

      // Wenn verifiziert wird, fehlende Entry-Keys generieren.
      if (isVerified) {
        await _rekeyEntriesForFriend(friend);
      }

      // Änderung speichern
      final updatedUser = friend.copyWith(isVerified: isVerified, updatedAt: DateTime.now().toUtc());
      await _databaseService.saveUser(updatedUser);

      // UI-Liste aktualisieren
      await loadFriends();
    } catch (e, st) {
      logError("Fehler beim Speichern der Verifizierung: $e", st);
      notifyUnexpectedError();
      notifyListeners();
    } finally {
      setBusy(false);
    }
  }

  /// Entfernt einen Freund aus der Liste.
  ///
  /// Der Datensatz wird gelöscht, wenn keine Verknüpfungen bestehen, ansonsten wird er ausgeblendet.
  Future<void> deleteFriend(UserEntity? friend) async {
    if (friend == null) return;
    try {
      // Prüfen, ob der User überhaupt Berechtigungen hat
      var perms = await _databaseService.getPermissionsByUserId(friend.id!);
      if (perms.isEmpty) {
        // Es werden keine Einträge mit dem Freund geteilt, daher kann er gelöscht werden.
        await _databaseService.deleteUser(friend.id!);
      } else {
        // Der Freund wird nicht gelöscht, sondern ausgeblendet, damit beim Synchronisieren alle geteilten Einträge entfernt werden können.
        await _databaseService.hideUser(friend.id!);
      }

      // Aus der UI-Liste entfernen
      await loadFriends();
    } catch (e, st) {
      logError("Löschen fehlgeschlagen: $e", st);
      notifyUnexpectedError();
    }
  }

  // ------------------------------------------------------------------------
  // --- Eigenschaften & Methoden für "Passwort-Generator" ---
  // ------------------------------------------------------------------------

  /// Eingestellte Länge für den Passwortgenerator.
  int get pwLength => _pwLength;

  set pwLength(int value) {
    _pwLength = value;
    notifyListeners();
  }

  /// Der aktuell gewählte Satz an Sonderzeichen für generierte Passwörter.
  String get pwSpecialCharSet => _pwSpecialCharSet;

  set pwSpecialCharSet(String value) {
    _pwSpecialCharSet = value;
    notifyListeners();
  }

  /// Gibt an, ob optisch ähnliche Zeichen ('I', 'l', 'O', '0') vermieden werden sollen.
  bool get pwAvoidIlO0 => _pwAvoidIlO0;

  set pwAvoidIlO0(bool value) {
    _pwAvoidIlO0 = value;
    notifyListeners();
  }

  /// Setzt den Zeichensatz für den Passwortgenerator basierend auf vordefinierten Gruppen.
  void setSpecialChars(String type) {
    switch (type) {
      case 'None':
        _pwSpecialCharSet = '';
        break;
      case 'Standard':
        _pwSpecialCharSet = '!@#\$%^&*()_+-=[]{}|;:,.<>?';
        break;
      case 'All':
        _pwSpecialCharSet = '!"#\$%&\'()*+,-./:;<=>?@[\\]^_`{|}~';
        break;
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------------
  // --- Eigenschaften & Methoden für "Design" ---
  // ------------------------------------------------------------------------

  /// Anzeigename für eine leere Kategorie.
  String get categoryPlaceholder => _categoryPlaceholder;

  set categoryPlaceholder(String value) {
    _categoryPlaceholder = value;
    notifyListeners();
  }

  /// Der gewählte Theme-Modus ('System', 'Light' oder 'Dark').
  ThemeMode get themeMode => _themeMode;

  // Das Theme wird sofort übernommen (ohne auf "Speichern" zu klicken, so wie in modernen Apps üblich)
  set themeMode(ThemeMode value) {
    if (_themeMode == value) return;
    _themeMode = value;

    // Wert als String im ConfigService speichern
    _configService.theme = value.name;

    notifyListeners();
  }

  // ------------------------------------------------------------------------
  // --- Eigenschaften & Methoden für "Systemeinstellungen" ---
  // ------------------------------------------------------------------------

  /// Öffnet die Systemeinstellungen für Biometrie.
  // todo Plattformspezifische Aufrufe haben hier nichts zu suchen
  Future<void> openBiometricSettings() async {
    if (Platform.isWindows) {
      await launchUrl(Uri.parse('ms-settings:signinoptions'));
    } else if (Platform.isAndroid) {
      await launchUrl(Uri.parse('intent:#Intent;action=android.settings.SECURITY_SETTINGS;end'));
    } else if (Platform.isIOS || Platform.isMacOS) {
      await launchUrl(Uri.parse('App-Prefs:root=FACEID_PASSCODE'));
    }
  }

  /// Öffnet die Systemeinstellungen (oder eine Hilfeseite) für den Auto-Fill-Dienst.
  Future<void> openAutofillSettings() async {
    if (Platform.isWindows) {
      await launchUrl(Uri.parse('https://support.microsoft.com/de-de/windows/ausf%C3%BCllen-von-formularen-mit-microsoft-autofill-64eb7382-777e-400a-8671-8884976c666e'), mode: LaunchMode.externalApplication);
    } else if (Platform.isAndroid) {
      await launchUrl(Uri.parse('intent:#Intent;action=android.settings.REQUEST_SET_AUTOFILL_SERVICE;end'));
    } else if (Platform.isIOS || Platform.isMacOS) {
      await launchUrl(Uri.parse('App-Prefs:root=PASSWORDS'));
    }
  }

  /// Öffnet die App-Info-Seite in den Systemeinstellungen.
  Future<void> openAppSettings() async {
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
  // --- Interne Methoden / Helper ---
  // ------------------------------------------------------------------------

  /// Konfiguriert den WebService mit den aktuell sichtbaren Einstellungen.
  ///
  /// Wirft ein Exception, wenn die Host-URL oder API-Token nicht angegeben sind.
  void initWebService() {
    if (_host.isEmpty) {
      throw Exception("Für die Synchronisation muss eine gültige Host-URL hinterlegt sein. Bitte trage sie in den Einstellungen ein.");
    }

    if (_apiToken.isEmpty) {
      throw Exception("Für die Synchronisation muss ein gültiger API-Token hinterlegt sein. Bitte trage ihn in den Einstellungen ein.");
    }

    _webService.updateConfig(host: _host, apiToken: _apiToken);
  }

  /// Verschlüsselt alle Entry-Keys, die aufgrund eines Identitätswechsels geleert wurden.
  ///
  /// Diese Methode wird aufgerufen, wenn ein Freund verifiziert wird.
  Future<void> _rekeyEntriesForFriend(UserEntity friend) async {
    if (_sessionService.privateKey == null) throw Exception("PrivateKey nicht initialisiert.");

    setBusy(true);
    try {
      clearError();
      // 1. Die geleerten Berechtigungen des Freundes laden
      var dirtyPermissions = await _databaseService.getPermissionsWithoutKeyByUserId(friend.id!);
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
      if (_friendNeedsRekeying[friend.id!] ?? false) {
        _friendNeedsRekeying[friend.id!] = false;
        notifyListeners();
      }
    } catch (e, st) {
      logError("Rekeying fehlgeschlagen: $e", st);
      notifyUnexpectedError();
    } finally {
      setBusy(false);
    }
  }
}
