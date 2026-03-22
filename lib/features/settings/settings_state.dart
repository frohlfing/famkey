import 'package:privault/core/app_error.dart';
import 'package:privault/database/database.dart';
import 'package:flutter/material.dart';
import 'package:privault/features/settings/settings_form_data.dart';

/// Ein Enum für den Status von Aktionen
enum SettingsActionStatus {
  initial, // Der Ausgangszustand
  progress, // Aktion läuft

  // todo Unterscheidung notwendig?
  loading, // Einstellungen werden geladen
  saving, // Änderungen werden gespeichert
  deleting, // Tresor wird gelöscht
  loaded, // Einstellungen wurden erfolgreich geladen
  saved, // Änderungen wurden erfolgreich gespeichert
  deleted, // Tresor wurde erfolgreich gelöscht

  testing, // Server-Verbindung wird getestet
  testSuccessful, // Test erfolgreich
  testFailed, // Test fehlgeschlagen

  changingVaultName, // Tresor wird umbenannt
  vaultNameChanged, // Tresor wurde erfolgreich umbenannt

  changingPassword, // Master-Passwort wird geändert
  passwordChanged, // Master-Passwort wurde erfolgreich geändert

  friendAdded, // Freund wurde erfolgreich hinzugefügt
  friendDeleted, // Freund wurde erfolgreich gelöscht
  friendVerified, // Freund wurde erfolgreich verifiziert
  failure, // Aktion mit Fehler beendet
}

class SettingsState {

  // --- Basiskonfiguration ---

  /// Speicherort der Tresore
  final String vaultStoragePath;

  /// Die Formulardaten.
  final SettingsFormData formData;

  /// Der ursprünglichen Formulardaten (für den Dirty-Check).
  final SettingsFormData originalFormData;

  /// Gibt an, ob der Benutzer bereits mit dem Server synchronisiert wurde (registriert ist).
  final bool isRegistered;

  // --- Freunde---

  /// Die Liste der Freunde.
  final List<UserEntity> friends;

  /// Fingerprints der Freunde.
  final Map<int, String> fingerprints;

  /// Freunde mit leeren Entry-Keys
  final Map<int, bool> friendNeedsRekeying;

  // --- Farbschema ---

  /// Das Farbschema ('System', 'Light' oder 'Dark').
  final ThemeMode themeMode;

  // --- Action-Status und -Error ---

  /// Neuer Tresorname (wird gesetzt, wenn der Tresor umbenannt wird).
  final String newVaultName;

  /// Neues Master-Passwort (wird gesetzt, wenn das Master-Passwort geändert wird).
  final String newPassword;

  /// Der Status der letzten Aktion.
  final SettingsActionStatus status;

  /// Der Fehler der letzten Operation.
  final FormError error;

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy =>
    status == SettingsActionStatus.progress ||
    status == SettingsActionStatus.loading ||
    status == SettingsActionStatus.saving ||
    status == SettingsActionStatus.deleting ||
    status == SettingsActionStatus.testing;

  /// Gibt an, ob der Benutzer ein Feld verändert hat.
  bool get isDirty => formData != originalFormData;

  /// Gibt an, ob für diesen Freund Einträge neu verschlüsselt werden müssen.
  /// Dies ist der Fall, wenn sein RSA-Key geändert und die lokalen Permission-Keys geleert wurden.
  bool getNeedsRekeying(int userId) {
    return friendNeedsRekeying[userId] ?? false;
  }

  /// Konstruktor
  const SettingsState({
    this.vaultStoragePath = '',
    this.formData = const SettingsFormData(),
    this.originalFormData = const SettingsFormData(),
    this.isRegistered = false,
    this.friends = const [],
    this.fingerprints = const {},
    this.friendNeedsRekeying = const {},
    this.themeMode = ThemeMode.system,
    this.newVaultName = '',
    this.newPassword = '',
    this.status = SettingsActionStatus.initial,
    this.error = const FormError.none(),
  });

  /// Status aktualisieren (immutable)
  SettingsState copyWith({
    String? vaultStoragePath,
    SettingsFormData? formData,
    SettingsFormData? originalFormData,
    bool? isRegistered,
    List<UserEntity>? friends,
    Map<int, String>? fingerprints,
    Map<int, bool>? friendNeedsRekeying,
    ThemeMode? themeMode,
    String? newVaultName,
    String? newPassword,
    SettingsActionStatus? status,
    FormError? error,
  }) {
    return SettingsState(
      vaultStoragePath: vaultStoragePath ?? this.vaultStoragePath,
      formData: formData ?? this.formData,
      originalFormData: originalFormData ?? this.originalFormData,
      isRegistered: isRegistered ?? this.isRegistered,
      friends: friends ?? this.friends,
      fingerprints: fingerprints ?? this.fingerprints,
      friendNeedsRekeying: friendNeedsRekeying ?? this.friendNeedsRekeying,
      themeMode: themeMode ?? this.themeMode,
      newVaultName: newVaultName ?? this.newVaultName,
      newPassword: newPassword ?? this.newPassword,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
