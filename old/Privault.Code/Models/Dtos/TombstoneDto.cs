using System.Text.Json.Serialization;

namespace Privault.Core.Models.DTOs;

/// <summary>
/// Transportobjekt für einen gelöschten Eintrag (Tombstone).
/// </summary>
public class TombstoneDto
{
    /// <summary>
    /// Die globale UUID des gelöschten Eintrags.
    /// </summary>
    [JsonPropertyName("entry_uuid")] 
    public string EntryUuid { get; init; } = string.Empty;
    
    private DateTime _deletedAt = DateTime.SpecifyKind(new DateTime(1970, 1, 1), DateTimeKind.Utc);
    
    /// <summary>
    /// Zeitpunkt der Löschung (UTC).
    /// </summary>
    [JsonPropertyName("deleted_at")] 
    public DateTime DeletedAt
    {
        get => _deletedAt;
        init => _deletedAt = value.Kind == DateTimeKind.Unspecified ? DateTime.SpecifyKind(value, DateTimeKind.Utc) : value.ToUniversalTime();
    }
}