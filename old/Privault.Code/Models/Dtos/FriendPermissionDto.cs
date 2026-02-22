using System.Text.Json.Serialization;

namespace Privault.Core.Models.DTOs;

/// <summary>
/// Transportobjekt für eine Zugriffsberechtigung eines Freundes innerhalb eines Eintrags.
/// </summary>
public class FriendPermissionDto
{
    /// <summary>
    /// Die globale UUID des Freundes.
    /// </summary>
    [JsonPropertyName("user_uuid")]
    public string UserUuid { get; init; } = string.Empty;

    /// <summary>
    /// Der für diesen Freund RSA-verschlüsselte Entry-Key.
    /// </summary>
    [JsonPropertyName("encrypted_key")]
    public string EncryptedKey { get; init; } = string.Empty;

    /// <summary>
    /// Die Berechtigungsstufe (1=Lesen, 2=Schreiben).
    /// </summary>
    [JsonPropertyName("access_level")]
    public int AccessLevel { get; init; }
}