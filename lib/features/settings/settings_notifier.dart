import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/env.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/settings/settings_state.dart';
import 'package:privault/services/auto_lock_service.dart';
import 'package:privault/services/autofill_service.dart';
import 'package:privault/services/biometric_service.dart';
import 'package:privault/services/clipboard_service.dart';
import 'package:privault/services/config_service.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/system_settings_service.dart';
import 'package:privault/services/session_service.dart';
import 'package:privault/services/web_service.dart';

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});

class SettingsNotifier extends Notifier<SettingsState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

  late final AutoLockService _autoLockService;
  late final AutofillService _autofillService;
  late final BiometricService _biometricService;
  late final ClipboardService _clipboardService;
  late final ConfigService _configService;
  late final CryptoService _cryptoService;
  late final DatabaseService _databaseService;
  late final SessionService _sessionService;
  late final SystemSettingsService _systemSettingsService;
  late final WebService _webService;

  // ------------------------------------------------------------------------
  // --- Interne Variablen (nicht reaktiv, nicht UI‑relevant) ---
  // ------------------------------------------------------------------------

  /// Die Datenbank-Entität.
  SettingsEntity? _settings;

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert einen Notifier.
  ///
  /// Die Verwendung von `Ref.watch` oder `Ref.listen` innerhalb dieser Methode ist unbedenklich.
  /// Ändert sich eine Abhängigkeit dieses Notifiers (bei Verwendung von `Ref.watch`), wird der Build-Prozess erneut ausgeführt. Der Notifier selbst wird jedoch nicht neu erstellt. Seine Instanz bleibt zwischen den Build-Ausführungen erhalten.
  @override
  SettingsState build() {
    // Dienste aus getIt holen
    _autoLockService = getIt<AutoLockService>();
    _autofillService = getIt<AutofillService>();
    _biometricService = getIt<BiometricService>();
    _clipboardService = getIt<ClipboardService>();
    _configService = getIt<ConfigService>();
    _cryptoService = getIt<CryptoService>();
    _databaseService = getIt<DatabaseService>();
    _sessionService = getIt<SessionService>();
    _systemSettingsService = getIt<SystemSettingsService>();
    _webService = getIt<WebService>();

    // Initialer State
    return SettingsState().copyWith(
      canOpenAppSettings: _systemSettingsService.canOpenAppSettings,
      canOpenBiometricSettings: _systemSettingsService.canOpenBiometricSettings,
      canOpenAutofillSettings: _systemSettingsService.canOpenAutofillSettings,
    );
  }

  /// Lädt die Daten für die Anzeige.
  Future<void> load() async {
    if (state.isBusy) return;

    // UI-State zurücksetzen
    state = state.copyWith(status: SettingsActionStatus.progress, error: AppError.none());

    try {
      // Einstellungen aus der Datenbank laden
      _settings = await _databaseService.getSettings();
      if (_settings == null) throw Exception('Die Einstellungen sind nicht in der Datenbank hinterlegt.'); // wird bereits direkt nach dem Login angelegt

      // Freundesliste laden
      final friends = await _databaseService.getNotHiddenFriends();
      final fingerprints = _getFingerprints(friends);
      final friendNeedsRekeying = await _getFriendNeedsRekeying(friends);

      // Autofill-Status abfragen (Android: Systemzustand via MethodChannel)
      final isAutofillEnabled = await _autofillService.isAutofillEnabled();

      // UI-State aktualisieren
      state = state.copyWith(
        vaultStoragePath: env.vaultStoragePath,
        vaultName: _sessionService.vaultName,
        useBiometric: _settings!.useBiometric,
        userName: _sessionService.user?.name ?? '',
        isRegistered: _settings!.lastSyncAt.year > 1970,
        host: _settings!.host,
        pwLength: _settings!.pwLength,
        pwSpecialChars: _settings!.pwSpecialChars,
        pwAvoidIlO0: _settings!.pwAvoidIlO0,
        friends: friends,
        fingerprints: fingerprints,
        friendNeedsRekeying: friendNeedsRekeying,
        themeMode: _configService.themeMode,
        categoryPlaceholder: _settings!.categoryPlaceholder,
        autofillEnabled: _configService.autofillEnabled,
        isAutofillEnabled: isAutofillEnabled,
        autofillRelockAfterFill: _configService.autofillRelockAfterFill,
        autofillHotkey: _configService.autofillHotkey,
        autoLockMinutes: _configService.autoLockMinutes,
        clipboardClearSeconds: _configService.clipboardClearSeconds,
        logLevel: _configService.logLevel,
        logDays: _configService.logDays,
        status: SettingsActionStatus.loaded,
      );

    } catch (e, st) {
      Logger().fatal('Fehler beim Laden: $e', stack: st);
      state = state.copyWith(status: SettingsActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Tresor löschen ---
  // ------------------------------------------------------------------------

  /// Löscht den Tresor nur lokal vom Gerät.
  /// Die Daten auf dem Server bleiben erhalten.
  Future<void> deleteVaultLocal() async {
    if (state.isBusy) return;

    // 1. UI-State aktualisieren
    state = state.copyWith(status: SettingsActionStatus.progress, error: AppError.none());

    try {

      // 2. Datenbank löschen
      await _databaseService.deleteCurrentDatabaseAndSaltFile();

      // 3. SecureStore leeren
      await _biometricService.removeMasterKey(_sessionService.vaultName);

      // 4. Konfiguration bereinigen
      if (_configService.lastVaultName == _sessionService.vaultName) {
        _configService.lastVaultName = '';
      }

      // 5. Session zurücksetzen
      _sessionService.clearSession();
      state = SettingsState().copyWith(status: SettingsActionStatus.deleted);
    } catch (e, st) {
      Logger().fatal('Fehler beim lokalen Löschen des Tresors: $e', stack: st);
      state = state.copyWith(status: SettingsActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  /// Löscht den Tresor nur auf dem Server.
  /// Die lokalen Daten bleiben erhalten. lastSyncAt wird zurückgesetzt,
  /// damit der nächste Sync den Tresor unter dem aktuellen Namen neu registriert.
  ///
  /// Falls der Benutzer der letzte im Tresor ist, wird der gesamte Tresor gelöscht.
  /// Andernfalls wird nur der eigene Benutzer-Datensatz entfernt.
  Future<void> deleteVaultServer() async {
    if (state.isBusy) return;
    state = state.copyWith(status: SettingsActionStatus.progress, error: AppError.none());
    try {
      if (_sessionService.user == null || _sessionService.settings == null) {
        throw Exception('Session nicht initialisiert.');
      }
      final settings = _sessionService.settings!;
      final user = _sessionService.user!;

      // WebService konfigurieren
      _webService.updateConfig(host: settings.host, apiToken: settings.apiToken);
      _webService.setSignatureData(userUuid: user.uuid, privateKey: _sessionService.privateKey!, publicKey: user.publicKey);

      // Tresor serverseitig löschen (Server entscheidet: letzter User → Tresor löschen, sonst nur User)
      await _webService.deleteVault(user.uuid);

      // lastSyncAt zurücksetzen → nächster Sync registriert Tresor unter aktuellem Namen neu
      if (_settings == null) throw Exception('Settings nicht geladen.');
      final updatedSettings = _settings!.copyWith(
        lastSyncAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
      _settings = await _databaseService.saveSettings(updatedSettings);
      _sessionService.setSettings(_settings!);

      state = state.copyWith(
        isRegistered: false,
        status: SettingsActionStatus.saved,
      );
    } on DioException catch (de) {
      final error = WebService.convertDioError(de);
      Logger().error(error.text);
      state = state.copyWith(status: SettingsActionStatus.failure, error: error);
    } catch (e, st) {
      Logger().fatal('Fehler beim serverseitigen Löschen des Tresors: $e', stack: st);
      state = state.copyWith(status: SettingsActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  /// Löscht den Tresor sowohl auf dem Server als auch lokal.
  Future<void> deleteVaultBoth() async {
    if (state.isBusy) return;
    state = state.copyWith(status: SettingsActionStatus.progress, error: AppError.none());
    try {
      if (_sessionService.user == null || _sessionService.settings == null) {
        throw Exception('Session nicht initialisiert.');
      }
      final settings = _sessionService.settings!;
      final user = _sessionService.user!;

      // WebService konfigurieren
      _webService.updateConfig(host: settings.host, apiToken: settings.apiToken);
      _webService.setSignatureData(userUuid: user.uuid, privateKey: _sessionService.privateKey!, publicKey: user.publicKey);

      // Tresor serverseitig löschen
      await _webService.deleteVault(user.uuid);

      // Lokal löschen
      await _databaseService.deleteCurrentDatabaseAndSaltFile();
      await _biometricService.removeMasterKey(_sessionService.vaultName);
      if (_configService.lastVaultName == _sessionService.vaultName) {
        _configService.lastVaultName = '';
      }
      _sessionService.clearSession();
      state = SettingsState().copyWith(status: SettingsActionStatus.deleted);
    } on DioException catch (de) {
      final error = WebService.convertDioError(de);
      Logger().error(error.text);
      state = state.copyWith(status: SettingsActionStatus.failure, error: error);
    } catch (e, st) {
      Logger().fatal('Fehler beim vollständigen Löschen des Tresors: $e', stack: st);
      state = state.copyWith(status: SettingsActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Biometrie aktivieren / deaktivieren ---
  // ------------------------------------------------------------------------

  /// Speichert die Biometrie-Einstellung.
  Future<void> saveBiometricSettings(bool useBiometric) async {
    if (state.isBusy) return;

    // 1. Ladeanzeige einblenden
    state = state.copyWith(status: SettingsActionStatus.progress, error: AppError.none());

    try {

      // 2. Benutzereingabe validieren
      if (useBiometric == state.useBiometric) {
        state = state.copyWith(status: SettingsActionStatus.failure, error: AppError(ErrorCode.valueNotChanged, field: 'useBiometric'));
        return;
      }

      if (_settings == null) throw Exception("Die Settings sind nicht geladen.");


      // 3. Falls Biometrie deaktiviert wurde, SecureStore leeren
      if (_settings!.useBiometric && !useBiometric) {
        await _biometricService.removeMasterKey(_sessionService.vaultName);
        Logger().info("Biometrie-Key entfernt, da Option deaktiviert wurde.");
      }

      // 4. Basiskonfiguration in der DB speichern.
      final updatedSettings = _settings!.copyWith(useBiometric: useBiometric);
      _settings = await _databaseService.saveSettings(updatedSettings);

      // 5. Session aktualisieren
      _sessionService.setSettings(_settings!);

      // 6. State aktualisieren
      state = state.copyWith(
        useBiometric: useBiometric,
        status: SettingsActionStatus.saved,
      );

    } catch (e, st) {
      Logger().fatal("Fehler beim Speichern: $e", stack: st);
      state = state.copyWith(status: SettingsActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Timeouts ---
  // ------------------------------------------------------------------------

  /// Speichert die Auto-Sperre-Einstellung (null = nie).
  void saveAutoLockMinutes(int? minutes) {
    if (state.isBusy) return;
    state = state.copyWith(status: SettingsActionStatus.progress, error: AppError.none());
    _configService.autoLockMinutes = minutes;
    _autoLockService.configure(minutes);
    state = state.copyWith(autoLockMinutes: minutes, status: SettingsActionStatus.saved);
  }

  /// Speichert die Zwischenablage-Timeout-Einstellung (null = nie).
  void saveClipboardClearSeconds(int? seconds) {
    if (state.isBusy) return;
    state = state.copyWith(status: SettingsActionStatus.progress, error: AppError.none());
    _configService.clipboardClearSeconds = seconds;
    state = state.copyWith(clipboardClearSeconds: seconds, status: SettingsActionStatus.saved);
  }

  /// Kopiert den Text in die Zwischenablage und startet den Clear-Timer.
  void copyToClipboard(String text) {
    _clipboardService.copy(text);
  }

  // ------------------------------------------------------------------------
  // --- Autofill ---
  // ------------------------------------------------------------------------

  /// Schaltet Autofill ein oder aus und speichert die Einstellung.
  void toggleAutofill(bool value) {
    state = state.copyWith(status: SettingsActionStatus.progress, error: AppError.none());
    _configService.autofillEnabled = value;
    state = state.copyWith(autofillEnabled: value, status: SettingsActionStatus.saved);
  }

  /// Aktualisiert den Android-Systemzustand von Autofill (nach Rückkehr aus Systemeinstellungen).
  Future<void> refreshAutofillStatus() async {
    state = state.copyWith(status: SettingsActionStatus.progress, error: AppError.none());
    final isEnabled = await _autofillService.isAutofillEnabled();
    state = state.copyWith(isAutofillEnabled: isEnabled, status: SettingsActionStatus.saved);
  }

  /// Speichert die Einstellung "Tresor nach Autofill wieder sperren" in der Konfiguration.
  void setAutofillRelockAfterFill(bool value) {
    state = state.copyWith(status: SettingsActionStatus.progress, error: AppError.none());
    _configService.autofillRelockAfterFill = value;
    state = state.copyWith(autofillRelockAfterFill: value, status: SettingsActionStatus.saved);
  }

  // ------------------------------------------------------------------------
  // --- Freunde verwalten ---
  // ------------------------------------------------------------------------

  /// Berechnet die SHA-256 Fingerprints der Freunde basierend auf dem PublicKey.
  /// Nutzt ein unsichtbares Leerzeichen (\u200B) nach den Doppelpunkten für bessere Zeilenumbrüche in der UI.
  Map<int, String> _getFingerprints(List<UserEntity> friends) {
    final map = <int, String>{};
    for (var f in friends) {
      map[f.id] = _cryptoService.fingerprint(f.publicKey).replaceAll(":", ":\u200B");
    }
    return map;
  }

  /// Ermittelt für jeden Freund, ob dieser Zugriff auf Einträge mit geleerten  Entry-Key hat.
  /// Zurückgegeben wird ein Mapping UserID -> true/false
  Future<Map<int, bool>> _getFriendNeedsRekeying(List<UserEntity> friends) async {
    final idsWithMissingKeys = await _databaseService.getUserIdsWithEmptyEntryKeys();
    final map = <int, bool>{};
    for (var f in friends) {
      map[f.id] = idsWithMissingKeys.contains(f.id);
    }
    return map;
  }

  /// Speichert den aktualisierten Verifizierungsstatus des Freundes.
  Future<void> toggleVerification(UserEntity friend) async {
    if (state.isBusy) return;
    final isVerified = !friend.isVerified;

    // 1. UI-State aktualisieren
    state = state.copyWith(
      status: SettingsActionStatus.progress, error: AppError.none(),
    );

    try {

      // 2. Wenn verifiziert wird, fehlende Entry-Keys generieren.
      if (isVerified) {
        await _rekeyEntriesForFriend(friend);
        if (state.friendNeedsRekeying[friend.id] == true) {
          final updatedNeedsRekeying = Map<int, bool>.from(state.friendNeedsRekeying); // Map kopieren, damit wir sie sicher bearbeiten können
          updatedNeedsRekeying[friend.id] = false;
          state = state.copyWith(friendNeedsRekeying: updatedNeedsRekeying);
        }
      }

      // 3. Änderung speichern
      final updatedUser = friend.copyWith(isVerified: isVerified, updatedAt: DateTime.now().toUtc());
      await _databaseService.saveUser(updatedUser);

      // 4. UI-State aktualisieren
      final friends = await _databaseService.getNotHiddenFriends();
      state = state.copyWith(
        friends: friends,
        status: SettingsActionStatus.friendVerified,
      );

    } catch (e, st) {
      Logger().fatal("Fehler beim Speichern der Verifizierung: $e", stack: st);
      state = state.copyWith(status: SettingsActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  /// Verschlüsselt alle Entry-Keys, die aufgrund eines Identitätswechsels geleert wurden.
  ///
  /// Diese Methode wird aufgerufen, wenn ein Freund verifiziert wird.
  Future<void> _rekeyEntriesForFriend(UserEntity friend) async {
    if (_sessionService.privateKey == null) throw Exception("PrivateKey nicht initialisiert.");

    // 1. Die geleerten Berechtigungen des Freundes laden
    final dirtyPermissions = await _databaseService.getPermissionsWithoutKeyByUserId(friend.id);

    for (var perm in dirtyPermissions) {
      // 2. Wir brauchen meine eigene Berechtigung für diesen Eintrag, um an den AES-Entry-Key zu kommen
      final myPerm = await _databaseService.getPermissionByEntryIdAndUserId(perm.entryId, 1); // 1 = Me
      if (myPerm == null) continue;

      // 3. Entry-Key mit meinem Private-Key entschlüsseln
      final entryKey = await _cryptoService.decryptRsa(myPerm.encryptedKey, _sessionService.privateKey!);

      // 4. Entry-Key mit dem NEUEN Public-Key des Freundes verschlüsseln
      final encryptedKey = await _cryptoService.encryptRsa(entryKey, friend.publicKey);

      // 5. In DB speichern (wird beim nächsten Sync hochgeladen)
      perm = perm.copyWith(encryptedKey: encryptedKey);
      await _databaseService.savePermission(perm);
    }
  }

  /// Entfernt einen Freund aus der Liste.
  ///
  /// Der Datensatz wird gelöscht, wenn keine Verknüpfungen bestehen, ansonsten wird er ausgeblendet.
  Future<void> deleteFriend(UserEntity friend) async {
    if (state.isBusy) return;

    // 1. Ladeanzeige einblenden
    state = state.copyWith(status: SettingsActionStatus.progress, error: AppError.none());

    try {

      // 2. Freund löschen bzw. ausblenden
      final perms = await _databaseService.getPermissionsByUserId(friend.id);
      if (perms.isEmpty) {
        // Es werden keine Einträge mit dem Freund geteilt, daher kann er gelöscht werden.
        await _databaseService.deleteUser(friend.id);
      } else {
        // Der Freund wird nicht gelöscht, sondern ausgeblendet, damit beim Synchronisieren alle geteilten Einträge entfernt werden können.
        await _databaseService.hideUser(friend.id);
      }

      // 3. UI-State zurücksetzen
      final friends = await _databaseService.getNotHiddenFriends();
      final fingerprints = _getFingerprints(friends);
      final friendNeedsRekeying = await _getFriendNeedsRekeying(friends);
      state = state.copyWith(
        friends: friends,
        fingerprints: fingerprints,
        friendNeedsRekeying: friendNeedsRekeying,
        status: SettingsActionStatus.friendDeleted,
      );

    } catch (e, st) {
      Logger().fatal('Löschen fehlgeschlagen: $e', stack: st);
      state = state.copyWith(status: SettingsActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Farbschema ändern ---
  // ------------------------------------------------------------------------

  /// Setter für das Farbschema.
  ///
  /// `PriVaultApp` (siehe `main.dart`) beobachtet das Farbschema indirekt über
  /// das `MaterialApp`-Widget und reagiert auf diese Änderungen.
  void setThemeMode(ThemeMode value) {
    final error = state.error.field == 'themeMode' ? AppError.none() : null;
    state = state.copyWith(themeMode: value, error: error);
    if (_configService.themeMode == value) return;
    _configService.themeMode = value;
  }

  // ------------------------------------------------------------------------
  // --- Buttons für Systemeinstellungen ---
  // ------------------------------------------------------------------------

  /// Öffnet die Systemeinstellungen für Biometrie.
  Future<void> openBiometricSettings() async {
    await _systemSettingsService.openBiometricSettings();
  }

  /// Öffnet die Android-Systemeinstellungen für den Autofill-Anbieter.
  Future<void> openAutofillSettings() async {
    await _systemSettingsService.openAutofillSettings();
  }

  /// Öffnet die App-Info-Seite in den Systemeinstellungen.
  Future<void> openAppSettings() async {
    await _systemSettingsService.openAppSettings();
  }

}