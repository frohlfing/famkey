import 'dart:convert';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/main/adopt_identity/adopt_identity_state.dart';
import 'package:privault/features/main/adopt_identity/user_identity.dart';
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

    var password = state.password;

    // 1. UI-State aktualisieren
    state = state.copyWith(
      password: password,
      status: AdoptIdentityActionStatus.progress, error: AppError.none(),
    );

    try {

      // 2. Benutzereingabe validieren
      if (password.isEmpty) {
        state = state.copyWith(status: AdoptIdentityActionStatus.failure, error: AppError(ErrorCode.valueRequired, field: 'password'));
        return;
      }

      // 4. MasterKey ableiten (Argon2id)
      if (_sessionService.settings == null) throw Exception('Die Einstellungen sind nicht in der Session abgelegt.');
      if (_sessionService.settings!.salt.isEmpty) throw Exception("Das Salt liegt nicht in der Session.");
      await Future.delayed(const Duration(milliseconds: 50)); // Kurze Pause für Lade-Indikator, bevor Argon2 blockiert
      final salt = base64Decode(_sessionService.settings!.salt);
      masterKey = await _cryptoService.deriveKey(password, salt);

      // 5. Passwort validieren
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
        newMasterKey = await _cryptoService.deriveKey(password, newSalt);

        // 8. Private-Key der neune Identität entschlüsseln
        final newPrivateKey = await _cryptoService.decrypt(_userIdentity!.encryptedPrivateKey, newMasterKey);

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
                final entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, utf8.decode(_sessionService.privateKey!));
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
        _sessionService.setPrivateKey(newPrivateKey);
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
        password: '', // Passwortfeld leeren
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

  /// Setter für bisheriges Passwort
  void setPassword(String value) {
    final error = state.error.field == 'password' ? AppError.none() : null;
    state = state.copyWith(password: value, error: error);
  }
}
