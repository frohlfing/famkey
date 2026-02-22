using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Privault.Core.Models.Entities;
using Privault.Core.Services.Contracts;

namespace Privault.Core.ViewModels;

/// <summary>
/// Das <see cref="LoginViewModel"/> verwaltet den Authentifizierungsprozess und den Zugriff auf die Tresore.
/// <para>
/// <b>Hauptaufgaben:</b>
/// <list type="bullet">
/// <item>Anzeige und Auswahl vorhandener lokaler Tresore.</item>
/// <item>Erstellen / Öffnen des Tresors inklusive Schlüsselableitung (Argon2id).</item>
/// <item>Biometrie-Unterstützung: Kein Passwort → Login per Fingerabdruck oder Gesichtserkennung.</item>
/// </list>
/// </para>
/// <para>
/// <b>Sicherheitsaspekte:</b>
/// <list type="bullet">
/// <item>Kein Master-Passwort im RAM: Das Passwort wird nur kurzzeitig zur Ableitung des Master-Keys verwendet.</item>
/// <item>Wiping: Der Master-Key wird nach der Entschlüsselung sofort aus dem Speicher gelöscht (<see cref="ICryptoService.WipeKey"/>).</item>
/// <item>Hardware-Schutz für Biometrie: Der Master-Key liegt im verschlüsselten Secure-Store des Betriebssystems.</item>
/// </list>
/// </para>
/// </summary>
public partial class LoginViewModel : ObservableObject
{
    // ------------------------------------------------------------------------
    // --- Felder ---
    // ------------------------------------------------------------------------

    private readonly IBiometricService _biometricService;
    private readonly IConfigService _configService;
    private readonly ICryptoService _cryptoService;
    private readonly IDatabaseService _databaseService;
    private readonly ISessionService _sessionService;
    private readonly IUiService _uiService;

    /// <summary>
    /// Gibt an, ob Biometrie von der Hardware unterstützt wird und in der Systemeinstellung aktiviert ist.
    /// </summary>
    private bool _isBiometricAvailable;
    
    /// <summary>
    /// Signalisiert, ob gerade die Seite initialisiert wird.
    /// </summary>
    private bool _isInit;

    // ------------------------------------------------------------------------
    // --- Konstruktor ---
    // ------------------------------------------------------------------------

    /// <summary>
    /// Initialisiert eine neue Instanz des <see cref="LoginViewModel"/>.
    /// </summary>
    /// <param name="biometricService">Dienst für die Biometrie-Unterstützung.</param>
    /// <param name="configService">Dienst für globale App-Konfigurationen.</param>
    /// <param name="cryptoService">Dienst für kryptografische Funktionen.</param>
    /// <param name="databaseService">Dienst für den Datenbankzugriff (SQLite/SQLCipher).</param>
    /// <param name="sessionService">Dienst zur Verwaltung der aktuellen Sitzungsdaten (RAM).</param>
    /// <param name="uiService">UI-Abstraktion (Dialoge, Navigation, Toast).</param>
    /// <exception cref="ArgumentNullException">Wird geworfen, wenn einer der benötigten Services null ist.</exception>
    public LoginViewModel(
        IBiometricService biometricService,
        IConfigService configService,
        ICryptoService cryptoService,
        IDatabaseService databaseService,
        ISessionService sessionService,
        IUiService uiService)
    {
        _biometricService = biometricService ?? throw new ArgumentNullException(nameof(biometricService));
        _configService = configService ?? throw new ArgumentNullException(nameof(configService));
        _cryptoService = cryptoService ?? throw new ArgumentNullException(nameof(cryptoService));
        _databaseService = databaseService ?? throw new ArgumentNullException(nameof(databaseService));
        _sessionService = sessionService ?? throw new ArgumentNullException(nameof(sessionService));
        _uiService = uiService ?? throw new ArgumentNullException(nameof(uiService));

        // Letzten Tresor vorausfüllen, Fallback: Benutzername des Betriebssystems
        var lastVault = _configService.LastVaultName;
        VaultName = !string.IsNullOrEmpty(lastVault) ? lastVault : Environment.UserName;
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
        if (_isInit || IsBusy) return;
        _isInit = true;
        try
        {
            _isBiometricAvailable = await _biometricService.IsAvailableAsync();
            await UpdateStateAsync();
        }
        catch (Exception ex)
        {
            await _uiService.ErrorAsync(ex.Message);
        }
        finally
        {
            _isInit = false;
        }
    }
    
