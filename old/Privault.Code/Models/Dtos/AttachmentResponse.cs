using System.Text.Json.Serialization;

namespace Privault.Core.Models.DTOs;

/// <summary>
/// Repräsentiert das Datenübertragungsobjekt für Dateianhänge bei der Kommunikation mit der API.
/// Diese Klasse bündelt die verschlüsselten Fragmente eines Anhangs für den Up- oder Download.
/// </summary>
public class AttachmentResponse
{
    /// <summary>
    /// Die globale eindeutige Identifikationsnummer (UUID v4) des Anhangs.
    /// </summary>
    [JsonPropertyName("attachment_uuid")]
    public string AttachmentUuid { get; init; } = string.Empty;
    
    /// <summary>
    /// Die globale UUID des Tresoreintrags, zu dem dieser Anhang gehört.
    /// </summary>
    [JsonPropertyName("entry_uuid")] 
    public string EntryUuid { get; init; } = string.Empty;
    
    /// <summary>
    /// Der verschlüsselte Metadaten-Container (JSON) als Base64-kodierter String.
    /// Enthält Informationen wie Filename, Mime-Type und Thumbnail.
    /// </summary>
    [JsonPropertyName("encrypted_meta")] 
    public string EncryptedMeta { get; init; } = string.Empty; // Base64
    
    /// <summary>
    /// Der verschlüsselte Dateiinhalt als Base64-kodierter String.
    /// </summary>
    [JsonPropertyName("encrypted_content")] 
    public string EncryptedContent { get; init; } = string.Empty; // Base64
}
