using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Privault.Core.Models.Entities;
using Privault.Core.Models.Payloads;
using Privault.Core.Services.Contracts;
using System.Collections.ObjectModel;
using System.Text;
using System.Text.Json;

namespace Privault.Core.ViewModels;

/// <summary>
/// Das <see cref="EditViewModel"/> ist für das Hinzufügen oder Bearbeiten eines Tresoreintrags verantwortlich.
/// Es steuert den gesamten Lebenszyklus eines Eintrags: Erstellung, Entschlüsselung und Bearbeitung. 
/// <para>
/// <b>Kernfunktionalitäten:</b>
/// <list type="bullet">
/// <item>Envelope Encryption: Entschlüsselung des AES-Eintragschlüssels via RSA-Privatschlüssel des Nutzers.</item>
/// <item>Zustandsverwaltung: Unterscheidung zwischen Schreib- und Vollzugriff (Besitzer).</item>
/// </list>
/// </para>
/// <para>
/// <b>Sicherheitskonzept:</b>
/// Der symmetrische Schlüssel (<c>_entryKey</c>) wird nur im Arbeitsspeicher gehalten und beim Verlassen der Seite 
/// über <see cref="ICryptoService.WipeKey"/> sicher gelöscht. Anhänge werden erst bei Bedarf (Lazy Loading) entschlüsselt.
/// </para>
/// </summary>
public partial class EditViewModel : ObservableObject
{
    // ------------------------------------------------------------------------
    // --- Felder ---
    // ------------------------------------------------------------------------
    
    private readonly ICryptoService _cryptoService;
    private readonly IDatabaseService _databaseService;
    private readonly IPasswordService _passwordService;
    private readonly ISessionService _sessionService;
    private readonly IUiService _uiService;

    /// <summary>
    /// Die aktuell geladene Datenbank-Entität. Ist <c>null</c> bei einem neuen Eintrag.
    /// </summary>
    private EntryEntity? _entry;

    /// <summary>
    /// Der entschlüsselte 32-Byte AES-Schlüssel für diesen spezifischen Eintrag.
    /// Wird benötigt, um Daten und Anhänge zu ver- und zu entschlüsseln.
    /// </summary>
    private byte[]? _entryKey;

    /// <summary>
    /// Speichert den ursprünglichen Zustand des Eintrags, um beim Abbrechen Änderungen zu erkennen (Dirty-Check).
    /// </summary>
    private EntryPayload? _originalPayload;
    
    // ------------------------------------------------------------------------
    // --- Konstruktor ---
    // ------------------------------------------------------------------------

    /// <summary>
    /// Initialisiert eine neue Instanz des <see cref="EditViewModel"/>.
    /// </summary>
    /// <param name="cryptoService">Dienst für kryptografische Operationen.</param>
    /// <param name="databaseService">Dienst für den Datenbankzugriff.</param>
    /// <param name="passwordService">Dienst für Passwortfunktionen.</param>
    /// <param name="sessionService">Dienst für die aktuelle Sitzungsverwaltung.</param>
    /// <param name="uiService">UI-Abstraktion (Dialoge, Navigation, Toast).</param>
    /// <exception cref="ArgumentNullException">Wird geworfen, wenn ein benötigter Dienst null ist.</exception>
    public EditViewModel(
        ICryptoService cryptoService,
        IDatabaseService databaseService, 
        IPasswordService passwordService,
        ISessionService sessionService,
        IUiService uiService)
    {
        _cryptoService = cryptoService ?? throw new ArgumentNullException(nameof(cryptoService));
        _databaseService = databaseService ?? throw new ArgumentNullException(nameof(databaseService));
        _passwordService = passwordService ?? throw new ArgumentNullException(nameof(passwordService));
        _sessionService = sessionService ?? throw new ArgumentNullException(nameof(sessionService));
        _uiService = uiService ?? throw new ArgumentNullException(nameof(uiService));
    }
    
