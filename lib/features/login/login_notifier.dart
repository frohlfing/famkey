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
  // --- Services ---
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
    return LoginState();
  }

  /// Lädt die Daten für die Anzeige.
  Future<void> load() async {
    if (state.isBusy) return;

    // 1. Status zurücksetzen
    state = const LoginState().copyWith(status: LoginActionStatus.loading, error: FormError.none());

    try {
      // 2. Der zuletzt ausgewählte Tresor als Default nehmen
      final vaultName = _configService.lastVaultName;

      // 3. Liste der Tresore ermitteln
      final vaults = await _databaseService.getExistingVaults();

      // 4. Gibt es diesem Tresor noch?
      final exists = vaultName.isNotEmpty ? vaults.contains(vaultName) : false;

      // 5. Gibt es Biometrie-Unterstützung zu diesem Tresor?
      final hasBiometricKey = exists ? await _biometricService.containsMasterKey(vaultName) : false;

      // 6. State aktualisieren
      state = state.copyWith(
        vaultName: vaultName,
        existingVaults: vaults,
        isExists: exists,
        hasBiometricKey: hasBiometricKey,
        status: LoginActionStatus.initial,
      );

    } catch (e, st) {
      Logger().fatal("Fehler beim Laden: $e", stack: st);
      state = state.copyWith(status: LoginActionStatus.failure, error: FormError(ErrorCode.unknown));
    }
  }

  /// Führt eine Bereinigung durch (z.B. bei einer korrupten SQLite-Datei).
  Future<void> cleanUp() async {
    if (state.isBusy) return;

    // 1. Status auf loading setzen
    state = state.copyWith(status: LoginActionStatus.loading, error: FormError.none());

    try {

      // 2. Datenbank + Salt löschen
      await _databaseService.deleteCurrentDatabaseAndSaltFile();

      // 3. Master-Key aus dem Secure-Store löschen (wenn vorhanden, sonst passiert nichts)
      await _biometricService.removeMasterKey(state.vaultName);

      // 4. Session löschen
      _sessionService.clearSession();

      // 5. Letzten Tresor im ConfigService löschen
      _configService.lastVaultName = '';

      // 6. Liste der Tresore aktualisieren
      final vaults = await _databaseService.getExistingVaults();

      // 7. State zurücksetzen
      state = const LoginState().copyWith(
        existingVaults: vaults,
        status: LoginActionStatus.initial,
      );

    } catch (e, st) {
      Logger().fatal("Fehler beim Bereinigen: $e", stack: st);
      state = state.copyWith(status: LoginActionStatus.failure, error: FormError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Login-Prozess ---
  // ------------------------------------------------------------------------

  /// Startet den Login-Prozess.
  Future<void> login({bool forceCreate = false}) async {
    if (state.isBusy) return;

    Uint8List? masterKey;
    final vaultName = state.vaultName;
    final password = state.password;

    // 1. Validierung der Benutzereingabe
    if (vaultName.isEmpty) {
      state = state.copyWith(error: FormError(ErrorCode.valueRequired, field: 'vaultName'));
      return;
    }
    if (password.isEmpty && (!state.isExists || !state.hasBiometricKey)) {
      state = state.copyWith(error: FormError(ErrorCode.valueRequired, field: 'password'));
      return;
    }

    // 2. Wenn der Tresor nicht existiert, mit der Frage abbrechen, ob er angelegt werden soll
    if (!state.isExists && !forceCreate) {
      state = state.copyWith(status: LoginActionStatus.askToCreateVault);
      return;
    }

    // 3. Status auf loading setzen
    state = state.copyWith(status: LoginActionStatus.loading, error: FormError.none());

    try {
      // 4. Kurze Pause für den Lade-Indikator, bevor Argon2 blockiert
      await Future.delayed(const Duration(milliseconds: 50));

      // 5. Sicherstellen, dass keine alte Verbindung mehr offen ist
      await _databaseService.close();

      // 6. Salt laden bzw. neu generieren
      final salt = state.isExists ? await _databaseService.getSalt(vaultName) : _cryptoService.generateSalt();
      if (salt == null) {
        state = state.copyWith(status: LoginActionStatus.failure, error: FormError(state.isExists ? ErrorCode.vaultNotFound : ErrorCode.unknown));
        return;
      }

      // 7. Master-Key ableiten
      if (password.isEmpty) {
        // Biometrie verwenden: Master-Key aus Secure-Store holen (löst System-Dialog aus)
        masterKey = await _biometricService.getMasterKey(vaultName);
        if (masterKey == null) {
          state = state.copyWith(status: LoginActionStatus.failure, error: FormError(ErrorCode.biometricCanceled));
          return;
        }
      } else {
        // Master-Key ableiten aus Passwort und Salt berechnen
        masterKey = await _cryptoService.deriveKey(password, salt);
      }

      Uint8List privateKey;
      UserEntity? user;
      SettingsEntity? settings;

      // 8. Datenbank öffnen bzw. anlegen
      await _databaseService.initialize(vaultName, masterKey);

      if (state.isExists) {
        // DB geöffnet

        // Benutzer und Settings laden
        user = await _databaseService.getUser(1);
        settings = await _databaseService.getSettings();
        if (user == null || settings == null) {
          // Status auf askToCleanUp setzen (nicht auf failure), so dass nachgefragt wird, ob die Datenbank gelöscht werden soll
          state = state.copyWith(status: LoginActionStatus.askToCleanUp, error: FormError(ErrorCode.vaultCorrupt));
          return;
        }

        // Private Key entschlüsseln
        try {
          privateKey = await _cryptoService.decrypt(settings.encryptedPrivateKey, masterKey);
        } catch (e) {
          if (password.isEmpty) {
            // Biometrie fehlgeschlagen
            await _biometricService.removeMasterKey(vaultName);
            state = state.copyWith(
              hasBiometricKey: false,
              status: LoginActionStatus.failure,
              error: FormError(ErrorCode.wrongBiometric, field: 'password'),
            );
            return;
          }
          // Passwort falsch
          state = state.copyWith(
            status: LoginActionStatus.failure,
            error: FormError(ErrorCode.wrongPassword, field: 'password'),
          );
          return;
        }
      } else {
        // DB angelegt

        // Salt-Datei ebenfalls anlegen, RSA-Schlüsselpaar generieren und privaten Schlüssel verpacken
        await _databaseService.saveSalt(vaultName, salt);
        final (pubKey, privKey) = await _cryptoService.generateRsaKeyPair();
        final encryptedPrivKey = await _cryptoService.encrypt(privKey, masterKey);
        privateKey = privKey;

        // Benutzer der App (ID = 1) anlegen
        // SQLite-net schaut beim Insert in seine interne Sequenz-Tabelle.
        // Da die Datenbank neu ist, ist die nächste freie ID immer die 1.
        user = await _databaseService.saveUser(
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

        // Settings anlegen
        settings = await _databaseService.saveSettings(
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
      }

      // 9. Tresor für den nächsten Login merken
      _configService.lastVaultName = vaultName;

      // 10. Session anlegen
      _sessionService.setSession(
        user: user,
        privateKey: privateKey,
        vaultName: vaultName,
        settings: settings,
      );

      // 11. Status ermitteln
      // Falls mit Passwort eingeloggt und Biometrie gewünscht, aber noch nicht hinterlegt: Nachfragen, ob Biometrie aktiviert werden soll
      final status = password.isNotEmpty && settings.useBiometric && !state.hasBiometricKey
          ? LoginActionStatus.askToEnableBiometrics
          : LoginActionStatus.success;

      // 12. State aktualisieren
      state = state.copyWith(
        isExists: true,
        existingVaults: !state.isExists ? await _databaseService.getExistingVaults() : null,
        password: '', // Passwortfeld leeren
        passwordStrength: 0, // Passwortstärke zurücksetzen
        status: status,
      );

    } catch (e, st) {
      await _databaseService.close(); // Datenbank schließen (wenn sie nicht offen ist, passiert nichts)
      final msg = e.toString().toLowerCase();
      if (msg.contains('file is not a database') || msg.contains('authentication failed') || msg.contains('file is encrypted or is not a database')) {
        state = state.copyWith(status: LoginActionStatus.failure, error: FormError(ErrorCode.wrongPassword, field: 'password'));
        return;
      }

      if (msg.contains('database is locked')) {
        state = state.copyWith(status: LoginActionStatus.failure, error: FormError(ErrorCode.vaultLocked));
        return;
      }

      Logger().fatal('Fehler beim Login: $e', stack: st);
      state = state.copyWith(status: LoginActionStatus.failure, error: FormError(ErrorCode.unknown));

    } finally {
      // Master-Key aus dem RAM löschen
      if (masterKey != null) _cryptoService.wipeKey(masterKey);
    }
  }

  // ------------------------------------------------------------------------
  // --- Biometrie ---
  // ------------------------------------------------------------------------

  /// Speichert den Master-Key im biometrischen Secure-Store und setzt danach
  /// den Status auf Erfolg, um die Navigation zur Hauptseite auszulösen.
  ///
  /// Wird aufgerufen, wenn der Benutzer die Biometrie-Einrichtung akzeptiert.
  Future<void> saveMasterKeyAndCompleteLogin(String password) async {
    if (state.isBusy) return;
    Uint8List? masterKey;

    // 1. Status auf loading setzen
    state = state.copyWith(status: LoginActionStatus.loading, error: FormError.none());

    try {
      // 2. Salt laden
      final salt = await _databaseService.getSalt(state.vaultName);
      if (salt == null) throw Exception("Das Salt liegt nicht in der Datenbank.");

      // 3. Master-Key ableiten
      masterKey = await _cryptoService.deriveKey(password, salt);

      // 4. Im Secure-Store speichern
      await _biometricService.saveMasterKey(state.vaultName, masterKey);

      // 5. State aktualisieren (setzt den Status auf Erfolg, um die Navigation auszulösen)
      state = state.copyWith(
        hasBiometricKey: true,
        status: LoginActionStatus.success,
      );

    } catch (e, st) {
      Logger().fatal("Fehler beim Speichern des Master-Keys im biometrischen Secure-Store: $e", stack: st);
      state = state.copyWith(status: LoginActionStatus.failure, error: FormError(ErrorCode.unknown));

    } finally {
      // Master-Key aus dem RAM löschen
      if (masterKey != null) _cryptoService.wipeKey(masterKey);
    }
  }

  /// Setzt den Status auf Erfolg, um die Navigation zur Hauptseite auszulösen.
  ///
  /// Wird aufgerufen, wenn der Benutzer die Biometrie-Einrichtung ablehnt.
  void completeLogin() {
    state = state.copyWith(
      hasBiometricKey: false,
      status: LoginActionStatus.success,
    );
  }

  // ------------------------------------------------------------------------
  // --- Setter ---
  // ------------------------------------------------------------------------

  /// Setter für Tresorname.
  Future<void> setVaultName(String value) async {
    // Ungültige Zeichen für Dateinamen filtern
    final vaultName = value.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();

    // Zustand vor dem await sichern
    if (vaultName == state.vaultName) return; // Keine Änderung, nichts tun

    // Zuerst den Namen synchron aktualisieren, damit die UI sofort reagiert
    final exists = vaultName.isNotEmpty ? state.existingVaults.contains(vaultName) : false;
    final error = state.error.field == 'vaultName' ? FormError.none() : null;
    state = state.copyWith(vaultName: vaultName, isExists: exists, hasBiometricKey: false, error: error);

    // Dann asynchron die Biometrie-Info nachladen
    final hasBiometricKey = exists ? await _biometricService.containsMasterKey(vaultName) : false;

    // Nur aktualisieren, wenn der Benutzer in der Zwischenzeit nichts anderes eingegeben hat
    if (state.vaultName == vaultName) {
      state = state.copyWith(hasBiometricKey: hasBiometricKey);
    }
  }

  /// Setter für Passwort.
  void setPassword(String value) async {
    final error = state.error.field == 'password' ? FormError.none() : null;
    state = state.copyWith(
      password: value,
      passwordStrength: _passwordService.estimateStrength(value),
      error: error,
    );
  }

  /// Alias für `setPassword('')`.
  void clearPassword() {
    setPassword('');
  }
}
