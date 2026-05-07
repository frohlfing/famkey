import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famkey/core/app_error.dart';
import 'package:famkey/core/env.dart';
import 'package:famkey/core/logger.dart';
import 'package:famkey/core/service_locator.dart';
import 'package:famkey/database/database.dart';
import 'package:famkey/features/settings/settings_state.dart';
import 'package:famkey/services/autofill_service.dart';
import 'package:famkey/services/autotype_service.dart';
import 'package:famkey/services/biometric_service.dart';
import 'package:famkey/services/clipboard_service.dart';
import 'package:famkey/services/config_service.dart';
import 'package:famkey/services/crypto_service.dart';
import 'package:famkey/services/database_service.dart';
import 'package:famkey/services/info_service.dart';
import 'package:famkey/services/session_service.dart';

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});

class SettingsNotifier extends Notifier<SettingsState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

  late final AutofillService _autofillService;
  late final AutotypeService _autotypeService;
  late final BiometricService _biometricService;
  late final ClipboardService _clipboardService;
  late final ConfigService _configService;
  late final CryptoService _cryptoService;
  late final DatabaseService _databaseService;
  late final InfoService _infoService;
  late final SessionService _sessionService;

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
    _autofillService = getIt<AutofillService>();
    _autotypeService = getIt<AutotypeService>();
    _biometricService = getIt<BiometricService>();
    _clipboardService = getIt<ClipboardService>();
    _configService = getIt<ConfigService>();
    _cryptoService = getIt<CryptoService>();
    _databaseService = getIt<DatabaseService>();
    _infoService = getIt<InfoService>();
    _sessionService = getIt<SessionService>();

    // Initialer State
    return SettingsState().copyWith(
      canOpenBiometricSettings: _biometricService.canOpenSettings,
      isAutofillSupported: _autofillService.isSupported,
      isAutotypeSupported: _autotypeService.isSupported,
      canOpenAppSettings: _infoService.canOpenSettings,
      syncProtocolVersion: _infoService.syncProtocolVersion,
      schemaVersion: _infoService.schemaVersion,
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

      // App-Version laden (async)
      final appVersion = await _infoService.version;

      // UI-State aktualisieren
      state = state.copyWith(
        vaultStoragePath: env.vaultStoragePath,
        vaultName: _sessionService.vaultName,
        useBiometric: _settings!.useBiometric,
        autoLockSeconds: _configService.autoLockSeconds ?? 0,
        clipboardClearSeconds: _configService.clipboardClearSeconds ?? 0,
        isAutofillEnabled: isAutofillEnabled,
        isAutotypeEnabled: _configService.isAutotypeEnabled,
        autotypeHotkey: _configService.autotypeHotkey,
        isRegistered: _settings!.lastSyncAt.year > 1970,
        userName: _sessionService.user?.name ?? '',
        host: _settings!.host,
        friends: friends,
        fingerprints: fingerprints,
        friendNeedsRekeying: friendNeedsRekeying,
        pwLength: _settings!.pwLength,
        pwSpecialChars: _settings!.pwSpecialChars,
        pwAvoidIlO0: _settings!.pwAvoidIlO0,
        themeMode: _configService.themeMode,
        categoryPlaceholder: _settings!.categoryPlaceholder,
        logLevel: _configService.logLevel,
        logDays: _configService.logDays,
        logSize: _configService.logSize,
        appVersion: appVersion,
        status: SettingsActionStatus.loaded,
      );

    } catch (e, st) {
      log.fatal('Fehler beim Laden: $e', stack: st);
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
        log.info("Biometrie-Key entfernt, da Option deaktiviert wurde.");
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
      log.fatal("Fehler beim Speichern: $e", stack: st);
      state = state.copyWith(status: SettingsActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Timeouts ---
  // ------------------------------------------------------------------------

  /// Kopiert den Text in die Zwischenablage und startet den Clear-Timer.
  void copyToClipboard(String text) {
    _clipboardService.copy(text);
  }

  // ------------------------------------------------------------------------
  // --- Autofill ---
  // ------------------------------------------------------------------------

  /// Schaltet Autofill ein oder aus.
  /// Auf Android: öffnet die Systemeinstellungen zur Auswahl des Autofill-Anbieters.
  /// Auf Windows: speichert die Einstellung lokal.
  Future<void> toggleAutofill(bool value) async {
    if (env.isAndroid) {
      await openAutofillSettings();
      return;
    }
    state = state.copyWith(status: SettingsActionStatus.progress, error: AppError.none());
    _configService.isAutotypeEnabled = value;
    state = state.copyWith(isAutotypeEnabled: value, status: SettingsActionStatus.saved);
  }

  /// Aktualisiert den Android-Systemzustand von Autofill (nach Rückkehr aus Systemeinstellungen).
  Future<void> refreshAutofillStatus() async {
    state = state.copyWith(status: SettingsActionStatus.progress, error: AppError.none());
    final isEnabled = await _autofillService.isAutofillEnabled();
    state = state.copyWith(isAutofillEnabled: isEnabled, status: SettingsActionStatus.saved);
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
      log.fatal("Fehler beim Speichern der Verifizierung: $e", stack: st);
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
      log.fatal('Löschen fehlgeschlagen: $e', stack: st);
      state = state.copyWith(status: SettingsActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Farbschema ändern ---
  // ------------------------------------------------------------------------

  /// Setter für das Farbschema.
  ///
  /// `FamKeyApp` (siehe `main.dart`) beobachtet das Farbschema indirekt über
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

  /// Öffnet die Biometrie-Einstellungen in den Systemeinstellungen.
  Future<void> openBiometricSettings() async {
    await _biometricService.openSystemSettings();
  }

  /// Öffnet die Autofill-Einstellungen in den Android-Systemeinstellungen.
  Future<void> openAutofillSettings() async {
    await _autofillService.openSystemSettings();
  }

  /// Öffnet die App-Info-Seite in den Systemeinstellungen.
  Future<void> openAppSettings() async {
    await _infoService.openSystemSettings();
  }

}