    /// <summary>
    /// Verarbeitet die Navigationsattribute, die beim Öffnen der Seite übergeben werden.
    /// Lädt entweder einen bestehenden Eintrag oder initialisiert einen neuen.
    /// </summary>
    /// <param name="query">Ein Dictionary mit den Übergabeparametern.</param>
    /// <remarks>
    /// Dieser Befehl wird über die View (per Code-Behind) aufgerufen.
    /// </remarks>
    [RelayCommand]
    private async Task InitializeAsync(IDictionary<string, object> query)
    {
        if (IsLoading) return;
        IsLoading = true;
        try
        {
            // Kategorien für die Vorschlagsliste (ChipButtonGroup) laden
            await LoadExistingCategoriesAsync();

            // Eintrag laden
            if (query.TryGetValue("id", out _))
            {
                var entryId = int.Parse(query["id"].ToString()!);
                await LoadEntryAsync(entryId);
            }
            else
            {
                // Kein ID-Parameter -> Neuer Eintrag
                IsEditMode = false;
                _entry = null;
                _entryKey = null;
                InitNewEntry();
            }
        }
        catch (Exception ex)
        {
            await _uiService.ErrorAsync(ex.Message);
        }
        finally
        {
            IsLoading = false;
        }
    }
    
    // ------------------------------------------------------------------------
    // --- Eigenschaften ---
    // ------------------------------------------------------------------------
    
    /// <summary>
    /// Ein Text-Hinweis über den Ersteller und den Zeitpunkt der letzten Änderung.
    /// </summary>
    [ObservableProperty] 
    private string _auditHint = string.Empty;
    
    /// <summary>
    /// Die Kategorie des Eintrags (z.B. "Finanzen").
    /// </summary>
    [ObservableProperty] 
    private string _category = string.Empty;

    /// <summary>
    /// Liste der bereits im Tresor vorhandenen Kategorien für die Autovervollständigung.
    /// </summary>
    public ObservableCollection<string> ExistingCategories { get; } = [];
    
    /// <summary>
    /// Liefert den Namen der Standardkategorie aus den Einstellungen als Platzhalter für die UI.
    /// </summary>
    public string CategoryPlaceholder => _sessionService.Settings?.CategoryPlaceholder ?? "Allgemein";
    
    /// <summary>
    /// Der Titel des Eintrags.
    /// </summary>
    [ObservableProperty] 
    [NotifyPropertyChangedFor(nameof(HasTitle))]
    private string _title = string.Empty;
    
    /// <summary>
    /// Gibt an, ob ein Title eingetragen ist.
    /// </summary>
    public bool HasTitle => !string.IsNullOrWhiteSpace(Title);
    
    /// <summary>
    /// Der im Eintrag gespeicherte Benutzername.
    /// </summary>
    [ObservableProperty] 
    private string _username = string.Empty;
    
    /// <summary>
    /// Das im Eintrag gespeicherte Passwort.
    /// </summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(PasswordStrength))] // <--- UI aktualisieren
    private string _password = string.Empty;
    
    /// <summary>
    /// Für das Passwort-Auge. Steuert, ob das Passwortfeld im Klartext oder verborgen angezeigt wird.
    /// </summary>
    [ObservableProperty] 
    private bool _isPasswordHidden = true;
    
    /// <summary>
    /// Berechnete Stärke des Passworts (0-4).
    /// </summary>
    public int PasswordStrength => _passwordService.EstimateStrength(Password);
    
    /// <summary>
    /// Die hinterlegte URL (z.B. Login-Seite eines Webdienstes).
    /// </summary>
    [ObservableProperty] 
    private string _url = string.Empty;
    
    /// <summary>
    /// Notizen zum Eintrag.
    /// </summary>
    [ObservableProperty] 
    private string _notes = string.Empty;
    
    /// <summary>
    /// Gibt an, ob der aktuelle Benutzer Schreibrechte für diesen Eintrag besitzt.
    /// access_level >= 2
    /// </summary>
    [ObservableProperty] private bool _canWrite = true;

    /// <summary>
    /// Gibt an, ob der aktuelle Benutzer Vollzugriff (Besitzerrechte) hat, um z.B. den Eintrag zu löschen.
    /// access_level == 3
    /// </summary>
    [ObservableProperty] 
    private bool _hasFullAccess;
    
    /// <summary>
    /// Gibt an, ob etwas verändert wurde. 
    /// </summary>
    /// <returns><c>true</c> bei einer Änderung, sonst <c>false</c>.</returns>
    private bool IsDirty =>
        _originalPayload == null || // Neuer Eintrag
        Category != _originalPayload.Category || 
        Title != _originalPayload.Title ||
        Username != _originalPayload.Username ||
        Password != _originalPayload.Password ||
        Url != _originalPayload.Url ||
        Notes != _originalPayload.Notes;
    
