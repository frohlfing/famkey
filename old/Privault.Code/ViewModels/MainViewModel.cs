using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Privault.Core.Services.Contracts;
using System.Collections.ObjectModel;

namespace Privault.Core.ViewModels;

/// <summary>
/// Das <see cref="MainViewModel"/> steuert die Hauptansicht der Anwendung.
/// Es verwaltet die Anzeige, Filterung und Gruppierung aller Tresoreinträge und orchestriert die Synchronisation.
/// <para>
/// <b>Kernfunktionalitäten:</b>
/// <list type="bullet">
/// <item>Effizientes Laden von Eintrags-Metadaten ohne vollständige Entschlüsselung.</item>
/// <item>Echtzeit-Filterung nach Text (Titel, URL, Notizen) und Urheberschaft.</item>
/// <item>Kategorienbasierte Gruppierung inklusive Verwaltung des Aufklapp-Zustands.</item>
/// <item>Integration des <see cref="ISyncService"/> für den Datenabgleich mit dem Server.</item>
/// <item>Sicherer Logout-Prozess mit Bereinigung des Dateicaches.</item>
/// </list>
/// </para>
/// </summary>
public partial class MainViewModel : ObservableObject
{
    // ------------------------------------------------------------------------
    // --- Felder ---
    // ------------------------------------------------------------------------
    
    private readonly ICacheService _cacheService;
    private readonly IConfigService _configService;
    private readonly IDatabaseService _databaseService;
    private readonly ISessionService _sessionService;
    private readonly ISyncService _syncService;
    private readonly IUiService _uiService;

    private readonly List<MainEntryViewModel> _allEntries = [];
    private readonly HashSet<string> _collapsedGroups = []; // Speichert, welche Gruppen gerade eingeklappt sind

    // ------------------------------------------------------------------------
    // --- Konstruktor und Ladevorgang ---
    // ------------------------------------------------------------------------
    
    /// <summary>
    /// Initialisiert eine neue Instanz des <see cref="MainViewModel"/>.
    /// </summary>
    /// <param name="cacheService">Dienst für Cache-Operationen.</param>
    /// <param name="configService">Dienst für globale App-Konfigurationen.</param>
    /// <param name="databaseService">Dienst für den Datenbankzugriff.</param>
    /// <param name="sessionService">Dienst für die aktuelle Sitzungsverwaltung.</param>
    /// <param name="syncService">Dienst für die Synchronisation mit dem Server.</param>
    /// <param name="uiService">UI-Abstraktion (Dialoge, Navigation, Toast).</param>
    /// <exception cref="ArgumentNullException">Wird geworfen, wenn ein benötigter Dienst null ist.</exception>
    public MainViewModel(
        ICacheService cacheService,
        IConfigService configService, 
        IDatabaseService databaseService, 
        ISessionService sessionService, 
        ISyncService syncService,
        IUiService uiService)
    {
        _cacheService = cacheService ?? throw new ArgumentNullException(nameof(cacheService));
        _configService = configService ?? throw new ArgumentNullException(nameof(configService));
        _databaseService = databaseService ?? throw new ArgumentNullException(nameof(databaseService));
        _sessionService = sessionService ?? throw new ArgumentNullException(nameof(sessionService));
        _syncService = syncService ?? throw new ArgumentNullException(nameof(syncService));
        _uiService = uiService ?? throw new ArgumentNullException(nameof(uiService));
        
        _showOnlyMine = _configService.ShowOnlyMine;
        //VaultName = _sessionService.VaultName;
    }
    
    /// <summary>
    /// Initialisiert das ViewModel, nachdem die View geladen wurde.
    /// </summary>
    /// <remarks>
    /// Dieser Befehl wird über die View (per Code-Behind) aufgerufen.
    /// </remarks>
    [RelayCommand]
    private async Task InitializeAsync()
    {
        if (IsLoading || IsSyncing) return;
        if (_allEntries.Count > 0) return;
        try
        {
            await ReloadDataAsync();
        }
        catch (Exception ex)
        {
            await _uiService.ErrorAsync(ex.Message);
        }
    }
    
    // ------------------------------------------------------------------------
    // --- Eigenschaften ---
    // ------------------------------------------------------------------------
    
    /// <summary>
    /// Die nach Kategorien gruppierten Einträge für die UI-Liste.
    /// </summary>
    [ObservableProperty] 
    private ObservableCollection<MainGroupViewModel> _groupedEntries = [];
    
