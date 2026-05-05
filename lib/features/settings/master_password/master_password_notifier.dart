import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famkey/core/app_error.dart';
import 'package:famkey/core/logger.dart';
import 'package:famkey/core/service_locator.dart';
import 'package:famkey/database/database.dart';
import 'package:famkey/features/settings/master_password/master_password_form_data.dart';
import 'package:famkey/features/settings/master_password/master_password_state.dart';
import 'package:dio/dio.dart';
import 'package:famkey/services/biometric_service.dart';
import 'package:famkey/services/crypto_service.dart';
import 'package:famkey/services/database_service.dart';
import 'package:famkey/services/password_service.dart';
import 'package:famkey/services/session_service.dart';
import 'package:famkey/services/web_service.dart';

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
  late final WebService _webService;

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
    _webService = getIt<WebService>();

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

  /// Ändert das Master-Passwort und führt optional eine RSA-Schlüsselpaar-Rotation (Notfall-Reset) durch.
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

      final passwordChanged = formData.newPassword != formData.password;

      // 3. Noop wenn weder Passwort noch Schlüsselpaar geändert werden soll
      if (!passwordChanged && !formData.regenerateKeyPair) {
        state = state.copyWith(formData: MasterPasswordFormData(), status: MasterPasswordActionStatus.saved);
        return;
      }

      // 3a. Notfall-Reset erfordert zwingend ein neues Master-Passwort
      if (formData.regenerateKeyPair && !passwordChanged) {
        state = state.copyWith(status: MasterPasswordActionStatus.failure, error: AppError(ErrorCode.equalPassword, text: 'Für den Notfall-Reset ist ein neues Master-Passwort erforderlich.'));
        return;
      }

      // 4. Kurze Pause für Lade-Indikator, dann bisherigen Master-Key ableiten (Argon2id)
      await Future.delayed(const Duration(milliseconds: 50));
      if (_sessionService.settings == null) throw Exception('Die Einstellungen sind nicht in der Session abgelegt.');
      final currentSaltBytes = base64Decode(_sessionService.settings!.salt);
      masterKey = await _cryptoService.deriveKey(formData.password, currentSaltBytes);

      // 5. Passwort verifizieren
      try {
        await _cryptoService.decrypt(_sessionService.settings!.encryptedPrivateKey, masterKey);
      } catch (_) {
        state = state.copyWith(status: MasterPasswordActionStatus.failure, error: AppError(ErrorCode.wrongPassword, field: 'password'));
        return;
      }

      // 5a. Server-Erreichbarkeit vorab prüfen (nur bei RSA-Rotation erforderlich).
      // Die Rotation muss zwingend mit dem Server-Update abgeschlossen werden,
      // da AuthMiddleware sonst gegen den alten Public Key prüft und alle Requests scheitern.
      if (formData.regenerateKeyPair) {
        try {
          await _webService.getServerVersion();
        } on DioException catch (de) {
          state = state.copyWith(status: MasterPasswordActionStatus.failure, error: WebService.convertDioError(de));
          return;
        }
      }

      // 6. Physisches Datenbank-Backup erstellen
      await _databaseService.createBackup();

      try {
        // --- Start Kritische Logik ---

        // 7. Salt + Master-Key bestimmen
        final Uint8List newSalt;
        if (passwordChanged) {
          newSalt = _cryptoService.generateSalt();
          newMasterKey = await _cryptoService.deriveKey(formData.newPassword, newSalt);
        } else {
          // Kein Passwortwechsel: bestehenden Salt + Key wiederverwenden
          newSalt = currentSaltBytes;
          newMasterKey = masterKey;
          masterKey = null; // Verhindert doppeltes Löschen in finally (selbes Array)
        }

        // 8. Neues RSA-Schlüsselpaar generieren (falls Notfall-Reset aktiviert)
        String? newPublicKey;
        Uint8List? newPrivateKeyBytes;
        if (formData.regenerateKeyPair) {
          (newPublicKey, newPrivateKeyBytes) = await _cryptoService.generateRsaKeyPair();
        }
        final privateKeyToEncrypt = newPrivateKeyBytes ?? _sessionService.privateKey!;

        // 9. Private-Key (neu oder bestehend) mit dem (neuen) Master-Key verschlüsseln
        final newEncryptedPrivKey = await _cryptoService.encrypt(privateKeyToEncrypt, newMasterKey);

        // 10. Datenbankdatei mit dem neuen Master-Key umschlüsseln (nur bei Passwortwechsel)
        if (passwordChanged) {
          await _databaseService.rekey(newMasterKey);
        }

        // 11. Salt-Datei aktualisieren (nur bei Passwortwechsel)
        if (passwordChanged) {
          await _databaseService.saveSalt(_sessionService.vaultName, newSalt);
        }

        // 12. Master-Key im SecureStore aktualisieren (nur bei Passwortwechsel mit Biometrie)
        if (passwordChanged && _sessionService.settings!.useBiometric) {
          await _biometricService.saveMasterKey(_sessionService.vaultName, newMasterKey);
        }

        // 13. Schlüsselpaar-Rotation: alle Permissions und encryptedIndex-Felder umschlüsseln
        if (formData.regenerateKeyPair && newPrivateKeyBytes != null && newPublicKey != null) {

          // 13a. Permissions mit dem neuen Public-Key verschlüsseln
          final allPermissions = await _databaseService.getPermissions();
          final updatedPermissions = <PermissionEntity>[];
          for (final perm in allPermissions) {
            if (perm.encryptedKey.isNotEmpty) {
              try {
                final entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, _sessionService.privateKey!);
                final newEncryptedKey = await _cryptoService.encryptRsa(entryKey, newPublicKey);
                updatedPermissions.add(perm.copyWith(encryptedKey: newEncryptedKey));
              } catch (e) {
                throw Exception('Fehler beim Umschlüsseln der Permission ${perm.id}: $e');
              }
            }
          }
          if (updatedPermissions.isNotEmpty) {
            await _databaseService.updatePermissions(updatedPermissions);
          }

          // 13b. encryptedIndex-Felder mit dem neuen indexKey neu verschlüsseln
          final oldIndexKey = _sessionService.indexKey!;
          final newIndexKey = await _cryptoService.deriveKeyFromKey(newPrivateKeyBytes, null, 'entry-index-encryption');
          try {
            final allEntries = await _databaseService.getEntries();
            for (final entry in allEntries) {
              if (entry.encryptedIndex.isEmpty) continue;
              try {
                final decrypted = await _cryptoService.decrypt(entry.encryptedIndex, oldIndexKey);
                final reEncrypted = await _cryptoService.encrypt(decrypted, newIndexKey);
                await _databaseService.saveEntry(entry.copyWith(encryptedIndex: reEncrypted));
              } catch (e) {
                throw Exception('Fehler beim Verschlüsseln des Indexes für Eintrag ${entry.id}: $e');
              }
            }
          } finally {
            _cryptoService.wipeKey(newIndexKey);
          }

          // 13c. User in der Datenbank mit dem neuen Public-Key aktualisieren
          if (_sessionService.user == null) throw Exception('Der Benutzer liegt nicht in der Session.');
          final updatedUser = _sessionService.user!.copyWith(publicKey: newPublicKey);
          final savedUser = await _databaseService.saveUser(updatedUser);
          _sessionService.setUser(savedUser);

          // 13d. Session: neuen Private-Key setzen (aktualisiert auch den abgeleiteten indexKey)
          await _sessionService.setPrivateKey(newPrivateKeyBytes);
        }

        // 14. Datenbank und Session aktualisieren
        final updatedSettings = _sessionService.settings!.copyWith(
          salt: base64Encode(newSalt),
          encryptedPrivateKey: newEncryptedPrivKey,
          masterKeyTimestamp: DateTime.now().toUtc(),
        );
        final settings = await _databaseService.saveSettings(updatedSettings);
        _sessionService.setSettings(settings);

        // --- Ende Kritische Logik ---

        // 15. RSA-Rotation: neuen Public Key sofort zum Sync-Server übertragen.
        // Der WebService signiert noch mit dem alten Private Key – gewollt: der Server
        // validiert damit gegen den alten Public Key und speichert erst dann den neuen.
        // (Reine Passwortänderungen werden beim nächsten Sync automatisch nachgeholt.)
        if (formData.regenerateKeyPair && _sessionService.user != null) {
          await _webService.changePassword(
            _sessionService.user!.uuid,
            base64Encode(newSalt),
            _sessionService.user!.publicKey, // bereits der neue Key (Schritt 13c)
            newEncryptedPrivKey,
            settings.masterKeyTimestamp,
          );
          _webService.setSignatureData(userUuid: _sessionService.user!.uuid, privateKey: newPrivateKeyBytes!);
        }

        // 16. Erfolg: Backup löschen
        await _databaseService.removeBackup();

      } catch (_) {
        // Fehler während der Operation -> Rollback
        try {
          await _databaseService.close();
          await _databaseService.restoreBackup();
          await _databaseService.initialize(_sessionService.vaultName, masterKey!);
        } catch (_) {}
        rethrow;
      }

      // 17. State aktualisieren
      state = state.copyWith(
        formData: MasterPasswordFormData(), // Felder leeren
        status: MasterPasswordActionStatus.saved,
      );

    } catch (e, st) {
      log.fatal('Fehler beim Speichern: $e', stack: st);
      state = state.copyWith(status: MasterPasswordActionStatus.failure, error: AppError(ErrorCode.unknown));

    } finally {
      // Master-Keys aus dem RAM löschen
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

  /// Setter für Schlüsselpaar-Rotation
  void setRegenerateKeyPair(bool value) {
    final formData = state.formData.copyWith(regenerateKeyPair: value);
    state = state.copyWith(formData: formData);
  }
}
