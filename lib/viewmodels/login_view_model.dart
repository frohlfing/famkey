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

/// Das Ergebnis eines Anmeldeversuchs.
enum LoginResult {
  /// Anmeldung war erfolgreich.
  success,

  /// Das eingegebene Master-Passwort ist falsch.
  wrongPassword,

  /// Der angegebene Tresor konnte auf dem Gerät nicht gefunden werden.
  vaultNotFound,

  /// Die Tresordatei ist beschädigt oder keine gültige Datenbank.
  corrupt,

  /// Anmeldung erfolgreich, aber Biometrie könnte nun aktiviert werden.
  askToEnableBiometrics,

  /// Ein allgemeiner Fehler ist aufgetreten.
  error,
}

/// Das [LoginViewModel] verwaltet den Authentifizierungsprozess und den Zugriff auf die Tresore.
///
/// **Hauptaufgaben:**
/// * Anzeige und Auswahl vorhandener lokaler Tresore.
/// * Erstellen / Öffnen des Tresors inklusive Schlüsselableitung (Argon2id).
/// * Biometrie-Unterstützung: Login per Fingerabdruck oder Gesichtserkennung.
///
/// **Sicherheitsaspekte:**
/// * **Kein Master-Passwort im RAM:** Das Passwort wird nur kurzzeitig zur Ableitung des Master-Keys verwendet.
/// * **Wiping:** Der Master-Key wird nach der Entschlüsselung sofort aus dem Speicher gelöscht.
/// * **Hardware-Schutz für Biometrie:** Der Master-Key liegt im verschlüsselten Secure-Store des Betriebssystems.
class LoginViewModel extends BaseViewModel {
  // ------------------------------------------------------------------------
  // --- Felder ---
  // ------------------------------------------------------------------------

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

  // ------------------------------------------------------------------------
  // --- Konstruktor ---
  // ------------------------------------------------------------------------

  /// Initialisiert eine neue Instanz des [LoginViewModel].
  LoginViewModel(this._biometricService, this._configService, this._cryptoService, this._databaseService, this._sessionService) {
    resetState();
  }

  // ------------------------------------------------------------------------
  // --- Eigenschaften ---
  // ------------------------------------------------------------------------

  /// Der Name des Tresors, der geöffnet oder neu erstellt werden soll.
  String get vaultName => _vaultName;

  /// Das aktuell eingegebene Master-Passwort.
  String get password => _password;

  /// Gibt an, ob der gewählte Tresor bereits lokal existiert.
  bool get isExists => _isExists;

  /// Gibt an, ob für den aktuell gewählten Tresor der Master-Key im Secure-Store liegt.
  bool get hasBiometricKey => _hasBiometricKey;

  /// Eine Liste aller auf diesem Gerät gefundenen Tresore.
  List<String> get existingVaults => _existingVaults;