    // ------------------------------------------------------------------------
    // --- Eigenschaften ---
    // ------------------------------------------------------------------------

    /// <summary>
    /// Der Name des Tresors, der geöffnet oder neu erstellt werden soll.
    /// Sonderzeichen werden automatisch durch Unterstriche ersetzt.
    /// </summary>
    [ObservableProperty] 
    private string _vaultName = string.Empty;
    
    /// <summary>
    /// Gibt an, ober der Tresor existiert
    /// </summary>
    [ObservableProperty] 
    private bool _isExists;
    
    /// <summary>
    /// Gibt an, ob für den aktuell gewählten Tresor der Master-Key im Secure-Store liegt.
    /// </summary>
    [ObservableProperty]
    [NotifyCanExecuteChangedFor(nameof(LoginCommand))]
    private bool _hasBiometricKey;
    
    /// <summary>
    /// Das eingegebene Master-Passwort für den Login.
    /// </summary>
    [ObservableProperty] 
    [NotifyCanExecuteChangedFor(nameof(LoginCommand))] 
    private string _password = string.Empty;
    
    /// <summary>
    /// Gibt an, ob aktuell ein langlaufender Prozess (z.B. Argon2-Schlüsselableitung) aktiv ist.
    /// Deaktiviert automatisch den Login-Button.
    /// </summary>
    [ObservableProperty] 
    [NotifyCanExecuteChangedFor(nameof(LoginCommand))]
    private bool _isBusy;

    /// <summary>
    /// Signalisiert verzögert, ob ein Ladevorgang aktiv ist.
    /// </summary>
    [ObservableProperty] 
    private bool _showBusyIndicator;
    
    // ------------------------------------------------------------------------
    // --- Befehle ---
    // ------------------------------------------------------------------------
    
    /// <summary>
    /// Startet den Authentifizierungsprozess.
    /// <para>
    /// Prüft, ob der Tresor existiert, und leitet dann entweder das Öffnen oder die Neuanlage ein.
    /// </para>
    /// </summary>
    [RelayCommand(CanExecute = nameof(CanLogin))]
    private async Task LoginAsync()
    {
        if (_isInit || IsBusy) return;
        IsBusy = true;
        try
        {
            if (IsExists)
            {
                await OpenVaultAsync();
            }
            else
            {
                await CreateVaultAsync();
            }
            
            // // Nach erfolgreichem Login "warmup" triggern
            // _ = Task.Run(() => 
            // {
            //     // 1. JSON Reflektion aufwärmen
            //     var dummyJson = System.Text.Json.JsonSerializer.Serialize(new EntryPayload { Title = "Warmup" });
            //     _ = System.Text.Json.JsonSerializer.Deserialize<EntryPayload>(dummyJson);
            //
            //     // 2. Krypto-Provider initialisieren
            //     _ = _cryptoService.ComputeHash("warmup");
            // });
        }
        catch (Exception ex)
        {
            await _uiService.ErrorAsync(ex.Message);
            await _databaseService.CloseConnectionAsync();
        }
        finally
        {
            IsBusy = false;
        }
    }
    
    /// <summary>
    /// Öffnet ein Menü zur Auswahl eines bereits auf dem Gerät vorhandenen Tresors.
    /// </summary>
    [RelayCommand]
    private async Task PickVaultAsync()
    {
        var vaultMap = _configService.Vaults;
        if (vaultMap.Count == 0)
        {
            await _uiService.InfoAsync("Es sind noch keine lokalen Tresore vorhanden.");
            return;
        }

        var vaults = vaultMap.Keys.ToArray();
        var result = await _uiService.ActionSheetAsync(
            "Tresor wählen", 
            "Abbrechen", 
            null,
            vaults);

        if (!string.IsNullOrWhiteSpace(result) && result != "Abbrechen")
        {
            VaultName = result;
            // Passwort-Feld fokussieren
            OnVaultPicked?.Invoke();
        }
    }
    
