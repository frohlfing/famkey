/// Repräsentiert die Antwort des Servers auf eine Versionsabfrage.
class VersionResponse {

  /// "PriVault v1 REST-API"
  final String service;

  /// Sync-Protokollversion.
  final int syncProtocolVersion;

  /// Kleinste unterstützte Protokollversion
  final int minSyncProtocolVersion;

  /// Konstruktor
  VersionResponse({
    required this.service,
    required this.syncProtocolVersion,
    required this.minSyncProtocolVersion,
  });

  /// Wandelt ein JSON-Objekt in ein [VersionResponse] Objekt um.
  factory VersionResponse.fromJson(Map<String, dynamic> json) {
    return VersionResponse(
      service: json['service'] as String? ?? '',
      syncProtocolVersion: json['sync_protocol_version'] as int? ?? 0,
      minSyncProtocolVersion: json['min_sync_protocol_version'] as int? ?? 0,
    );
  }
}
