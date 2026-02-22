using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Privault.Core.Models.Entities;

namespace Privault.Core.ViewModels;

/// <summary>
/// Das <see cref="DetailFriendViewModel"/> repräsentiert einen Freund innerhalb der 
/// Berechtigungsverwaltung eines Tresoreintrags.
/// <para>
/// <b>Hauptaufgaben:</b>
/// <list type="bullet">
/// <item>Anzeige von Kontaktinformationen (Name) in der Detailansicht.</item>
/// <item>Verwaltung und Umschaltung der Berechtigungsstufen (Kein Zugriff, Lesen, Schreiben).</item>
/// <item>Benachrichtigung des übergeordneten ViewModels bei Änderungen über einen Callback.</item>
/// </list>
/// </para>
/// </summary>
/// <remarks>
/// Die Berechtigungsstufen sind wie folgt definiert:
/// <list type="number">
/// <item><description>0 = Kein Zugriff</description></item>
/// <item><description>1 = Leserechte</description></item>
/// <item><description>2 = Schreibrechte</description></item>
/// </list>
/// </remarks>
public partial class DetailFriendViewModel : ObservableObject
{
    // ------------------------------------------------------------------------
    // --- Eigenschaften ---
    // ------------------------------------------------------------------------

    /// <summary>
    /// Die zugrundeliegende Benutzer-Entität.
    /// Muss im Objekt-Initialisierer gesetzt werden (<c>new DetailFriendViewModel {User = u})</c>).
    /// </summary>
    public UserEntity User { get; init; } = null!; // "init" sorgt dafür, dass die Entität nach der Erstellung nicht mehr geändert werden kann 

    /// <summary>
    /// Der Name des Freundes.
    /// </summary>
    public string Name => User.Name; // berechnete Eigenschaft ist Best Practice für Read-Only

    /// <summary>
    /// Die aktuelle Berechtigungsstufe des Benutzers für den gewählten Eintrag.
    /// 0 = Kein Zugriff, 1 = Lesen, 2 = Schreiben
    /// </summary>
    [ObservableProperty] 
    private int _accessLevel; // muss [ObservableProperty] sein, um UI-Updates zu triggern

    /// <summary>
    /// Ein Callback, der aufgerufen wird, wenn sich die Berechtigungsstufe ändert.
    /// Ermöglicht dem übergeordneten ViewModel die sofortige Speicherung in der Datenbank.
    /// </summary>
    public Action<DetailFriendViewModel>? OnChanged { get; init; }

    // ------------------------------------------------------------------------
    // --- Befehle ---
    // ------------------------------------------------------------------------
    
    /// <summary>
    /// Setzt die Berechtigungsstufe basierend auf einem übergebenen String-Wert (aus der UI).
    /// </summary>
    /// <param name="level">
    /// Die neue Stufe als String (wird in <see cref="int"/> umgewandelt).
    /// </param>
    [RelayCommand]
    private void SetLevel(string level)
    {
        AccessLevel = int.Parse(level);
    }
    
    // ------------------------------------------------------------------------
    // --- Ereignishandler  ---
    // ------------------------------------------------------------------------
    
    /// <summary>
    /// Wird ausgelöst, wenn die Eigenschaft <see cref="AccessLevel"/> geändert wird (ist so CommunityToolkit.Mvvm automatisch verdrahtet).
    /// Triggert den <see cref="OnChanged"/> Callback für das übergeordnete ViewModel.
    /// </summary>
    /// <param name="value">
    /// Der neue Wert der Berechtigungsstufe.
    /// </param>
    /// ReSharper disable once UnusedParameterInPartialMethod
    partial void OnAccessLevelChanged(int value)
    {
        OnChanged?.Invoke(this);
    }
}