    /// <summary>
    /// Gibt an, ob Freunde hinzugefügt wurden.
    /// </summary>
    [ObservableProperty] 
    private bool _hasFriends;
    
    /// <summary>
    /// Signalisiert, ob gerade ein Ladevorgang aktiv ist.
    /// </summary>
    [ObservableProperty] 
    private bool _isLoading;

    // /// <summary>
    // /// Signalisiert verzögert, ob ein Ladevorgang aktiv ist.
    // /// </summary>
    // [ObservableProperty] 
    // private bool _showLoadingIndicator;
    
    /// <summary>
    /// Signalisiert, ob gerade eine Synchronisation aktiv ist.
    /// </summary>
    [ObservableProperty]
    private bool _isSyncing;
    
    /// <summary>
    /// Gibt an, ob die Liste nach Anwendung aller Filter leer ist.
    /// </summary>
    [ObservableProperty]
    private bool _isListEmpty;
    
    /// <summary>
    /// Der aktuelle Suchtext für die Filterung der Liste.
    /// </summary>
    [ObservableProperty]
    private string _searchText = string.Empty;
    
    /// <summary>
    /// Filter-Schalter: Falls <c>true</c>, werden nur vom aktuellen Benutzer erstellte Einträge angezeigt.
    /// </summary>
    [ObservableProperty]
    private bool _showOnlyMine;
    
    /// <summary>
    /// Der Name des Tresors.
    /// </summary>
    //[ObservableProperty] 
    //private string _vaultName = "";
    public string VaultName => _sessionService.VaultName; // todo was ist Best Practice? Berechnete Methode oder ObservableProperty
    
    // ------------------------------------------------------------------------
    // --- Befehle ---
    // ------------------------------------------------------------------------

    /// <summary>
    /// Öffnet die Editierseite für die Erstellung eines neuen Eintrags.
    /// </summary>
    [RelayCommand]
    private async Task AddEntryAsync()
    {
        if (IsLoading) return;
        IsLoading = true;
        try
        {
            await _uiService.NavigateAsync("edit");
        }
        catch (Exception ex)
        {
            await _uiService.ErrorAsync($"Edit-Navigation fehlgeschlagen: {ex.Message}");
        }
        finally
        {
            IsLoading = false;
        }   
    }
    
    /// <summary>
    /// Meldet den Benutzer ab, schließt die Datenbank und bereinigt den Arbeitsspeicher sowie den Cache.
    /// </summary>
    [RelayCommand]
    private async Task LogoutAsync()
    {
        if (IsLoading) return;
        IsLoading = true;
        try
        {
            // Datenbank schließen
            await _databaseService.CloseConnectionAsync();

            // Sensible Daten aus dem RAM wischen
            _sessionService.ClearSession();
        
            // Gesamten Cache-Ordner leeren
            await _cacheService.ClearCacheAsync();
            
            // Liste leeren
            _allEntries.Clear();

            // Zurück zur Login-Seite springen (und dabei den Navigationsstack zurücksetzen)
            await _uiService.NavigateAsync("/login");
        }
        catch (Exception ex)
        {
            await _uiService.ErrorAsync($"Logout-Navigation fehlgeschlagen: {ex.Message}");
        }
        finally
        {
            IsLoading = false;
        }
    } 
    
    /// <summary>
    /// Öffnet die Detailansicht für einen bestimmten Eintrag.
    /// </summary>
    /// <param name="item">Das gewählte Eintrags-ViewModel.</param>
    [RelayCommand]
    private async Task OpenEntryAsync(MainEntryViewModel item)
    {
        if (IsLoading) return;
        IsLoading = true;
        try
        {
            await _uiService.NavigateAsync("detail", new Dictionary<string, object> { { "id", item.Entry.Id } });
        }
        catch (Exception ex)
        {
            await _uiService.ErrorAsync($"Open-Navigation fehlgeschlagen: {ex.Message}");
        }
        finally
        {
            IsLoading = false;
        }   
    }
    
