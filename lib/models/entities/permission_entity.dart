class PermissionEntity {
  final int? id;
  final int entryId;
  final int userId;
  final String encryptedKey;
  final int accessLevel;

  PermissionEntity({
    this.id,
    required this.entryId,
    required this.userId,
    required this.encryptedKey,
    required this.accessLevel,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entry_id': entryId,
      'user_id': userId,
      'encrypted_key': encryptedKey,
      'access_level': accessLevel,
    };
  }

  factory PermissionEntity.fromMap(Map<String, dynamic> map) {
    return PermissionEntity(
      id: map['id'] as int?,
      entryId: map['entry_id'] as int,
      userId: map['user_id'] as int,
      encryptedKey: map['encrypted_key'] as String,
      accessLevel: map['access_level'] as int,
    );
  }

  PermissionEntity copyWith({
    int? id,
    int? entryId,
    int? userId,
    String? encryptedKey,
    int? accessLevel,
  }) {
    return PermissionEntity(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      userId: userId ?? this.userId,
      encryptedKey: encryptedKey ?? this.encryptedKey,
      accessLevel: accessLevel ?? this.accessLevel,
    );
  }
}
