/// Benutzerdaten, die für eine Identitätsübernahme benötigt werden.
class UserIdentity {
  /// Die globale eindeutige Identifikationsnummer (UUID v4) des Benutzers.
  final String userUuid;

  /// Das serverseitig gespeicherte Salt des Benutzers zur Ableitung des Master-Keys.
  final String salt;

  /// Der öffentliche RSA-Schlüssel des Benutzers (Base64-kodierter SPKI-String).
  final String publicKey;

  /// Der mit dem Master-Passwort verschlüsselte RSA-Privatschlüssel des Benutzers (Base64).
  final String encryptedPrivateKey;

  /// Konstruktor
  const UserIdentity({
    this.userUuid = '',
    this.salt = '',
    this.publicKey = '',
    this.encryptedPrivateKey = '',
  });
}