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
/// Das <see cref="DetailViewModel"/> ist für die Anzeige eines Tresoreintrags verantwortlich.
/// Außerdem können hier die Dateien an den Eintrag angehängt und Freunde für den Zugriff auf den Eintrag berechtigt werden.
/// <para>
/// <b>Kernfunktionalitäten:</b>
/// <list type="bullet">
/// <item>Envelope Encryption: Entschlüsselung des AES-Eintragschlüssels via RSA-Privatschlüssel des Nutzers.</item>
/// <item>Medienverarbeitung: Erstellung von Thumbnails für Bildanhänge mittels SkiaSharp.</item>
/// <item>Sicherheits-Cleanup: Temporär entschlüsselte Dateien werden nach dem Öffnen automatisch vom Dateisystem entfernt.</item>
/// </list>
/// </para>
/// <para>
/// <b>Sicherheitskonzept:</b>
/// Der symmetrische Schlüssel (<c>_entryKey</c>) wird nur im Arbeitsspeicher gehalten und beim Verlassen der Seite 
/// über <see cref="ICryptoService.WipeKey"/> sicher gelöscht. Anhänge werden erst bei Bedarf (Lazy Loading) entschlüsselt.
/// </para>
/// </summary>
public partial class DetailViewModel : ObservableObject
{
    // ------------------------------------------------------------------------
    // --- Felder ---
    // ------------------------------------------------------------------------
    
    private readonly ICryptoService _cryptoService;
    private readonly IDatabaseService _databaseService;
    private readonly IPasswordService _passwordService;
    private readonly ISessionService _sessionService;
    private readonly IThumbnailService _thumbnailService;
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
    /// Initialisiert eine neue Instanz des <see cref="DetailViewModel"/>.
    /// </summary>
    /// <param name="cryptoService">Dienst für kryptografische Operationen.</param>
    /// <param name="databaseService">Dienst für den Datenbankzugriff.</param>
    /// <param name="passwordService">Dienst für Passwortfunktionen.</param>
    /// <param name="sessionService">Dienst für die aktuelle Sitzungsverwaltung.</param>
    /// <param name="thumbnailService">Dienst für die Thumbnail-Erzeugung.</param>
    /// <param name="uiService">UI-Abstraktion (Dialoge, Navigation, Toast).</param>
    /// <exception cref="ArgumentNullException">Wird geworfen, wenn ein benötigter Dienst null ist.</exception>
    public DetailViewModel(
        ICryptoService cryptoService,
        IDatabaseService databaseService, 
        IPasswordService passwordService,
        ISessionService sessionService,
        IThumbnailService thumbnailService,
        IUiService uiService)
    {
        _cryptoService = cryptoService ?? throw new ArgumentNullException(nameof(cryptoService));
        _databaseService = databaseService ?? throw new ArgumentNullException(nameof(databaseService));
        _passwordService = passwordService ?? throw new ArgumentNullException(nameof(passwordService));
        _sessionService = sessionService ?? throw new ArgumentNullException(nameof(sessionService));
        _thumbnailService = thumbnailService ?? throw new ArgumentNullException(nameof(thumbnailService));
        _uiService = uiService ?? throw new ArgumentNullException(nameof(uiService));
    }
    
    /// <summary>
    /// Verarbeitet die Navigationsattribute, die beim Öffnen der Seite übergeben werden.
    /// Als Parameter wird die id für den zu öffnenden Eintrag erwartet.
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
            // Eintrag laden
            var entryId = int.Parse(query["id"].ToString()!);
            await LoadEntryAsync(entryId);
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
    /// Liefert den Anzeigenamen des Eintrags. Bevorzugt das unverschlüsselte Titelfeld.
    /// </summary>
    public string DisplayTitle => !string.IsNullOrWhiteSpace(Title) ? Title : "Unbekannt";
    
    /// <summary>
    /// Initiale (für Placeholder im Favicon-Kreis).
    /// </summary>
    public string DisplayTitleInitial => !string.IsNullOrWhiteSpace(DisplayTitle)
        ? DisplayTitle.Substring(0, 1).ToUpperInvariant() 
        : "?";

