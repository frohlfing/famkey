import 'dart:io';
import 'dart:typed_data';
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
import 'package:privault/viewmodels/settings_friend_view_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';

/// Die zentrale Logikschicht für die Einstellungsseite der Anwendung.
///
/// Es verwaltet die Konfiguration des aktuellen Tresors, die Synchronisationsparameter,
/// das Erscheinungsbild sowie die Liste der Freunde.
class SettingsViewModel extends BaseViewModel {
  // ------------------------------------------------------------------------
  // --- Felder ---
  // ------------------------------------------------------------------------

  final DatabaseService _databaseService;
  final SessionService _sessionService;
  final WebService _webService;
  final CryptoService _cryptoService;
  final BiometricService _biometricService;
  final ConfigService _configService;

  SettingsEntity? _settings;
  List<SettingsFriendViewModel> _friends = [];

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
  // --- Konstruktor ---
  // ------------------------------------------------------------------------

  SettingsViewModel(
    this._databaseService,
    this._sessionService,
    this._webService,
    this._cryptoService,
    this._biometricService,
    this._configService,
  );

  // ------------------------------------------------------------------------
  // --- Eigenschaften ---
  // ------------------------------------------------------------------------

  String get vaultName => _vaultName;

  String get userName => _userName;

  String get host => _host;

  String get apiToken => _apiToken;

  bool get useBiometric => _useBiometric;

  int get pwLength => _pwLength;

  String get pwSpecialCharSet => _pwSpecialCharSet;

  bool get pwAvoidIlO0 => _pwAvoidIlO0;

  String get categoryPlaceholder => _categoryPlaceholder;

  ThemeMode get themeMode => _themeMode;

  bool get isTokenHidden => _isTokenHidden;

  bool get isRegistered => _isRegistered;

  String get vaultStoragePath => _configService.vaultStoragePath;

  List<SettingsFriendViewModel> get friends => _friends;

  bool get requiresGuardForSave => !_isRegistered && _vaultName.trim() != _sessionService.vaultName.trim();

  // Getter für die Services (damit der UI-Layer sie an Dialoge weiterreichen kann)
  CryptoService get cryptoService => _cryptoService;
  SessionService get sessionService => _sessionService;
  DatabaseService get databaseService => _databaseService;

  // --- Setters ---

  set vaultName(String value) {
    _vaultName = value;
    notifyListeners();
  }

  set userName(String value) {
    _userName = value;
    notifyListeners();
  }

  set host(String value) {
    _host = value;
    notifyListeners();
  }

  set apiToken(String value) {
    _apiToken = value;
    notifyListeners();
  }

  set useBiometric(bool value) {
    _useBiometric = value;
    notifyListeners();
  }

  set pwLength(int value) {
    _pwLength = value;
    notifyListeners();
  }

  set pwSpecialCharSet(String value) {
    _pwSpecialCharSet = value;
    notifyListeners();
  }

  set pwAvoidIlO0(bool value) {
    _pwAvoidIlO0 = value;
    notifyListeners();
  }

  set categoryPlaceholder(String value) {
    _categoryPlaceholder = value;
    notifyListeners();
  }

  set themeMode(ThemeMode value) {
    _themeMode = value;
    notifyListeners();
  }

  // ------------------------------------------------------------------------
  // --- Befehle ---
  // ------------------------------------------------------------------------