    /// <summary>
    /// Öffnet die Einstellungen.
    /// </summary>
    [RelayCommand]
    private async Task OpenSettingsAsync()
    {
        if (IsLoading) return;
        IsLoading = true;
        try
        {
            await _uiService.NavigateAsync("settings");
        }
        catch (Exception ex)
        {
            await _uiService.ErrorAsync($"Settings-Navigation fehlgeschlagen: {ex.Message}");
        }
        finally
        {
            IsLoading = false;
        }   
        
    }
    
    /// <summary>
    /// Lädt die Daten aus der Datenbank und aktualisiert die Liste.
    /// </summary>
    [RelayCommand]
    private async Task ReloadDataAsync()
    {
        IsLoading = true;
        try
        {
            // 1. Einträge laden (nur die Metadaten aus der DB)
            var dbEntries = await _databaseService.GetEntriesAsync();
            var users = await _databaseService.GetUsersAsync();
            var myId = _sessionService.User?.Id ?? 0;

            // Prüfen, ob es überhaupt Freunde gibt (der nicht ausgeblendet ist)
            HasFriends = users.Any(u => u.Id != myId && !u.IsHidden);

            _allEntries.Clear();
        
            // Liste aufbauen (ohne Entschlüsselung)
            foreach (var entry in dbEntries)
            {
                // Wir erzeugen das Item-ViewModel direkt aus den Entity-Feldern.
                // Payload bleibt null, bis der User den Eintrag öffnet.
                var item = new MainEntryViewModel 
                { 
                    Entry = entry,
                    Payload = null, // Wird erst in der Detail-Ansicht entschlüsselt
                    Category = entry.Category,
                    Title = entry.Title,
                    Url = entry.Url,
                    Notes = entry.Notes
                };
            
                // Ersteller-Name auflösen
                var creator = users.FirstOrDefault(u => u.Id == item.Entry.CreatorId);
                item.CreatorName = creator?.Name ?? "Unbekannt";
                item.ShowCreatorName = item.Entry.CreatorId != myId;

                _allEntries.Add(item);
            }

            ApplyFilter(SearchText);        
        }
        finally
        {
            IsLoading = false;
        }
    }
    
    /// <summary>
    /// Startet den Synchronisationsprozess mit dem konfigurierten Server.
    /// </summary>
    [RelayCommand]
    private async Task SyncAsync()
    {
        if (IsLoading || IsSyncing) return;
        IsSyncing = true;
        try
        {
            // Check: Haben wir überhaupt einen Host konfiguriert? (aus den Vault-Settings)
            var host = _sessionService.Settings?.Host ?? string.Empty;
        
            if (string.IsNullOrEmpty(host))
            {
                await _uiService.InfoAsync("Bitte konfiguriere erst den Sync-Server in den Einstellungen.");
                return;
            }
            
            // Die Registrierung passiert vollautomatisch im Service.
            var stats = await _syncService.SyncAsync();
        
            // Daten neu laden (direkter Aufruf der internen Methode)
            await ReloadDataAsync();
            
            // Erfolgsmeldung
            await _uiService.InfoAsync($"Synchronisation erfolgreich abgeschlossen:\n\n{stats}");
        }
        catch (Exception ex)
        {
            await _uiService.ErrorAsync(ex.Message);    
        }
        finally
        {
            IsSyncing = false;
        }
    }

    /// <summary>
    /// Schaltet den Erweiterungszustand (aufgeklappt/zugeklappt) einer Gruppe um.
    /// </summary>
    /// <param name="groupViewModel">Die betroffene Gruppe.</param>
    [RelayCommand]
    private void ToggleGroup(MainGroupViewModel groupViewModel)
    {
        // Zustand umschalten
        // ReSharper disable once CanSimplifySetAddingWithSingleCall
        if (_collapsedGroups.Contains(groupViewModel.Name))
        {
            _collapsedGroups.Remove(groupViewModel.Name);
        }
        else
        {
            _collapsedGroups.Add(groupViewModel.Name);
        }
        
        // Liste neu berechnen
        ApplyFilter(SearchText);
    }
    
    // /// <summary>
    // /// Öffnet das Header-Kontextmenü (Hamburger) und führt die ausgewählte Aktion aus.
    // /// </summary>
    // [RelayCommand]
    // private async Task OpenHeaderMenuAsync()
    // {
    //     var action = await _uiService.ActionSheetAsync(
    //         title: "Menü",
    //         cancel: "Abbrechen",
    //         destruction: null,
    //         "Sync",
    //         "Setup",
    //         "Logout");
    //
    //     if (string.IsNullOrWhiteSpace(action) || action == "Abbrechen")
    //         return;
    //
    //     switch (action)
    //     {
    //         case "Sync":
    //             await SyncAsync();
    //             break;
    //
    //         case "Setup":
    //             await OpenSettingsAsync();
    //             break;
    //
    //         case "Logout":
    //             await LogoutAsync();
    //             break;
    //     }
    // }
    
