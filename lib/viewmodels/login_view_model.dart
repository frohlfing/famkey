import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:privault/core/base_view_model.dart';
import 'package:privault/models/entities/user_entity.dart';
import 'package:privault/models/entities/settings_entity.dart';
import 'package:privault/services/biometric_service.dart';
import 'package:privault/services/config_service.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

enum LoginResult {
  success,
  wrongPassword,
  vaultNotFound,
  corrupt,
  askToEnableBiometrics,
  error
}

class LoginViewModel extends BaseViewModel {
  final BiometricService _biometricService;
  final ConfigService _configService;
  final CryptoService _cryptoService;
  final DatabaseService _databaseService;
  final SessionService _sessionService;

  String _vaultName = '';
  String _password = '';
  bool _isExists = false;
  bool _hasBiometricKey = false;
  List<String> _existingVaults = [];

  LoginViewModel(
    this._biometricService,
    this._configService,
    this._cryptoService,
    this._databaseService,
    this._sessionService,
  ) {
    _vaultName = _configService.lastVaultName;
    refreshVaultList();
  }

  String get vaultName => _vaultName;
  String get password => _password;
  bool get isExists => _isExists;
  bool get hasBiometricKey => _hasBiometricKey;
  List<String> get existingVaults => _existingVaults;

  set vaultName(String value) {
    if (_vaultName == value) return;
    _vaultName = value.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    if (errorMessage != null) clearError();
    _updateState();
    notifyListeners();
  }

  set password(String value) {
    if (_password == value) return;
    _password = value;
    if (errorMessage != null) clearError();
    notifyListeners();
  }

  void resetState() {
    _password = '';
    clearError();
    refreshVaultList();
  }

  /// Löscht das Passwort aus dem RAM. 
  /// [notify] kann auf false gesetzt werden, um "locked widget tree" Fehler zu vermeiden (z.B. in dispose).
  void clearPassword({bool notify = true}) {
    _password = '';
    if (notify) notifyListeners();
  }

  Future<void> refreshVaultList() async {
    final path = _configService.vaultStoragePath;
    if (path.isEmpty) {
      _existingVaults = [];
    } else {
      final dir = Directory(path);
      if (await dir.exists()) {
        final List<String> vaults = [];
        await for (final file in dir.list()) {
          if (file.path.endsWith('.db3.salt')) {
            final baseName = p.basename(file.path).replaceAll('.db3.salt', '');
            final dbFile = File(p.join(path, '$baseName.db3'));
            if (await dbFile.exists()) vaults.add(baseName);
          }
        }
        _existingVaults = vaults;
      }
    }
    await _updateState();
  }

  Future<void> _updateState() async {
    _isExists = _existingVaults.contains(_vaultName);
    _hasBiometricKey = await _biometricService.containsMasterKey(_vaultName);
    notifyListeners();
  }

  Future<LoginResult> login({bool forceCreate = false}) async {
    if (_vaultName.isEmpty) return LoginResult.error;
    if (!_isExists && !forceCreate) return LoginResult.vaultNotFound;

    setBusy(true);
    clearError();
    try {
      if (_isExists) {
        return await _openVault();
      } else {
        if (_password.isEmpty) {
          setError("Bitte ein Master-Passwort festlegen.");
          setBusy(false);
          return LoginResult.error;
        }
        return await _createVault();
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains("database is locked") || msg.contains("file is not a database") || msg.contains("authentication failed")) {
        setError("Falsches Master-Passwort.");
        return LoginResult.wrongPassword;
      }
      setError("Fehler: $e");
      return LoginResult.error;
    } finally {
      setBusy(false);
    }
  }

