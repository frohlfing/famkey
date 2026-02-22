using System.Text.Json.Serialization;

namespace Privault.Core.Models.DTOs;

/// <summary>
/// Antwort des Servers für die Daten eines Benutzers
/// </summary>
public class UserResponse
{
    /// <summary>
    /// Die globale eindeutige Identifikationsnummer (UUID v4) des Benutzers.
    /// </summary>
    [JsonPropertyName("user_uuid")] 
    public string UserUuid { get; init; } = string.Empty;

    /// <summary>
    /// Die globale eindeutige Identifikationsnummer (UUID v4) des Tresors.
    /// </summary>
    [JsonPropertyName("vault_uuid")] 
    public string VaultUuid { get; init; } = string.Empty;

    /// <summary>
    /// Der SHA-256-Hash des Benutzernamens.
    /// </summary>
    [JsonPropertyName("user_hash")] 
    public string UserHash { get; init; } = string.Empty;
    
    /// <summary>
    /// Das serverseitig gespeicherte Salt des Benutzers zur Ableitung des Master-Keys.
    /// </summary>
    [JsonPropertyName("salt")] 
    public string Salt { get; init; } = string.Empty;

    /// <summary>
    /// Der öffentliche RSA-Schlüssel des Benutzers (Base64-kodierter SPKI-String).
    /// </summary>
    [JsonPropertyName("public_key")] 
    public string PublicKey { get; init; } = string.Empty;

    /// <summary>
    /// Der mit dem Master-Passwort verschlüsselte RSA-Privatschlüssel des Benutzers (Base64).
    /// </summary>
    [JsonPropertyName("encrypted_private_key")] 
    public string EncryptedPrivateKey { get; init; } = string.Empty;

    /// <summary>
    /// Die verschlüsselte Freundesliste des Benutzers (Base64).
    /// </summary>
    [JsonPropertyName("encrypted_friends")] 
    public string EncryptedFriends { get; init; } = string.Empty;
}