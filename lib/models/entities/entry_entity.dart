/// Repräsentiert einen Tresoreintrag in der SQLite-Datenbank.
class EntryEntity {
  /// Die interne ID (Auto-Increment in der Datenbank).
  /// Nullable für neue Einträge, bevor sie in die Datenbank geschrieben werden.
  final int? id;

  /// Die globale eindeutige ID des Eintrags (Universally Unique Identifier v4).
  final String uuid;

  /// Die Kategorie des Eintrags.
  final String category;

  /// Der Anzeigename des Eintrags.
  final String title;

  /// Die zugehörige Adresse der Webseite oder des Dienstes.
  final String url;

  /// Ergänzende Notiz (Metadaten).
  final String notes;

  /// Der binäre Dateninhalt des Website-Icons, gespeichert als Base64-kodierter String.
  /// Ermöglicht die visuelle Identifikation in der Liste ohne zusätzliche Netzwerkanfragen.
  final String favicon;

  /// Der AES-256-GCM verschlüsselte Daten-Container (Ciphertext + Nonce + Auth-Tag).
  /// Enthält das serialisierte JSON-Objekt der Klasse [EntryPayload].
  final String encryptedData;

  /// Die lokale ID des Benutzers, der diesen Eintrag erstellt hat.
  final int creatorId;

  /// Die lokale ID des Benutzers, der den Eintrag zuletzt aktualisiert hat.
  final int updaterId;

  /// Zeitpunkt der letzten Änderung (UTC).
  final DateTime updatedAt;

  /// Konstruktor
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

  /// Konvertiert eine [EntryEntity] in eine Map (z.B. für SQLite oder JSON).
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

  /// Erstellt ein [EntryEntity] Objekt aus einer Map.
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

  /// Erzeugt eine Kopie des Objekts mit modifizierten Eigenschaften.
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