    /// <summary>
    /// Steuert, ob die Ansicht im Edit- oder im Insert-Modus ist
    /// </summary>
    [ObservableProperty] 
    private bool _isEditMode;
    
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
    /// Bricht die Bearbeitung ab. Falls Änderungen vorgenommen wurden, erfolgt eine Sicherheitsabfrage.
    /// </summary>
    [RelayCommand]
    private async Task CancelAsync()
    {
        if (IsDirty)
        {
            var save = await _uiService.ConfirmAsync(
                "Eintrag speichern",
                "Möchtest du die Änderungen speichern?", 
                "Ja, speichern", "Nein, verwerfen");
            if (save)
            {
                var ok = await SaveAsync();
                if (!ok) return;
            }
        }

        await GoBackAsync();
    }

    /// <summary>
    /// Kopiert den übergebenen Text in die Zwischenablage und zeigt einen Toast zur Bestätigung an.
    /// </summary>
    /// <param name="text">Der zu kopierende Text.</param>
    [RelayCommand]
    private async Task CopyToClipboard(string text)
    {
        if (string.IsNullOrEmpty(text)) return;
        await _uiService.CopyToClipboardAsync(text);
        await _uiService.ToastAsync("In die Zwischenablage kopiert");
    }

    /// <summary>
    /// Löscht den aktuellen Eintrag unwiderruflich nach einer Bestätigung. 
    /// Erzeugt einen Tombstone für die Synchronisation.
    /// </summary>
    [RelayCommand]
    private async Task DeleteAsync()
    {
        if (_entry == null) return;

        if (!HasFullAccess)
        {
            await _uiService.AlertAsync(
                "Keine Berechtigung", 
                "Du darfst diesen Eintrag nicht löschen.");
            return;
        }

        var confirm = await _uiService.ConfirmAsync(
            "Eintrag löschen",
            "Soll dieser Eintrag wirklich und unwiderruflich gelöscht werden?", 
            "Ja, löschen", 
            "Nein, abbrechen");
        if (!confirm) return;

        try
        {
            // 1. Zuerst den Grabstein setzen.
            // Damit sagen wir dem Server später: "Diese UUID ist weg."
            var tombstone = new TombstoneEntity
            {
                EntryUuid = _entry.Uuid,
                DeletedAt = DateTime.UtcNow
            };
            await _databaseService.SaveTombstoneAsync(tombstone);

            // 2. DANN den Eintrag lokal physikalisch löschen (Hard Delete)
            await _databaseService.DeleteEntryAsync(_entry.Id);

            // Zurück zur Hauptansicht
            await GoBackAsync();
        }
        catch (Exception ex)
        {
            await _uiService.ErrorAsync($"Löschen fehlgeschlagen: {ex.Message}");
        }
    }

    /// <summary>
    /// Generiert ein neues Zufallspasswort basierend auf den Benutzereinstellungen.
    /// </summary>
    [RelayCommand]
    private void GeneratePassword()
    {
        var settings = _sessionService.Settings;
        var length = settings?.PwLength ?? 16;
        var avoidIlO0 = settings?.PwAvoidIlO0 ?? true;
        var specialChars = settings?.PwSpecialChars ?? "!@#$%^&*()_+-=[]{}|;:,.<>?";
        Password = _passwordService.GeneratePassword(length, avoidIlO0, specialChars);
    }
    
    /// <summary>
    /// Speichert den aktuellen Eintrag und schließt die Seite bei Erfolg.
    /// </summary>
    [RelayCommand]
    private async Task OkAsync()
    {
        if (await SaveAsync())
        {
            await GoBackAsync();
        }
    }
    
    /// <summary>
    /// Öffnet die hinterlegte URL im Systembrowser.
    /// </summary>
    [RelayCommand]
    private async Task OpenUrlAsync()
    {
        if (string.IsNullOrWhiteSpace(Url)) return;

        try
        {
            // Prüfen auf http/https, sonst davor hängen
            var uriString = Url;
            if (!uriString.StartsWith("http")) uriString = "https://" + uriString;

            await _uiService.OpenUrlAsync(uriString);
        }
        catch
        {
            await _uiService.ErrorAsync("URL konnte nicht geöffnet werden.");
        }
    }

