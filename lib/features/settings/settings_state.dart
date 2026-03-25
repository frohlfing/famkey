import 'package:privault/core/app_error.dart';
import 'package:privault/database/database.dart';
import 'package:flutter/material.dart';
import 'package:privault/features/settings/password_generator_dialog.dart';
import 'package:privault/features/settings/server_dialog.dart';

/// Ein Enum für den Status von Aktionen
enum SettingsActionStatus {
  initial, // Der Ausgangszustand
  progress, // Aktion läuft

  loaded, // Einstellungen wurden erfolgreich geladen
  saved, // Änderungen wurden erfolgreich gespeichert
  deleted, // Tresor wurde erfolgreich gelöscht
  testSuccessful, // Test erfolgreich
  friendAdded, // Freund wurde erfolgreich hinzugefügt
  friendDeleted, // Freund wurde erfolgreich gelöscht
  friendVerified, // Freund wurde erfolgreich verifiziert

  renameVaultFailed, // Tresor konnte nicht umbenannt werden
  changePasswordFailed, // Passwort konnte nicht geändert werden
  renameUserFailed, // Benutzer konnte nicht umbenannt werden
  testFailed, // Test fehlgeschlagen
  changeServerFailed, // Servereinstellung konnte nicht geändert werden
  changePasswordGeneratorFailed, // Servereinstellung konnte nicht geändert werden
  changeCategoryPlaceholderFailed, // Platzhalter für leere Kategorie konnte nicht geändert werden
  failure, // Aktion mit Fehler beendet
}

class SettingsState {

  // --- Tresor ---

  /// Speicherort der Tresore
  final String vaultStoragePath;

  /// Der Tresorname.
  final String vaultName;

  /// Der neue Tresorname (für den Dialog, wenn der Tresor umbenannt wird).
  final String newVaultName;

  // --- Login ---

  /// Neues Master-Passwort (für den Dialog, wenn das Master-Passwort geändert wird).
  final String newPassword;

  /// Gibt an, ob Fingerabdruck bzw. Gesichtserkennung als Anmeldeoption zur Verfügung steht.
  final bool useBiometric;

  // --- Server ---

  /// Der Benutzername.
  final String userName;

  /// Der neue Benutzername (für den Dialog, wenn der Benutzer umbenannt wird).
  final String newUserName;

  /// Gibt an, ob der Benutzer bereits mit dem Server synchronisiert wurde (registriert ist).
  final bool isRegistered;

  /// Die URL des Servers für die Synchronisation.
  final String host;

  /// Daten für den Dialog, wenn der Server geändert werden.
  final ServerDialogData serverSettingsDialogData;

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

  /// Daten für den Dialog, wenn der Passwortgenerator geändert werden.
  final PasswordGeneratorDialogData passwordGeneratorDialogData;

  // --- Farbschema ---

  /// Das Farbschema ('System', 'Light' oder 'Dark').
  final ThemeMode themeMode;

  /// Anzeigename für eine leere Kategorie.
  final String categoryPlaceholder;

  /// Anzeigename für eine leere Kategorie.
  final String newCategoryPlaceholder;

  // --- Action-Status und -Error ---

  /// Der Status der letzten Aktion.
  final SettingsActionStatus status;

  /// Der Fehler der letzten Operation.
  final AppError error;

  // --- Getter ---

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
    this.newVaultName = '',
    this.newPassword = '',
    this.useBiometric = false,
    this.userName = '',
    this.newUserName = '',
    this.isRegistered = false,
    this.host = '',
    this.serverSettingsDialogData = const ServerDialogData(),
    this.friends = const [],
    this.fingerprints = const {},
    this.friendNeedsRekeying = const {},
    this.pwLength = 16,
    this.pwSpecialChars = '',
    this.pwAvoidIlO0 = false,
    this.passwordGeneratorDialogData = const PasswordGeneratorDialogData(),
    this.themeMode = ThemeMode.system,
    this.categoryPlaceholder = '',
    this.newCategoryPlaceholder = '',
    this.status = SettingsActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  SettingsState copyWith({
    String? vaultStoragePath,
    String? vaultName,
    String? newVaultName,
    String? newPassword,
    bool? useBiometric,
    String? userName,
    String? newUserName,
    bool? isRegistered,
    String? host,
    ServerDialogData? serverSettingsDialogData,
    List<UserEntity>? friends,
    Map<int, String>? fingerprints,
    Map<int, bool>? friendNeedsRekeying,
    int? pwLength,
    String? pwSpecialChars,
    bool? pwAvoidIlO0,
    PasswordGeneratorDialogData? passwordGeneratorDialogData,
    ThemeMode? themeMode,
    String? categoryPlaceholder,
    String? newCategoryPlaceholder,
    SettingsActionStatus? status,
    AppError? error,
  }) {
    return SettingsState(
      vaultStoragePath: vaultStoragePath ?? this.vaultStoragePath,
      vaultName: vaultName ?? this.vaultName,
      newVaultName: newVaultName ?? this.newVaultName,
      newPassword: newPassword ?? this.newPassword,
      useBiometric: useBiometric ?? this.useBiometric,
      userName: userName ?? this.userName,
      newUserName: newUserName ?? this.newUserName,
      isRegistered: isRegistered ?? this.isRegistered,
      host: host ?? this.host,
      serverSettingsDialogData: serverSettingsDialogData ?? this.serverSettingsDialogData,
      friends: friends ?? this.friends,
      fingerprints: fingerprints ?? this.fingerprints,
      friendNeedsRekeying: friendNeedsRekeying ?? this.friendNeedsRekeying,
      pwLength: pwLength ?? this.pwLength,
      pwSpecialChars: pwSpecialChars ?? this.pwSpecialChars,
      pwAvoidIlO0: pwAvoidIlO0 ?? this.pwAvoidIlO0,
      passwordGeneratorDialogData: passwordGeneratorDialogData ?? this.passwordGeneratorDialogData,
      themeMode: themeMode ?? this.themeMode,
      categoryPlaceholder: categoryPlaceholder?? this.categoryPlaceholder,
      newCategoryPlaceholder: newCategoryPlaceholder?? this.newCategoryPlaceholder,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
