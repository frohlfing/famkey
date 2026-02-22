using System.Text.Json.Serialization;

namespace Privault.Core.Models.DTOs;

/// <summary>
/// Repräsentiert die Anfrage an den Server beim Hochladen lokaler Änderungen (Push-Vorgang).
/// </summary>
public class SyncPushRequest
{
    /// <summary>
    /// Eine Liste neuer oder lokal geänderter Tresoreinträge.
    /// </summary>
    [JsonPropertyName("updates")] 
    public List<EntryDto> Updates { get; init; } = [];
    
    /// <summary>
    /// Eine Liste lokaler Löschungen, die auf dem Server nachvollzogen werden sollen.
    /// </summary>
    [JsonPropertyName("deletes")] 
    public List<TombstoneDto> Deletes { get; init; } = [];
}