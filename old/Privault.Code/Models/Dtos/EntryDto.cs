using System.Text.Json.Serialization;

namespace Privault.Core.Models.DTOs;

/// <summary>
/// Datenübertragungsobjekt für einen Tresoreintrag auf API-Ebene.
/// Bündelt verschlüsselte Daten, Metadaten und Freigabeinformationen.
/// </summary>
public class EntryDto
{
    /// <summary>
    /// Die globale eindeutige Identifikationsnummer (UUID v4) des Eintrags.
    /// </summary>
    [JsonPropertyName("entry_uuid")] 
    public string EntryUuid { get; init; } = string.Empty;
    
    /// <summary>
    /// Der AES-256-GCM verschlüsselte Daten-Container (Base64).
    /// </summary>
    [JsonPropertyName("encrypted_data")] 
    public string EncryptedData { get; init; } = string.Empty;
    
    /// <summary>
    /// Der für den aktuellen Benutzer verschlüsselte Entry-Key (RSA-Umschlag, Base64).
    /// </summary>
    [JsonPropertyName("encrypted_key")] 
    public string EncryptedKey { get; init; }  = string.Empty;

    /// <summary>
    /// Die Zugriffsebene des anfragenden Benutzers für diesen Eintrag.
    /// </summary>
    [JsonPropertyName("access_level")]
    public int AccessLevel { get; init; }

    /// <summary>
    /// Eine Liste von UUIDs zugehöriger Dateianhänge.
    /// </summary>
    [JsonPropertyName("attachment_uuids")]
    public List<string> AttachmentUuids { get; init; } = [];
    
    /// <summary>
    /// Eine Liste von Freigaben für andere Freunde.
    /// </summary>
    [JsonPropertyName("friends")] 
    public List<FriendPermissionDto> Friends { get; init; } = [];
    
    /// <summary>
    /// Die globale UUID des Benutzers, der diesen Eintrag ursprünglich erstellt hat.
    /// </summary>
    [JsonPropertyName("creator_uuid")] 
    public string CreatorUuid { get; init; } = string.Empty;
    
    /// <summary>
    /// Die globale UUID des Benutzers, der die letzte Änderung vorgenommen hat.
    /// </summary>
    [JsonPropertyName("updater_uuid")] 
    public string UpdaterUuid { get; init; } = string.Empty;
    
    private readonly DateTime _updatedAt = DateTime.SpecifyKind(new DateTime(1970, 1, 1), DateTimeKind.Utc);
    
    /// <summary>
    /// Zeitpunkt der letzten Änderung (UTC).
    /// </summary>
    [JsonPropertyName("updated_at")] 
    public DateTime UpdatedAt
    {
        get => _updatedAt;
        init => _updatedAt = value.Kind == DateTimeKind.Unspecified ? DateTime.SpecifyKind(value, DateTimeKind.Utc) : value.ToUniversalTime();
    }
}