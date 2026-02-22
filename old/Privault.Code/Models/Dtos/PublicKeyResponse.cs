using System.Text.Json.Serialization;

namespace Privault.Core.Models.DTOs;

/// <summary>
/// Die UUID und der öffentliche RSA-Schlüssel eines Benutzers.
/// </summary>
public class PublicKeyResponse
{
    /// <summary>
    /// Die globale eindeutige Identifikationsnummer (UUID v4) des Benutzers.
    /// </summary>
    [JsonPropertyName("user_uuid")] 
    public string UserUuid { get; init; } = string.Empty;

    /// <summary>
    /// Der öffentliche RSA-Schlüssel des Benutzers (Base64-kodierter SPKI-String).
    /// </summary>
    [JsonPropertyName("public_key")] 
    public string PublicKey { get; init; } = string.Empty;
}

