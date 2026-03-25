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
  /// Falls das JSON ungültig ist, wird ein Objekt mit leeren Werten geliefert.
  factory VersionResponse.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return VersionResponse(service: '', syncProtocolVersion: 0, minSyncProtocolVersion: 0);
    }

    return VersionResponse(
      service: json['service']?.toString() ?? '',
      syncProtocolVersion: int.tryParse(json['sync_protocol_version']?.toString() ?? '0') ?? 0,
      minSyncProtocolVersion: int.tryParse(json['min_sync_protocol_version']?.toString() ?? '0') ?? 0,
    );
  }
}
