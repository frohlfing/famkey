using System.Text.Json.Serialization;

namespace Privault.Core.Models.DTOs;

/// <summary>
/// Repräsentiert die Antwort des Servers auf eine Versionsabfrage.
/// </summary>
public class VersionResponse
{
    [JsonPropertyName("service")] 
    public string Service { get; init; } = string.Empty;
    
    /// <summary>
    /// Die Haupt-Versionsnummer.
    /// Wird erhöht bei Schema-Änderungen, die nicht abwärtskompatibel sind.
    /// </summary>
    [JsonPropertyName("major")] 
    public int Major { get; init; }
    
    /// <summary>
    /// Die Neben-Versionsnummer.
    /// Wird erhöht, wenn das Schema abwärtskompatibel verändert wurde (z.B. neue optionale Felder)
    /// </summary>
    [JsonPropertyName("minor")] 
    public int Minor { get; init; }
    
    /// <summary>
    /// Die Revisionsnummer (Patch).
    /// Wird erhöht, wenn das Schema optimiert wurde (z.B. Index hinzugefügt/verändert)
    /// </summary>
    [JsonPropertyName("patch")] 
    public int Patch { get; init; }
    
    /// <summary>
    /// Minimal erforderliche Client-Minor-Version.
    /// </summary>
    [JsonPropertyName("required_client_minor")] 
    public int RequiredClientMinor { get; init; }
}