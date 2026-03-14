import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/login/login_state.dart';
import 'package:privault/services/biometric_service.dart';
import 'package:privault/services/config_service.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/password_service.dart';
import 'package:privault/services/session_service.dart';
import 'package:uuid/uuid.dart';

final loginProvider = NotifierProvider<LoginNotifier, LoginState>(
  LoginNotifier.new,
);

class LoginNotifier extends Notifier<LoginState> {

  // ------------------------------------------------------------------------
  // --- Verwendete Dienste ---
  // ------------------------------------------------------------------------

  late final BiometricService _biometricService;
  late final ConfigService _configService;
  late final CryptoService _cryptoService;
  late final DatabaseService _databaseService;
  late final PasswordService _passwordService;
  late final SessionService _sessionService;

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert einen Notifier.
  ///
  /// Die Verwendung von `Ref.watch` oder `Ref.listen` innerhalb dieser Methode ist unbedenklich.
  /// Ändert sich eine Abhängigkeit dieses Notifiers (bei Verwendung von `Ref.watch`), wird der Build-Prozess erneut ausgeführt. Der Notifier selbst wird jedoch nicht neu erstellt. Seine Instanz bleibt zwischen den Build-Ausführungen erhalten.
  @override
  LoginState build() {
    // Dienste aus getIt holen
    _biometricService = getIt();
    _configService = getIt();
    _cryptoService = getIt();
    _databaseService = getIt();
    _passwordService = getIt();
    _sessionService = getIt();

    // Initialer State
    return LoginState(vaultName: _configService.lastVaultName);
  }

