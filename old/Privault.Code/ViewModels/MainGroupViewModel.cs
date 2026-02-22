using System.Collections.ObjectModel;

// ReSharper disable UnusedAutoPropertyAccessor.Global

namespace Privault.Core.ViewModels;

/// <summary>
/// Das <see cref="MainGroupViewModel"/> dient zur Gruppierung von Tresoreinträgen in der Hauptansicht.
/// Es repräsentiert eine Kategorie (z.B. "Soziale Medien" oder "Banking") und hält die zugehörigen Einträge.
/// <para>
/// <b>Hauptaufgaben:</b>
/// <list type="bullet">
/// <item>Verwaltung der Gruppenüberschrift (Kategoriename).</item>
/// <item>Bereitstellung einer Liste von <see cref="MainEntryViewModel"/> Objekten.</item>
/// <item>Steuerung des visuellen Zustands (erweitert/eingeklappt) für die UI.</item>
/// </list>
/// </para>
/// </summary>
/// <remarks>
/// Diese Klasse erbt von <see cref="ObservableCollection{T}"/>, um direkt als Datenquelle für gruppierte 
/// Listen in MAUI (z.B. CollectionView mit IsGrouped="True") zu fungieren.
/// </remarks>
public class MainGroupViewModel : ObservableCollection<MainEntryViewModel>
{
    // ------------------------------------------------------------------------
    // --- Konstruktor ---
    // ------------------------------------------------------------------------

    /// <summary>
    /// Initialisiert eine neue Gruppe mit einem Namen und einer optionalen Liste von Einträgen.
    /// </summary>
    /// <param name="name">
    /// Der Name der Kategorie, der als Gruppenkopf angezeigt wird.
    /// </param>
    /// <param name="entries">
    /// Eine initiale Liste von Einträgen für diese Gruppe.
    /// </param>
    /// <param name="isExpanded">
    /// Gibt an, ob die Gruppe initial ausgeklappt sein soll.
    /// </param>
    /// <param name="defaultName">
    /// Fallback-Name, falls <paramref name="name"/> leer oder null ist.
    /// </param>
    public MainGroupViewModel(
        string name, 
        List<MainEntryViewModel> entries, 
        bool isExpanded, 
        string defaultName) 
        : base(isExpanded ? entries : [])
    {
        TotalCount = entries.Count;
        IsExpanded = isExpanded;
        Name = string.IsNullOrWhiteSpace(name) ? defaultName : name;
    }
    
    // ------------------------------------------------------------------------
    // --- Eigenschaften ---
    // ------------------------------------------------------------------------
    
    /// <summary>
    /// Die Gesamtzahl der Einträge in dieser Gruppe (unabhängig davon, ob sie gerade angezeigt werden).
    /// </summary>
    public int TotalCount { get; private set; }
    
    /// <summary>
    /// Ruft ab oder legt fest, ob die Gruppe erweitert (ausgeklappt) dargestellt werden soll.
    /// </summary>
    // ReSharper disable once MemberCanBePrivate.Global
    public bool IsExpanded { get; private set; }
    
    /// <summary>
    /// Der Anzeigename der Gruppe (Kategorie).
    /// </summary>
    public string Name { get; private set; }
    
    /// <summary>
    /// Liefert ein Icon-Symbol passend zum aktuellen Erweiterungszustand (Pfeil nach unten/rechts).
    /// </summary>
    public string StateIcon => IsExpanded ? "▼" : "▶";
}