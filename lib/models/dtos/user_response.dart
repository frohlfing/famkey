class UserResponse {
  final String userUuid;
  final String vaultUuid;
  final String userHash;
  final String salt;
  final String publicKey;
  final String encryptedPrivateKey;
  final String? encryptedFriends;

  UserResponse({
    required this.userUuid,
    required this.vaultUuid,
    required this.userHash,
    required this.salt,
    required this.publicKey,
    required this.encryptedPrivateKey,
    this.encryptedFriends,
  });

  factory UserResponse.fromJson(Map<String, dynamic> json) {
    return UserResponse(
      userUuid: json['user_uuid'] as String,
      vaultUuid: json['vault_uuid'] as String,
      userHash: json['user_hash'] as String,
      salt: json['salt'] as String,
      publicKey: json['public_key'] as String,
      encryptedPrivateKey: json['encrypted_private_key'] as String,
      encryptedFriends: json['encrypted_friends'] as String?,
    );
  }
}
