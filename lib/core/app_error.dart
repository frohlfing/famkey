/// Zentrale Liste aller fachlichen Fehlercodes der App.
enum ErrorCode {
  // --- Allgemeines ---

  /// kein Fehler
  none,

  /// Eingabe erforderlich
  valueRequired,

  /// Eingabe ungültig
  valueInvalid,

  /// Die Eingabe wurde nicht verändert.
  valueNotChanged,

  /// Validierungsfehler
  validationFailed,

  // --- Tresor ---

  /// Tresor nicht gefunden
  vaultNotFound,

  /// Die Namen sind identisch.
  vaultEqualName, // todo == valueNotChanged

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
  equalPassword, // todo == valueNotChanged

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

  /// App ist veraltet
  appIsOutdated,

  /// Sync-Server ist veraltet
  serverIsOutdated,

  // --- Dateien ---

  /// Temporären Datei konnte nicht gelöscht werden
  cleanupFailed,

  // --- Fallback ---

  /// Unbekannter/Unerwarteter Fehler
  unknown,
}

/// Erweiterung für [ErrorCode], um jedem Code eine Standard-Fehlermeldung zuzuweisen.
extension ErrorCodeExtension on ErrorCode {
  /// Gibt den Standard-Fehlertext für diesen Fehlercode zurück.
  String get defaultText {
    // @formatter:off
    switch (this) {
      // --- Allgemeines ---
      case ErrorCode.none: return '';
      case ErrorCode.valueRequired: return 'Eingabe erforderlich';
      case ErrorCode.valueInvalid: return 'Eingabe ungültig';
      case ErrorCode.valueNotChanged: return 'Eingabe wurde nicht verändert';
      case ErrorCode.validationFailed: return 'Bitte korrigiere die markierten Eingabefelder.';

      // --- Tresor ---
      case ErrorCode.vaultNotFound: return 'Der angegebene Tresor konnte auf diesem Gerät nicht gefunden werden.';
      case ErrorCode.vaultEqualName: return 'Neuer und alter Name sind identisch.';
      case ErrorCode.vaultAlreadyExists: return 'Ein Tresor mit diesem Namen existiert bereits.';
      case ErrorCode.vaultCorrupt: return 'Die Tresordatei scheint beschädigt oder keine gültige Datenbank zu sein.';
      case ErrorCode.vaultLocked: return 'Der Tresor ist blockiert. Bitte App neu starten.';

      // --- Benutzer ---
      case ErrorCode.userNotFound: return 'Person nicht gefunden.';
      case ErrorCode.userSelfAdd: return 'Das bist du selbst.';
      case ErrorCode.userAlreadyAdded: return 'Person bereits hinzugefügt.';

      // --- Passwort ---
      case ErrorCode.equalPassword: return 'Neues und altes Master-Passwort sind identisch.';
      case ErrorCode.wrongPassword: return 'Das eingegebene Passwort ist nicht korrekt.';

      // --- Biometrie ---
      case ErrorCode.biometricCanceled: return 'Die biometrische Authentifizierung wurde abgebrochen.';
      case ErrorCode.wrongBiometric: return 'Die biometrische Authentifizierung ist veraltet. Die Eingabe des Passworts ist erforderlich.';

      // --- Synchronisation ---
      case ErrorCode.syncSaltMismatch: return 'Die Identität des Benutzers stimmt nicht überein.';
      case ErrorCode.syncEmptyEntryKey: return 'Der Entry-Key ist nicht gesetzt.';

      // --- Netzwerk ---
      case ErrorCode.networkError: return 'Es konnte keine Verbindung zum Server hergestellt werden.';
      case ErrorCode.unauthorized: return 'Die Anmeldung am Server ist fehlgeschlagen (API-Token ungültig).';
      case ErrorCode.notRegistered: return 'Dieser Tresor wurde noch nicht mit einem Server synchronisiert.';
      case ErrorCode.appIsOutdated: return 'Die App ist veraltet.';
      case ErrorCode.serverIsOutdated: return 'Der Sync-Server ist veraltet.';

      // --- Dateien ---
      case ErrorCode.cleanupFailed: return 'Fehler beim Entfernen der temporären Datei.';

      // --- Fallback ---
      default: return 'Ein unerwarteter Fehler ist aufgetreten.';
    }
    // @formatter:on
  }
}

/// Zentrale Klasse für fachlichen Fehler der App
class FormError { // todo in AppError umbenennen
  final ErrorCode code;
  final String text;
  final String? field;
  FormError(this.code, {String? text, this.field}) : text = text ?? code.defaultText;
  const FormError.none() : code = ErrorCode.none, text = '', field = null;
}
