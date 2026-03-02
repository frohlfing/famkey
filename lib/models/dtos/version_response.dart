/// Repräsentiert die Antwort des Servers auf eine Versionsabfrage.
class VersionResponse {
    final String service;

    /// Die Haupt-Versionsnummer.
    /// Wird erhöht bei Schema-Änderungen, die nicht abwärtskompatibel sind.
    final int major;

    /// Die Neben-Versionsnummer.
    /// Wird erhöht, wenn das Schema abwärtskompatibel verändert wurde.
    final int minor;

    /// Die Revisionsnummer (Patch).
    /// Wird erhöht bei Fehlerbehebungen.
    final int patch;

    /// Die vom Server mindestens erforderliche Client-Minor-Version.
    final int requiredClientMinor;

    /// Konstruktor
    VersionResponse({
        required this.service,
        required this.major,
        required this.minor,
        required this.patch,
        required this.requiredClientMinor,
    });

    /// Wandelt ein JSON-Objekt in ein [VersionResponse] Objekt um.
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