    // ------------------------------------------------------------------------
    // --- Ereignishandler ---
    // ------------------------------------------------------------------------

    // /// <summary>
    // /// Wird aufgerufen, wenn IsLoading geändert wird.
    // /// Schaltet den Ladeindikator verzögert ein bzw. sofort aus.
    // /// </summary>
    // /// <param name="value"></param>
    // partial void OnIsLoadingChanged(bool value)
    // {
    //     if (value)
    //         _ = DelayLoadingIndicatorAsync(); // fire-and-forget
    //     else
    //         ShowLoadingIndicator = false;
    // }
    
    /// <summary>
    /// Reagiert auf die Änderung des Suchtextes und aktualisiert die Filterung.
    /// </summary>
    /// <param name="value">Der neue Suchstring.</param>
    partial void OnSearchTextChanged(string value)
    {
        ApplyFilter(value);
    }

    /// <summary>
    /// Reagiert auf die Änderung des "Nur eigene"-Filters und speichert die Einstellung global.
    /// </summary>
    /// <param name="value">Der neue Filterzustand.</param>
    partial void OnShowOnlyMineChanged(bool value)
    {
        _configService.ShowOnlyMine = value; 
        ApplyFilter(SearchText);
    }
    
    // ------------------------------------------------------------------------
    // --- Private Methoden ---
    // ------------------------------------------------------------------------

    /// <summary>
    /// Filtert die Liste der Einträge basierend auf dem Suchtext und dem Ersteller-Filter und gruppiert das Ergebnis.
    /// </summary>
    /// <param name="filterText">Die Zeichenkette, nach der gesucht werden soll.</param>
    private void ApplyFilter(string filterText)
    {
        IEnumerable<MainEntryViewModel> list = _allEntries;

        // 1) Ersteller-Filter: Nur eigene Einträge anzeigen?
        if (ShowOnlyMine)
        {
            var myId = _sessionService.User?.Id ?? 0;
            list = list.Where(e => e.Entry.CreatorId == myId);
        }

        // 2) Textsuche
        if (!string.IsNullOrWhiteSpace(filterText))
        {
            var q = filterText.ToLowerInvariant();
            list = list.Where(e => 
                (e.Title.ToLowerInvariant().Contains(q)) ||
                //(e.Category.ToLowerInvariant().Contains(q)) ||
                (e.Url.ToLowerInvariant().Contains(q)) ||
                (e.Notes.ToLowerInvariant().Contains(q)));
        }
        
        // Prüfen, ob nach Filterung überhaupt noch etwas übrig ist
        var filteredList = list.ToList();
        IsListEmpty = !filteredList.Any();

        // 3) Gruppierung anwenden
        var defaultCat = _sessionService.Settings?.CategoryPlaceholder ?? "Allgemein";
        var grouped = filteredList
            .GroupBy(e => e.Category)
            .Select(g => 
            {
                var categoryName = string.IsNullOrWhiteSpace(g.Key) ? defaultCat : g.Key;
                var isExpanded = !_collapsedGroups.Contains(categoryName);
                return new MainGroupViewModel(categoryName, g.OrderBy(x => x.Title).ToList(), isExpanded, defaultCat);
            })
            .OrderBy(g => g.Name == defaultCat) // Leere Kategorien nach unten
            .ThenBy(g => g.Name)                // Dann alphanumerisch nach Kategorienamen
            .ToList();
        
        // Kompletter Austausch der Collection zur Vermeidung von UI-Deadlocks in MAUI CollectionView.
        GroupedEntries = new ObservableCollection<MainGroupViewModel>(grouped);
    }
    
    // /// <summary>
    // /// Schaltet im Ladeprozess den Ladeindikator verzögert ein.
    // /// </summary>
    // private async Task DelayLoadingIndicatorAsync()
    // {
    //     await Task.Delay(250);
    //     if (IsLoading)
    //     {
    //         ShowLoadingIndicator = true;
    //     }
    // }
 }