    // ------------------------------------------------------------------------
    // --- Ereignishandler ---
    // ------------------------------------------------------------------------

    // /// <summary>
    // /// Wird aufgerufen, wenn IsBusy geändert wird.
    // /// Schaltet den Busy-Indikator verzögert ein bzw. sofort aus.
    // /// </summary>
    // /// <param name="value"></param>
    // partial void OnIsBusyChanged(bool value)
    // {
    //     if (value)
    //         _ = DelayBusyIndicatorAsync(); // fire-and-forget
    //     else
    //         ShowBusyIndicator = false;
    // }
    
    /// <summary>
    /// Wird aufgerufen, wenn sich der VaultName ändert, um ungültige Zeichen sofort zu entfernen.
    /// </summary>
    partial void OnVaultNameChanged(string value)
    {
        if (string.IsNullOrEmpty(value)) return;

        // Ungültige Zeichen entfernen.
        var invalidChars = Path.GetInvalidFileNameChars();
        var sanitized = string.Join("_", value.Split(invalidChars, StringSplitOptions.None));
        if (sanitized != value)
            VaultName = sanitized;
        
        // Status-Flags aktualisieren 
        _ = UpdateStateAsync(); // fire-and-forget      
    }
    
    /// <summary>
    /// Tritt auf, wenn ein Tresor aus der Liste gewählt wurde. 
    /// Die View kann darauf reagieren, um z.B. den Fokus in das Passwortfeld zu setzen.
    /// </summary>
    public event Action? OnVaultPicked;
    
    // ------------------------------------------------------------------------
    // --- Private Methoden ---
    // ------------------------------------------------------------------------

    // --- Kern-Logik ---
    
    /// <summary>
    /// Erstellt eine neue Tresor-Datenbank, generiert ein RSA-Schlüsselpaar für die Identität 
    /// und verschlüsselt den privaten Teil mit dem Master-Key.
    /// </summary>
    private async Task CreateVaultAsync()
    {
        // Entweder war der Tresor nie da, oder er wurde gerade wegen Inkonsistenz gelöscht.
        var createNew = await _uiService.ConfirmAsync(
            "Tresor anlegen",
            $"Der Tresor '{VaultName}' existiert auf diesem Gerät noch nicht.\nMöchtest du ihn anlegen?",
            "Ja, anlegen",
            "Nein, abbrechen");

        if (!createNew) return;
        
        // 1. Neues Salt generieren
        var salt = _cryptoService.GenerateSalt();
        var saltBase64 = Convert.ToBase64String(salt);

        // 2. Master-Key ableiten
        var masterKey = await _cryptoService.DeriveKeyAsync(Password, salt);

        try
        {
            // 3. Datenbank initialisieren (erstellt Tabellen)
            await _databaseService.InitializeAsync(VaultName, masterKey);

            // 4. Salt in die Map eintragen
            var map = _configService.Vaults;
            map[VaultName] = saltBase64;
            _configService.Vaults = map;

            // 5. RSA-Schlüsselpaar für den User generieren
            var (pubKey, privKey) = _cryptoService.GenerateRsaKeyPair();

            // 6. Private Key verschlüsseln (mit dem Master-Key)
            var encryptedPrivKey = _cryptoService.Encrypt(privKey, masterKey);

            // 7. UserEntity mit der ID = 1 (Benutzer der App) erstellen. 
            // SQLite-net schaut beim Insert in seine interne Sequenz-Tabelle.
            // Da die Datenbank neu ist, ist die nächste freie ID immer die 1.
            var newUser = new UserEntity
            {
                //Id = 1, // wird automatisch gesetzt 
                Uuid = Guid.NewGuid().ToString(), // Direkt lokal generieren (V4)   
                Name = Environment.UserName, // muss eindeutig im Tresor sein
                PublicKey = pubKey,
                IsVerified = true, // Ich vertraue mir selbst :-)
            };

            var newSettings = new SettingsEntity
            {
                Salt = saltBase64,
                EncryptedPrivateKey = encryptedPrivKey
            };

            // 8. User und Settings in der DB speichern
            await _databaseService.SaveUserAsync(newUser);
            await _databaseService.SaveSettingsAsync(newSettings);

            // 9. Letzten Tresor merken
            _configService.LastVaultName = VaultName;

            // 10. Session setzen (damit wir direkt eingeloggt sind)
            _sessionService.User = newUser;
            _sessionService.VaultName = VaultName;
            _sessionService.Settings = newSettings;
            _sessionService.PrivateKey = privKey;
        }
        finally
        {
            // Master-Key aus dem RAM löschen
            _cryptoService.WipeKey(masterKey);
        }

        // 11. Aufräumen und zur Liste springen
        Password = string.Empty; // GC-Hinweis
        await GoToMainPageAsync();
    }
    
