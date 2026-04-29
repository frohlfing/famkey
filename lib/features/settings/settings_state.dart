import 'package:privault/core/app_error.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/database/database.dart';
import 'package:flutter/material.dart';
import 'package:privault/services/password_service.dart';

/// Ein Enum für den Status von Aktionen
enum SettingsActionStatus {
  initial, // Der Ausgangszustand
  progress, // Aktion läuft
  loaded, // Einstellungen wurden erfolgreich geladen
  saved, // Änderungen wurden erfolgreich gespeichert
  deleted, // Tresor wurde erfolgreich gelöscht
  friendAdded, // Freund wurde erfolgreich hinzugefügt
  friendDeleted, // Freund wurde erfolgreich gelöscht
  friendVerified, // Freund wurde erfolgreich verifiziert
  failure, // Aktion mit Fehler beendet
}

class SettingsState {

  // --- Tresor ---

  /// Speicherort der Tresore
  final String vaultStoragePath;

  /// Der aktuelle (lokale) Tresorname.
  final String vaultName;

  // --- Login ---

  /// Gibt an, ob Fingerabdruck bzw. Gesichtserkennung als Anmeldeoption zur Verfügung steht.
  final bool useBiometric;

  // --- Server ---

  /// Der Benutzername.
  final String userName;

  /// Gibt an, ob der Benutzer bereits mit dem Server synchronisiert wurde (registriert ist).
  final bool isRegistered;

  /// Die URL des Sync-Servers
  final String host;

  // --- Freunde---

  /// Die Liste der Freunde.
  final List<UserEntity> friends;

  /// Fingerprints der Freunde.
  final Map<int, String> fingerprints;

  /// Freunde mit leeren Entry-Keys
  final Map<int, bool> friendNeedsRekeying;

  // --- Passwortgenerator ---

  /// Eingestellte Länge für den Passwortgenerator.
  final int pwLength;

  /// Der aktuell gewählte Satz an Sonderzeichen für generierte Passwörter.
  final String pwSpecialChars;

  /// Gibt an, ob optisch ähnliche Zeichen ('I', 'l', 'O', '0') ausgelassen werden.
  final bool pwAvoidIlO0;

  // --- Farbschema ---

  /// Das Farbschema ('System', 'Light' oder 'Dark').
  final ThemeMode themeMode;

  /// Anzeigename für eine leere Kategorie.
  final String categoryPlaceholder;

  // --- Capabilities ---
  /// Capabilities - Kann die App-Info-Seite geöffnet werden?
  final bool canOpenAppSettings;

  /// Capabilities - Kann die Biometrie-Seite geöffnet werden?
  final bool canOpenBiometricSettings;

  /// Capabilities - Kann die Autofill-Seite geöffnet werden?
  final bool canOpenAutofillSettings;

  // --- Autofill ---

  /// Gibt an, ob der Nutzer Autofill verwenden möchte (ConfigService-Einstellung, beide Plattformen).
  final bool autofillEnabled;

  /// Gibt an, ob PriVault aktuell als Autofill-Anbieter im Android-System aktiv ist.
  /// Wird über MethodChannel abgefragt und spiegelt den Systemzustand wider.
  final bool isAutofillEnabled;

  /// Das Tastenkürzel für Auto-Type (nur Windows).
  final String autofillHotkey;

  // --- Timeouts ---

  /// Inaktivitätsdauer in Minuten bis zur automatischen Sperre. null = nie.
  final int? autoLockMinutes;

  /// Dauer in Sekunden bis zum automatischen Leeren der Zwischenablage. null = nie.
  final int? clipboardClearSeconds;

  // --- Logging ---

  /// Log-Level
  final LogLevel logLevel;

  /// Aufbewahrungsdauer in Tagen.
  final int logDays;

  /// Maximale Dateigröße in Bytes
  final int logSize;

  // --- Action-Status und -Error ---

  /// Der Status der letzten Aktion.
  final SettingsActionStatus status;

  /// Der Fehler der letzten Operation.
  final AppError error;

  // --- Getter ---

  String get autoLockLabel => autoLockMinutes == null ? 'Nie' : 'Nach ${autoLockMinutes == 1 ? '1 Minute' : '$autoLockMinutes Minuten'}';

  String get clipboardClearLabel => clipboardClearSeconds == null ? 'Nie' : 'Nach $clipboardClearSeconds Sekunden';

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy =>
    status == SettingsActionStatus.progress;

