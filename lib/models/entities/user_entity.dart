/// Repräsentiert eine Benutzeridentität innerhalb eines Tresors.
///
/// Diese Klasse verwaltet sowohl den Benutzer der App als auch alle hinzugefügten
/// Freunde, mit denen Einträge geteilt werden können.
///
/// **Rollenverteilung:**
/// * **Besitzer:** Der Hauptbenutzer der App hat lokal stets die `id = 1`.
/// * **Freunde:** Weitere Benutzer, mit denen Einträge geteilt werden können.
class UserEntity {
  /// Die interne ID (Auto-Increment in der Datenbank).
  /// Der Benutzer der App wird systemintern stets mit der ID 1 identifiziert.
  /// Nullable für neue Einträge, bevor sie in die Datenbank geschrieben werden.
  final int? id;

  /// Die globale eindeutige ID des Benutzers (Universally Unique Identifier v4).
  final String uuid;

  /// Der Name des Benutzers (eindeutig pro Tresor auf dem Server).
  /// Ist im Normalfall UNVERÄNDERLICH nach der Registrierung.
  final String name;

  /// Der öffentliche RSA-Schlüssel des Benutzers (Base64-kodierter SPKI-String).
  final String publicKey;

  /// Gibt an, ob die Identität dieses Benutzers (per Fingerprint-Vergleich) manuell verifiziert wurde.
  final bool isVerified;

  /// Gibt an, ob der Benutzer in der UI ausgeblendet ist (z.B. gelöschte Freunde, die wegen Sync noch erhalten bleiben müssen).
  final bool isHidden;

  /// Zeitpunkt der letzten Änderung (UTC).
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

  /// Konvertiert eine [UserEntity] in eine Map (z.B. für SQLite oder JSON).
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

  /// Erstellt ein [UserEntity] Objekt aus einer Map.
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

  /// Erzeugt eine Kopie des Objekts mit modifizierten Eigenschaften.
  UserEntity copyWith({int? id, String? uuid, String? name, String? publicKey, bool? isVerified, bool? isHidden, DateTime? updatedAt}) {
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
