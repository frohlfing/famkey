import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/features/settings/vault_name/vault_name_form_data.dart';
import 'package:privault/features/settings/vault_name/vault_name_state.dart';
import 'package:privault/services/biometric_service.dart';
import 'package:privault/services/config_service.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';

final vaultNameProvider = NotifierProvider<VaultNameNotifier, VaultNameState>(() {
  return VaultNameNotifier();
});

class VaultNameNotifier extends Notifier<VaultNameState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

  late final BiometricService _biometricService;
  late final ConfigService _configService;
  late final CryptoService _cryptoService;
  late final DatabaseService _databaseService;
  late final SessionService _sessionService;

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert einen Notifier.
  ///
  /// Die Verwendung von `Ref.watch` oder `Ref.listen` innerhalb dieser Methode ist unbedenklich.
  /// Ändert sich eine Abhängigkeit dieses Notifiers (bei Verwendung von `Ref.watch`), wird der Build-Prozess erneut ausgeführt. Der Notifier selbst wird jedoch nicht neu erstellt. Seine Instanz bleibt zwischen den Build-Ausführungen erhalten.
  @override
  VaultNameState build() {
    // Dienste aus getIt holen
    _biometricService = getIt<BiometricService>();
    _configService = getIt<ConfigService>();
    _cryptoService = getIt<CryptoService>();
    _databaseService = getIt<DatabaseService>();
    _sessionService = getIt<SessionService>();

    // Initialer State
    return VaultNameState();
  }

  /// Lädt die Daten für die Anzeige.
  Future<void> load() async {
    if (state.isBusy) return;

    // UI-State zurücksetzen
    final formData = VaultNameFormData(vaultName: _sessionService.vaultName);
    state = const VaultNameState().copyWith(
      formData: formData,
      originalFormData: formData,
      status: VaultNameActionStatus.loaded,
    );
  }

  // ------------------------------------------------------------------------
  // --- Speichern ---
  // ------------------------------------------------------------------------

  /// Benennt den Tresor um.
  Future<void> save() async {
    if (state.isBusy) return;
    Uint8List? masterKey;

    // 1. Benutzereingabe bereinigen
    var formData = state.formData;
    formData = formData.copyWith(
      // Ungültige Zeichen für Dateinamen entfernen
      vaultName: formData.vaultName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim(),
    );

    // 2. UI-State aktualisieren
    state = state.copyWith(
      formData: formData,
      status: VaultNameActionStatus.progress, error: AppError.none(),
    );

    try {

      // 3. Benutzereingabe validieren
      if (formData.vaultName.isEmpty) {
        state = state.copyWith(status: VaultNameActionStatus.failure, error: AppError(ErrorCode.valueRequired, field: 'vaultName'));
        return;
      }

      // 4. Datenbank und Salt-Datei umbenennen, Session aktualisieren
      if (formData != state.originalFormData) {

        // 4.1 Sicherstellen, dass die Datenbank noch nicht existiert
        if (await _databaseService.databaseExists(formData.vaultName)) {
          state = state.copyWith(status: VaultNameActionStatus.failure, error: AppError(ErrorCode.vaultAlreadyExists, field: 'vaultName'));
          return;
        }

        // 4.2 Kurze Pause für Lade-Indikator, bevor Argon2 blockiert
        await Future.delayed(const Duration(milliseconds: 50));

        // 4.3 MasterKey ableiten (Argon2id)
        if (_sessionService.settings == null) throw Exception('Die Einstellungen sind nicht in der Session abgelegt.');
        final salt = base64Decode(_sessionService.settings!.salt);
        masterKey = await _cryptoService.deriveKey(formData.password, salt);

        // 4.4 Passwort validieren
        try {
          await _cryptoService.decrypt(_sessionService.settings!.encryptedPrivateKey, masterKey);
        } catch (_) {
          state = state.copyWith(status: VaultNameActionStatus.failure, error: AppError(ErrorCode.wrongPassword, field: 'password'));
          return;
        }

        // 4.5. Physisches Datenbank-Backup erstellen
        await _databaseService.createBackup();
        try {
          // --- Start Kritische Logik ---

          // 4.6. Verbindung trennen & Umbenennen
          await _databaseService.close();
          await _databaseService.renameDatabaseAndSaltFile(state.originalFormData.vaultName, formData.vaultName);

          // 4.7. Konfiguration (Login-Liste / Config) aktualisieren
          if (_configService.lastVaultName == state.originalFormData.vaultName) {
            _configService.lastVaultName = formData.vaultName;
          }

          // 4.8. Neue Verbindung zur umbenannten Datei herstellen
          await _databaseService.initialize(formData.vaultName, masterKey);

          // 4.9. Master-Key im SecureStore umziehen
          if (await _biometricService.containsMasterKey(state.originalFormData.vaultName)) {
            await _biometricService.removeMasterKey(state.originalFormData.vaultName);
            if (_sessionService.settings!.useBiometric) {
              await _biometricService.saveMasterKey(formData.vaultName, masterKey);
            }
          }

          // 4.10. Session aktualisieren
          _sessionService.setVaultName(formData.vaultName);

          // --- Ende Kritische Logik ---

          // 4.11 Erfolg: Backup löschen
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
        originalFormData: formData,
        status: VaultNameActionStatus.saved,
      );

    } catch (e, st) {
      Logger().fatal("Fehler beim Speichern: $e", stack: st);
      state = state.copyWith(status: VaultNameActionStatus.failure, error: AppError(ErrorCode.unknown));

    } finally {
      // Master-Key aus dem RAM löschen
      if (masterKey != null) _cryptoService.wipeKey(masterKey);
    }
  }

  // ------------------------------------------------------------------------
  // --- Setter für den UI-State (synchron) ---
  // ------------------------------------------------------------------------

  /// Setter für Tresorname
  void setVaultName(String value) {
    final error = state.error.field == 'vaultName' ? AppError.none() : null;
    final formData = state.formData.copyWith(
        // Ungültige Zeichen für Dateinamen entfernen
        vaultName: value.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim(),
    );
    state = state.copyWith(formData: formData, error: error);
  }

  /// Setter für Passwort
  void setPassword(String value) {
    final error = state.error.field == 'password' ? AppError.none() : null;
    final formData = state.formData.copyWith(password: value);
    state = state.copyWith(formData: formData, error: error);
  }
}
