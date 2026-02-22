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

  LoginViewModel(
    this._biometricService,
    this._configService,
    this._cryptoService,
    this._databaseService,
    this._sessionService,
  ) {
    _vaultName = _configService.lastVaultName;
    if (_vaultName.isEmpty) {
      _vaultName = Platform.environment['USERNAME'] ?? 'MyVault';
    }
    _updateState();
  }

  String get vaultName => _vaultName;
  String get password => _password;
  bool get isExists => _isExists;
  bool get hasBiometricKey => _hasBiometricKey;
  List<String> get existingVaults => _configService.vaults.keys.toList();

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

  Future<void> _updateState() async {
    _isExists = _configService.vaults.containsKey(_vaultName);
    _hasBiometricKey = await _biometricService.containsMasterKey(_vaultName);
    notifyListeners();
  }

  Future<LoginResult> login({bool forceCreate = false}) async {
    if (_vaultName.isEmpty) {
      setError("Bitte einen Namen für den Tresor eingeben.");
      return LoginResult.error;
    }

    if (!_isExists && !forceCreate) {
      return LoginResult.vaultNotFound;
    }

    setBusy(true);
    clearError();
    try {
      if (_isExists) {
        return await _openVault();
      } else {
        if (_password.isEmpty) {
          setError("Bitte ein Master-Passwort für den neuen Tresor festlegen.");
          setBusy(false);
          return LoginResult.error;
        }
        return await _createVault();
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains("database is locked") || 
          msg.contains("file is not a database") || 
          msg.contains("authentication failed")) {
        
        if (_password.isEmpty && _hasBiometricKey) {
          await _biometricService.removeMasterKey(_vaultName);
          _hasBiometricKey = false;
          setError("Biometrie-Schlüssel veraltet. Bitte mit Passwort einloggen.");
        } else {
          setError("Falsches Master-Passwort.  $msg");
        }
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
    final saltBase64 = base64.encode(salt);
    final masterKey = await _cryptoService.deriveKey(_password, salt);
    final hexMasterKey = _bytesToHex(masterKey);

    try {
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
        salt: saltBase64,
        encryptedPrivateKey: encryptedPrivKey,
        useBiometric: false, 
        lastSyncAt: DateTime.fromMillisecondsSinceEpoch(0).toUtc(),
      );

      await _databaseService.saveUser(newUser);
      await _databaseService.saveSettings(newSettings);
      
      _configService.addVault(_vaultName, saltBase64);
      _configService.lastVaultName = _vaultName;
      await _updateState();

      _sessionService.setSession(
        user: newUser,
        privateKey: privKeyBytes,
        vaultName: _vaultName,
        settings: newSettings.toMap(),
      );

      return LoginResult.success;
    } finally {
      _cryptoService.wipeKey(masterKey);
    }
  }

  Future<LoginResult> _openVault() async {
    final saltBase64 = _configService.vaults[_vaultName];
    if (saltBase64 == null) return LoginResult.vaultNotFound;

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
      masterKey = await _cryptoService.deriveKey(_password, base64.decode(saltBase64));
    }

    final hexMasterKey = _bytesToHex(masterKey);

    try {
      await _databaseService.initialize(_vaultName, hexMasterKey);
      
      final user = await _databaseService.getUserById(1);
      final settings = await _databaseService.getSettings();
      
      if (user == null || settings == null) return LoginResult.corrupt;

      try {
        final privKeyBytes = await _cryptoService.decrypt(settings.encryptedPrivateKey, masterKey);
        _sessionService.setSession(
          user: user,
          privateKey: privKeyBytes,
          vaultName: _vaultName,
          settings: settings.toMap(),
        );

        if (isManualLogin && settings.useBiometric && !_hasBiometricKey) {
          return LoginResult.askToEnableBiometrics;
        }

      } catch (e) {
        if (!isManualLogin && _hasBiometricKey) {
           await _biometricService.removeMasterKey(_vaultName);
           _hasBiometricKey = false;
           setError("Veralteter Biometrie-Schlüssel gelöscht. Bitte mit Passwort anmelden.");
           return LoginResult.wrongPassword;
        }
        return LoginResult.corrupt;
      }

      _configService.lastVaultName = _vaultName;
      return LoginResult.success;
    } catch (e) {
      await _databaseService.close();
      rethrow;
    } finally {
      _cryptoService.wipeKey(masterKey);
    }
  }

  Future<void> saveMasterKey(String password) async {
    final saltBase64 = _configService.vaults[_vaultName];
    if (saltBase64 == null) return;
    
    final masterKey = await _cryptoService.deriveKey(password, base64.decode(saltBase64));
    try {
      await _biometricService.saveMasterKey(_vaultName, masterKey);
      await _updateState();
    } finally {
      _cryptoService.wipeKey(masterKey);
    }
  }

  Future<void> cleanUp() async {
    await _databaseService.deleteCurrentDatabase();
    _configService.removeVault(_vaultName);
    _sessionService.clearSession();
    vaultName = ''; 
    await _updateState();
  }

  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
