using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Privault.Core.Models.Entities;
using Privault.Core.Services.Contracts;

namespace Privault.Core.ViewModels;

/// <summary>
/// Das <see cref="SettingsViewModel"/> ist die zentrale Logikschicht für die Einstellungsseite der Anwendung.
/// Es verwaltet die Konfiguration des aktuellen Tresors, die Synchronisationsparameter, das Erscheinungsbild 
/// sowie die Liste der Freunde.
/// <para>
/// <b>Kernfunktionalitäten:</b>
/// <list type="bullet">
/// <item>Verwaltung von Server-Verbindungsdaten (Host, API-Token).</item>
/// <item>Konfiguration des Passwort-Generators (Länge, Zeichensätze).</item>
/// <item>Steuerung der Themes.</item>
/// <item>Verwaltung von Kontakten inkl. Suche über den WebService und Verifizierung von Schlüssel-Fingerprints.</item>
/// <item>Kritische Tresor-Operationen wie Umbenennen, Löschen oder Ändern des Master-Passworts.</item>
/// </list>
/// </para>
/// <para>
/// <b>Sicherheit und Validierung:</b>
/// Sensible Aktionen (z.B. Passwortänderung) werden über den <see cref="IGuardService"/> abgesichert,
/// der eine erneute Eingabe des Master-Passworts erzwingt. Ein integrierter "Dirty-Check" verhindert das 
/// versehentliche Verlassen der Seite bei ungespeicherten Änderungen.
/// </para>
/// <para>
/// <b>Zusammenhang mit Services:</b>
/// Dieses ViewModel orchestriert fast alle Kern-Services der App, um die Brücke zwischen der verschlüsselten 
/// lokalen SQLite-Datenbank (<see cref="IDatabaseService"/>) und der Remote-API (<see cref="IWebService"/>) zu schlagen.
/// </para>
/// </summary>
public partial class SettingsViewModel : ObservableObject
{
    // ------------------------------------------------------------------------
    // --- Konstanten und Strukturen ---
    // ------------------------------------------------------------------------

    /// <summary>
    /// Standard-Satz an Sonderzeichen für den Passwortgenerator.
    /// </summary>
    private const string CharsStandard = "!@#$%^&*()_+-=[]{}|;:,.<>?";
    
    /// <summary>
    /// Erweiterter Satz an Sonderzeichen inklusive komplexerer Symbole.
    /// </summary>
    private const string CharsAll = "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~";

    /// <summary>
    /// Snapshot über die veränderlichen Eigenschaften.
    /// </summary>
    private readonly record struct SettingsSnapshot(
        string Host,
        string ApiToken,
        bool UseBiometric,
        int PwLength,
        string PwSpecialChars,
        bool PwAvoidIlO0,
        string Theme,
        string CategoryPlaceholder);
    
    // ------------------------------------------------------------------------
    // --- Felder ---
    // ------------------------------------------------------------------------
    
    private readonly IBiometricService _biometricService;
    private readonly IConfigService _configService;
    private readonly ICryptoService _cryptoService;
    private readonly IDatabaseService _databaseService;
    private readonly IGuardService _guardService;
    private readonly ISessionService _sessionService;
    private readonly IUiService _uiService;
    private readonly IWebService _webService;
    
    /// <summary>
    /// Originalwerte.
    /// <para>
    /// Wird für Dirty Check beim Abbrechen benötigt.
    /// </para>
    /// </summary>
    private SettingsSnapshot _orig;
    
    // ------------------------------------------------------------------------
    // --- Konstruktor ---
    // ------------------------------------------------------------------------
    
