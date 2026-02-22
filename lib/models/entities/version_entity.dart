class VersionEntity {
  final int id;
  final int major;
  final int minor;
  final int patch;
  final DateTime updatedAt;

  VersionEntity({
    this.id = 1,
    required this.major,
    required this.minor,
    required this.patch,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'major': major,
      'minor': minor,
      'patch': patch,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory VersionEntity.fromMap(Map<String, dynamic> map) {
    return VersionEntity(
      id: map['id'] as int,
      major: map['major'] as int,
      minor: map['minor'] as int,
      patch: map['patch'] as int,
      updatedAt: DateTime.parse(map['updated_at'] as String).toUtc(),
    );
  }
}
