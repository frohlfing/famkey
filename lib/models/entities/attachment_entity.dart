/// Repräsentiert einen Dateianhang zu einem Tresoreintrag in der lokalen SQLite-Datenbank.
/// Der gesamte Inhalt wird verschlüsselt gespeichert, um die Privatsphäre zu gewährleisten.
class AttachmentEntity {
  /// Die interne ID (Auto-Increment in der Datenbank).
  /// Nullable für neue Einträge, bevor sie in die Datenbank geschrieben werden.
  final int? id;

  /// Die globale eindeutige ID des Anhangs (Universally Unique Identifier v4).
  final String uuid;

  /// Die interne ID des zugehörigen Eintrags.
  final int entryId;

  /// Der AES-256-GCM verschlüsselte Metadaten-Container (Ciphertext + Nonce + Auth-Tag).
  /// Enthält das serialisierte JSON-Objekt der Klasse [AttachmentMetaPayload].
  final String encryptedMeta;

  /// Der AES-256-GCM verschlüsselte Binärdaten-Container (Ciphertext + Nonce + Auth-Tag).
  /// Enthält den binären Dateninhalt des Anhangs.
  final String encryptedContent;

  /// `true`, wenn der Anhang erfolgreich zum Server synchronisiert wurde, sonst `false`.
  final bool isSynced;

  /// Konstruktor
  AttachmentEntity({
    this.id,
    required this.uuid,
    required this.entryId,
    required this.encryptedMeta,
    required this.encryptedContent,
    this.isSynced = false,
  });

  /// Konvertiert eine [AttachmentEntity] in eine Map (z.B. für SQLite oder JSON).
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

  /// Erstellt ein [AttachmentEntity] Objekt aus einer Map.
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

  /// Erzeugt eine Kopie des Objekts mit modifizierten Eigenschaften.
  AttachmentEntity copyWith({int? id, String? uuid, int? entryId, String? encryptedMeta, String? encryptedContent, bool? isSynced}) {
    return AttachmentEntity(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      entryId: entryId ?? this.entryId,
      encryptedMeta: encryptedMeta ?? this.encryptedMeta,
      encryptedContent: encryptedContent ?? this.encryptedContent,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
