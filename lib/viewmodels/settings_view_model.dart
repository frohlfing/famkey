import 'dart:convert';
import 'dart:io';
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
import 'package:privault/viewmodels/settings_friend_view_model.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsViewModel extends BaseViewModel {
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

  SettingsViewModel(
    this._databaseService, 
    this._sessionService, 
    this._webService, 
    this._cryptoService,
    this._biometricService,
    this._configService,
  );

  // Getters
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

  // Setters
  set vaultName(String value) { _vaultName = value; notifyListeners(); }
  set userName(String value) { _userName = value; notifyListeners(); }
  set host(String value) { _host = value; notifyListeners(); }
  set apiToken(String value) { _apiToken = value; notifyListeners(); }
  set useBiometric(bool value) { _useBiometric = value; notifyListeners(); }
  set pwLength(int value) { _pwLength = value; notifyListeners(); }
  set pwSpecialCharSet(String value) { _pwSpecialCharSet = value; notifyListeners(); }
  set pwAvoidIlO0(bool value) { _pwAvoidIlO0 = value; notifyListeners(); }
  set categoryPlaceholder(String value) { _categoryPlaceholder = value; notifyListeners(); }
  set themeMode(ThemeMode value) { _themeMode = value; notifyListeners(); }

  void toggleTokenVisibility() {
    _isTokenHidden = !_isTokenHidden;
    notifyListeners();
  }

  // 1) Sonderzeichen-Presets repariert
  void setSpecialChars(String type) {
    switch (type) {
      case 'None': _pwSpecialCharSet = ''; break;
      case 'Standard': _pwSpecialCharSet = '!@#\$%^&*()_+-=[]{}|;:,.<>?'; break;
      case 'All': _pwSpecialCharSet = '!\"#\$%&\'()*+,-./:;<=>?@[\\]^_`{|}~'; break;
    }
    notifyListeners();
  }

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

  Future<bool> save() async {
    if (_settings == null) return false;
    setBusy(true);
    try {
      // 2) Wenn Biometrie deaktiviert wird -> Key aus Secure Store löschen
      if (_settings!.useBiometric && !_useBiometric) {
        await _biometricService.removeMasterKey(_sessionService.vaultName);
        debugPrint('🔐 Biometrie-Key entfernt, da Option deaktiviert wurde.');
      }

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
      
      if (!_isRegistered && _userName != _sessionService.user?.name) {
        final updatedUser = _sessionService.user!.copyWith(name: _userName);
        await _databaseService.saveUser(updatedUser);
      }

      _sessionService.setSession(
        user: _sessionService.user!,
        privateKey: _sessionService.privateKey!,
        vaultName: _vaultName,
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

  // 5) Komplette Lösch-Sequenz
  Future<void> deleteVault() async {
    final nameToDelete = _sessionService.vaultName;
    await _databaseService.deleteCurrentDatabase();
    await _biometricService.removeMasterKey(nameToDelete);
    if (_configService.lastVaultName == nameToDelete) {
      _configService.lastVaultName = '';
    }
    _sessionService.clearSession();
  }

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

  void toggleVerification(SettingsFriendViewModel friendVm) async {
    final updated = friendVm.user.copyWith(isVerified: !friendVm.isVerified);
    await _databaseService.saveUser(updated);
    await loadFriends();
  }

  // 3) Korrigierte Systemeinstellungen für Windows & Android
  Future<void> openBiometricSettings() async {
    if (Platform.isWindows) {
      await launchUrl(Uri.parse('ms-settings:signinoptions'));
    } else if (Platform.isAndroid) {
      await launchUrl(Uri.parse('package:com.android.settings'));
    }
  }

  Future<void> openAutofillSettings() async {
    if (Platform.isWindows) {
      await launchUrl(Uri.parse('https://support.microsoft.com/de-de/windows/ausf%C3%BCllen-von-formularen-mit-microsoft-autofill-64eb7382-777e-400a-8671-8884976c666e'));
    } else if (Platform.isAndroid) {
      await launchUrl(Uri.parse('package:com.android.settings'));
    }
  }

  Future<void> openAppSettings() async {
    if (Platform.isWindows) {
      await launchUrl(Uri.parse('ms-settings:appsfeatures-app'));
    } else if (Platform.isAndroid) {
      await launchUrl(Uri.parse('app-settings:'));
    }
  }
}
