/// Repräsentiert die Schema-Version der lokalen SQLite-Datenbank.
/// Diese Entität wird genutzt, um automatische Migrationen bei App-Updates durchzuführen.
///
/// **Besonderheit:**
/// Diese Tabelle fungiert als Singleton-Speicher und enthält systembedingt exakt einen Datensatz,
/// welcher den aktuellen Zustand der lokalen Datenbankstruktur beschreibt.
///
/// **Versioning-Schema (SemVer):**
/// * **Major:** Inkompatible Änderungen am Datenformat.
/// * **Minor:** Neue Tabellen oder Spalten (abwärtskompatibel).
/// * **Patch:** Fehlerkorrekturen am Schema ohne Strukturänderung.
class VersionEntity {

    /// Die interne ID (Auto-Increment in der Datenbank).
    /// Da es sich um einen Singleton-Datensatz handelt, ist der Wert hierbei stets 1.
    final int id;

    /// Die Haupt-Versionsnummer.
    /// Wird erhöht bei Schema-Änderungen, die nicht abwärtskompatibel sind.
    final int major;

    /// Die Neben-Versionsnummer.
    /// Wird erhöht, wenn das Schema abwärtskompatibel verändert wurde (z.B. neue optionale Felder).
    final int minor;

    /// Die Revisionsnummer.
    /// Wird erhöht, wenn das Schema optimiert wurde (z.B. Index hinzugefügt/verändert).
    final int patch;

    /// Zeitstempel der letzten lokalen Schema-Änderung (UTC).
    final DateTime updatedAt;

    /// Konstruktor
    VersionEntity({
        this.id = 1, 
        required this.major, 
        required this.minor, 
        required this.patch, 
        required this.updatedAt
    });

    /// Konvertiert eine [VersionEntity] in eine Map (z.B. für SQLite oder JSON).
    Map<String, dynamic> toMap() {
        return {
            'id': id, 
            'major': major,
            'minor': minor, 
            'patch': patch, 
            'updated_at': updatedAt.toIso8601String()
        };
    }

    /// Konvertiert eine Map in ein [VersionEntity] Objekt.
    factory VersionEntity.fromMap(Map<String, dynamic> map) {
        return VersionEntity(
            id: map['id'] as int,
            major: map['major'] as int,
            minor: map['minor'] as int,
            patch: map['patch'] as int,
            updatedAt: DateTime.parse(map['updated_at'] as String).toUtc(),
        );
    }
}