  set vaultName(String value) {
    if (_vaultName == value) return;
    // Ungültige Zeichen für Dateinamen filtern
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

  // ------------------------------------------------------------------------
  // --- Befehle ---
  // ------------------------------------------------------------------------

  /// Setzt den Status der Login-Maske zurück.
  void resetState() {
    _password = '';
    _vaultName = _configService.lastVaultName;
    clearError();
    refreshVaultList();
  }

  /// Löscht das Passwort aus dem RAM.
  void clearPassword({bool notify = true}) {
    _password = '';
    if (notify) notifyListeners();
  }

  /// Scannt das Dateisystem nach vorhandenen Tresor-Datenbanken.
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

  /// Startet den Authentifizierungsprozess.
  /// Prüft, ob der Tresor existiert, und leitet dann entweder das Öffnen oder die Neuanlage ein.
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

  /// Erstellt eine neue Tresor-Datenbank, generiert ein RSA-Schlüsselpaar für die Identität
  /// und verschlüsselt den privaten Teil mit dem Master-Key.
  Future<LoginResult> _createVault() async {
    // 1. Neues Salt generieren
    final salt = _cryptoService.generateSalt();

    // 2. Master-Key ableiten
    final masterKey = await _cryptoService.deriveKey(_password, salt);
    final hexMasterKey = _bytesToHex(masterKey);

    try {
      await _databaseService.deleteCurrentDatabase();
      final storagePath = _configService.vaultStoragePath;
      final saltFile = File(p.join(storagePath, '$_vaultName.db3.salt'));
      await saltFile.writeAsBytes(salt);

      // 3. Datenbank initialisieren (erstellt Tabellen)
      await _databaseService.initialize(_vaultName, hexMasterKey);

      // 4. RSA-Schlüsselpaar für den User generieren
      final (pubKey, privKeyBytes) = await _cryptoService.generateRsaKeyPair();

      // 5. Private Key verschlüsseln (mit dem Master-Key)
      final encryptedPrivKey = await _cryptoService.encrypt(privKeyBytes, masterKey);

      // 6. Eigene Identität und Settings anlegen
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

      // 7. In DB speichern
      await _databaseService.saveUser(newUser);
      await _databaseService.saveSettings(newSettings);

      _configService.lastVaultName = _vaultName;
      await refreshVaultList();

      // 8. Session setzen
      _sessionService.setSession(user: newUser, privateKey: privKeyBytes, vaultName: _vaultName, settings: newSettings.toMap());

      clearPassword(notify: true);
      return LoginResult.success;
    } finally {
      // Hygiene: Master-Key sofort aus dem RAM löschen
      _cryptoService.wipeKey(masterKey);
    }
  }

  /// Öffnet einen bestehenden Tresor, leitet den Master-Key ab und entschlüsselt die Sitzungsdaten.
  Future<LoginResult> _openVault() async {
    // final storagePath = _configService.vaultStoragePath;
    // final saltFile = File(p.join(storagePath, '$_vaultName.db3.salt'));
    // if (!await saltFile.exists()) return LoginResult.vaultNotFound;
    // final salt = await saltFile.readAsBytes();

    // Salt über den Service laden
    final salt = await _databaseService.getSalt(_vaultName);
    if (salt == null) return LoginResult.vaultNotFound;

    Uint8List? masterKey;
    bool isManualLogin = _password.isNotEmpty;

    if (!isManualLogin && _hasBiometricKey) {
      // 1. Master-Key aus Secure-Store holen (löst System-Dialog aus)
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
      // 1. Master-Key aus eingegebenes Master-Passwort und Salt ableiten (Argon2id)
      masterKey = await _cryptoService.deriveKey(_password, salt);
    }

    final hexMasterKey = _bytesToHex(masterKey);

    try {
      // 2. Datenbank öffnen
      await _databaseService.initialize(_vaultName, hexMasterKey);

      // 3. Eigene Identität und Einstellungen auslesen
      final settings = await _databaseService.getSettings();
      if (settings == null) return LoginResult.corrupt;

      final user = await _databaseService.getUserById(1);
      if (user == null) return LoginResult.corrupt;

      // 4. Private Key entschlüsseln
      try {
        final privKeyBytes = await _cryptoService.decrypt(settings.encryptedPrivateKey, masterKey);
        _sessionService.setSession(user: user, privateKey: privKeyBytes, vaultName: _vaultName, settings: settings.toMap());

        // Falls manuell eingeloggt und Biometrie gewünscht, aber noch nicht hinterlegt: Nachfragen
        if (isManualLogin && settings.useBiometric && !_hasBiometricKey) {
          return LoginResult.askToEnableBiometrics;
        }
      } catch (e) {
        // Falls Biometrie-Key veraltet ist (z.B. nach Password Change auf anderem Gerät)
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
      // Hygiene: Master-Key aus dem RAM löschen
      _cryptoService.wipeKey(masterKey);
    }
  }

  /// Speichert den abgeleiteten Master-Key im biometrisch geschützten Secure-Store des Betriebssystems.
  Future<void> saveMasterKey(String password) async {
    // final storagePath = _configService.vaultStoragePath;
    // final saltFile = File(p.join(storagePath, '$_vaultName.db3.salt'));
    // if (!await saltFile.exists()) return;
    // final salt = await saltFile.readAsBytes();

    // Salt über den Service laden
    final salt = await _databaseService.getSalt(_vaultName);
    if (salt == null) return;

    final masterKey = await _cryptoService.deriveKey(password, salt);
    try {
      await _biometricService.saveMasterKey(_vaultName, masterKey);
      await _updateState();
    } finally {
      _cryptoService.wipeKey(masterKey);
    }
  }

  /// Führt eine Bereinigung durch (z.B. bei korruptem Tresor).
  Future<void> cleanUp() async {
    await _databaseService.deleteCurrentDatabase();
    _sessionService.clearSession();
    _vaultName = '';
    _password = '';
    _configService.lastVaultName = '';
    await refreshVaultList();
  }

  // ------------------------------------------------------------------------
  // --- Private Methoden ---
  // ------------------------------------------------------------------------

  Future<void> _updateState() async {
    _isExists = _existingVaults.contains(_vaultName);
    _hasBiometricKey = await _biometricService.containsMasterKey(_vaultName);
    notifyListeners();
  }

  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
