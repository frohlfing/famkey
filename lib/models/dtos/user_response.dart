/// Antwort des Servers für die Daten eines Benutzers.
class UserResponse {
  /// Die globale eindeutige Identifikationsnummer (UUID v4) des Benutzers.
  final String userUuid;

  /// Die globale eindeutige Identifikationsnummer (UUID v4) des Tresors.
  final String vaultUuid;

  /// Der SHA-256-Hash des Benutzernamens.
  final String userHash;

  /// Das serverseitig gespeicherte Salt des Benutzers zur Ableitung des Master-Keys.
  final String salt;

  /// Der öffentliche RSA-Schlüssel des Benutzers (Base64-kodierter SPKI-String).
  final String publicKey;

  /// Der mit dem Master-Passwort verschlüsselte RSA-Privatschlüssel des Benutzers (Base64).
  final String encryptedPrivateKey;

  /// Zeitstempel des Master-Keys (UTC).
  final DateTime masterKeyTimestamp;

  /// Die verschlüsselte Freundesliste des Benutzers (Base64), optional.
  final String? encryptedFriends;

  /// Konstruktor
  UserResponse({
    required this.userUuid,
    required this.vaultUuid,
    required this.userHash,
    required this.salt,
    required this.publicKey,
    required this.encryptedPrivateKey,
    required this.masterKeyTimestamp,
    required this.encryptedFriends,
  });

  /// Wandelt ein JSON-Objekt in ein [UserResponse] Objekt um.
  factory UserResponse.fromJson(Map<String, dynamic> json) {
    return UserResponse(
      userUuid: json['user_uuid'] as String,
      vaultUuid: json['vault_uuid'] as String,
      userHash: json['user_hash'] as String,
      salt: json['salt'] as String,
      publicKey: json['public_key'] as String,
      encryptedPrivateKey: json['encrypted_private_key'] as String,
      masterKeyTimestamp: DateTime.tryParse(json['master_key_timestamp'])?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true), // Fallback: 1970‑01‑01 00:00:00 UTC
      encryptedFriends: json['encrypted_friends'] as String?,
    );
  }
}
