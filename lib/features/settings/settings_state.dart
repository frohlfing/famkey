import 'package:famkey/core/app_error.dart';
import 'package:famkey/core/logger.dart';
import 'package:famkey/database/database.dart';
import 'package:flutter/material.dart';
import 'package:famkey/services/password_service.dart';

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

  /// Capabilities - Kann die Biometrie-Seite geöffnet werden?
  final bool canOpenBiometricSettings;

  // --- Timeouts ---

  /// Inaktivitätsdauer in Sekunden bis zur automatischen Sperre. 0 = nie.
  final int autoLockSeconds;

  /// Dauer in Sekunden bis zum automatischen Leeren der Zwischenablage. 0 = nie.
  final int clipboardClearSeconds;

  // --- Autofill ---

  /// Gibt an, ob Autofill auf dieser Plattform verfügbar ist.
  final bool isAutofillSupported;

  /// Gibt an, ob FamKey aktuell als Autofill-Anbieter im Android-System aktiv ist.
  /// Wird über MethodChannel abgefragt und spiegelt den Systemzustand wider.
  final bool isAutofillEnabled;

  // --- Autotype ---

  /// Gibt an, ob Autotype auf dieser Plattform verfügbar ist (Windows only).
  final bool isAutotypeSupported;

  /// Gibt an, ob der Nutzer Autotype verwenden möchte.
  final bool isAutotypeEnabled;

  /// Das Tastenkürzel für Autotype.
  final String autotypeHotkey;

  // --- Sync-Server ---

  /// Gibt an, ob der Benutzer bereits mit dem Server synchronisiert wurde (registriert ist).
  final bool isRegistered;

  /// Der Benutzername.
  final String userName;

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

  // --- Logging ---

  /// Log-Level
  final LogLevel logLevel;

  /// Aufbewahrungsdauer in Tagen.
  final int logDays;

  /// Maximale Dateigröße in Bytes
  final int logSize;

  // --- App-Info ---

  /// Kann die App-Info-Seite geöffnet werden?
  final bool canOpenAppSettings;

  // --- Action-Status und -Error ---

  /// Der Status der letzten Aktion.
  final SettingsActionStatus status;

  /// Der Fehler der letzten Operation.
  final AppError error;

  // --- Getter ---

  String get autoLockLabel {
    if (autoLockSeconds == 0) return 'Nie';
    if (autoLockSeconds < 60) return 'Nach $autoLockSeconds Sekunden';
    final m = autoLockSeconds ~/ 60;
    return m == 1 ? 'Nach 1 Minute' : 'Nach $m Minuten';
  }

  String get clipboardClearLabel => clipboardClearSeconds == 0 ? 'Nie' : 'Nach $clipboardClearSeconds Sekunden';

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
    this.canOpenBiometricSettings = false,
    this.autoLockSeconds = 0,
    this.clipboardClearSeconds = 0,
    this.isAutofillSupported = false,
    this.isAutofillEnabled = false,
    this.isAutotypeSupported = false,
    this.isAutotypeEnabled = true,
    this.autotypeHotkey = 'Strg+Shift+A',
    this.isRegistered = false,
    this.userName = '',
    this.host = '',
    this.friends = const [],
    this.fingerprints = const {},
    this.friendNeedsRekeying = const {},
    this.pwLength = defaultPwLength,
    this.pwSpecialChars = '',
    this.pwAvoidIlO0 = false,
    this.themeMode = ThemeMode.system,
    this.categoryPlaceholder = '',
    this.logLevel = LogLevel.info,
    this.logDays = 7,
    this.logSize = 512 * 1024,
    this.canOpenAppSettings = false,
    this.status = SettingsActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable).
  /// Für nullable int-Felder (autoLockSeconds, clipboardClearSeconds) mit clearAutoLockSeconds/clearClipboardClearSeconds auf null setzen.
  SettingsState copyWith({
    String? vaultStoragePath,
    String? vaultName,
    bool? useBiometric,
    bool? canOpenBiometricSettings,
    int? autoLockSeconds,
    int? clipboardClearSeconds,
    bool? isAutofillSupported,
    bool? isAutofillEnabled,
    bool? isAutotypeSupported,
    bool? isAutotypeEnabled,
    String? autotypeHotkey,
    bool? isRegistered,
    String? userName,
    String? host,
    List<UserEntity>? friends,
    Map<int, String>? fingerprints,
    Map<int, bool>? friendNeedsRekeying,
    int? pwLength,
    String? pwSpecialChars,
    bool? pwAvoidIlO0,
    ThemeMode? themeMode,
    String? categoryPlaceholder,
    LogLevel? logLevel,
    int? logDays,
    int? logSize,
    bool? canOpenAppSettings,
    SettingsActionStatus? status,
    AppError? error,
  }) {
    return SettingsState(
      vaultStoragePath: vaultStoragePath ?? this.vaultStoragePath,
      vaultName: vaultName ?? this.vaultName,
      useBiometric: useBiometric ?? this.useBiometric,
      canOpenBiometricSettings: canOpenBiometricSettings ?? this.canOpenBiometricSettings,
      autoLockSeconds: autoLockSeconds ?? this.autoLockSeconds,
      clipboardClearSeconds: clipboardClearSeconds ?? this.clipboardClearSeconds,
      isAutofillSupported: isAutofillSupported ?? this.isAutofillSupported,
      isAutofillEnabled: isAutofillEnabled ?? this.isAutofillEnabled,
      isAutotypeSupported: isAutotypeSupported ?? this.isAutotypeSupported,
      isAutotypeEnabled: isAutotypeEnabled ?? this.isAutotypeEnabled,
      autotypeHotkey: autotypeHotkey ?? this.autotypeHotkey,
      isRegistered: isRegistered ?? this.isRegistered,
      userName: userName ?? this.userName,
      host: host ?? this.host,
      friends: friends ?? this.friends,
      fingerprints: fingerprints ?? this.fingerprints,
      friendNeedsRekeying: friendNeedsRekeying ?? this.friendNeedsRekeying,
      pwLength: pwLength ?? this.pwLength,
      pwSpecialChars: pwSpecialChars ?? this.pwSpecialChars,
      pwAvoidIlO0: pwAvoidIlO0 ?? this.pwAvoidIlO0,
      themeMode: themeMode ?? this.themeMode,
      categoryPlaceholder: categoryPlaceholder ?? this.categoryPlaceholder,
      logLevel: logLevel ?? this.logLevel,
      logDays: logDays ?? this.logDays,
      logSize: logSize ?? this.logSize,
      canOpenAppSettings: canOpenAppSettings ?? this.canOpenAppSettings,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}