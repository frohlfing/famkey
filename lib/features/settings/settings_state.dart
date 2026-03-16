import 'package:privault/core/app_error.dart';
import 'package:privault/database/database.dart';
import 'package:flutter/material.dart';

class SettingsState {
  /// Gibt an, ob ein Ladesymbol angezeigt wird
  final bool isBusy;

  // --- Tresor ---

  /// Der Name des Tresors.
  final String vaultName;

  // --- Login ---

  /// Gibt an, ob Fingerabdruck bzw. Gesichtserkennung als Anmeldeoption zur Verfügung steht.
  final bool useBiometric;

  // --- Sync-Server ---

  /// Gibt an, ob der Benutzer bereits mit dem Server synchronisiert wurde (registriert ist).
  final bool isRegistered;

  /// Der Name des angemeldeten Benutzers innerhalb des Tresors.
  final String userName;

  /// Die URL des Servers für die Synchronisation.
  final String host;

  /// Das API-Token für die Authentifizierung gegenüber dem Server.
  final String apiToken;

  // --- Passwort-Generator ---

  /// Eingestellte Länge für den Passwortgenerator.
  final int pwLength;

  /// Der aktuell gewählte Satz an Sonderzeichen für generierte Passwörter.
  final String pwSpecialChars;

  /// Gibt an, ob optisch ähnliche Zeichen ('I', 'l', 'O', '0') ausgelassen werden.
  final bool pwAvoidIlO0;

  // --- Freunde---

  /// Die Liste der Freunde.
  final List<UserEntity> friends;

  /// Freunde mit leeren Entry-Keys
  final Map<int, bool> friendNeedsRekeying;

  // --- Design ---

  /// Der gewählte Theme-Modus ('System', 'Light' oder 'Dark').
  final ThemeMode themeMode;

  /// Anzeigename für eine leere Kategorie.
  final String categoryPlaceholder;

  // --- Error ---

  /// Der Fehler der letzten Operation.
  final FormError error;

  /// Konstruktor
  const SettingsState({
    this.isBusy = false,
    this.vaultName = '',
    this.useBiometric = false,
    this.isRegistered = false,
    this.userName = '',
    this.host = '',
    this.apiToken = '',
    this.pwLength = 16,
    this.pwSpecialChars = '',
    this.pwAvoidIlO0 = true,
    this.friends = const [],
    this.friendNeedsRekeying = const {},
    this.themeMode = ThemeMode.system,
    this.categoryPlaceholder = 'Allgemein',
    this.error = const FormError.none(),
  });

  /// Status aktualisieren (immutable)
  SettingsState copyWith({
    bool? isBusy,
    String? vaultName,
    bool? useBiometric,
    bool? isRegistered,
    String? userName,
    String? host,
    String? apiToken,
    int? pwLength,
    String? pwSpecialChars,
    bool? pwAvoidIlO0,
    List<UserEntity>? friends,
    Map<int, bool>? friendNeedsRekeying,
    ThemeMode? themeMode,
    String? categoryPlaceholder,
    FormError? error,
  }) {
    return SettingsState(
      isBusy: isBusy ?? this.isBusy,
      vaultName: vaultName ?? this.vaultName,
      useBiometric: useBiometric ?? this.useBiometric,
      isRegistered: isRegistered ?? this.isRegistered,
      userName: userName ?? this.userName,
      host: host ?? this.host,
      apiToken: apiToken ?? this.apiToken,
      pwLength: pwLength ?? this.pwLength,
      pwSpecialChars: pwSpecialChars ?? this.pwSpecialChars,
      pwAvoidIlO0: pwAvoidIlO0 ?? this.pwAvoidIlO0,
      friends: friends ?? this.friends,
      friendNeedsRekeying: friendNeedsRekeying ?? this.friendNeedsRekeying,
      themeMode: themeMode ?? this.themeMode,
      categoryPlaceholder: categoryPlaceholder ?? this.categoryPlaceholder,
      error: error ?? this.error,
    );
  }
}
