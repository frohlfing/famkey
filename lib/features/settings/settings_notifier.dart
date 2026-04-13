import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/env.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/settings/settings_state.dart';
import 'package:privault/services/autofill_service.dart';
import 'package:privault/services/biometric_service.dart';
import 'package:privault/services/config_service.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';
import 'package:url_launcher/url_launcher.dart';

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});

class SettingsNotifier extends Notifier<SettingsState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

  late final AutofillService _autofillService;
  late final BiometricService _biometricService;
  late final ConfigService _configService;
  late final CryptoService _cryptoService;
  late final DatabaseService _databaseService;
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
    _biometricService = getIt<BiometricService>();
    _configService = getIt<ConfigService>();
    _cryptoService = getIt<CryptoService>();
    _databaseService = getIt<DatabaseService>();
    _sessionService = getIt<SessionService>();

    // Initialer State
    return SettingsState();
  }

  /// Lädt die Daten für die Anzeige.
  Future<void> load() async {
    if (state.isBusy) return;

    // UI-State zurücksetzen
    state = const SettingsState().copyWith(status: SettingsActionStatus.progress, error: AppError.none());

    try {
      // Einstellungen aus der Datenbank laden
      _settings = await _databaseService.getSettings();
      if (_settings == null) throw Exception('Die Einstellungen sind nicht in der Datenbank hinterlegt.'); // wird bereits direkt nach dem Login angelegt

      // Freundesliste laden
      final friends = await _databaseService.getNotHiddenFriends();
      final fingerprints = _getFingerprints(friends);
      final friendNeedsRekeying = await _getFriendNeedsRekeying(friends);

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
        categoryPlaceholder: _settings!.categoryPlaceholder.isEmpty ? 'Allgemein' : _settings!.categoryPlaceholder,
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

  /// Löscht den aktuellen Tresor lokal vom Gerät.
  Future<void> deleteVault() async {
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

      // 6. UI-State zurücksetzen
      state = SettingsState().copyWith(
        status: SettingsActionStatus.deleted,
      );

    } catch (e, st) {
      Logger().fatal('Fehler beim Löschen des Tresors: $e', stack: st);
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

  /// Kopiert den Text in die Zwischenablage.
  void copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
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
    await _biometricService.openSystemSettings();
  }

  /// Öffnet die Systemeinstellungen (oder eine Hilfeseite) für den Autofill-Dienst.
  Future<void> openAutofillSettings() async {
    await _autofillService.openSystemSettings();
  }

  /// Öffnet die App-Info-Seite in den Systemeinstellungen.
  Future<void> openAppSettings() async {
    // todo Die Platform-Weiche möchte ich hier nicht haben. Daher auslagern in einen Service.

    if (env.isWindows) {
      // Unter Windows gibt es keinen direkten Weg in die Detail-Ansicht einer fremden MSIX/EXE via URI.
      // Der Standardweg öffnet "ms-settings:appsfeatures-app".
      // Man kann versuchen, direkt auf die Windows-App-Einstellungen für *diese* App zu zielen.
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        final pfn = packageInfo.packageName;
        final advancedUri = Uri.parse('ms-settings:appsfeatures-app?PFN=$pfn');

        if (await canLaunchUrl(advancedUri)) {
          await launchUrl(advancedUri);
          return;
        }
      } catch (_) {}

      // Fallback: Die allgemeine Liste der installierten Apps
      await launchUrl(Uri.parse('ms-settings:appsfeatures'));
    } else if (env.isAndroid) {
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        final packageName = packageInfo.packageName;
        await launchUrl(Uri.parse('intent:package:$packageName#Intent;action=android.settings.APPLICATION_DETAILS_SETTINGS;end'));
      } catch (_) {
        await launchUrl(Uri.parse('intent:#Intent;action=android.settings.APPLICATION_SETTINGS;end'));
      }
    } else if (env.isApple) {
      await launchUrl(Uri.parse('app-settings:'));
    }
  }

}
