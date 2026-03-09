import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:privault/core/base_view_model.dart';
import 'package:privault/database/database.dart';
import 'package:privault/services/biometric_service.dart';
import 'package:privault/services/config_service.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/password_service.dart';
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

/// Das `LoginViewModel` verwaltet den Authentifizierungsprozess und den Zugriff auf die Tresore.
class LoginViewModel extends BaseViewModel {
  // ------------------------------------------------------------------------
  // --- Verwendete Dienste ---
  // ------------------------------------------------------------------------

  final BiometricService _biometricService;
  final ConfigService _configService;
  final CryptoService _cryptoService;
  final DatabaseService _databaseService;
  final PasswordService _passwordService;
  final SessionService _sessionService;

  // ------------------------------------------------------------------------
  // --- Interne Variablen ---
  // ------------------------------------------------------------------------

  String _vaultName = '';
  String _password = '';
  bool _isExists = false;
  bool _hasBiometricKey = false;
  List<String> _existingVaults = [];

  // ------------------------------------------------------------------------
  // --- Initialisierung ---
  // ------------------------------------------------------------------------

  /// Konstruktor
  LoginViewModel(this._biometricService, this._configService, this._cryptoService, this._databaseService, this._passwordService, this._sessionService);

  /// Initialisiert die Variablen, bevor der erste Frame gerendert wird.
  void init() {
    clearError(notify: false);
    _vaultName = _configService.lastVaultName;
    _password = '';
    _isExists = false;
    _hasBiometricKey = false;
    _existingVaults = [];
  }

