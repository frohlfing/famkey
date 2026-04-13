import 'dart:convert';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/main/sync/adopt_identity/adopt_identity_form_data.dart';
import 'package:privault/features/main/sync/adopt_identity/adopt_identity_state.dart';
import 'package:privault/features/main/sync/adopt_identity/user_identity.dart';
import 'package:privault/services/biometric_service.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';

final adoptIdentityProvider = NotifierProvider<AdoptIdentityNotifier, AdoptIdentityState>(() {
  return AdoptIdentityNotifier();
});

class AdoptIdentityNotifier extends Notifier<AdoptIdentityState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

  late final BiometricService _biometricService;
  late final CryptoService _cryptoService;
  late final DatabaseService _databaseService;
  late final SessionService _sessionService;

  // ------------------------------------------------------------------------
  // --- Interne Variablen (nicht reaktiv, nicht UI‑relevant) ---
  // ------------------------------------------------------------------------

  /// Die neue Benutzeridentität
  UserIdentity? _userIdentity;

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert einen Notifier.
  ///
  /// Die Verwendung von `Ref.watch` oder `Ref.listen` innerhalb dieser Methode ist unbedenklich.
  /// Ändert sich eine Abhängigkeit dieses Notifiers (bei Verwendung von `Ref.watch`), wird der Build-Prozess erneut ausgeführt. Der Notifier selbst wird jedoch nicht neu erstellt. Seine Instanz bleibt zwischen den Build-Ausführungen erhalten.
  @override
  AdoptIdentityState build() {
    // Dienste aus getIt holen
    _biometricService = getIt<BiometricService>();
    _cryptoService = getIt<CryptoService>();
    _databaseService = getIt<DatabaseService>();
    _sessionService = getIt<SessionService>();

    // Initialer State
    return AdoptIdentityState();
  }

  /// Lädt die Daten für die Anzeige.
  Future<void> load(UserIdentity userIdentity) async {
    if (state.isBusy) return;

    _userIdentity = userIdentity;

    if (_sessionService.user == null) throw Exception("Der Benutzer liegt nicht in der Session.");
    final isOnboarding = userIdentity.userUuid != _sessionService.user!.uuid;

    // UI-State zurücksetzen
    state = const AdoptIdentityState().copyWith(isOnboarding: isOnboarding);
  }

  // ------------------------------------------------------------------------
  // --- Speichern ---
  // ------------------------------------------------------------------------

  /// Übernimmt eine neue Identität vom Server.
  ///
  /// Führt eine Umschlüsselung aller vorhandenen Berechtigungen durch, verschlüsselt die sqLite-Datei mit dem
  /// neuen Master-Schlüssel und aktualisiert die Salt-Datei.
  /// [userIdentity] ist die neue Identität.
  Future<void> save() async {
    if (state.isBusy) return;
    Uint8List? masterKey; // bisheriger Master-Key
    Uint8List? newMasterKey; // Master-Key der neuen Identität

    var formData = state.formData;

    // 1. UI-State aktualisieren
    state = state.copyWith(
      formData: formData,
      status: AdoptIdentityActionStatus.progress, error: AppError.none(),
    );

    try {

      // 2. Benutzereingabe validieren
      if (formData.newPassword.isEmpty) {
        state = state.copyWith(status: AdoptIdentityActionStatus.failure, error: AppError(ErrorCode.valueRequired, field: 'newPassword'));
        return;
      }
      if (formData.password.isEmpty) {
        state = state.copyWith(status: AdoptIdentityActionStatus.failure, error: AppError(ErrorCode.valueRequired, field: 'password'));
        return;
      }

      // 4. Master-Key vom lokalen Salt ableiten (Argon2id)
      if (_sessionService.settings == null) throw Exception('Die Einstellungen sind nicht in der Session abgelegt.');
      if (_sessionService.settings!.salt.isEmpty) throw Exception("Das Salt liegt nicht in der Session.");
      await Future.delayed(const Duration(milliseconds: 50)); // Kurze Pause für Lade-Indikator, bevor Argon2 blockiert
      final salt = base64Decode(_sessionService.settings!.salt);
      masterKey = await _cryptoService.deriveKey(formData.password, salt);

      // 5. Master-Passwort validieren (muss zum lokalen Tresor passen)
      if (_sessionService.settings!.encryptedPrivateKey.isEmpty) throw Exception("`encryptedPrivateKey` ist in der Session leer.");
      try {
        await _cryptoService.decrypt(_sessionService.settings!.encryptedPrivateKey, masterKey);
      } catch (_) {
        state = state.copyWith(status: AdoptIdentityActionStatus.failure, error: AppError(ErrorCode.wrongPassword, field: 'password'));
        return;
      }

      // 6. Physisches Datenbank-Backup erstellen
      await _databaseService.createBackup();

      try {
        // --- Start Kritische Logik ---

        // 7. Neuen Master-Key mit dem Salt der neuen Identität berechnen
        if (_userIdentity == null || _userIdentity!.userUuid.isEmpty) throw Exception('Keine Benutzeridentität zum adoptieren geladen.');
        final newSalt = base64Decode(_userIdentity!.salt);
        newMasterKey = await _cryptoService.deriveKey(formData.newPassword, newSalt);

        // 8. Private-Key der neuen Identität entschlüsseln
        Uint8List newPrivateKey;
        try {
          newPrivateKey = await _cryptoService.decrypt(_userIdentity!.encryptedPrivateKey, newMasterKey);
        } catch (_) {
          state = state.copyWith(status: AdoptIdentityActionStatus.failure, error: AppError(ErrorCode.wrongPassword, text: 'Der Tresor auf dem Server ist mit einem anderen Master-Passwort verschlüsselt.'));
          return;
        }

        // 9. Falls sich das RSA-Schlüsselpaar geändert hat: Alle Permissions umschlüsseln
        if (_sessionService.privateKey == null) throw Exception("Der privater Schlüssel ist nicht entpackt.");
        final rsaKeyChanged = !const ListEquality().equals(_sessionService.privateKey, newPrivateKey);
        if (rsaKeyChanged) {
          final allPermissions = await _databaseService.getPermissions();
          final updatedPermissions = <PermissionEntity>[];
          for (var perm in allPermissions) {
            if (perm.encryptedKey.isNotEmpty && _sessionService.privateKey != null) {
              try {
                // Entschlüsseln mit altem (aktuellem) Private-Key, verschlüsseln mit dem Public-Key der neuen Identität
                final entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, _sessionService.privateKey!);
                final newEncryptedKey = await _cryptoService.encryptRsa(entryKey, _userIdentity!.publicKey);
                updatedPermissions.add(perm.copyWith(encryptedKey: newEncryptedKey));
              } catch (e) {
                throw Exception("Fehler beim Umschlüsseln der Permission ${perm.id}: $e");
              }
            }
          }
          if (updatedPermissions.isNotEmpty) {
            await _databaseService.updatePermissions(updatedPermissions);
          }

          // 9b. encryptedIndex-Felder mit dem neuen indexKey neu verschlüsseln
          final oldIndexKey = _sessionService.indexKey!;
          final newIndexKey = await _cryptoService.deriveKeyFromKey(newPrivateKey, null, 'entry-index-encryption');
          try {
            final allEntries = await _databaseService.getEntries();
            for (var entry in allEntries) {
              if (entry.encryptedIndex.isEmpty) continue;
              try {
                final decrypted = await _cryptoService.decrypt(entry.encryptedIndex, oldIndexKey);
                final reEncrypted = await _cryptoService.encrypt(decrypted, newIndexKey);
                await _databaseService.saveEntry(entry.copyWith(encryptedIndex: reEncrypted));
              } catch (e) {
                throw Exception("Fehler beim verschlüsseln des Indexes für Eintrag ${entry.id}: $e");
              }
            }
          } finally {
            _cryptoService.wipeKey(newIndexKey);
          }
        }

        // 10. Datenbankdatei mit dem neuen Master-Key umschlüsseln
        await _databaseService.rekey(newMasterKey);

        // 11. Salt-Datei aktualisieren
        await _databaseService.saveSalt(_sessionService.vaultName, newSalt);

        // 12. Master-Key im SecureStore aktualisieren
        if (_sessionService.settings!.useBiometric) {
          await _biometricService.saveMasterKey(_sessionService.vaultName, newMasterKey);
        }

        // 13. User-UUID übernehmen, falls geändert
        if (_sessionService.user == null) throw Exception("Der Benutzer liegt nicht in der Session.");
        UserEntity user = _sessionService.user!;
        if (user.uuid != _userIdentity!.userUuid) {
          // Wenn ein Zweitgerät das erste mal synchronisiert wird, muss auch die UUID des Benutzers übernommen werden.
          user = user.copyWith(uuid: _userIdentity!.userUuid);
          user = await _databaseService.saveUser(user);
        }

        // 14. Settings aktualisieren
        final settings = _sessionService.settings!.copyWith(
          salt: base64Encode(newSalt),
          encryptedPrivateKey: _userIdentity!.encryptedPrivateKey,
        );
        await _databaseService.saveSettings(settings);

        // 15. Session aktualisieren
        _sessionService.setUser(user);
        await _sessionService.setPrivateKey(newPrivateKey);
        _sessionService.setSettings(settings);

        // --- Ende Kritische Logik ---

        // 16. Erfolg: Backup löschen
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

      // 17. State aktualisieren
      state = state.copyWith(
        formData: AdoptIdentityFormData(), // Passwortfelder leeren
        status: AdoptIdentityActionStatus.saved,
      );

    } catch (e, st) {
      Logger().fatal("Fehler bei der Identitätsübernahme: $e", stack: st);
      state = state.copyWith(status: AdoptIdentityActionStatus.failure, error: AppError(ErrorCode.unknown));

    } finally {
      // Master-Key aus dem RAM löschen
      if (masterKey != null) _cryptoService.wipeKey(masterKey);
      if (newMasterKey != null) _cryptoService.wipeKey(newMasterKey);
    }
  }

  // ------------------------------------------------------------------------
  // --- Setter für den UI-State (synchron) ---
  // ------------------------------------------------------------------------

  /// Setter für "serverseitiges" Passwort
  void setNewPassword(String value) {
    final error = state.error.field == 'newPassword' ? AppError.none() : null;
    final formData = state.formData.copyWith(newPassword: value);
    state = state.copyWith(formData: formData, error: error);
  }

  /// Setter für lokales Passwort
  void setPassword(String value) {
    final error = state.error.field == 'password' ? AppError.none() : null;
    final formData = state.formData.copyWith(password: value);
    state = state.copyWith(formData: formData, error: error);
  }
}
