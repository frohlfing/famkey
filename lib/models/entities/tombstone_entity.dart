class TombstoneEntity {
  final int? id;
  final String entryUuid;
  final DateTime deletedAt;

  TombstoneEntity({
    this.id,
    required this.entryUuid,
    required this.deletedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entry_uuid': entryUuid,
      'deleted_at': deletedAt.toIso8601String(),
    };
  }

  factory TombstoneEntity.fromMap(Map<String, dynamic> map) {
    return TombstoneEntity(
      id: map['id'] as int?,
      entryUuid: map['entry_uuid'] as String,
      deletedAt: DateTime.parse(map['deleted_at'] as String).toUtc(),
    );
  }
}