  Future<LoginResult> _createVault() async {
    final salt = _cryptoService.generateSalt();
    final masterKey = await _cryptoService.deriveKey(_password, salt);
    final hexMasterKey = _bytesToHex(masterKey);

    try {
      await _databaseService.deleteCurrentDatabase(); 
      final storagePath = _configService.vaultStoragePath;
      final saltFile = File(p.join(storagePath, '$_vaultName.db3.salt'));
      await saltFile.writeAsBytes(salt);

      await _databaseService.initialize(_vaultName, hexMasterKey);
      
      final (pubKey, privKeyBytes) = await _cryptoService.generateRsaKeyPair();
      final encryptedPrivKey = await _cryptoService.encrypt(privKeyBytes, masterKey);

      final newUser = UserEntity(
        uuid: const Uuid().v4(),
        name: Platform.environment['USERNAME'] ?? 'User',
        publicKey: pubKey,
        isVerified: true,
        updatedAt: DateTime.now().toUtc(),
      );

      final newSettings = SettingsEntity(
        salt: base64.encode(salt),
        encryptedPrivateKey: encryptedPrivKey,
        useBiometric: false, 
        lastSyncAt: DateTime.fromMillisecondsSinceEpoch(0).toUtc(),
      );

      await _databaseService.saveUser(newUser);
      await _databaseService.saveSettings(newSettings);
      
      _configService.lastVaultName = _vaultName;
      await refreshVaultList();

      _sessionService.setSession(user: newUser, privateKey: privKeyBytes, vaultName: _vaultName, settings: newSettings.toMap());
      
      clearPassword(notify: true);
      return LoginResult.success;
    } finally {
      _cryptoService.wipeKey(masterKey);
    }
  }

  Future<LoginResult> _openVault() async {
    final storagePath = _configService.vaultStoragePath;
    final saltFile = File(p.join(storagePath, '$_vaultName.db3.salt'));
    if (!await saltFile.exists()) return LoginResult.vaultNotFound;

    final salt = await saltFile.readAsBytes();
    Uint8List? masterKey;
    bool isManualLogin = _password.isNotEmpty;
    
    if (!isManualLogin && _hasBiometricKey) {
      masterKey = await _biometricService.getMasterKey(_vaultName);
      if (masterKey == null) {
        setError("Biometrische Authentifizierung abgebrochen.");
        return LoginResult.error;
      }
    } else {
      if (_password.isEmpty) {
        setError("Bitte das Master-Passwort eingeben.");
        return LoginResult.error;
      }
      masterKey = await _cryptoService.deriveKey(_password, salt);
    }

    final hexMasterKey = _bytesToHex(masterKey);

    try {
      await _databaseService.initialize(_vaultName, hexMasterKey);
      
      final settings = await _databaseService.getSettings();
      if (settings == null) return LoginResult.corrupt;

      final user = await _databaseService.getUserById(1);
      if (user == null) return LoginResult.corrupt;

      try {
        final privKeyBytes = await _cryptoService.decrypt(settings.encryptedPrivateKey, masterKey);
        _sessionService.setSession(user: user, privateKey: privKeyBytes, vaultName: _vaultName, settings: settings.toMap());

        if (isManualLogin && settings.useBiometric && !_hasBiometricKey) {
          return LoginResult.askToEnableBiometrics;
        }
      } catch (e) {
        if (!isManualLogin && _hasBiometricKey) {
           await _biometricService.removeMasterKey(_vaultName);
           _hasBiometricKey = false;
           setError("Veralteter Biometrie-Schlüssel gelöscht.");
           return LoginResult.wrongPassword;
        }
        setError("Falsches Master-Passwort.");
        return LoginResult.wrongPassword;
      }

      _configService.lastVaultName = _vaultName;
      clearPassword(notify: true);
      return LoginResult.success;
    } catch (e) {
      await _databaseService.close();
      setError("Falsches Master-Passwort.");
      return LoginResult.wrongPassword;
    } finally {
      _cryptoService.wipeKey(masterKey);
    }
  }

  Future<void> saveMasterKey(String password) async {
    final storagePath = _configService.vaultStoragePath;
    final saltFile = File(p.join(storagePath, '$_vaultName.db3.salt'));
    if (!await saltFile.exists()) return;
    final salt = await saltFile.readAsBytes();
    final masterKey = await _cryptoService.deriveKey(password, salt);
    try {
      await _biometricService.saveMasterKey(_vaultName, masterKey);
      await _updateState();
    } finally {
      _cryptoService.wipeKey(masterKey);
    }
  }

  Future<void> cleanUp() async {
    await _databaseService.deleteCurrentDatabase();
    _sessionService.clearSession();
    _vaultName = '';
    _password = '';
    _configService.lastVaultName = '';
    await refreshVaultList();
  }

  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
