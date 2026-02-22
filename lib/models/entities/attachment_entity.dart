class AttachmentEntity {
  final int? id;
  final String uuid;
  final int entryId;
  final String encryptedMeta;
  final String encryptedContent;
  final bool isSynced;

  AttachmentEntity({
    this.id,
    required this.uuid,
    required this.entryId,
    required this.encryptedMeta,
    required this.encryptedContent,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'entry_id': entryId,
      'encrypted_meta': encryptedMeta,
      'encrypted_content': encryptedContent,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory AttachmentEntity.fromMap(Map<String, dynamic> map) {
    return AttachmentEntity(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      entryId: map['entry_id'] as int,
      encryptedMeta: map['encrypted_meta'] as String,
      encryptedContent: map['encrypted_content'] as String,
      isSynced: (map['is_synced'] as int) == 1,
    );
  }
}
