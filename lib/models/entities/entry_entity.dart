class EntryEntity {
  final int? id;
  final String uuid;
  final String category;
  final String title;
  final String url;
  final String notes; // Corresponds to 'notes' column in C#
  final String favicon; // Base64 string
  final String encryptedData; // AES-256-GCM blob
  final int creatorId;
  final int updaterId;
  final DateTime updatedAt;

  EntryEntity({
    this.id,
    required this.uuid,
    this.category = '',
    this.title = '',
    this.url = '',
    this.notes = '',
    this.favicon = '',
    required this.encryptedData,
    required this.creatorId,
    required this.updaterId,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'category': category,
      'title': title,
      'url': url,
      'notes': notes,
      'favicon': favicon,
      'encrypted_data': encryptedData,
      'creator_id': creatorId,
      'updater_id': updaterId,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory EntryEntity.fromMap(Map<String, dynamic> map) {
    return EntryEntity(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      category: map['category'] as String? ?? '',
      title: map['title'] as String? ?? '',
      url: map['url'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      favicon: map['favicon'] as String? ?? '',
      encryptedData: map['encrypted_data'] as String,
      creatorId: map['creator_id'] as int,
      updaterId: map['updater_id'] as int,
      updatedAt: DateTime.parse(map['updated_at'] as String).toUtc(),
    );
  }

  EntryEntity copyWith({
    int? id,
    String? uuid,
    String? category,
    String? title,
    String? url,
    String? notes,
    String? favicon,
    String? encryptedData,
    int? creatorId,
    int? updaterId,
    DateTime? updatedAt,
  }) {
    return EntryEntity(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      category: category ?? this.category,
      title: title ?? this.title,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      favicon: favicon ?? this.favicon,
      encryptedData: encryptedData ?? this.encryptedData,
      creatorId: creatorId ?? this.creatorId,
      updaterId: updaterId ?? this.updaterId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
