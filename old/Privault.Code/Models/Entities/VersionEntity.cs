using SQLite;

// ReSharper disable PropertyCanBeMadeInitOnly.Global
// ReSharper disable UnusedAutoPropertyAccessor.Global

namespace Privault.Core.Models.Entities;

/// <summary>
/// Repräsentiert die Schema-Version der lokalen SQLite-Datenbank.
/// Diese Entität wird genutzt, um automatische Migrationen bei App-Updates durchzuführen.
/// <para>
/// <b>Besonderheit:</b>
/// Diese Tabelle fungiert als Singleton-Speicher und enthält systembedingt exakt einen Datensatz, 
/// welcher den aktuellen Zustand der lokalen Datenbankstruktur beschreibt.
/// </para>
/// <para>
/// <b>Versioning-Schema (SemVer):</b>
/// <list type="bullet">
/// <item><b>Major:</b> Inkompatible Änderungen am Datenformat.</item>
/// <item><b>Minor:</b> Neue Tabellen oder Spalten (abwärtskompatibel).</item>
/// <item><b>Patch:</b> Fehlerkorrekturen am Schema ohne Strukturänderung.</item>
/// </list>
/// </para>
/// </summary>
[Table("version")]
public class VersionEntity
{
    /// <summary>
    /// Die interne ID (Auto-Increment).
    /// Dient als Primärschlüssel für den Object-Relational Mapper (ORM) benötigt.
    /// Da es sich um einen Singleton-Datensatz handelt, ist der Wert hierbei stets 1.
    /// </summary>
    [PrimaryKey, AutoIncrement]
    [Column("id")]
    public int Id { get; set; }

    /// <summary>
    /// Die Haupt-Versionsnummer.
    /// Wird erhöht bei Schema-Änderungen, die nicht abwärtskompatibel sind.
    /// </summary>
    [Column("major")]
    public int Major { get; set; }

    /// <summary>
    /// Die Neben-Versionsnummer.
    /// Wird erhöht, wenn das Schema abwärtskompatibel verändert wurde (z.B. neue optionale Felder).
    /// </summary>
    [Column("minor")]
    public int Minor { get; set; }

    /// <summary>
    /// Die Revisionsnummer.
    /// Wird erhöht, wenn das Schema optimiert wurde (z.B. Index hinzugefügt/verändert).
    /// </summary>
    [Column("patch")]
    public int Patch { get; set; }

    /// <summary>
    /// Zeitstempel der letzten lokalen Änderung.
    /// </summary>
    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; } = DateTime.SpecifyKind(new DateTime(1970, 1, 1), DateTimeKind.Utc);
}