  /// Gibt an, ob für diesen Freund Einträge neu verschlüsselt werden müssen.
  /// Dies ist der Fall, wenn sein RSA-Key geändert und die lokalen Permission-Keys geleert wurden.
  bool getNeedsRekeying(int userId) {
    return friendNeedsRekeying[userId] ?? false;
  }

  /// Konstruktor
  const SettingsState({
    this.vaultStoragePath = '',
    this.vaultName = '',
    this.useBiometric = false,
    this.userName = '',
    this.isRegistered = false,
    this.host = '',
    this.friends = const [],
    this.fingerprints = const {},
    this.friendNeedsRekeying = const {},
    this.pwLength = defaultPwLength,
    this.pwSpecialChars = '',
    this.pwAvoidIlO0 = false,
    this.themeMode = ThemeMode.system,
    this.categoryPlaceholder = '',
    this.canOpenAppSettings = false,
    this.canOpenBiometricSettings = false,
    this.canOpenAutofillSettings = false,
    this.autofillEnabled = true,
    this.isAutofillEnabled = false,
    this.autofillHotkey = 'Strg+Shift+A',
    this.autoLockMinutes,
    this.clipboardClearSeconds,
    this.logLevel = LogLevel.info,
    this.logDays = 7,
    this.logSize = 512 * 1024,
    this.status = SettingsActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable).
  /// Für nullable int-Felder (autoLockMinutes, clipboardClearSeconds) mit clearAutoLockMinutes/clearClipboardClearSeconds auf null setzen.
  SettingsState copyWith({
    String? vaultStoragePath,
    String? vaultName,
    bool? useBiometric,
    String? userName,
    bool? isRegistered,
    String? host,
    List<UserEntity>? friends,
    Map<int, String>? fingerprints,
    Map<int, bool>? friendNeedsRekeying,
    int? pwLength,
    String? pwSpecialChars,
    bool? pwAvoidIlO0,
    ThemeMode? themeMode,
    String? categoryPlaceholder,
    bool? canOpenAppSettings,
    bool? canOpenBiometricSettings,
    bool? canOpenAutofillSettings,
    bool? autofillEnabled,
    bool? isAutofillEnabled,
    String? autofillHotkey,
    Object? autoLockMinutes = _keep,
    Object? clipboardClearSeconds = _keep,
    LogLevel? logLevel,
    int? logDays,
    int? logSize,
    SettingsActionStatus? status,
    AppError? error,
  }) {
    return SettingsState(
      vaultStoragePath: vaultStoragePath ?? this.vaultStoragePath,
      vaultName: vaultName ?? this.vaultName,
      useBiometric: useBiometric ?? this.useBiometric,
      userName: userName ?? this.userName,
      isRegistered: isRegistered ?? this.isRegistered,
      host: host ?? this.host,
      friends: friends ?? this.friends,
      fingerprints: fingerprints ?? this.fingerprints,
      friendNeedsRekeying: friendNeedsRekeying ?? this.friendNeedsRekeying,
      pwLength: pwLength ?? this.pwLength,
      pwSpecialChars: pwSpecialChars ?? this.pwSpecialChars,
      pwAvoidIlO0: pwAvoidIlO0 ?? this.pwAvoidIlO0,
      themeMode: themeMode ?? this.themeMode,
      categoryPlaceholder: categoryPlaceholder ?? this.categoryPlaceholder,
      canOpenAppSettings: canOpenAppSettings ?? this.canOpenAppSettings,
      canOpenBiometricSettings: canOpenBiometricSettings ?? this.canOpenBiometricSettings,
      canOpenAutofillSettings: canOpenAutofillSettings ?? this.canOpenAutofillSettings,
      autofillEnabled: autofillEnabled ?? this.autofillEnabled,
      isAutofillEnabled: isAutofillEnabled ?? this.isAutofillEnabled,
      autofillHotkey: autofillHotkey ?? this.autofillHotkey,
      autoLockMinutes: autoLockMinutes == _keep ? this.autoLockMinutes : autoLockMinutes as int?,
      clipboardClearSeconds: clipboardClearSeconds == _keep ? this.clipboardClearSeconds : clipboardClearSeconds as int?,
      logLevel: logLevel ?? this.logLevel,
      logDays: logDays ?? this.logDays,
      logSize: logSize ?? this.logSize,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}

const _keep = Object();