    /// <summary>
    /// Speichert den aktuellen Eintrag in der Datenbank. Verschlüsselt dabei alle sensiblen Felder.
    /// </summary>
    [RelayCommand]
    private async Task<bool> SaveAsync()
    {
        // Vorab-Checks: Darf der User überhaupt speichern und sind die Pflichtfelder da?
        if (!CanWrite && _entry != null)
        {
            await _uiService.AlertAsync(
                "Keine Berechtigung", 
                "Du hast keine Schreibrechte für diesen Eintrag.");
            return false;
        }

        if (string.IsNullOrWhiteSpace(Title))
        {
            await _uiService.ErrorAsync("Titel fehlt.");
            return false;
        }

        try
        {
            // 1. Favicon laden, falls URL vorhanden und noch kein Icon da ist oder die URL sich geändert hat
            var origFavicon = _originalPayload?.Favicon ?? string.Empty;
            var origUrl = _originalPayload?.Url ?? string.Empty;
            if (!string.IsNullOrWhiteSpace(Url) && (string.IsNullOrEmpty(origFavicon) || Url != origUrl))
            {
                origFavicon = await DownloadFaviconAsBase64Async(Url);
            }

            // 2. Payload bauen (Das komplette Objekt, welches verschlüsselt wird)
            var payload = new EntryPayload
            {
                Category = Category,
                Title = Title,
                Username = Username,
                Password = Password,
                Url = Url,
                Notes = Notes,
                Favicon = origFavicon ?? string.Empty
            };
            var jsonString = JsonSerializer.Serialize(payload);
            var plainPayloadBytes = Encoding.UTF8.GetBytes(jsonString);

            // 3. Key-Management.
            // Wir benötigen einen 32-Byte AES-Key. 
            // Neu: Generieren | Bestehend: Aus eigener Permission entschlüsseln.
            if (_entryKey == null)
            {
                if (_entry == null)
                {
                    _entryKey = new byte[32];
                    using var rng = System.Security.Cryptography.RandomNumberGenerator.Create();
                    rng.GetBytes(_entryKey);
                }
                else
                {
                    if (!await EnsureEntryKeyLoadedAsync())
                        return false;
                }
            }

            // 4. Verschlüsseln (AES) des Payloads für den "Safe-Blob"
            var encryptedData = _cryptoService.Encrypt(plainPayloadBytes, _entryKey!);

            // 5. Datenbank-Entity erzeugen, wenn ein neuer Eintrag angelegt werden soll
            // ReSharper disable once ConvertIfStatementToNullCoalescingAssignment
            if (_entry == null)
            {
                _entry = new EntryEntity
                {
                    Uuid =  Guid.NewGuid().ToString(),
                    CreatorId = _sessionService.User!.Id,
                    UpdaterId = _sessionService.User!.Id
                };
            }

            // 6. Daten aus der UI übernehmen
            _entry.Category = Category;
            _entry.Title = Title;
            _entry.Url = Url;
            _entry.Notes = Notes;
            _entry.Favicon = origFavicon ?? string.Empty;
            _entry.EncryptedData = encryptedData;
            _entry.UpdatedAt = DateTime.UtcNow;
            
            // 7. Daten speichern
            var encryptedEntryKey = _cryptoService.EncryptRsa(_entryKey!, _sessionService.User!.PublicKey);
            await _databaseService.SaveEntryWithPermissionsAsync(_entry, _sessionService.User.Id, encryptedEntryKey);

            // 8. Den Original-Stand für Dirty-Check auf den neuen Stand setzen
            _originalPayload = payload; 

            // 9. UI aktualisieren
            if (!IsEditMode) IsEditMode = true; // Löschen-button anzeigen
            await UpdateAuditHintAsync(); // CreatorId und UpdaterId in der UI aktualisieren
        }
        catch (Exception ex)
        {
            await _uiService.ErrorAsync(ex.Message);
            return false;
        }
        
        return true;
    }
    
