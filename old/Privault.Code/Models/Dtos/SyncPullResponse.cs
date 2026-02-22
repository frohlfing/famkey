using System.Text.Json.Serialization;

namespace Privault.Core.Models.DTOs;

/// <summary>
/// Repräsentiert die Antwort des Servers beim Herunterladen von Änderungen (Pull-Vorgang).
/// Enthält neue oder aktualisierte Einträge sowie Informationen über gelöschte Objekte.
/// </summary>
public class SyncPullResponse
{
    /// <summary>
    /// Eine Liste von neuen oder aktualisierten Tresoreinträgen.
    /// </summary>
    [JsonPropertyName("updates")] 
    public List<EntryDto> Updates { get; init; } = [];
    
    /// <summary>
    /// Eine Liste von gelöschten Einträgen (Tombstones).
    /// </summary>
    [JsonPropertyName("deletes")] 
    public List<TombstoneDto> Deletes { get; init; } = [];
    
    private DateTime _serverTime = DateTime.SpecifyKind(new DateTime(1970, 1, 1), DateTimeKind.Utc);

    /// <summary>
    /// Der aktuelle Zeitstempel des Servers zum Zeitpunkt der Anfrage.
    /// Dient als Basis für den nächsten inkrementellen Synchronisationsvorgang.
    /// </summary>
    [JsonPropertyName("server_time")] 
    public DateTime ServerTime
    {
        get => _serverTime;
        set => _serverTime = value.Kind == DateTimeKind.Unspecified ? DateTime.SpecifyKind(value, DateTimeKind.Utc) : value.ToUniversalTime();
    }
}
