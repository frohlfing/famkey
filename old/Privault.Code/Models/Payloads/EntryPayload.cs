using Privault.Core.Models.Entities;

namespace Privault.Core.Models.Payloads;

/// <summary>
/// Repräsentiert einen verschlüsselten Tresoreintrag.
/// Dieses Objekt wird als JSON serialisiert und anschließend mittels AES-256-GCM verschlüsselt 
/// in der Spalte <c>EncryptedData</c> der <see cref="EntryEntity"/> gespeichert.
/// </summary>
public class EntryPayload
{
    /// <summary>
    /// Die Kategorie des Eintrags.
    /// </summary>
    public string Category { get; init; } = string.Empty;
    
    /// <summary>
    /// Der Anzeigename oder Titel des Eintrags.
    /// </summary>
    public string Title { get; init; } = string.Empty;
    
    /// <summary>
    /// Der Benutzername für diesen Eintrag.
    /// </summary>
    public string Username { get; init; } = string.Empty;
    
    /// <summary>
    /// Das Passwort des Eintrags.
    /// </summary>
    public string Password { get; init; } = string.Empty;
    
    /// <summary>
    /// Die zugehörige Web-Adresse.
    /// </summary>
    public string Url { get; init; } = string.Empty;
    
    /// <summary>
    /// Ergänzende Notizen zum Eintrag.
    /// </summary>
    public string Notes { get; init; } = string.Empty;
    
    /// <summary>
    /// Der binäre Dateninhalt des Website-Icons (Favicon) als Base64-String.
    /// </summary>
    public string Favicon { get; init; } = string.Empty;
}