    /// <summary>
    /// Erzeugt eine neue Instanz des ViewModels und initialisiert die Dienste sowie den aktuellen Benutzerstatus.
    /// </summary>
    /// <param name="biometricService">Dienst für die Biometrie-Unterstützung.</param>
    /// <param name="configService">Dienst für globale App-Konfigurationen.</param>
    /// <param name="cryptoService">Dienst für kryptografische Funktionen.</param>
    /// <param name="databaseService">Dienst für den Datenbankzugriff (SQLite/SQLCipher).</param>
    /// <param name="guardService">Dienst für kritische Tresor-Operationen.</param>
    /// <param name="sessionService">Dienst zur Verwaltung der aktuellen Sitzungsdaten (RAM).</param>
    /// <param name="uiService">UI-Abstraktion (Dialoge, Navigation, Toast).</param>
    /// <param name="webService">Dienst für die Kommunikation mit der REST-API.</param>
    /// <exception cref="ArgumentNullException">Wird geworfen, wenn einer der benötigten Services null ist.</exception>
    public SettingsViewModel(
        IBiometricService biometricService,
        IConfigService configService, 
        ICryptoService cryptoService, 
        IDatabaseService databaseService, 
        IGuardService guardService,
        IUiService uiService,
        ISessionService sessionService, 
        IWebService webService) 
    {
        _biometricService = biometricService ?? throw new ArgumentNullException(nameof(biometricService));
        _configService = configService ?? throw new ArgumentNullException(nameof(configService));
        _cryptoService = cryptoService ?? throw new ArgumentNullException(nameof(cryptoService));
        _databaseService = databaseService ?? throw new ArgumentNullException(nameof(databaseService));
        _guardService = guardService ?? throw new ArgumentNullException(nameof(guardService));
        _sessionService = sessionService ?? throw new ArgumentNullException(nameof(sessionService));
        _uiService = uiService ?? throw new ArgumentNullException(nameof(uiService));
        _webService = webService ?? throw new ArgumentNullException(nameof(webService));
        
        VaultName = _sessionService.VaultName;
        UserName = _sessionService.User?.Name ?? string.Empty;
        IsRegistered = _sessionService.Settings?.LastSyncAt.Year > 1970;
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
        if (IsLoading) return;
        try
        {
            IsBiometricAvailable = await _biometricService.IsAvailableAsync();
            await LoadSettingsAsync();

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
    /// Gibt an, ob im Hintergrund eine langlaufende Operation (z.B. Netzwerkanfrage) läuft.
    /// </summary>
    [ObservableProperty] 
    private bool _isBusy;
    
    /// <summary>
    /// Gibt an, ob eine nicht gespeicherte Änderung vorliegt.
    /// </summary>
    private bool IsDirty => CaptureSnapshot() != _orig;
    
    /// <summary>
    /// Der Name des Tresors.
    /// </summary>
    [ObservableProperty] 
    private string _vaultName = "";
    
    /// <summary>
    /// Der Name des angemeldeten Benutzers innerhalb des Tresors.
    /// </summary>
    [ObservableProperty] 
    private string _userName = "";
    
    /// <summary>
    /// Gibt an, ob der Benutzer bereits mit dem Server synchronisiert wurde (registriert ist).
    /// </summary>
    [ObservableProperty] 
    private bool _isRegistered;

    /// <summary>
    /// Die Liste der Freunde, aufbereitet für die UI-Liste.
    /// </summary>
    public System.Collections.ObjectModel.ObservableCollection<SettingsFriendViewModel> Friends { get; } = [];

    /// <summary>
    /// Gibt an, ob mindestens eine Person in der Liste noch nicht verifiziert ist.
    /// </summary>
    public bool HasUnverifiedFriends => Friends.Any(f => !f.IsVerified);

    /// <summary>
    /// Die URL des Servers für die Synchronisation.
    /// </summary>
    [ObservableProperty] 
    private string _host = "";
    
    /// <summary>
    /// Das API-Token für die Authentifizierung gegenüber dem Server.
    /// </summary>
    [ObservableProperty] 
    private string _apiToken = "";

    /// <summary>
    /// Gibt an, ob Biometrie von der Hardware unterstützt wird und in der Systemeinstellung aktiviert ist.
    /// </summary>
    [ObservableProperty] 
    private bool _isBiometricAvailable;
    
    /// <summary>
    /// Gibt an, ob Fingerabdruck bzw. Gesichtserkennung als Anmeldeoption zur Verfügung steht.
    /// </summary>
    [ObservableProperty] 
    private bool _useBiometric;
    
    /// <summary>
    /// Für das Passwort-Auge. Steuert, ob das API-Token in der UI im Klartext oder verborgen (Passwortfeld) angezeigt wird.
    /// </summary>
    [ObservableProperty] 
    private bool _isTokenHidden = true;

    /// <summary>
    /// Eingestellte Länge für den Passwortgenerator.
    /// </summary>
    [ObservableProperty] 
    private int _pwLength;
    
    /// <summary>
    /// Der aktuell gewählte Satz an Sonderzeichen für generierte Passwörter.
    /// </summary>
    [ObservableProperty] 
    private string _pwSpecialCharSet = "";
    
    /// <summary>
    /// Gibt an, ob optisch ähnliche Zeichen ('I', 'l', 'O', '0') vermieden werden sollen.
    /// </summary>
    [ObservableProperty] 
    private bool _pwAvoidIlO0;
    
    /// <summary>
    /// Schalter, ob Sonderzeichen im Generator überhaupt verwendet werden sollen.
    /// </summary>
    [ObservableProperty] 
    private bool _pwSpecialChars = true;

    /// <summary>
    /// Liste der verfügbaren Theme-Arten (z.B. <c>"Modern"</c>, <c>"Classic"</c>, ...).
    /// </summary>
    public IReadOnlyList<string> ThemeKinds => _uiService.GetThemeKinds();
    
    /// <summary>
    /// Liste der verfügbaren Theme-Modes (üblicherweise <c>"System"</c>, <c>"Light"</c>, <c>"Dark"</c>).
    /// </summary>
    public IReadOnlyList<string> ThemeModes => _uiService.GetThemeModes();

    /// <summary>
    /// Die gewählte Theme-Art (z.B. <c>"Modern"</c>).
    /// </summary>
    [ObservableProperty]
    private string _themeKind = "Modern"; // todo hier _uiService.ThemeKinds.First nehmen
    
    /// <summary>
    /// Der gewählte Theme-Modus (z.B. <c>"Light"</c>).
    /// </summary>
    [ObservableProperty]
    private string _themeMode = "System"; // todo hier _uiService.ThemeMode.First nehmen

    /// <summary>
    /// Das gewählte Theme.
    /// </summary>
    private string Theme => $"{ThemeKind}.{ThemeMode}";

    /// <summary>
    /// Standardkategorie für neu erstellte Tresoreinträge.
    /// </summary>
    [ObservableProperty] 
    private string _categoryPlaceholder = "Allgemein";
    
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
    
    // ------------------------------------------------------------------------
    // --- Befehle ---
    // ------------------------------------------------------------------------

    /// <summary>
    /// Öffnet einen Dialog, um einen neuen Freund über seinen Namen im Tresor-Verbund zu suchen und hinzuzufügen.
    /// </summary>
    [RelayCommand]
    private async Task AddFriendAsync()
    {
        var name = await _uiService.PromptAsync(
            "Person suchen", 
            "Gib den exakten Namen der Person ein.");

        if (string.IsNullOrWhiteSpace(name)) return;

        try 
        {
            var userResponse = await _webService.FindUserAsync(_sessionService.VaultName, name);
            if (userResponse == null)
            {
                await _uiService.InfoAsync($"Die Person '{name}' wurde im Tresor nicht gefunden.");
                return;
            }

            // Prüfen, ob der User bereits lokal existiert (auch wenn versteckt)
            var existingUser = await _databaseService.GetUserByUuidAsync(userResponse.UserUuid);
            if (existingUser != null)
            {
                if (!existingUser.IsHidden)
                {
                    await _uiService.InfoAsync("Diese Person ist bereits in deiner Liste.");
                    return;
                }

                // Wiederherstellung eines versteckten Benutzers
                existingUser.Name = name;
                existingUser.PublicKey = userResponse.PublicKey; 
                existingUser.IsVerified = false; 
                existingUser.IsHidden = false;
                existingUser.UpdatedAt = DateTime.UtcNow;
                await _databaseService.SaveUserAsync(existingUser);
            }
            else
            {
                // Benutzer neu anlegen
                var newUser = new UserEntity
                {
                    Uuid = userResponse.UserUuid,
                    Name = name,
                    PublicKey = userResponse.PublicKey,
                    IsVerified = false,
                    IsHidden = false,
                    UpdatedAt = DateTime.UtcNow ,
                };
                await _databaseService.SaveUserAsync(newUser);
            }
            
            // UI-Liste neu laden
            await LoadFriendsAsync();
            OnPropertyChanged(nameof(HasUnverifiedFriends));
            await _uiService.InfoAsync($"'{name}' wurde hinzugefügt. Bitte verifiziere jetzt den Fingerprint.");
        }
        catch (Exception ex)
        {
            await _uiService.ErrorAsync("Suche fehlgeschlagen: " + ex.Message);
        }
    }
    
    /// <summary>
    /// Bricht den Vorgang ab und prüft vorher auf ungespeicherte Änderungen (Dirty-Check).
    /// </summary>
    [RelayCommand]
    private async Task CancelAsync()
    {
        if (IsDirty)
        {
            var save = await _uiService.ConfirmAsync(
                "Einstellungen speichern",
                "Möchtest du die Änderungen speichern?",
                "Ja, speichern",
                "Nein, verwerfen");

            if (save)
            {
                var ok = await SaveAsync();
                if (!ok) return;
            }
            else
            {
                if (Theme != _orig.Theme)
                    ResetTheme();
            }
        }

        await GoBackAsync();
    }

    /// <summary>
    /// Führt den Prozess zur Änderung des Master-Passworts inklusive Umschlüsselung der Datenbank aus.
    /// </summary>
    [RelayCommand]
    private async Task ChangeMasterPasswordAsync()
    {
        // Neues Passwort abfragen (Bevor wir die kritische Operation starten)
        var newPassword = await _uiService.PromptAsync(
            "Passwort ändern",
            "Bitte gib dein neues Master-Passwort ein:");

        if (string.IsNullOrWhiteSpace(newPassword)) return;

        // Kritische Operation ausführen
        await _guardService.ExecuteCriticalOperationAsync(
            "Passwort-Änderung bestätigen",
            "Bitte gib dein AKTUELLES Master-Passwort ein, um die Änderung zu autorisieren:",
            async (_) =>
            {
                // 1. Neues Salt generieren
                var newSalt = _cryptoService.GenerateSalt();

                // 2. Neuen Master-Key ableiten
                var newMasterKey = await _cryptoService.DeriveKeyAsync(newPassword, newSalt);
                string newEncryptedPrivKey;

                try
                {
                    if (_sessionService.PrivateKey == null) 
                        throw new InvalidOperationException("Privater Schlüssel fehlt in der Session.");

                    // 3. Private Key mit dem neuen Key verschlüsseln
                    newEncryptedPrivKey = _cryptoService.Encrypt(_sessionService.PrivateKey, newMasterKey);
                    
                    // 4. Datenbankdatei mit dem neuen Key umschlüsseln
                    await _databaseService.RekeyAsync(newMasterKey);
                    
                    // 5. Master-Key im SecureStore aktualisieren
                    if (IsBiometricAvailable && await _biometricService.ContainsMasterKeyAsync(_sessionService.VaultName))
                        await _biometricService.SaveMasterKeyAsync(_sessionService.VaultName, newMasterKey);
                }
                finally
                {
                    _cryptoService.WipeKey(newMasterKey);
                }

                // 6. Settings in DB aktualisieren
                var settings = _sessionService.Settings!;
                settings.Salt = Convert.ToBase64String(newSalt);
                settings.EncryptedPrivateKey = newEncryptedPrivKey;
                await _databaseService.SaveSettingsAsync(settings);

                // 7. Server informieren
                await _webService.ChangePasswordAsync(_sessionService.User!.Uuid, settings.Salt, settings.EncryptedPrivateKey);

                // 8. Lokale Konfiguration (Vault-Map) aktualisieren
                UpdateSaltMap(_sessionService.VaultName, settings.Salt);

                await _uiService.InfoAsync("Das Master-Passwort wurde geändert. Andere Geräte müssen bei der nächsten Synchronisation das neue Passwort eingeben.");
            }, forceLogout: false);
    }
    
    /// <summary>
    /// Entfernt einen Freund aus der Liste. Der Datensatz wird gelöscht, wenn keine Verknüpfungen bestehen, ansonsten wird er ausgeblendet.
    /// </summary>
    [RelayCommand]
    private async Task DeleteFriendAsync(SettingsFriendViewModel? item)
    {
        if (item?.User == null) return;

        var confirm = await _uiService.ConfirmAsync(
            "Person löschen", 
            $"Möchtest du '{item.User.Name}' wirklich aus deiner Liste löschen? Das Teilen von Einträgen mit dieser Person ist dann nicht mehr möglich.", 
            "Ja, löschen", 
            "Nein, abbrechen");

        if (!confirm) return;

        try
        {
            // Prüfen, ob der User überhaupt Berechtigungen hat
            var perms = await _databaseService.GetPermissionsByUserIdAsync(item.User.Id);
                
            if (perms.Count == 0)
            {
                // Es werden keine Einträge mit dem Freund geteilt, daher kann er gelöscht werden.
                await _databaseService.DeleteUserAsync(item.User.Id);
            }
            else
            {
                // Der Freund wird nicht gelöscht, sondern ausgeblendet, damit beim Synchronisieren alle geteilten Einträge entfernt werden können. 
                await _databaseService.HideUserAsync(item.User.Id);
            }

            // Aus der UI-Liste entfernen
            Friends.Remove(item);
            OnPropertyChanged(nameof(HasUnverifiedFriends));
            await _uiService.ToastAsync($"{item.User.Name} wurde entfernt");
        }
        catch (Exception ex)
        {
            await _uiService.ErrorAsync("Löschen fehlgeschlagen: " + ex.Message);
        }
    }
    
    /// <summary>
    /// Löscht den aktuellen Tresor lokal vom Gerät nach Bestätigung durch das Master-Passwort.
    /// </summary>
    [RelayCommand]
    private async Task DeleteVaultAsync()
    {
        var vault = _sessionService.VaultName;
        await _guardService.ExecuteCriticalOperationAsync(
            "Tresor löschen",
            $"Bist du sicher? Alle lokalen Daten für '{vault}' werden unwiderruflich gelöscht. Bestätige mit deinem Master-Passwort:",
            async (_) =>
            {
                // Datenbank löschen
                await _databaseService.DeleteCurrentDatabase();

                // Tresor aus der lokalen Tresorliste nehmen
                var map = _configService.Vaults;
                if (map.Remove(vault))
                    _configService.Vaults = map;
                
                // SecureStore leeren
                if (IsBiometricAvailable)
                    await _biometricService.RemoveMasterKeyAsync(_sessionService.VaultName);

            }, forceLogout: true);
    }
    
    // todo dokumentiere
    [RelayCommand]
    private Task OpenBiometricSettingsAsync() => _uiService.OpenSystemSettingsAsync("biometrics");

    [RelayCommand]
    private Task OpenAutofillSettingsAsync() => _uiService.OpenSystemSettingsAsync("autofill");

    [RelayCommand]
    private Task OpenAppSettingsAsync() => _uiService.OpenSystemSettingsAsync("app_info");

    /// <summary>
    /// Speichert die Einstellungen und schließt die Seite bei Erfolg.
    /// </summary>
    [RelayCommand]
    private async Task SaveAndExitAsync()
    {
        if (await SaveAsync())
        {
            await GoBackAsync();
        }
    }
    
    /// <summary>
    /// Speichert alle geänderten Einstellungen in der Datenbank und aktualisiert die Session.
    /// Beinhaltet Logik für die Umbenennung des Tresors.
    /// </summary>
    [RelayCommand]
    private async Task<bool> SaveAsync()
    {
        var oldVaultName = _sessionService.VaultName;
        var currentVaultName = VaultName;
        var user = _sessionService.User;
        var settings = _sessionService.Settings;
        if (user == null || settings == null) return false;

        // 1. Falls Biometrie deaktiviert wurde, SecureStore leeren
        if (IsBiometricAvailable && settings.UseBiometric && !UseBiometric)
            await _biometricService.RemoveMasterKeyAsync(VaultName);    
        
        // 2. Alle Basis-Einstellungen in der DB speichern (Host, API, PW-Gen).
        Host = NormalizeHost(Host);
        settings.Host = Host;
        settings.ApiToken = ApiToken;
        settings.UseBiometric = UseBiometric;
        settings.PwLength = PwLength;
        settings.PwSpecialChars = PwSpecialCharSet;
        settings.PwAvoidIlO0 = PwAvoidIlO0;
        settings.CategoryPlaceholder = CategoryPlaceholder;
        await _databaseService.SaveSettingsAsync(settings);
        
        // 3. Benutzername aktualisieren (falls nicht registriert)
        if (!IsRegistered && UserName != user.Name)
        {
            user.Name = UserName;
            user.UpdatedAt = DateTime.UtcNow;
            await _databaseService.SaveUserAsync(user);
        }
        
        // 4. Theme in der Konfiguration speichern
        _configService.Theme = Theme;

        // 5. Tresorname aktualisieren (falls nicht registriert)
        if (!IsRegistered && currentVaultName != oldVaultName)
        {
            // Existiert der Zielname bereits?
            if (_databaseService.DatabaseExists(currentVaultName))
            {
                await _uiService.ErrorAsync($"Ein Tresor mit dem Namen '{currentVaultName}' existiert bereits auf diesem Gerät.");
                return false;
            }
            
            // Kritische Operation: Umbenennen erfordert Passwort-Bestätigung
            return await _guardService.ExecuteCriticalOperationAsync(
                "Tresor umbenennen",
                $"Möchtest du den Tresor wirklich in '{currentVaultName}' umbenennen? Bestätige mit deinem Passwort:",
                async (masterKey) =>
                {
                    // 1. Verbindung trennen & Umbenennen
                    await _databaseService.CloseConnectionAsync();
                    _databaseService.RenameDatabase(oldVaultName, currentVaultName);
                    
                    // 2. Session im Speicher aktualisieren
                    _sessionService.VaultName = currentVaultName;
                    
                    // 3. Neue Verbindung zur umbenannten Datei herstellen
                    await _databaseService.InitializeAsync(currentVaultName, masterKey);
                    
                    // 4. Konfiguration (Login-Liste) aktualisieren
                    UpdateVaultMap(oldVaultName, currentVaultName, settings.Salt);

                    // 5. Master-Key im SecureStore umziehen
                    if (IsBiometricAvailable && await _biometricService.ContainsMasterKeyAsync(oldVaultName))
                    {
                        await _biometricService.RemoveMasterKeyAsync(oldVaultName);
                        await _biometricService.SaveMasterKeyAsync(currentVaultName, masterKey);
                    }
                    
                    await _uiService.ToastAsync($"Tresor umbenannt in '{currentVaultName}'");
                }, forceLogout: false);
        }
        
        // Speichern erfolgreich -> aktuellen Zustand merken
        _orig = CaptureSnapshot();
        return true;
    }
    
    /// <summary>
    /// Setzt den Zeichensatz für den Passwortgenerator basierend auf vordefinierten Gruppen.
    /// </summary>
    [RelayCommand]
    private void SetSpecialChars(string type)
    {
        // Setzt den Text im Eingabefeld basierend auf den Buttons
        PwSpecialCharSet = type switch
        {
            "None" => "",
            "Standard" => CharsStandard,
            "All" => CharsAll,
            _ => PwSpecialCharSet
        };
        
        // Wenn man Buttons klickt, schalten wir den Switch automatisch ein
        if (!string.IsNullOrEmpty(PwSpecialCharSet))
        {
            PwSpecialChars = true;
        }
    }
    
    /// <summary>
    /// Testet die Verbindung zum Sync-Server.
    /// </summary>
    [RelayCommand]
    private async Task TestConnectionAsync()
    {
        try
        {
            var versionResponse = await _webService.GetServerVersionAsync(Host, ApiToken);
            var version = $"{versionResponse.Service} v{versionResponse.Major}.{versionResponse.Minor}.{versionResponse.Patch}";
            await _uiService.InfoAsync($"Erfolgreich: {version}");
        }
        catch (Exception ex)
        {
            await _uiService.InfoAsync(ex.Message);
        }
    }
    
    /// <summary>
    /// Schaltet die Sichtbarkeit des API-Tokens um.
    /// </summary>
    [RelayCommand]
    private void ToggleTokenVisibility()
    {
        IsTokenHidden = !IsTokenHidden;
    }

    /// <summary>
    /// Speichert den aktualisierten Verifizierungsstatus eines Kontakts.
    /// <para>
    /// Wird aufgerufen, wenn in Settings auf die Checkbox "Verifiziert" geklickt wird.
    /// </para>
    /// <param name="item">Das ViewModel des betroffenen Freundes.</param>
    /// </summary>
    [RelayCommand]
    private async Task UpdateFriendVerificationAsync(SettingsFriendViewModel? item)
    {
        if (item?.User == null) return;
        
        try 
        {
            // Wenn verifiziert wird, fehlende Entry-Keys generieren.
            if (item.IsVerified)
            {
                await RekeyEntriesForFriendAsync(item.User);
                await item.RefreshStatusAsync();
            }
            
            // Änderung speichern
            item.User.UpdatedAt = DateTime.UtcNow;
            await _databaseService.SaveUserAsync(item.User);
            OnPropertyChanged(nameof(HasUnverifiedFriends));
            
            // Visuelles Feedback geben
            var status = item.User.IsVerified ? "verifiziert" : "unverifiziert";
            await _uiService.ToastAsync($"{item.User.Name} ist jetzt {status}");
        }
        catch (Exception ex)
        {
            await _uiService.ErrorAsync("Die Checkbox konnte nicht gespeichert werden: " + ex.Message);
        }
    }
    
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
    /// Reagiert auf Änderungen der Theme-Art und wendet das neue Erscheinungsbild sofort an.
    /// </summary>
    /// <param name="value">Die Theme-Art (z.B. <c>"Modern"</c>).</param>
    partial void OnThemeKindChanged(string value)
    {
        if (IsLoading) return;
        _ = _uiService.SetThemeAsync($"{value}.{ThemeMode}"); // fire-and-forget
    }
    
    /// <summary>
    /// Reagiert auf die Änderung des Theme-Modes und wendet das gewählte Erscheinungsbild sofort auf die Anwendung an.
    /// </summary>
    /// <param name="value">Der Theme-Mode (z.B. <c>"Light"</c>).</param>
    partial void OnThemeModeChanged(string value)
    {
        if (IsLoading) return;
        _ = _uiService.SetThemeAsync($"{ThemeKind}.{value}"); // fire-and-forget
    }

    // ------------------------------------------------------------------------
    // --- Private Methoden ---
    // ------------------------------------------------------------------------
    
    /// <summary>
    /// Macht einen Snapshot von der aktuellen Ansicht.  
    /// </summary>
    /// <returns>Der nuee Snapshot.</returns>
    private SettingsSnapshot CaptureSnapshot()
    {
        return new SettingsSnapshot(
            Host: NormalizeHost(Host),
            ApiToken: ApiToken,
            UseBiometric: UseBiometric,
            PwLength: PwLength,
            PwSpecialChars: PwSpecialCharSet,
            PwAvoidIlO0: PwAvoidIlO0,
            Theme: Theme,                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  
            CategoryPlaceholder: CategoryPlaceholder
        );
    }
    
    // /// <summary>
    // /// Schaltet im Ladeprozess den Ladeindikator verzögert ein.
    // /// </summary>
    // private async Task DelayLoadingIndicatorAsync()
    // {
    //     await Task.Delay(250);
    //     if (IsLoading)
    //         ShowLoadingIndicator = true;
    // }
    
    /// <summary>
    /// Zurück zur Liste.
    /// </summary>
    private async Task GoBackAsync()
    {
        if (IsLoading) return;
        IsLoading = true;
        try
        {
            await _uiService.NavigateAsync("..");
        }
        finally
        {
            IsLoading = false;
        }
    }
    
    /// <summary>
    /// Lädt alle Freunde aus der Datenbank und bereitet die ViewModels für die Liste vor.
    /// </summary>
    private async Task LoadFriendsAsync()
    {
        var users = await _databaseService.GetUsersAsync();
        var myUuid = _sessionService.User?.Uuid;
        Friends.Clear();
        foreach (var user in users.Where(u => u.Uuid != myUuid && !u.IsHidden))
        {
            var friendVm = new SettingsFriendViewModel(_cryptoService, _databaseService) { User = user };
            await friendVm.RefreshStatusAsync(); // Warnung für NeedsRekeying aktualisieren 
            Friends.Add(friendVm);
        }
    }

    /// <summary>
    /// Lädt die Einstellungen aus der Datenbank und initialisiert die View-Properties.
    /// </summary>
    private async Task LoadSettingsAsync()
    {
        IsLoading = true;
        try
        {
            // Einstellungen aus DB laden
            var settings = await _databaseService.GetSettingsAsync();
            if (settings == null)
            {
                // Fallback (sollte nicht passieren, DB wird bei Login/Anlage erstellt)
                settings = new SettingsEntity();
                await _databaseService.SaveSettingsAsync(settings);
            }

            // View-Properties aus Settings befüllen

            // todo Hack wieder rausnehmen !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            Host = string.IsNullOrEmpty(settings.Host) ? "https://privault.test/api" : settings.Host;
            ApiToken = string.IsNullOrEmpty(settings.ApiToken) ? "6h54qT5l2r37Kr7XxfP08YD7gPAGff6aWSaa" : settings.ApiToken;
            //Host = settings.Host ?? string.Empty;
            //ApiToken = settings.ApiToken ?? string.Empty;
            
            UseBiometric = settings.UseBiometric;
            PwLength = settings.PwLength;
            PwSpecialCharSet = string.IsNullOrEmpty(settings.PwSpecialChars) ? CharsStandard : settings.PwSpecialChars;
            PwAvoidIlO0 = settings.PwAvoidIlO0;
            PwSpecialChars = !string.IsNullOrEmpty(settings.PwSpecialChars);
            CategoryPlaceholder = settings.CategoryPlaceholder;

            // Theme-Art und -Mode aus Config lesen und auf UI anwenden
            ResetTheme();
            await _uiService.SetThemeAsync(Theme);

            // Freunde laden
            await LoadFriendsAsync();

            // aktuellen Zustand merken
            _orig = CaptureSnapshot();
            _sessionService.Settings = settings;
        }
        finally
        {
            IsLoading = false;
        }
    }

    /// <summary>
    /// Entfernt ein Slash-Zeichen am Ende der URL.
    /// </summary>
    /// <param name="host"></param>
    /// <returns></returns>
    private static string NormalizeHost(string host)
    {
        return string.IsNullOrWhiteSpace(host) ? string.Empty : host.Trim().TrimEnd('/');
    }
    
    /// <summary>
    /// Verschlüsselt alle Entry-Keys für einen Freund neu, die aufgrund eines Key-Wechsels geleert wurden.
    /// </summary>
    /// <param name="friend">Der Freund, dessen Berechtigungen aktualisiert werden sollen.</param>
    private async Task RekeyEntriesForFriendAsync(UserEntity friend)
    {
        var myPrivateKey = _sessionService.PrivateKey;
        if (myPrivateKey == null) return;

        // 1. Die geleerten Berechtigungen des Freundes laden (Pending State)
        var allPermissions = await _databaseService.GetPermissionsByUserIdAsync(friend.Id);
        var dirtyPermissions = allPermissions.Where(p => string.IsNullOrEmpty(p.EncryptedKey) && p.AccessLevel > 0).ToList();
        if (dirtyPermissions.Count == 0) return;
       
        var successCount = 0;
        foreach (var perm in dirtyPermissions)
        {
            try
            {
                // 2. Wir brauchen meine eigene Berechtigung für diesen Eintrag, um an den AES-Entry-Key zu kommen
                var myPerm = await _databaseService.GetPermissionByEntryIdAndUserIdAsync(perm.EntryId, 1); // 1 = Me 
                if (myPerm == null) continue;

                // 3. Entry-Key mit meinem Private-Key entschlüsseln
                var entryKey = _cryptoService.DecryptRsa(myPerm.EncryptedKey, myPrivateKey);

                // 4. Entry-Key mit dem NEUEN Public-Key des Freundes verschlüsseln
                perm.EncryptedKey = _cryptoService.EncryptRsa(entryKey, friend.PublicKey);
                    
                // 5. In DB speichern (wird beim nächsten Sync hochgeladen)
                await _databaseService.SavePermissionAsync(perm);
                successCount++;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Rekeying fehlgeschlagen: {ex.Message}");
            }
        }

        if (successCount > 0)
        {
            await _uiService.ToastAsync($"{successCount} Schlüssel für {friend.Name} wurden aktualisiert.");
        }
    }
    
    /// <summary>
    /// Lädt Theme-Art und Theme-Mode aus der Konfiguration
    /// </summary>
    private void ResetTheme()
    {
        var parts = _configService.Theme.Trim().Split('.', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        ThemeKind = parts.Length >= 1 && ThemeKinds.Contains(parts[0]) ? parts[0] : ThemeKinds[0];
        ThemeMode = parts.Length >= 2 && ThemeModes.Contains(parts[1]) ? parts[1] : ThemeModes[0];
    }
    
    /// <summary>
    /// Aktualisiert das Salt eines Tresors in der globalen Konfigurations-Map (Preferences).
    /// </summary>
    /// <param name="vaultName">Name des betroffenen Tresors.</param>
    /// <param name="newSalt">Das neue, Base64-kodierte Salt.</param>
    private void UpdateSaltMap(string vaultName, string newSalt)
    {
        var map = _configService.Vaults;
        map[vaultName] = newSalt;
        _configService.Vaults = map;
    }
    
    /// <summary>
    /// Aktualisiert die Tresor-Liste nach einer Umbenennung. Entfernt den alten Namen und fügt den neuen hinzu.
    /// </summary>
    /// <param name="oldName">Der bisherige Name des Tresors.</param>
    /// <param name="newName">Der neue Name des Tresors.</param>
    /// <param name="salt">Das zugehörige Salt des Tresors.</param>
    private void UpdateVaultMap(string oldName, string newName, string salt)
    {
        var map = _configService.Vaults;
        map.Remove(oldName);
        map[newName] = salt;
        _configService.Vaults = map;
        _configService.LastVaultName = newName;
    }
}