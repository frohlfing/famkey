using SQLite;

// ReSharper disable PropertyCanBeMadeInitOnly.Global

namespace Privault.Core.Models.Entities;

/// <summary>
/// Repräsentiert einen Löschmarker ("Tombstone") für Tresoreinträge.
/// Diese Entität speichert die UUIDs von gelöschten Objekten, um die Synchronisation 
/// von Löschvorgängen über mehrere Geräte hinweg zu ermöglichen.
/// <para>
/// <b>Funktionsweise:</b>
/// Wenn ein Eintrag lokal gelöscht wird, wird hier ein Grabstein hinterlassen. Beim nächsten 
/// Synchronisationsvorgang meldet der Client dem Server: "Eintrag mit UUID X wurde gelöscht".
/// </para>
/// </summary>
[Table("tombstones")]
public class TombstoneEntity
{
    /// <summary>
    /// Die interne ID (Auto-Increment).
    /// Dient als Primärschlüssel für den Object-Relational Mapper (ORM).
    /// </summary>
    [PrimaryKey, AutoIncrement]
    [Column("id")]
    public int Id { get; set; }
    
    /// <summary>
    /// Die globale ID des gelöschten Eintrags (Universally Unique Identifier v4).
    /// </summary>
    [Indexed(Name = "uk_tombstones_entry_uuid", Unique = true)] 
    [Column("entry_uuid")]
    public string EntryUuid { get; set; } = string.Empty;

    private DateTime _deletedAt = DateTime.SpecifyKind(new DateTime(1970, 1, 1), DateTimeKind.Utc);

    /// <summary>
    /// Zeitpunkt (UTC) der Löschung.
    /// </summary>
    [Indexed(Name = "idx_tombstones_deleted_at")]
    [Column("deleted_at")]
    public DateTime DeletedAt
    {
        get => _deletedAt;
        set => _deletedAt = value.Kind == DateTimeKind.Unspecified ? DateTime.SpecifyKind(value, DateTimeKind.Utc) : value.ToUniversalTime();
    }
}