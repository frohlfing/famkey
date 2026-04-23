/// Repräsentiert den Status und die Identitätsdaten eines Freundes.
/// Ein Array dieser Objekte wird als JSON serialisiert und verschlüsselt auf dem
/// Server abgelegt, um die Freundesliste zwischen Geräten zu synchronisieren.
class FriendPayload {
  /// Die globale eindeutige ID des Freundes.
  final String uuid;

  /// Der aktuelle Benutzername des Freundes (kann sich durch Umbenennung ändern).
  final String name;

  /// Der Name, unter dem dieser Freund ursprünglich auf dem Server gefunden und
  /// hinzugefügt wurde. Unveränderlich nach dem ersten Hinzufügen.
  /// Wenn [name] != [syncedName], hat sich der Freund umbenannt.
  final String syncedName;

  /// Gibt an, ob der Freund bereits verifiziert wurde.
  final bool isVerified;

  /// Gibt an, ob der Freund in der UI ausgeblendet wurde.
  final bool isHidden;

  /// Zeitpunkt der letzten Änderung (UTC).
  /// Dient zur Konfliktauflösung (Last-Write-Wins).
  final DateTime updatedAt;

  /// Konstruktor
  FriendPayload({
    required this.uuid,
    required this.name,
    required this.syncedName,
    required this.isVerified,
    required this.isHidden,
    required this.updatedAt,
  });

  /// Erstellt eine [FriendPayload] aus einer JSON-Map.
  factory FriendPayload.fromJson(Map<String, dynamic> json) {
    return FriendPayload(
      uuid: json['uuid'] as String,
      name: json['name'] as String,
      syncedName: json['syncedName'] as String,
      isVerified: json['isVerified'] as bool,
      isHidden: json['isHidden'] as bool,
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '')?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true), // Fallback: 1970‑01‑01 00:00:00 UTC
    );
  }

  /// Konvertiert eine [FriendPayload] in eine Map für die JSON-Serialisierung.
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'name': name,
      'syncedName': syncedName,
      'isVerified': isVerified,
      'isHidden': isHidden,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}