  /// Lädt die Daten.
  Future<void> load() async {
    setBusy(true);
    try {
      clearError();
      await refreshVaultList();
    } catch (e, st) {
      logError('Fehler beim Initialisieren: $e', st);
      notifyUnexpectedError();
    } finally {
      setBusy(false);
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
  // --- Login-Button ---
  // ------------------------------------------------------------------------

  /// Startet den Authentifizierungsprozess.
  /// Prüft, ob der Tresor existiert, und leitet dann entweder das Öffnen oder die Neuanlage ein.
  Future<LoginResult> login({bool forceCreate = false}) async {
    if (_vaultName.isEmpty) return LoginResult.error;

    // WICHTIG: Sicherstellen, dass keine alte Verbindung mehr offen ist
    await _databaseService.close();

    if (!_isExists && !forceCreate) return LoginResult.vaultNotFound;

    setBusy(true);
    try {
      clearError();

      // Kurze Pause für Lade-Indikator, bevor Argon2 blockiert
      await Future.delayed(const Duration(milliseconds: 50));

      if (_isExists) {
        return await _openVault();
      } else {
        if (_password.isEmpty) {
          notifyError("Bitte ein Master-Passwort festlegen.");
          return LoginResult.error;
        }
        return await _createVault();
      }
    } catch (e, st) {
      final msg = e.toString().toLowerCase();

      if (msg.contains("database is locked")) {
        notifyError("Der Tresor ist blockiert. Bitte App neu starten.");
        return LoginResult.error;
      }

      if (msg.contains("file is not a database") || msg.contains("authentication failed") || msg.contains("file is encrypted or is not a database")) {
        notifyError("Falsches Master-Passwort oder Tresor beschädigt.");
        return LoginResult.wrongPassword;
      }

      logError("Login-Exception: $e", st);
      notifyUnexpectedError();
      return LoginResult.error;
    } finally {
      setBusy(false);
    }
  }

  /// Erstellt eine neue Tresor-Datenbank, generiert ein RSA-Schlüsselpaar für die Identität
  /// und verschlüsselt den privaten Teil mit dem Master-Key.
  Future<LoginResult> _createVault() async {
    if (_password.isEmpty) {
      notifyError("Bitte das Master-Passwort eingeben.");
      return LoginResult.error;
    }

    // 1. Neues Salt generieren
    final salt = _cryptoService.generateSalt();

    // 2. Master-Key ableiten
    final masterKey = await _cryptoService.deriveKey(_password, salt);

    try {
      // Bestehende löschen
      //await _databaseService.deleteCurrentDatabase();

      // 3. Datenbank initialisieren (erstellt Tabellen)
      await _databaseService.initialize(_vaultName, masterKey);

      // 4. Salt-Datei anlegen
      // Alle Zeichen außer Buchstaben, Zahlen, Unterstrichen und Bindestrichen durch '_' ersetzen.
      final safeName = vaultName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
      final saltFile = File(p.join(_configService.vaultStoragePath, '$safeName.db3.salt'));
      await saltFile.writeAsBytes(salt);

      // 5. RSA-Schlüsselpaar für den User generieren
      final (pubKey, privKeyBytes) = await _cryptoService.generateRsaKeyPair();

      // 6. Private Key verschlüsseln (mit dem Master-Key)
      final encryptedPrivKey = await _cryptoService.encrypt(privKeyBytes, masterKey);

      // 7. UserEntity mit der ID = 1 (Benutzer der App) erstellen.
      // SQLite-net schaut beim Insert in seine interne Sequenz-Tabelle.
      // Da die Datenbank neu ist, ist die nächste freie ID immer die 1.
      final newUser = await _databaseService.saveUser(UserEntity(
        id: 0,
        uuid: const Uuid().v4(),
        name: Platform.environment['USERNAME'] ?? 'User',
        publicKey: pubKey,
        isVerified: true,
        isHidden: false,
        updatedAt: DateTime.now().toUtc(),
      ));

      // 8.  Settings anlegen
      final newSettings = await _databaseService.saveSettings(SettingsEntity(
        id: 0,
        salt: base64.encode(salt),
        encryptedPrivateKey: encryptedPrivKey,
        host: kDebugMode ? 'https://privault.test/api' : '', // todo später wieder auskommentieren!!!!
        apiToken: kDebugMode ? '6h54qT5l2r37Kr7XxfP08YD7gPAGff6aWSaa' : '', // todo später wieder auskommentieren!!!!
        useBiometric: false,
        pwLength: 16,
        pwSpecialChars: '',
        pwAvoidIlO0: true,
        categoryPlaceholder: '',
        lastSyncAt: DateTime.fromMillisecondsSinceEpoch(0).toUtc(),
      ));

      // 9. Letzten Tresor merken
      _configService.lastVaultName = _vaultName;
      await refreshVaultList();

      // 8. Session setzen
      _sessionService.setSession(
        user: newUser,
        privateKey: privKeyBytes,
        vaultName: _vaultName,
        settings: newSettings,
      );

      clearPassword();
      return LoginResult.success;
    } finally {
      // Master-Key sofort aus dem RAM löschen
      _cryptoService.wipeKey(masterKey);
    }
  }

  /// Öffnet einen bestehenden Tresor, leitet den Master-Key ab und entschlüsselt die Sitzungsdaten.
  Future<LoginResult> _openVault() async {
    // Salt aus der Salt-Datei lesen
    final salt = await _databaseService.getSalt(_vaultName);
    if (salt == null) return LoginResult.vaultNotFound;

    Uint8List? masterKey;
    bool isManualLogin = _password.isNotEmpty;

    // 1. Master-Key aus dem Secure-Store holen oder aus dem eingegebenen Master-Passwort ableiten
    if (!isManualLogin && _hasBiometricKey) {
      // Master-Key aus Secure-Store holen (löst System-Dialog aus)
      masterKey = await _biometricService.getMasterKey(_vaultName);
      if (masterKey == null) {
        notifyError("Biometrische Authentifizierung abgebrochen.");
        return LoginResult.error;
      }
    } else {
      // Master-Key aus eingegebenes Master-Passwort und Salt ableiten (Argon2id)
      if (_password.isEmpty) {
        notifyError("Bitte das Master-Passwort eingeben.");
        return LoginResult.error;
      }
      masterKey = await _cryptoService.deriveKey(_password, salt);
    }

    try {
      // 2. Datenbank öffnen
      await _databaseService.initialize(_vaultName, masterKey);

      // 3b. Einstellungen aus der DB lesen
      final settings = await _databaseService.getSettings();
      if (settings == null) {
        logError("Settings in DB nicht gefunden!");
        return LoginResult.corrupt;
      }

      // 3b. Eigene Identität aus der DB lesen
      final user = await _databaseService.getUser(1);
      if (user == null) {
        logError("User mit ID 1 in DB nicht gefunden!");
        return LoginResult.corrupt;
      }

      // 4. Private Key entschlüsseln
      try {
        final privKeyBytes = await _cryptoService.decrypt(settings.encryptedPrivateKey, masterKey);
        _sessionService.setSession(user: user, privateKey: privKeyBytes, vaultName: _vaultName, settings: settings);
      } catch (e) {
        //logError("Entschlüsselung des PrivateKeys fehlgeschlagen: $e");
        if (!isManualLogin && _hasBiometricKey) {
          await _biometricService.removeMasterKey(_vaultName);
          _hasBiometricKey = false;
          notifyError("Biometrie zurückgesetzt (gespeicherter Schlüssel war veraltet).");
          return LoginResult.wrongPassword;
        }
        notifyError("Falsches Master-Passwort.");
        return LoginResult.wrongPassword;
      }

      _configService.lastVaultName = _vaultName;
      clearPassword();

      // Falls manuell eingeloggt und Biometrie gewünscht, aber noch nicht hinterlegt: Nachfragen
      if (isManualLogin && settings.useBiometric && !_hasBiometricKey) {
        return LoginResult.askToEnableBiometrics;
      }

      return LoginResult.success;
    } catch (e) {
      await _databaseService.close();
      rethrow; // Wird im login() gefangen
    } finally {
      // Hygiene: Master-Key aus dem RAM löschen
      _cryptoService.wipeKey(masterKey);
    }
  }

  // ------------------------------------------------------------------------
  // --- Eigenschaften und Methoden ---
  // ------------------------------------------------------------------------

  // --- Tresor ---

  /// Der Name des Tresors, der geöffnet oder neu erstellt werden soll.
  String get vaultName => _vaultName;

  set vaultName(String value) {
    if (_vaultName == value) return;
    // Ungültige Zeichen für Dateinamen filtern
    _vaultName = value.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    if (errorMessage != null) clearError();
    _updateState();
    notifyListeners();
  }

  /// Gibt an, ob der gewählte Tresor bereits lokal existiert.
  bool get isExists => _isExists;

  /// Eine Liste aller auf diesem Gerät gefundenen Tresore.
  List<String> get existingVaults => _existingVaults;

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

  /// Prüft, ob es den Tresor gibt und ob es für diesen Tresor ein Wert im Secure-Store liegt.
  Future<void> _updateState() async {
    _isExists = _existingVaults.contains(_vaultName);
    _hasBiometricKey = await _biometricService.containsMasterKey(_vaultName);
    notifyListeners();
  }

  // --- Passwort ---

  /// Das aktuell eingegebene Master-Passwort.
  String get password => _password;

  set password(String value) {
    if (_password == value) return;
    _password = value;
    if (errorMessage != null) clearError();
    notifyListeners();
  }

  /// Berechnete Stärke des aktuell eingegebenen Passworts (0-4).
  int get passwordStrength => _passwordService.estimateStrength(_password);

  /// Löscht das Passwort aus dem RAM.
  void clearPassword({bool notify = true}) {
    _password = '';
    if (notify) notifyListeners();
  }

  // --- Biometrie ---

  /// Gibt an, ob für den aktuell gewählten Tresor der Master-Key im Secure-Store liegt.
  bool get hasBiometricKey => _hasBiometricKey;

  /// Speichert den abgeleiteten Master-Key im biometrisch geschützten Secure-Store des Betriebssystems.
  Future<void> saveMasterKey(String password) async {
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
}
