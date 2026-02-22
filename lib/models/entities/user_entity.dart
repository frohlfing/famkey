
class UserEntity {
  final int? id; // Nullable for new entries before DB insert
  final String uuid;
  final String name;
  final String publicKey;
  final bool isVerified;
  final bool isHidden;
  final DateTime updatedAt;

  UserEntity({
    this.id,
    required this.uuid,
    required this.name,
    required this.publicKey,
    this.isVerified = false,
    this.isHidden = false,
    required this.updatedAt,
  });

  // Convert a UserEntity into a Map. The keys must correspond to the column names in the database.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'name': name,
      'public_key': publicKey,
      'is_verified': isVerified ? 1 : 0,
      'is_hidden': isHidden ? 1 : 0,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Extract a UserEntity object from a Map.
  factory UserEntity.fromMap(Map<String, dynamic> map) {
    return UserEntity(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      name: map['name'] as String,
      publicKey: map['public_key'] as String,
      isVerified: (map['is_verified'] as int) == 1,
      isHidden: (map['is_hidden'] as int) == 1,
      updatedAt: DateTime.parse(map['updated_at'] as String).toUtc(),
    );
  }

  UserEntity copyWith({
    int? id,
    String? uuid,
    String? name,
    String? publicKey,
    bool? isVerified,
    bool? isHidden,
    DateTime? updatedAt,
  }) {
    return UserEntity(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      publicKey: publicKey ?? this.publicKey,
      isVerified: isVerified ?? this.isVerified,
      isHidden: isHidden ?? this.isHidden,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