  /// Schaltet die Sichtbarkeit des API-Tokens um.
  void toggleTokenVisibility() {
    _isTokenHidden = !_isTokenHidden;
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

  /// Lädt die Einstellungen aus der Datenbank und initialisiert die View-Properties.
  Future<void> loadSettings() async {
    setBusy(true);
    try {
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
    } catch (e) {
      setError("Fehler beim Laden: $e");
    } finally {
      setBusy(false);
    }
  }

  /// Lädt alle Freunde aus der Datenbank und bereitet die ViewModels für die Liste vor.
  Future<void> loadFriends() async {
    final allUsers = await _databaseService.getUsers();
    final myUuid = _sessionService.user?.uuid;

    _friends = allUsers
        .where((u) => u.uuid != myUuid && !u.isHidden)
        .map((u) => SettingsFriendViewModel(_cryptoService, _databaseService, u))
        .toList();

    for (var f in _friends) {
      await f.refreshStatus();
    }
    notifyListeners();
  }

  /// Speichert alle geänderten Einstellungen in der Datenbank und aktualisiert die Session.
  Future<bool> save() async {
    return saveAsync();
  }

  /// Entspricht der MAUI-`SaveAsync`-Logik inkl. Guard-abhängiger Tresor-Umbenennung.
  Future<bool> saveAsync({Uint8List? masterKey}) async {
    if (_settings == null) return false;
    setBusy(true);
    try {
      final oldVaultName = _sessionService.vaultName.trim();
      final currentVaultName = _vaultName.trim();

      // Wenn Biometrie deaktiviert wurde -> Key aus Secure Store löschen
      if (_settings!.useBiometric && !_useBiometric) {
        await _biometricService.removeMasterKey(_sessionService.vaultName);
        debugPrint('🔐 Biometrie-Key entfernt, da Option deaktiviert wurde.');
      }

      // Host-URL normalisieren (Trailing-Slash entfernen)
      final normalizedHost = _host.trim().replaceAll(RegExp(r'/+$'), '');

      final updated = _settings!.copyWith(
        host: normalizedHost,
        apiToken: _apiToken.trim(),
        useBiometric: _useBiometric,
        pwLength: _pwLength,
        pwSpecialChars: _pwSpecialCharSet,
        pwAvoidIlO0: _pwAvoidIlO0,
        categoryPlaceholder: _categoryPlaceholder,
      );
      await _databaseService.saveSettings(updated);

      // Benutzername nur änderbar, wenn noch nicht registriert/gesynct
      if (!_isRegistered && _userName != _sessionService.user?.name) {
        final updatedUser = _sessionService.user!.copyWith(name: _userName);
        await _databaseService.saveUser(updatedUser);
      }

      // MAUI-Logik: Tresorname vor Erstregistrierung geändert -> Guard erforderlich
      if (!_isRegistered && currentVaultName != oldVaultName) {
        if (masterKey == null) {
          throw Exception('Bestätigung per Master-Passwort erforderlich.');
        }

        if (_databaseService.databaseExists(currentVaultName)) {
          throw Exception("Ein Tresor mit dem Namen '$currentVaultName' existiert bereits.");
        }

        _databaseService.renameDatabase(oldVaultName, currentVaultName);

        if (_configService.lastVaultName == oldVaultName) {
          _configService.lastVaultName = currentVaultName;
        }

        await _biometricService.removeMasterKey(oldVaultName);
      }

      // Session aktualisieren, damit Änderungen sofort aktiv sind
      _sessionService.setSession(
        user: _sessionService.user!,
        privateKey: _sessionService.privateKey!,
        vaultName: currentVaultName,
        settings: updated.toMap(),
      );
      return true;
    } catch (e) {
      setError("Speichern fehlgeschlagen: $e");
      return false;
    } finally {
      setBusy(false);
    }
  }

  /// Entspricht der MAUI-`ChangeMasterPasswordAsync`-Operation.
  /// Wird innerhalb des GuardDialogs aufgerufen (nachdem das alte Passwort validiert wurde).
  Future<bool> changeMasterPasswordAsync(String newPassword) async {
    setBusy(true);
    clearError();
    Uint8List? newMasterKey;
    try {
      // 1. Neues Salt generieren
      final newSalt = _cryptoService.generateSalt();

      // 2. Neuen Master-Key ableiten
      newMasterKey = await _cryptoService.deriveKey(newPassword, newSalt);
      String newEncryptedPrivKey;

      if (_sessionService.privateKey == null) {
        throw Exception("Privater Schlüssel fehlt in der Session.");
      }

      // 3. Private Key mit dem neuen Key verschlüsseln
      newEncryptedPrivKey = await _cryptoService.encrypt(_sessionService.privateKey!, newMasterKey);

      // 4. Datenbankdatei mit dem neuen Key umschlüsseln
      await _databaseService.rekey(newMasterKey);

      // 5. Master-Key im SecureStore aktualisieren
      if (_useBiometric) {
        await _biometricService.saveMasterKey(_sessionService.vaultName, newMasterKey);
      }

      // 6. Settings in DB aktualisieren
      if (_settings != null) {
        final updatedSettings = _settings!.copyWith(
          salt: base64Encode(newSalt),
          encryptedPrivateKey: newEncryptedPrivKey,
        );
        await _databaseService.saveSettings(updatedSettings);

        // 7. Server informieren
        if (_isRegistered && _sessionService.user != null && _sessionService.user!.uuid.isNotEmpty) {
          await _webService.changePassword(
            _sessionService.user!.uuid,
            updatedSettings.salt,
            updatedSettings.encryptedPrivateKey,
          );
        }
      }

      // 8. Lokale Konfiguration (Salt-Datei im OS) aktualisieren
      await _databaseService.saveSalt(_sessionService.vaultName, newSalt);

      return true;
    } catch (e) {
      setError("Passwort ändern fehlgeschlagen: $e");
      return false;
    } finally {
      if (newMasterKey != null) {
        _cryptoService.wipeKey(newMasterKey);
      }
      setBusy(false);
    }
  }

  /// Löscht den aktuellen Tresor lokal vom Gerät.
  Future<void> deleteVault() async {
    final nameToDelete = _sessionService.vaultName;
    await _databaseService.deleteCurrentDatabase();
    await _biometricService.removeMasterKey(nameToDelete);
    if (_configService.lastVaultName == nameToDelete) {
      _configService.lastVaultName = '';
    }
    _sessionService.clearSession();
  }

  /// Testet die Verbindung zum Sync-Server.
  Future<bool> testConnection() async {
    setBusy(true);
    clearError();
    try {
      final response = await _webService.getServerVersion(host: _host, apiToken: _apiToken);
      setBusy(false);
      return response.service.isNotEmpty;
    } catch (e) {
      setError("Verbindung fehlgeschlagen: $e");
      setBusy(false);
      return false;
    }
  }

  /// Sucht und fügt einen neuen Freund über dessen Namen hinzu.
  void addFriend(String name) async {
    if (name.isEmpty) return;
    setBusy(true);
    try {
      final response = await _webService.findUser(_sessionService.vaultName, name);
      if (response == null) {
        setError("Benutzer '$name' nicht gefunden.");
        return;
      }
      final newUser = UserEntity(
        uuid: response.userUuid,
        name: name,
        publicKey: response.publicKey,
        isVerified: false,
        updatedAt: DateTime.now().toUtc(),
      );
      await _databaseService.saveUser(newUser);
      await loadFriends();
    } catch (e) {
      setError("Suche fehlgeschlagen: $e");
    } finally {
      setBusy(false);
    }
  }

  /// Speichert den aktualisierten Verifizierungsstatus eines Kontakts.
  void toggleVerification(SettingsFriendViewModel friendVm) async {
    final updated = friendVm.user.copyWith(isVerified: !friendVm.isVerified);
    await _databaseService.saveUser(updated);
    await loadFriends();
  }

  /// Öffnet die Systemeinstellungen für Biometrie.
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
      await launchUrl(
        Uri.parse(
          'https://support.microsoft.com/de-de/windows/ausf%C3%BCllen-von-formularen-mit-microsoft-autofill-64eb7382-777e-400a-8671-8884976c666e',
        ),
        mode: LaunchMode.externalApplication,
      );
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
}