    /// <summary>
    /// Öffnet einen bestehenden Tresor, leitet den Master-Key ab und entschlüsselt die Sitzungsdaten.
    /// <para>
    /// Wenn die Biometrie genutzt wird, muss der Tresor bereits existieren.
    /// </para>
    /// </summary>
    /// <remarks>
    /// Es wird vorausgesetzt, dass der Tresor in der lokalen Tresorliste steht.
    /// </remarks>
    private async Task OpenVaultAsync()
    {
        byte[]? masterKey;
        
        // Biometrie nutzen, wenn das Passwortfeld leer ist UND Master-Key im Secure-Store liegt
        var useBiometrics = string.IsNullOrEmpty(Password) && HasBiometricKey;
        if (useBiometrics)
        {
            // 1. Master-Key aus Secure-Store holen (löst System-Dialog aus)
            masterKey = await _biometricService.GetMasterKeyAsync(VaultName);
            if (masterKey == null)
                throw new Exception("Biometrie abgebrochen oder nicht konfiguriert.");
        }
        else
        {
            // 1. Master-Key aus eingegebenes Master-Passwort und Salt ableiten (Argon2id)
            var saltBase64 = _configService.Vaults[VaultName]; // zum Tresor zugehörigen Salt aus der lokalen Tresorliste laden
            var salt = Convert.FromBase64String(saltBase64);
            masterKey = await _cryptoService.DeriveKeyAsync(Password, salt);
        }

        try
        {
            UserEntity? user;
            SettingsEntity? settings;
            try
            {
                // 2. Datenbank öffnen
                await _databaseService.InitializeAsync(VaultName, masterKey);

                if (VaultName == "frank" && Password == "falsch") // TODO Hack wieder rausnehmen, ist nur zum Test!!!!!!!!!!
                    throw new Exception("file is not a database");
                
                // 3. Eigene Identität (öffentlich) und Einstellungen (privat) auslesen
                user = await _databaseService.GetUserAsync(1); // Ich bin immer ID 1
                settings = await _databaseService.GetSettingsAsync();
            }
            catch (Exception ex)
            {
                if (ex.Message.Contains("file is not a database"))
                {
                    if (useBiometrics)
                        await _biometricService.RemoveMasterKeyAsync(VaultName);
                    throw new Exception("Falsches Master-Passwort.");
                }
                throw;
            }

            // 4. Private Key entschlüsseln
            try
            {
                if (user == null || settings == null) throw new Exception("Tresor ist korrupt.");
                _sessionService.User = user;
                _sessionService.VaultName = VaultName;
                _sessionService.Settings = settings;
                _sessionService.PrivateKey = _cryptoService.Decrypt(settings.EncryptedPrivateKey, masterKey);
            }
            catch (Exception)
            {
                // Tresor ist beschädigt
                var confirm = await _uiService.ConfirmAsync(
                    "Tresor löschen",
                    "Der Tresor ist korrupt. Soll er gelöscht werden?",
                    "Ja, löschen",
                    "Nein, abbrechen");
                if (confirm)
                    await CleanUpAsync();
                return;
            }
            
            // Falls es ein manueller Login war:
            // Wenn Biometrie in den Einstellungen aktiviert ist, aber und noch nichts im Secure-Store liegt,
            // nachfragen, ob der Master-Key nun im Secure-Store abgelegt werden soll.
            if (!useBiometrics && settings.UseBiometric && !await _biometricService.ContainsMasterKeyAsync(VaultName))
            {
                var confirm = await _uiService.ConfirmAsync(
                    "Biometrie",
                    "Soll dein Schlüssel sicher auf diesem Gerät abgelegt werden, damit du dich beim " +
                                "nächsten Mal bequem per Fingerabdruck oder Gesichtserkennung anmelden kannst?",
                    "Ja, Schlüssel speichern",
                    "Nein, Biometrie deaktivieren");
                if (confirm)
                {
                    await _biometricService.SaveMasterKeyAsync(VaultName, masterKey);
                    await UpdateStateAsync();
                }
                else
                {
                    settings.UseBiometric = false;
                    await _databaseService.SaveSettingsAsync(settings);
                }
            }
        }
        finally
        {
            // Master-Key aus dem Arbeitsspeicher entfernen
            _cryptoService.WipeKey(masterKey);
        }

        // 5. Erfolg: Letzten Tresor merken
        _configService.LastVaultName = VaultName;

        // 6. Aufräumen (Passwort-String) und zur Liste springen
        Password = string.Empty;
        await GoToMainPageAsync();
    }
    
