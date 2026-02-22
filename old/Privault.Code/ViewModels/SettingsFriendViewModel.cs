using CommunityToolkit.Mvvm.ComponentModel;
using Privault.Core.Models.Entities;
using Privault.Core.Services.Contracts;

namespace Privault.Core.ViewModels;

/// <summary>
/// Das <see cref="SettingsFriendViewModel"/> dient als spezialisiertes Datenmodell für die UI-Darstellung
/// von Freunden innerhalb der Tresor-Einstellungen.
/// <para>
/// <b>Hauptaufgaben:</b>
/// <list type="bullet">
/// <item>Aufbereitung von Benutzerdaten (<see cref="UserEntity"/>) für die Listenansicht.</item>
/// <item>Berechnung und Bereitstellung des kryptografischen Fingerprints zur Identitätsprüfung.</item>
/// <item>Synchronisation des Verifizierungsstatus zwischen UI und Datenmodell.</item>
/// </list>
/// </para>
/// <para>
/// <b>Kryptografie:</b>
/// Die Klasse nutzt den <see cref="ICryptoService"/>, um aus dem öffentlichen RSA-Schlüssel eines Benutzers
/// einen SHA-256 Fingerprint zu erzeugen. Dieser Fingerprint ist die Basis für das "Out-of-Band" Vertrauensmodell
/// (Benutzer vergleichen Fingerprints über einen sicheren Drittkanal).
/// </para>
/// </summary>
/// <remarks>
/// Dieses ViewModel wird typischerweise in einer <see cref="System.Collections.ObjectModel.ObservableCollection{T}"/> 
/// innerhalb des <c>SettingsViewModel</c> verwendet.
/// </remarks>
/// <example>
/// <code>
/// var item = new SettingsFriendViewModel(cryptoService) { User = userEntity };
/// FriendsList.Add(item);
/// </code>
/// </example>
public class SettingsFriendViewModel : ObservableObject
{
    // ------------------------------------------------------------------------
    // --- Felder ---
    // ------------------------------------------------------------------------
    
    private readonly ICryptoService _cryptoService;
    private readonly IDatabaseService _databaseService;
    
    private bool _needsRekeying;
    
    // ------------------------------------------------------------------------
    // --- Konstruktor ---
    // ------------------------------------------------------------------------
    
    /// <summary> 
    /// Initialisiert eine neue Instanz der <see cref="SettingsFriendViewModel"/> Klasse.
    /// </summary>
    /// <param name="cryptoService">Der Dienst für kryptografische Operationen.</param>
    /// <param name="databaseService">Der Dienst für den Datenbankzugriff.</param>
    /// <exception cref="ArgumentNullException">Wird geworfen, wenn der cryptoService null ist.</exception>
    public SettingsFriendViewModel(
        ICryptoService cryptoService, 
        IDatabaseService databaseService)
    {
        _cryptoService = cryptoService ?? throw new ArgumentNullException(nameof(cryptoService));
        _databaseService = databaseService ?? throw new ArgumentNullException(nameof(databaseService));
    }
    
    // ------------------------------------------------------------------------
    // --- Eigenschaften ---
    // ------------------------------------------------------------------------

    /// <summary>
    /// Die zugrundeliegende Benutzer-Entität.
    /// Muss im Objekt-Initialisierer gesetzt werden (<c>new SettingsFriendViewModel {User = u})</c>).
    /// </summary>
    public UserEntity User { get; init; } = null!; // "init" sorgt dafür, dass die Entität nach der Erstellung nicht mehr geändert werden kann 

    /// <summary>
    /// Ruft den Anzeigenamen des Freundes ab.
    /// </summary>
    public string Name => User.Name; // berechnete Eigenschaft ist Best Practice für Read-Only

    /// <summary>
    /// Berechnet den SHA-256 Fingerprint über den CryptoService basierend auf dem Public Key.
    /// </summary>
    public string Fingerprint => _cryptoService.Fingerprint(User.PublicKey).Replace(":", ":\u200B"); // unsichtbares Leerzeichen für Zeilenumbruch

    /// <summary>
    /// Signalisiert der UI, ob für diesen Freund Einträge neu verschlüsselt werden müssen.
    /// Dies ist der Fall, wenn sein RSA-Key geändert wurde und die lokalen Permission-Keys geleert wurden.
    /// </summary>
    public bool NeedsRekeying
    {
        get => _needsRekeying;
        private set => SetProperty(ref _needsRekeying, value);
    }
    
    /// <summary>
    /// Wrapper für den Verifizierungsstatus des Freundes.
    /// Aktualisiert bei Änderung auch den Warnstatus für geänderte Fingerprints.
    /// </summary>
    public bool IsVerified
    {
        get => User.IsVerified;
        set
        {
            if (User.IsVerified == value) return;
            User.IsVerified = value;
            OnPropertyChanged(); // Aktualisiert IsVerified in der UI
        }
    }
    
    // ------------------------------------------------------------------------
    // --- Öffentliche Methoden ---
    // ------------------------------------------------------------------------
    
    /// <summary>
    /// Aktualisiert den Rekeying-Status basierend auf dem aktuellen Zustand der Datenbank.
    /// </summary>
    /// <exception cref="ArgumentNullException">Wird geworfen, wenn der databaseService null ist.</exception>
    public async Task RefreshStatusAsync()
    {
        NeedsRekeying = await _databaseService.HasAccessWithoutKeyAsync(User.Id);
    }
}