    /// <summary>
    /// Setzt die gewählte Kategorie aus der Liste der Vorschläge.
    /// </summary>
    /// <param name="category">Der Name der gewählten Kategorie.</param>
    [RelayCommand]
    private void SelectCategory(string category)
    {
        Category = category;
    }
    
    /// <summary>
    /// Schaltet die Sichtbarkeit des Passworts (Auge-Symbol) um.
    /// </summary>
    [RelayCommand]
    private void TogglePassword()
    {
        IsPasswordHidden = !IsPasswordHidden;
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
    
    // ------------------------------------------------------------------------
    // --- Private Methoden ---
    // ------------------------------------------------------------------------
    
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
    /// Lädt das Favicon einer Website über den Google-Dienst und gibt es als Base64-String zurück.
    /// </summary>
    /// <param name="url">Die URL der Website.</param>
    /// <returns>Das Icon als Base64-String oder null bei Fehlern.</returns>
    private async Task<string?> DownloadFaviconAsBase64Async(string url)
    {
        try
        {
            var uri = new Uri(url.StartsWith("http") ? url : "https://" + url);
            var faviconUrl = $"https://www.google.com/s2/favicons?domain={uri.Host}&sz=64";

            using var client = new HttpClient();
            var bytes = await client.GetByteArrayAsync(faviconUrl);
            return Convert.ToBase64String(bytes);
        }
        catch
        {
            return null;
        }
    }
    
    /// <summary>
    /// Stellt sicher, dass der AES-Entry-Key (<see cref="_entryKey"/>) geladen und entschlüsselt ist.
    /// Falls der Schlüssel noch nicht im RAM vorliegt, wird versucht, ihn mittels RSA zu entschlüsseln.
    /// </summary>
    /// <returns><c>true</c>, wenn der Schlüssel erfolgreich geladen wurde oder bereits vorhanden war; andernfalls <c>false</c>.</returns>
    private async Task<bool> EnsureEntryKeyLoadedAsync()
    {
        if (_entryKey != null)
            return true;

        if (_entry == null)
            return false;

        try
        {
            var myPerm = await _databaseService.GetPermissionByEntryIdAndUserIdAsync(_entry.Id, 1);
            if (myPerm == null)
            {
                await _uiService.ErrorAsync("Keine Berechtigung für diesen Vorgang.");
                return false;
            }

            // Entschlüsselung des AES-Schlüssels mit dem privaten RSA-Schlüssel des Benutzers
            _entryKey = _cryptoService.DecryptRsa(myPerm.EncryptedKey, _sessionService.PrivateKey!);
            return _entryKey != null;
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Fehler beim Laden des Eintragschlüssels: {ex.Message}");
            await _uiService.ErrorAsync("Der Sicherheitsschlüssel konnte nicht geladen werden.");
            return false;
        }
    }

    /// <summary>
    /// Navigiert zurück zur vorherigen Seite und löscht den Entry-Key sicher aus dem RAM.
    /// </summary>
    private async Task GoBackAsync()
    {
        if (IsLoading) return;
        IsLoading = true;
        try
        {
            _cryptoService.WipeKey(_entryKey);
            _entryKey = null;
            await _uiService.NavigateAsync("..");
        }
        catch (Exception ex)
        {
            await _uiService.ErrorAsync($"Zurück-Navigation fehlgeschlagen: {ex.Message}");
        }
        finally
        {
            IsLoading = false;
        }        
    }
    
    /// <summary>
    /// Setzt alle Felder für die Erstellung eines neuen Tresoreintrags zurück.
    /// </summary>
    private void InitNewEntry()
    {
        // Alle Eingabefelder leeren
        Title = "";
        Username = "";
        Password = "";
        Url = "";
        Notes = "";

        // Neuer Eintrag: Ersteller hat immer Vollzugriff
        CanWrite = true;
        HasFullAccess = true;

        // Den "Original-Zustand" für den Dirty-Check (Abbrechen-Warnung) zurücksetzen
        _originalPayload = new EntryPayload();

        // Passwort-Feld wieder verstecken (Standard)
        IsPasswordHidden = true;
    }

    /// <summary>
    /// Lädt einen spezifischen Eintrag aus der Datenbank und führt die RSA/AES-Entschlüsselung durch.
    /// </summary>
    /// <param name="id">Die lokale Datenbank-ID des Eintrags.</param>
    private async Task LoadEntryAsync(int id)
    {
        try
        {
            // 1. Basis-Entität laden
            _entry = await _databaseService.GetEntryAsync(id);
            if (_entry == null)
            {
                await _uiService.ErrorAsync("Eintrag nicht gefunden.");
                await GoBackAsync();
                return;
            }

            IsEditMode = true;
            
            // CreatorId und UpdaterId auslesen
            await UpdateAuditHintAsync();  
            
            // Kategorie auslesen
            Category = _entry.Category;

            // 2. Berechtigungen prüfen
            var perm = await _databaseService.GetPermissionByEntryIdAndUserIdAsync(_entry.Id, 1);
            if (perm == null || perm.AccessLevel < 1)
            {
                throw new Exception("Keine Berechtigung für diesen Eintrag.");
            }

            CanWrite = perm.AccessLevel >= 2;
            HasFullAccess = perm.AccessLevel >= 3;

            // 3. Entry-Key laden
            try
            {
                if (!await EnsureEntryKeyLoadedAsync())
                {
                    await GoBackAsync();
                    return;
                }
            }
            catch (Exception)
            {
                await _uiService.ErrorAsync("Dein Schlüssel für diesen Eintrag passt nicht." + (_entry.CreatorId != 1 ? "\nBitte den Ersteller, erneut zu synchronisieren." : ""));
                CanWrite = false;
                await GoBackAsync();
                return;
            }
            
            // 4. EncryptedData entschlüsseln
            try
            {
                var plainBytes = _cryptoService.Decrypt(_entry.EncryptedData, _entryKey!);
                var json = Encoding.UTF8.GetString(plainBytes);
                _originalPayload = JsonSerializer.Deserialize<EntryPayload>(json);
                if (_originalPayload != null)
                {
                    // Daten aus dem Original in die UI-Properties kopieren
                    Category = _originalPayload.Category;
                    Title = _originalPayload.Title;
                    Username = _originalPayload.Username;
                    Password = _originalPayload.Password;
                    Url = _originalPayload.Url;
                    Notes = _originalPayload.Notes;
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Fehler beim Entschlüsseln des Payloads: {ex.Message}");
                await _uiService.ErrorAsync("Die Daten konnten nicht entschlüsselt werden.");
                CanWrite = false; 
            }
        }
        catch (Exception ex)
        {
            await _uiService.ErrorAsync($"Eintrag konnte nicht geladen werden: {ex.Message}");
            await GoBackAsync();
        }
    }
        
    /// <summary>
    /// Lädt die Liste der bereits verwendeten Kategorien für die Vorschlagsliste.
    /// </summary>
    private async Task LoadExistingCategoriesAsync()
    {
        try
        {
            var entries = await _databaseService.GetEntriesAsync();

            // Wir nehmen die Kategorien direkt aus der Entity (unverschlüsselt)
            var categories = entries
                .Select(e => e.Category)
                .Where(c => !string.IsNullOrWhiteSpace(c))
                .Distinct()
                .OrderBy(c => c)
                .ToList();

            ExistingCategories.Clear();
            foreach (var c in categories)
                ExistingCategories.Add(c);
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Fehler beim Laden der Kategorien: {ex.Message}");
        }
    }
    
    /// <summary>
    /// Aktualisiert den Text-Hinweis (Audit Trail) über Ersteller und letzte Bearbeitung.
    /// </summary>
    private async Task UpdateAuditHintAsync()
    {
        try
        {
            if (_entry == null)
            {
                AuditHint = string.Empty;
                return;
            }

            var creator = "Unbekannt";
            var updater = "Unbekannt";
            var cu = _entry.CreatorId != 0 ? await _databaseService.GetUserAsync(_entry.CreatorId) : null;
            var uu = _entry.UpdaterId != 0 ? await _databaseService.GetUserAsync(_entry.UpdaterId) : null;

            if (cu != null) creator = cu.Name;
            if (uu != null) updater = uu.Name;

            var dateStr = _entry.UpdatedAt.ToLocalTime().ToString("dd.MM.yyyy HH:mm:ss");
            AuditHint = $"Erstellt von: {creator} • Zuletzt bearbeitet von: {updater}, am {dateStr}";
        }
        catch
        {
            AuditHint = string.Empty;
        }
    }
}