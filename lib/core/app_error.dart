/// Zentrale Liste aller fachlichen Fehlercodes der App.
enum AppError {
  // --- Allgemeines ---

  /// kein Fehler
  none,

  /// Eingabe erforderlich
  valueRequired,

  /// Validierungsfehler
  validationFailed,

  // --- Tresor ---

  /// Tresor nicht gefunden
  vaultNotFound,

  /// Die Namen sind identisch.
  vaultEqualName,

  /// Tresor existiert bereits
  vaultAlreadyExists,

  /// Tresor beschädigt
  vaultCorrupt,

  /// Tresor gesperrt
  vaultLocked,

  // --- Benutzer ---

  /// Tresor nicht gefunden
  userNotFound,

  /// Sich selbst hinzufügen geht nicht
  userSelfAdd,

  /// Bereits hinzugefügt
  userAlreadyAdded,

  // --- Passwort ---

  /// Die Passwörter sind identisch.
  equalPassword,

  /// Falsches Passwort
  wrongPassword,

  // --- Biometrie ---

  /// Biometrische Authentifizierung abgebrochen
  biometricCanceled,

  /// Biometrische Authentifizierung veraltet
  wrongBiometric,

  // --- Synchronisation ---

  /// Die UUID oder das Salt des Benutzers stimmen nicht überein.
  syncSaltMismatch,

  /// Der Entry-Key ist nicht gesetzt.
  syncEmptyEntryKey,

  // --- Netzwerk ---

  /// Netzwerkfehler
  networkError,

  /// Anmeldung am Server fehlgeschlagen
  unauthorized,

  /// Tresor noch nicht synchronisiert
  notRegistered,

  // --- Dateien ---

  /// Temporären Datei konnte nicht gelöscht werden
  cleanupFailed,

  // --- Fallback ---

  /// Unbekannter/Unerwarteter Fehler
  unknown,
}

/// Erweiterung für [AppError], um jedem Code eine Standard-Fehlermeldung zuzuweisen.
extension AppErrorExtension on AppError {
  /// Gibt den Standard-Fehlertext für diesen Fehlercode zurück.
  String get defaultMessage {
    // @formatter:off
    switch (this) {
      // --- Allgemeines ---
      case AppError.none: return '';
      case AppError.valueRequired: return 'Eingabe erforderlich';
      case AppError.validationFailed: return 'Bitte korrigiere die markierten Eingabefelder.';

      // --- Tresor ---
      case AppError.vaultNotFound: return 'Der angegebene Tresor konnte auf diesem Gerät nicht gefunden werden.';
      case AppError.vaultEqualName: return 'Neuer und alter Name sind identisch.';
      case AppError.vaultAlreadyExists: return 'Ein Tresor mit diesem Namen existiert bereits.';
      case AppError.vaultCorrupt: return 'Die Tresordatei scheint beschädigt oder keine gültige Datenbank zu sein.';
      case AppError.vaultLocked: return 'Der Tresor ist blockiert. Bitte App neu starten.';

      // --- Benutzer ---
      case AppError.userNotFound: return 'Person nicht gefunden.';
      case AppError.userSelfAdd: return 'Das bist du selbst.';
      case AppError.userAlreadyAdded: return 'Person bereits hinzugefügt.';

      // --- Passwort ---
      case AppError.equalPassword: return 'Neues und altes Master-Passwort sind identisch.';
      case AppError.wrongPassword: return 'Das eingegebene Passwort ist nicht korrekt.';

      // --- Biometrie ---
      case AppError.biometricCanceled: return 'Die biometrische Authentifizierung wurde abgebrochen.';
      case AppError.wrongBiometric: return 'Die biometrische Authentifizierung ist veraltet. Die Eingabe des Passworts ist erforderlich.';

      // --- Synchronisation ---
      case AppError.syncSaltMismatch: return 'Die Identität des Benutzers stimmt nicht überein.';
      case AppError.syncEmptyEntryKey: return 'Der Entry-Key ist nicht gesetzt.';

      // --- Netzwerk ---
      case AppError.networkError: return 'Es konnte keine Verbindung zum Server hergestellt werden.';
      case AppError.unauthorized: return 'Die Anmeldung am Server ist fehlgeschlagen (API-Token ungültig).';
      case AppError.notRegistered: return 'Dieser Tresor wurde noch nicht mit einem Server synchronisiert.';

      // --- Dateien ---
      case AppError.cleanupFailed: return 'Fehler beim Entfernen der temporären Datei.';

      // --- Fallback ---
      default: return 'Ein unerwarteter Fehler ist aufgetreten.';
    }
    // @formatter:on
  }
}
