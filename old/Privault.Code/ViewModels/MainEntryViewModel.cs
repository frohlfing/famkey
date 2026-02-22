using CommunityToolkit.Mvvm.ComponentModel;
using Privault.Core.Models.Entities;
using Privault.Core.Models.Payloads;

namespace Privault.Core.ViewModels;

/// <summary>
/// Das <see cref="MainEntryViewModel"/> dient als Daten-Wrapper für die Anzeige eines Tresoreintrags in der Hauptansicht.
/// </summary>
public class MainEntryViewModel : ObservableObject
{
    // ------------------------------------------------------------------------
    // --- Eigenschaften ---
    // ------------------------------------------------------------------------
    
    /// <summary>
    /// Der Name der Kategorie (unverschlüsselt aus der Datenbank).
    /// </summary>
    public string Category { get; init; } = string.Empty;

    /// <summary>
    /// Der Name des Erstellers, falls dieser angezeigt werden soll (z.B. bei geteilten Einträgen).
    /// </summary>
    public string CreatorName { get; set; } = string.Empty;

    /// <summary>
    /// Liefert den aufbereiteten Untertitel für die Liste (z.B. "google.com • mein_user").
    /// </summary>
    public string DisplaySubtitle
    {
        get
        {
            var displayUrl = !string.IsNullOrWhiteSpace(Url) ? Url : (Payload?.Url ?? string.Empty);
            var displayUser = Payload?.Username ?? string.Empty;

            var hasUrl = !string.IsNullOrWhiteSpace(displayUrl);
            var hasUser = !string.IsNullOrWhiteSpace(displayUser);

            if (hasUrl && hasUser) 
                return $"{displayUrl} • {displayUser}";
            
            return hasUrl ? displayUrl : (hasUser ? displayUser : string.Empty);
        }
    }
    
    /// <summary>
    /// Liefert den Anzeigenamen des Eintrags. Bevorzugt das unverschlüsselte Titelfeld.
    /// </summary>
    public string DisplayTitle => !string.IsNullOrWhiteSpace(Title) ? Title : (Payload?.Title ?? "Unbekannt");

    /// <summary>
    /// Die zugrundeliegende Datenbank-Entität des Eintrags.
    /// </summary>
    public EntryEntity Entry { get; init; } = null!;
    
    /// <summary>
    /// Base64 des Favicons (oder leer), UI wandelt das in ein Bild um (für MAUI Converter / Blazor img-tag).
    /// </summary>
    public string FaviconBase64 => !string.IsNullOrWhiteSpace(Entry.Favicon) ? Entry.Favicon : (Payload?.Favicon ?? string.Empty);
    
    /// <summary>
    /// Optionale Notizen zum Eintrag (unverschlüsseltes Feld).
    /// </summary>
    public string Notes { get; init; } = string.Empty;
    
    /// <summary>
    /// Der entschlüsselte Inhalt des Eintrags (optional, falls bereits geladen).
    /// </summary>
    public EntryPayload? Payload { get; init; }
    
    /// <summary>
    /// Steuert, ob der Name des Erstellers in der UI eingeblendet werden soll.
    /// </summary>
    public bool ShowCreatorName { get; set; }
    
    /// <summary>
    /// Der Titel des Eintrags (unverschlüsselt aus der Datenbank).
    /// </summary>
    public string Title { get; init; } = string.Empty;

    /// <summary>
    /// Die URL des Eintrags (unverschlüsselt aus der Datenbank).
    /// </summary>
    public string Url { get; init; } = string.Empty;
}