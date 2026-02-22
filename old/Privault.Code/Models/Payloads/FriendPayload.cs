namespace Privault.Core.Models.Payloads;

/// <summary>
/// Repräsentiert den Status und die Identitätsdaten eines Freundes.
/// </summary>
public class FriendPayload
{
    /// <summary>
    /// Die globale eindeutige ID des Freundes.
    /// </summary>
    public string Uuid { get; init; } = string.Empty;
    
    /// <summary>
    /// Der Benutzername des Freundes.
    /// </summary>
    public string Name { get; init; } = string.Empty;
    
    /// <summary>
    /// Gibt an, ob der Freund bereits verifiziert wurde.
    /// </summary>
    public bool IsVerified { get; init; }
    
    /// <summary>
    /// Gibt an, ob der Freund in der UI ausgeblendet wurde.
    /// </summary>
    public bool IsHidden { get; init; }
    
    private readonly DateTime _updatedAt = DateTime.SpecifyKind(new DateTime(1970, 1, 1), DateTimeKind.Utc);

    /// <summary>
    /// Zeitpunkt der letzten Änderung (UTC).
    /// Dient zur Konfliktauflösung (Last-Write-Wins).
    /// </summary>
    public DateTime UpdatedAt
    {
        get => _updatedAt;
        init => _updatedAt = value.Kind == DateTimeKind.Unspecified ? DateTime.SpecifyKind(value, DateTimeKind.Utc) : value.ToUniversalTime();
    }
}