    // --- Sonstige Helfer ---
    
    /// <summary>
    /// Validiert, ob die für einen Login notwendigen Felder ausgefüllt sind.
    /// </summary>
    private bool CanLogin()
    {
        if (IsBusy) 
            return false;
        
        if (string.IsNullOrWhiteSpace(VaultName))
            return false; // kein Tresorname

        // Login ist möglich, wenn ein Passwort eingegeben wurde oder der Master-Key im Secure-Store liegt
        return !string.IsNullOrWhiteSpace(Password) || HasBiometricKey;
    }
    
    /// <summary>
    /// Führt eine Notfall-Bereinigung durch, wenn ein Tresor als korrupt oder inkonsistent erkannt wird.
    /// Löscht die Datenbankdatei und den Eintrag in der Konfigurations-Map.
    /// </summary>
    private async Task CleanUpAsync()
    {
        // Datenbank löschen
        await _databaseService.DeleteCurrentDatabase();

        // Lokalen Map-Eintrag entfernen
        var map = _configService.Vaults;
        map.Remove(VaultName);
        _configService.Vaults = map;
        
        // Master-Key aus dem Secure-Store löschen, falls vorhanden
        if (HasBiometricKey)
            await _biometricService.RemoveMasterKeyAsync(VaultName);
        
        // Status-Flags aktualisieren
        await UpdateStateAsync();
    }
    
    /// <summary>
    /// Navigiert zur Hauptansicht und setzt den Navigationsstack zurück.
    /// </summary>
    private async Task GoToMainPageAsync()
    {
        try
        {
            await _uiService.NavigateAsync("/main");
        }
        catch (Exception ex)
        {
            await _uiService.ErrorAsync($"Main-Navigation fehlgeschlagen: {ex.Message}");
        }
    }

    // /// <summary>
    // /// Schaltet im Login-Prozess den Busy-Indikator verzögert ein.
    // /// </summary>
    // private async Task DelayBusyIndicatorAsync()
    // {
    //     await Task.Delay(250);
    //     if (IsBusy)
    //         ShowBusyIndicator = true;
    // }
    
    /// <summary>
    /// Prüft, ob es den Tresor gibt und ob es für diesen Tresor ein Wert im Secure-Store liegt.
    /// </summary>
    private async Task UpdateStateAsync()
    {
        IsExists = !string.IsNullOrWhiteSpace(VaultName) && _configService.Vaults.ContainsKey(VaultName);
        if (_isBiometricAvailable && IsExists)
        {
            HasBiometricKey = await _biometricService.ContainsMasterKeyAsync(VaultName);
        }
        else
        {
            HasBiometricKey = false; // Biometrie ist nicht verfügbar oder Tresor existiert nicht
        }
        LoginCommand.NotifyCanExecuteChanged();
    }
}