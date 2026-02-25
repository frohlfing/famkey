/// Repräsentiert einen Löschmarker ("Tombstone") für Tresoreinträge.
/// Diese Entität speichert die UUIDs von gelöschten Objekten, um die Synchronisation
/// von Löschvorgängen über mehrere Geräte hinweg zu ermöglichen.
///
/// **Funktionsweise:**
/// Wenn ein Eintrag lokal gelöscht wird, wird hier ein Grabstein hinterlassen.
/// Beim nächsten Synchronisationsvorgang meldet der Client dem Server:
/// "Eintrag mit UUID X wurde gelöscht".
class TombstoneEntity {
  /// Die interne ID (Auto-Increment in der Datenbank).
  /// Nullable für neue Einträge, bevor sie in die Datenbank geschrieben werden.
  final int? id;

  /// Die globale ID des gelöschten Eintrags (Universally Unique Identifier v4).
  final String entryUuid;

  /// Zeitpunkt (UTC) der Löschung.
  final DateTime deletedAt;

  TombstoneEntity({this.id, required this.entryUuid, required this.deletedAt});

  /// Konvertiert eine [TombstoneEntity] in eine Map (z.B. für SQLite oder JSON).
  Map<String, dynamic> toMap() {
    return {'id': id, 'entry_uuid': entryUuid, 'deleted_at': deletedAt.toIso8601String()};
  }

  /// Erstellt ein [TombstoneEntity] Objekt aus einer Map.
  factory TombstoneEntity.fromMap(Map<String, dynamic> map) {
    return TombstoneEntity(
      id: map['id'] as int?,
      entryUuid: map['entry_uuid'] as String,
      deletedAt: DateTime.parse(map['deleted_at'] as String).toUtc(),
    );
  }
}
