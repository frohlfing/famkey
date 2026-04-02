import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/features/settings/master_password/master_password_form_data.dart';
import 'package:privault/features/settings/master_password/master_password_state.dart';
import 'package:privault/services/biometric_service.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/password_service.dart';
import 'package:privault/services/session_service.dart';

final masterPasswordProvider = NotifierProvider<MasterPasswordNotifier, MasterPasswordState>(() {
  return MasterPasswordNotifier();
});

class MasterPasswordNotifier extends Notifier<MasterPasswordState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

  late final BiometricService _biometricService;
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
  MasterPasswordState build() {
    // Dienste aus getIt holen
    _biometricService = getIt<BiometricService>();
    _cryptoService = getIt<CryptoService>();
    _databaseService = getIt<DatabaseService>();
    _passwordService = getIt<PasswordService>();
    _sessionService = getIt<SessionService>();

    // Initialer State
    return MasterPasswordState();
  }

  /// Lädt die Daten für die Anzeige.
  Future<void> load() async {
    if (state.isBusy) return;

    // UI-State zurücksetzen
    state = const MasterPasswordState();
  }

  // ------------------------------------------------------------------------
  // --- Speichern ---
  // ------------------------------------------------------------------------

  /// Generiert ein neuen Salt, verschlüsselt die sqLite-Datei mit dem neuen Master-Schlüssel und aktualisiert die Salt-Datei.
  Future<void> save() async {
    if (state.isBusy) return;
    Uint8List? masterKey; // bisheriger Master-Key
    Uint8List? newMasterKey;

    var formData = state.formData;

    // 1. UI-State aktualisieren
    state = state.copyWith(
      formData: formData,
      status: MasterPasswordActionStatus.progress, error: AppError.none(),
    );

    try {

      // 2. Benutzereingabe validieren
      if (formData.newPassword.isEmpty) {
        state = state.copyWith(status: MasterPasswordActionStatus.failure, error: AppError(ErrorCode.valueRequired, field: 'newPassword'));
        return;
      }

      // 3. Datenbank und Salt-Datei umbenennen, Session aktualisieren
      if (formData.newPassword != state.formData.password) {

        // 3.1 Kurze Pause für Lade-Indikator, bevor Argon2 blockiert
        await Future.delayed(const Duration(milliseconds: 50));

        // 3.2 MasterKey ableiten (Argon2id)
        if (_sessionService.settings == null) throw Exception('Die Einstellungen sind nicht in der Session abgelegt.');
        final salt = base64Decode(_sessionService.settings!.salt);
        masterKey = await _cryptoService.deriveKey(formData.password, salt);

        // 3.3. Passwort validieren
        try {
          await _cryptoService.decrypt(_sessionService.settings!.encryptedPrivateKey, masterKey);
        } catch (_) {
          state = state.copyWith(status: MasterPasswordActionStatus.failure, error: AppError(ErrorCode.wrongPassword, field: 'password'));
          return;
        }

        // 3.4. Physisches Datenbank-Backup erstellen
        await _databaseService.createBackup();

        try {
          // --- Start Kritische Logik ---

          // 3.5. Neues Salt generieren, neuen Master-Key ableiten und damit den Private-Key neu verschlüsseln
          final newSalt = _cryptoService.generateSalt(); // todo erhöht ein neuer Salt die Sicherheit? salt ist ja kein Geheimnis. wenn nicht, brauchen webservice.changePassword kein salt-Parameter
          newMasterKey = await _cryptoService.deriveKey(formData.newPassword, newSalt);
          final newEncryptedPrivKey = await _cryptoService.encrypt(_sessionService.privateKey!, newMasterKey);

          // 3.6. Datenbankdatei mit dem neuen Master-Key umschlüsseln
          await _databaseService.rekey(newMasterKey);

          // 3.7. Salt-Datei aktualisieren
          await _databaseService.saveSalt(_sessionService.vaultName, newSalt);

          // 3.8. Master-Key im SecureStore aktualisieren
          if (_sessionService.settings!.useBiometric) {
            await _biometricService.saveMasterKey(_sessionService.vaultName, newMasterKey);
          }

          // 3.9. Datenbank und Session aktualisieren
          final updatedSettings = _sessionService.settings!.copyWith(
            salt: base64Encode(newSalt),
            encryptedPrivateKey: newEncryptedPrivKey,
            masterKeyTimestamp: DateTime.now().toUtc(),
          );
          final settings = await _databaseService.saveSettings(updatedSettings);
          _sessionService.setSettings(settings);

          // --- Ende Kritische Logik ---

          // 3.10. Erfolg: Backup löschen
          await _databaseService.removeBackup();

        } catch (_) {
          // Fehler während der Operation -> Rollback
          try {
            await _databaseService.close();
            await _databaseService.restoreBackup();
            await _databaseService.initialize(_sessionService.vaultName, masterKey);
          } catch (_) {}
          rethrow;
        }
      }

      // 5. State aktualisieren
      state = state.copyWith(
        formData: MasterPasswordFormData(), // Passwortfelder leeren
        status: MasterPasswordActionStatus.saved,
      );

    } catch (e, st) {
      Logger().fatal("Fehler beim Speichern: $e", stack: st);
      state = state.copyWith(status: MasterPasswordActionStatus.failure, error: AppError(ErrorCode.unknown));

    } finally {
      // Master-Key aus dem RAM löschen
      if (masterKey != null) _cryptoService.wipeKey(masterKey);
      if (newMasterKey != null) _cryptoService.wipeKey(newMasterKey);
    }
  }

  // ------------------------------------------------------------------------
  // --- Setter für den UI-State (synchron) ---
  // ------------------------------------------------------------------------

  /// Setter für neues Passwort
  void setNewPassword(String value) {
    final error = state.error.field == 'newPassword' ? AppError.none() : null;
    final formData = state.formData.copyWith(newPassword: value);
    state = state.copyWith(
      formData: formData,
      passwordStrength: _passwordService.estimateStrength(value),
      error: error,
    );
  }

  /// Setter für bisheriges Passwort
  void setPassword(String value) {
    final error = state.error.field == 'password' ? AppError.none() : null;
    final formData = state.formData.copyWith(password: value);
    state = state.copyWith(formData: formData, error: error);
  }
}