  /// Lädt die Daten für die Anzeige.
  Future<void> load() async {
    state = state.copyWith(isBusy: true, error: FormError.none());
    try {
      await _refreshVaultList();
    } catch (e, st) {
      Logger().fatal('Fehler beim Laden: $e', stack: st);
      state = state.copyWith(error: FormError(ErrorCode.unknown));
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  /// Scannt das Dateisystem nach vorhandenen Tresoren.
  Future<void> _refreshVaultList() async {
    final vaults = await _databaseService.getExistingVaults();
    final exists = vaults.contains(state.vaultName);
    state = state.copyWith(existingVaults: vaults, isExists: exists);
  }

  /// Führt eine Bereinigung durch (z.B. bei einer korrupten SQLite-Datei).
  Future<void> cleanUp() async {
    // 1. Datenbank + Salt löschen
    await _databaseService.deleteCurrentDatabaseAndSaltFile();

    // 2. Session löschen
    _sessionService.clearSession();

    // 3. State zurücksetzen
    state = const LoginState();

    // 4. Letzten Tresor im ConfigService löschen
    _configService.lastVaultName = '';

    // 5. Liste der Tresore aktualisieren
    await _refreshVaultList();
  }

  // ------------------------------------------------------------------------
  // --- Login-Prozess ---
  // ------------------------------------------------------------------------

  /// Startet den Login-Prozess.
  Future<bool> login({bool forceCreate = false}) async {
    // Validierung der Benutzereingabe
    if (state.vaultName.isEmpty) {
      state = state.copyWith(error: FormError(ErrorCode.valueRequired, field: 'vaultName'));
      return false;
    }
    if (!state.isExists && !forceCreate) {
      state = state.copyWith(error: FormError(ErrorCode.vaultNotFound, field: 'vaultName'));
      return false;
    }

    // Busy setzen, Fehler zurücksetzen
    state = state.copyWith(isBusy: true, error: FormError.none(), askToEnableBiometrics: false);

    try {
      // Kurze Pause für den Lade-Indikator, bevor Argon2 blockiert
      await Future.delayed(const Duration(milliseconds: 50));

      // Sicherstellen, dass keine alte Verbindung mehr offen ist
      await _databaseService.close();

      // falls der Tresor existiert,Tresor öffnen, sonst neu anlegen
      if (state.isExists) {
        return await _openVault();
      } else {
        if (state.password.isEmpty) {
          state = state.copyWith(error: FormError(ErrorCode.valueRequired, field: 'password'));
          return false;
        }
        return await _createVault();
      }

    } catch (e, st) {
      final msg = e.toString().toLowerCase();

      if (msg.contains('database is locked')) {
        state = state.copyWith(error: FormError(ErrorCode.vaultLocked));
        return false;
      }

      if (msg.contains('file is not a database') ||
          msg.contains('authentication failed') ||
          msg.contains('file is encrypted or is not a database')) {
        state = state.copyWith(error: FormError(ErrorCode.wrongPassword, field: 'password'));
        return false;
      }

      Logger().fatal('Fehler beim Login: $e', stack: st);
      state = state.copyWith(error: FormError(ErrorCode.unknown));
      return false;

    } finally {
      // Busy zurücksetzen
      state = state.copyWith(isBusy: false);
    }
  }

  /// Öffnet einen bestehenden Tresor
  Future<bool> _openVault() async {
    final vaultName = state.vaultName;
    final password = state.password;
    final isManualLogin = password.isNotEmpty;

    // 1. Salt laden
    final salt = await _databaseService.getSalt(vaultName);
    if (salt == null) {
      state = state.copyWith(error: FormError(ErrorCode.vaultNotFound));
      return false;
    }

    // 2. Master-Key aus dem Secure-Store holen oder aus dem eingegebenen Master-Passwort ableiten
    Uint8List? masterKey;
    if (!isManualLogin && state.hasBiometricKey) {
      // Master-Key aus Secure-Store holen (löst System-Dialog aus)
      masterKey = await _biometricService.getMasterKey(vaultName);
      if (masterKey == null) {
        state = state.copyWith(error: FormError(ErrorCode.biometricCanceled));
        return false;
      }
    } else {
      // Master-Key aus eingegebenes Master-Passwort und Salt ableiten (Argon2id)
      if (password.isEmpty) {
        state = state.copyWith(error: FormError(ErrorCode.valueRequired, field: 'password'));
        return false;
      }
      masterKey = await _cryptoService.deriveKey(password, salt);
    }

    try {
      // 3. Datenbank öffnen
      await _databaseService.initialize(vaultName, masterKey);
      final settings = await _databaseService.getSettings();
      final user = await _databaseService.getUser(1);
      if (settings == null || user == null) {
        state = state.copyWith(error: FormError(ErrorCode.vaultCorrupt));
        return false;
      }

      // 4. Private Key entschlüsseln
      try {
        final privKeyBytes =
        await _cryptoService.decrypt(settings.encryptedPrivateKey, masterKey);
        _sessionService.setSession(
          user: user,
          privateKey: privKeyBytes,
          vaultName: vaultName,
          settings: settings,
        );
      } catch (e) {
        if (!isManualLogin && state.hasBiometricKey) {
          // Biometrie fehlgeschlagen
          await _biometricService.removeMasterKey(vaultName);
          state = state.copyWith(
              hasBiometricKey: false,
              error: FormError(ErrorCode.wrongBiometric, field: 'password'),
          );
          return false;
        }
        // Passwort falsch
        state = state.copyWith(error: FormError(ErrorCode.wrongPassword, field: 'password'));
        return false;
      }

      // 5. Tresor für den nächsten Login merken
      _configService.lastVaultName = vaultName;

      // 6. Passwort aus dem RAM löschen
      state = state.copyWith(password: '');

      // 7. Biometrie anbieten?
      // Falls manuell eingeloggt und Biometrie gewünscht, aber noch nicht hinterlegt: Nachfragen
      if (isManualLogin && settings.useBiometric && !state.hasBiometricKey) {
        state = state.copyWith(askToEnableBiometrics: true);
      }
      return true;
    } catch (e) {
      await _databaseService.close();
      rethrow; // wird im login() gefangen
    } finally {
      // Master-Key aus dem RAM löschen
      _cryptoService.wipeKey(masterKey);
    }
  }

  /// Erstellt einen neuen Tresor.
  Future<bool> _createVault() async {
    final vaultName = state.vaultName;
    final password = state.password;

    // Validierung der Benutzereingabe
    if (password.isEmpty) {
      state = state.copyWith(error: FormError(ErrorCode.valueRequired, field: 'password'));
      return false;
    }

    // 1. Salt generieren
    final salt = _cryptoService.generateSalt();

    // 2. Master-Key ableiten
    final masterKey = await _cryptoService.deriveKey(password, salt);

    try {
      // Bestehende löschen
      //await _databaseService.deleteCurrentDatabase();

      // 3. Datenbank initialisieren (erstellt Tabellen)
      await _databaseService.initialize(vaultName, masterKey);

      // 4. Salt-Datei anlegen
      await _databaseService.saveSalt(vaultName, salt);

      // 5. RSA-Schlüsselpaar generieren
      final (pubKey, privKeyBytes) = await _cryptoService.generateRsaKeyPair();

      // 6. Privaten Schlüssel verschlüsseln
      final encryptedPrivKey = await _cryptoService.encrypt(privKeyBytes, masterKey);

      // 7. User (Benutzer der App; ID = 1) anlegen
      // SQLite-net schaut beim Insert in seine interne Sequenz-Tabelle.
      // Da die Datenbank neu ist, ist die nächste freie ID immer die 1.
      final newUser = await _databaseService.saveUser(
        UserEntity(
          id: 0,
          uuid: const Uuid().v4(),
          name: Platform.environment['USERNAME'] ?? 'User',
          publicKey: pubKey,
          isVerified: true,
          isHidden: false,
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      // 8. Settings anlegen
      final newSettings = await _databaseService.saveSettings(
        SettingsEntity(
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
        ),
      );

      // 9. Letzten Tresor speichern und Liste der verfügbaren Tresore aktualisieren
      _configService.lastVaultName = vaultName;
      await _refreshVaultList();

      // 10. Session setzen
      _sessionService.setSession(
        user: newUser,
        privateKey: privKeyBytes,
        vaultName: vaultName,
        settings: newSettings,
      );

      // 11. Passwort löschen
      state = state.copyWith(password: '');

      return true;
    } finally {
      // Master-Key sofort aus dem RAM löschen
      _cryptoService.wipeKey(masterKey);
    }
  }

  // ------------------------------------------------------------------------
  // --- Biometrie ---
  // ------------------------------------------------------------------------

  /// Speichert den Master-Key im biometrischen Secure-Store.
  /// Entspricht saveMasterKey() im alten ViewModel.
  Future<bool> saveMasterKey(String password) async {
    Uint8List? masterKey;
    final vaultName = state.vaultName;

    try {
      // 1. Salt laden
      final salt = await _databaseService.getSalt(vaultName);
      if (salt == null) throw Exception("Das Salt liegt nicht in der Datenbank.");

      // 2. Master-Key ableiten
      masterKey = await _cryptoService.deriveKey(password, salt);

      // 3. Im Secure-Store speichern
      await _biometricService.saveMasterKey(vaultName, masterKey);

      // 4. State aktualisieren
      state = state.copyWith(hasBiometricKey: true);
      return true;

    } catch (e, st) {
      Logger().fatal("Fehler beim Speichern des Master-Keys im biometrischen Secure-Store: $e", stack: st);
      state = state.copyWith(error: FormError(ErrorCode.unknown));
      return false;

    } finally {
      // Master-Key aus dem RAM löschen
      if (masterKey != null)  _cryptoService.wipeKey(masterKey);
    }
  }

  // ------------------------------------------------------------------------
  // --- Convenience Setter & Getter ---
  // ------------------------------------------------------------------------

  /// Setter für Tresorname.
  void setVaultName(String value) {
    // Ungültige Zeichen für Dateinamen filtern
    final cleaned = value.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    final exists = state.existingVaults.contains(cleaned);
    final error = state.error.field == 'vaultName' ? FormError.none() : null;
    state = state.copyWith(vaultName: cleaned, isExists: exists, error: error);
  }

  /// Setter für Passwort.
  void setPassword(String value) {
    final error = state.error.field == 'password' ? FormError.none() : null;
    state = state.copyWith(password: value, error: error);
  }

  /// Alias für `setPassword('')`.
  void clearPassword() {
    setPassword('');
  }

  /// Berechnete Stärke des aktuell eingegebenen Passworts (0–4).
  int getPasswordStrength() {
    return _passwordService.estimateStrength(state.password);
  }

  /// Gibt die Fehlermeldung für ein bestimmtes Feld zurück oder null.
  String? getFieldErrorText(String field) {
    return state.error.field == field ? state.error.text : null;
  }
}
