class VersionResponse {
  final String service;
  final int major;
  final int minor;
  final int patch;
  final int requiredClientMinor; // Hinzugefügt für Version Check

  VersionResponse({
    required this.service,
    required this.major,
    required this.minor,
    required this.patch,
    required this.requiredClientMinor,
  });

  factory VersionResponse.fromJson(Map<String, dynamic> json) {
    return VersionResponse(
      service: json['service'] as String? ?? 'PriVault API',
      major: json['major'] as int? ?? 0,
      minor: json['minor'] as int? ?? 0,
      patch: json['patch'] as int? ?? 0,
      requiredClientMinor: json['required_client_minor'] as int? ?? 0,
    );
  }
}