    /// <summary>
    /// Base64 des Favicons (oder leer).
    /// Fallback auf Payload, falls Entity noch kein Favicon hat.
    /// </summary>
    public string FaviconBase64 =>
        !string.IsNullOrWhiteSpace(_entry?.Favicon)
            ? _entry!.Favicon
            : (_originalPayload?.Favicon ?? string.Empty);

    /// <summary>
    /// Gibt an, ob ein Favicon vorhanden ist.
    /// </summary>
    public bool HasFavicon => !string.IsNullOrWhiteSpace(FaviconBase64);
    
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
    /// Der Titel des Eintrags.
    /// </summary>
    [ObservableProperty] 
    [NotifyPropertyChangedFor(nameof(DisplayTitle))]
    [NotifyPropertyChangedFor(nameof(DisplayTitleInitial))]
    private string _title = string.Empty;
    
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
    /// Liste der Anhänge dieses Eintrags, aufbereitet für die UI.
    /// </summary>
    public ObservableCollection<DetailAttachmentViewModel> Attachments { get; } = [];
    
    /// <summary>
    /// Liste der Freunde und deren aktuelle Zugriffsstufe auf diesen Eintrag.
    /// </summary>
    public ObservableCollection<DetailFriendViewModel> Friends { get; } = [];

    /// <summary>
    /// Gibt an, ob es Freunde gibt.
    /// </summary>
    [ObservableProperty] 
    private bool _hasFriends;
    
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
    /// Fügt dem aktuellen Eintrag einen neuen Dateianhang hinzu. 
    /// Öffnet den Dateipicker, verschlüsselt die Daten und speichert sie in der Datenbank.
    /// </summary>
    [RelayCommand(CanExecute = nameof(CanWrite))]
    private async Task AddAttachmentAsync()
    {
        if (_entry == null) // sollte nicht möglich sein
        {
            await _uiService.ErrorAsync("Kein Eintrag geladen.");
            return;
        } 
        
        try
        {
            // Datei wählen
            var result = await _uiService.PickFileAsync("Datei auswählen");
            if (result == null) return;

            if (!await EnsureEntryKeyLoadedAsync())
                return;

            var bytes = result.Content;

            // 1. Metadaten-Payload vorbereiten
            var thumbnail = _thumbnailService.TryCreateThumbnailBase64(result.Filename, bytes, 64, 64);
            var timestamp = DateTime.UtcNow;
            var metaPayload = new AttachmentMetaPayload
            {
                Filename = result.Filename,
                Mime = result.Mime,
                Size = bytes.Length,
                Thumbnail = thumbnail!,
                Timestamp = timestamp
            };

            // 2. Verschlüsseln
            var encryptedMeta = _cryptoService.Encrypt(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(metaPayload)), _entryKey!);
            var encryptedContent = _cryptoService.Encrypt(bytes, _entryKey!);

            // 3. Entity speichern
            var attUuid = Guid.NewGuid().ToString();
            var attEntity = new AttachmentEntity
            {
                Uuid = attUuid,
                EntryId = _entry!.Id,
                EncryptedMeta = encryptedMeta,
                EncryptedContent = encryptedContent,
                IsSynced = false
            };
            await _databaseService.SaveAttachmentAsync(attEntity);

            // 4. Den Haupteintrag als geändert markieren, damit die neue Attachment-Liste gesynct wird
            _entry.UpdatedAt = DateTime.UtcNow;
            await _databaseService.SaveEntryAsync(_entry);
            
            // 5. UI aktualisieren
            Attachments.Add(new DetailAttachmentViewModel
            {
                Attachment = attEntity,
                Filename = result.Filename,
                Mime = result.Mime,
                Size = bytes.Length,
                ThumbnailBase64 = thumbnail!,
                Timestamp = timestamp
            });

            // 5. Bestätigen, dass die Datei angehängt wurde
            await _uiService.ToastAsync("Anhang gespeichert");
        }
        catch (Exception ex)
        {
            await _uiService.ErrorAsync($"Anhang konnte nicht hinzugefügt werden: {ex.Message}");
        }
    }
    
    /// <summary>
    /// Bricht die Bearbeitung ab. Falls Änderungen vorgenommen wurden, erfolgt eine Sicherheitsabfrage.
    /// </summary>
    [RelayCommand]
    private async Task CloseAsync()
    {
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
        if (_entry == null) // sollte nicht möglich sein
        {
            await _uiService.ErrorAsync("Kein Eintrag geladen.");
            return;
        } 

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
    /// Löscht einen spezifischen Anhang aus der Datenbank und der Liste.
    /// </summary>
    /// <param name="attachment">Das für den Anhang zuständige ViewModel.</param>
    [RelayCommand(CanExecute = nameof(CanWrite))]
    private async Task DeleteAttachmentAsync(DetailAttachmentViewModel attachment)
    {
        if (_entry == null) // sollte nicht möglich sein
        {
            await _uiService.ErrorAsync("Kein Eintrag geladen.");
            return;
        } 

        try
        {
            var confirm = await _uiService.ConfirmAsync(
                "Dateianhang löschen",
                $"Soll der Dateianhang '{attachment.Filename}' wirklich gelöscht werden?", 
                "Ja, löschen", 
                "Nein, abbrechen");

            if (!confirm) return;

            Attachments.Remove(attachment);
            await _databaseService.DeleteAttachmentAsync(attachment.Attachment.Id);
            
            // Den Haupteintrag als geändert markieren
            _entry.UpdatedAt = DateTime.UtcNow;
            await _databaseService.SaveEntryAsync(_entry);
            
            await _uiService.ToastAsync("Anhang gelöscht");
        }
        catch (Exception ex)
        {
            await _uiService.ErrorAsync($"Anhang konnte nicht gelöscht werden: {ex.Message}");
        }
    }
    
    /// <summary>
    /// Navigiert zur Editierseite zum Bearbeiten des Eintrags.
    /// </summary>
    [RelayCommand]
    private async Task EditAsync()
    {
        if (IsLoading) return;

        if (_entry == null) // sollte nicht möglich sein
        {
            await _uiService.ErrorAsync("Kein Eintrag geladen.");
            return;
        } 
        
        IsLoading = true;
        try
        {
            await _uiService.NavigateAsync("edit", new Dictionary<string, object> { { "id", _entry.Id } });
        } 
        catch (Exception ex)
        {
            await _uiService.ErrorAsync($"Navigation zur Bearbeitung fehlgeschlagen: {ex.Message}");
        }
        finally
        {
            IsLoading = false;
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
    /// Entschlüsselt einen Anhang und öffnet ihn mit der standardmäßigen App des Betriebssystems.
    /// </summary>
    /// <param name="attachment">Das für den Anhang zuständige ViewModel.</param>
    [RelayCommand]
    private async Task OpenAttachmentAsync(DetailAttachmentViewModel attachment)
    {
        try
        {
            if (!await EnsureEntryKeyLoadedAsync())
                return;

            // Inhalt entschlüsseln
            var fileBytes = _cryptoService.Decrypt(attachment.Attachment.EncryptedContent, _entryKey!);

            // Öffnen (Tempfile + Cleanup macht der UI-Service)
            await _uiService.OpenFileAsync(attachment.Filename, fileBytes);
        }
        catch (Exception ex)
        {
            await _uiService.ErrorAsync(ex.Message);
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
    
    // /// <summary>
    // /// Entschlüsselt einen Anhang und öffnet einen Dialog zum Speichern der Datei auf dem Dateisystem.
    // /// </summary>
    // /// <param name="attachment">Das für den Anhang zuständige ViewModel.</param>
    // [RelayCommand]
    // private async Task SaveAttachmentToDiskAsync(DetailAttachmentViewModel attachment)
    // {
    //     try
    //     {
    //         if (!await EnsureEntryKeyLoadedAsync())
    //             return;
    //         
    //         // Inhalt entschlüsseln
    //         var fileBytes = _cryptoService.Decrypt(attachment.Attachment.EncryptedContent, _entryKey!);
    //         
    //         // Speichern (Ziel wid per Speicher-Dialog ausgewählt)
    //         var ok = await _uiService.SaveFileAsync(attachment.Filename, fileBytes);
    //         if (ok)
    //             await _uiService.ToastAsync("Datei erfolgreich gespeichert");
    //         else
    //             await _uiService.ErrorAsync("Die Datei konnte nicht gespeichert werden.");
    //     }
    //     catch (Exception ex)
    //     {
    //         await _uiService.ErrorAsync($"Speichern fehlgeschlagen: {ex.Message}");
    //     }
    // }
    
    // /// <summary>
    // /// Setzt die gewählte Kategorie aus der Liste der Vorschläge.
    // /// </summary>
    // /// <param name="category">Der Name der gewählten Kategorie.</param>
    // [RelayCommand]
    // private void SelectCategory(string category)
    // {
    //     Category = category;
    // }
    
    /// <summary>
    /// Schaltet die Sichtbarkeit des Passworts (Auge-Symbol) um.
    /// </summary>
    [RelayCommand]
    private void TogglePassword()
    {
        IsPasswordHidden = !IsPasswordHidden;
    }

    /// <summary>
    /// Aktualisiert oder erstellt eine Berechtigung für den Freund für diesen Eintrag.
    /// </summary>
    /// <param name="friend">Das ViewModel des Freundes inklusive der neuen Berechtigungsstufe.</param>
    [RelayCommand]
    private async Task UpdatePermissionAsync(DetailFriendViewModel? friend)
    {
        if (_entry == null) // sollte nicht möglich sein
        {
            await _uiService.ErrorAsync("Kein Eintrag geladen.");
            return;
        } 

        if (friend?.User == null || _entry == null || _entry.Id == 0) return;

        try
        {
            if (!await EnsureEntryKeyLoadedAsync())
                return;
            
            var changed = false;
            var userPerm = await _databaseService.GetPermissionByEntryIdAndUserIdAsync(_entry.Id, friend.User.Id);
            if (userPerm == null) // der Freund hatte noch nie ein Recht auf diesen Eintrag 
            {
                if (friend.AccessLevel > 0)  // ... soll aber nun Recht bekommen
                {
                    // Ein neues Recht hinzufügen.
                    var encKeyForFriend = _cryptoService.EncryptRsa(_entryKey!, friend.User.PublicKey);
                    await _databaseService.SavePermissionAsync(new PermissionEntity
                    {
                        EntryId = _entry.Id,
                        UserId = friend.User.Id,
                        EncryptedKey = encKeyForFriend,
                        AccessLevel = friend.AccessLevel < 3 ? friend.AccessLevel : 2 // beim Teilen kann maximal Level 2 (Schreiben) vergeben werden
                    });
                    changed = true;
                }
            }
            else if (userPerm.AccessLevel != friend.AccessLevel)  
            {
                // Das Recht hat sich geändert!
                
                // Zugriffsrecht speichern
                userPerm.AccessLevel = friend.AccessLevel < 3 ? friend.AccessLevel : 2;
                if (friend.AccessLevel == 0)
                {
                    // Dem Freund wurde das Recht entzogen, wir löschen daher auch den Entry-Key
                    userPerm.EncryptedKey = string.Empty;
                }
                else if (string.IsNullOrEmpty(userPerm.EncryptedKey))
                {
                    // Entry-Key generieren 
                    userPerm.EncryptedKey = _cryptoService.EncryptRsa(_entryKey!, friend.User.PublicKey);
                }
                await _databaseService.SavePermissionAsync(userPerm);
                changed = true;
            }

            if (changed)
            {
                // Eintrag als geändert markieren für den Sync
                _entry.UpdatedAt = DateTime.UtcNow;
                await _databaseService.SaveEntryAsync(_entry);
                var status = friend.AccessLevel switch { 1 => "Leserechte", 2 => "Schreibrechte", _ => "Zugriff entzogen" };
                await _uiService.ToastAsync($"{friend.Name}: {status}");
            }
        }
        catch (Exception ex)
        {
            await _uiService.ErrorAsync("Berechtigung konnte nicht aktualisiert werden: " + ex.Message);
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
            
            // CreatorId und UpdaterId auslesen
            await UpdateAuditHintAsync();  
            
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
                    Category = !string.IsNullOrEmpty(_originalPayload.Category) ? _originalPayload.Category : _sessionService.Settings?.CategoryPlaceholder ?? "Allgemein";
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
            
            //  Header/Binding-Properties aktualisieren (computed props)
            OnPropertyChanged(nameof(FaviconBase64));
            OnPropertyChanged(nameof(HasFavicon));
            OnPropertyChanged(nameof(DisplayTitle));
            OnPropertyChanged(nameof(DisplayTitleInitial));
            
            // 5. Anhänge laden und Metadaten entschlüsseln
            await LoadAttachmentsAsync();

            // 6. Freunde laden
            await LoadFriendsAsync();
        }
        catch (Exception ex)
        {
            await _uiService.ErrorAsync($"Eintrag konnte nicht geladen werden: {ex.Message}");
            await GoBackAsync();
        }
    }

    /// <summary>
    /// Lädt die Dateianhänge des Eintrags.
    /// </summary>
    private async Task LoadAttachmentsAsync()
    {
        Attachments.Clear();
        if (_entry == null) return;
        
        var dbAttachments = await _databaseService.GetAttachmentsByEntryAsync(_entry.Id);
        foreach (var att in dbAttachments)
        {
            try
            {
                var metaPlainBytes = _cryptoService.Decrypt(att.EncryptedMeta, _entryKey!);
                var metaJson = Encoding.UTF8.GetString(metaPlainBytes);
                var meta = JsonSerializer.Deserialize<AttachmentMetaPayload>(metaJson);
                if (meta != null)
                {
                    Attachments.Add(new DetailAttachmentViewModel
                    {
                        Attachment = att,
                        Filename = meta.Filename,
                        Mime = meta.Mime,
                        Size = meta.Size,
                        Timestamp = meta.Timestamp,
                        ThumbnailBase64 = meta.Thumbnail
                    });
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Anhang {att.Uuid} konnte nicht entschlüsselt werden: {ex.Message}");
            }
        }
    }
    
    // todo Warnung anzeigen, wenn Personen den Eintrag sehen dürfen, die nicht in der Freundesliste des Benutzers sind (nicht in Tabelle users sind)
    
    /// <summary>
    /// Lädt die Liste der Freunde und ermittelt deren aktuelle Zugriffsstufe auf diesen Eintrag.
    /// </summary>
    private async Task LoadFriendsAsync()
    {
        Friends.Clear();
        if (_entry == null) return;

        try
        {
            var users = await _databaseService.GetUsersAsync();
            foreach (var u in users.Where(u => u.Id != 1 && !u.IsHidden))
            {
                var currentLevel = 0; // Standard: Kein Zugriff
                if (_entry != null)
                {
                    var p = await _databaseService.GetPermissionByEntryIdAndUserIdAsync(_entry.Id, u.Id);
                    if (p != null) currentLevel = p.AccessLevel; 
                }

                Friends.Add(new DetailFriendViewModel
                {
                    User = u,
                    AccessLevel = currentLevel,
                    OnChanged = (item) => _ = UpdatePermissionAsync(item)
                });
            }

            HasFriends = Friends.Count > 0;
        }
        catch
        {
            /* Ignoriert Fehler beim Laden der Mitglieder */ 
        }
    }
    
    /// <summary>
    /// Aktualisiert den Text-Hinweis (Audit Trail) über Ersteller und letzte Bearbeitung.
    /// </summary>
    private async Task UpdateAuditHintAsync()
    {
        if (_entry == null)
        {
            AuditHint = string.Empty;
            return;
        }
        
        try
        {
            var creator = "Unbekannt";
            var updater = "Unbekannt";
            var cu = _entry.CreatorId != 0 ? await _databaseService.GetUserAsync(_entry.CreatorId) : null;
            var uu = _entry.UpdaterId != 0 ? await _databaseService.GetUserAsync(_entry.UpdaterId) : null;

            if (cu != null) creator = cu.Name;
            if (uu != null) updater = uu.Name;

            var dateStr = _entry.UpdatedAt.ToLocalTime().ToString("dd.MM.yyyy HH:mm:ss");
            AuditHint = $"• Erstellt von: {creator} \n• Zuletzt bearbeitet von: {updater}, am {dateStr}";
        }
        catch
        {
            AuditHint = string.Empty;
        }
    }
}