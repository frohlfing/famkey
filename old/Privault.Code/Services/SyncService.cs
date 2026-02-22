using Privault.Core.Models.Entities;
using Privault.Core.Models.DTOs; 
using Privault.Core.Models.Payloads; 
using Privault.Core.Services.Contracts;
using System.Text;
using System.Text.Json;

// ReSharper disable PropertyCanBeMadeInitOnly.Local
// ReSharper disable UnusedAutoPropertyAccessor.Local

namespace Privault.Core.Services;

/// <inheritdoc cref="ISyncService" />
public class SyncService : ISyncService
{
    // ------------------------------------------------------------------------
    // --- Felder ---
    // ------------------------------------------------------------------------

    private readonly IConfigService _configService;
    private readonly ICryptoService _cryptoService;
    private readonly IDatabaseService _databaseService;
    private readonly ISessionService _sessionService;
    private readonly IGuardService _guardService;
    private readonly IWebService _webService;

    // ------------------------------------------------------------------------
    // --- Konstruktor ---
    // ------------------------------------------------------------------------
    
    /// <summary>
    /// Initialisiert eine neue Instanz des <see cref="SyncService"/> und injiziert die benötigten Dienste.
    /// </summary>
    /// <param name="configService">Dienst für den Zugriff auf globale App-Konfigurationen.</param>
    /// <param name="cryptoService">Dienst für kryptografische Operationen (Verschlüsselung, Signaturen).</param>
    /// <param name="databaseService">Dienst für den Zugriff auf die lokale verschlüsselte SQLite-Datenbank.</param>
    /// <param name="sessionService">Dienst zur Verwaltung der aktuellen Sitzungsdaten und Schlüssel im RAM.</param>
    /// <param name="guardService">Dienst für kritische Operationen wie den Identitätsabgleich.</param>
    /// <param name="webService">Dienst für die Kommunikation mit der REST-API des Sync-Servers.</param>
    /// <exception cref="ArgumentNullException">Wird geworfen, wenn einer der injizierten Dienste null ist.</exception>
    public SyncService(
        IConfigService configService, 
        ICryptoService cryptoService, 
        IDatabaseService databaseService, 
        ISessionService sessionService, 
        IGuardService guardService,
        IWebService webService)
    {
        _configService = configService ?? throw new ArgumentNullException(nameof(configService));
        _cryptoService = cryptoService ?? throw new ArgumentNullException(nameof(cryptoService));
        _databaseService = databaseService ?? throw new ArgumentNullException(nameof(databaseService));
        _sessionService = sessionService ?? throw new ArgumentNullException(nameof(sessionService));
        _guardService = guardService ?? throw new ArgumentNullException(nameof(guardService));
        _webService = webService ?? throw new ArgumentNullException(nameof(webService));
    }

    // ------------------------------------------------------------------------
    // --- Öffentliche Methoden ---
    // ------------------------------------------------------------------------

    /// <inheritdoc />
    public async Task<SyncStatistics> SyncAsync()
    {
        var stats = new SyncStatistics();
        if (!_sessionService.IsLoggedIn) return stats;

        //var vaultName = _sessionService.VaultName;
        var vaultName = "frank"; // todo hack wieder rausnehmen !!!!!!!!!!!!!!!!!!!!!!
        
        var settings = _sessionService.Settings!;

        // Versionsprüfung
        var serverVersion = await _webService.GetServerVersionAsync();
        if (serverVersion.Major != AppVersion.Major)
        {
            var v = AppVersion.Major > 1 ? $"{AppVersion.Major}" : "";
            throw new Exception("Die Server-Version passt nicht zur App. Korrigiere die Host-URL in den Einstellungen: " + 
                                $"https://privault{v}/api.frank-rohlfing.de");
        }
        if (serverVersion.Minor < AppVersion.RequiredServerMinor)
        {
            throw new Exception("Der Server ist noch nicht auf dem aktuellen Stand. Versuche es später nochmal.");
        }
        if (AppVersion.Minor < serverVersion.RequiredClientMinor)
        {
            throw new Exception("Bitte aktualisiere die App und start danach nochmal die Synchronisation.");
        }
        
        // 1. Prüfen: Gibt es mich auf dem Server?
        var user = _sessionService.User ?? throw new Exception("Kein lokaler User geladen.");
        var userName = user.Name;
        var userResponse = await _webService.FindUserAsync(vaultName, userName);
        if (userResponse == null)
        {
            // FALL A: User (und evtl. Tresor) existieren noch nicht.
            // -> Wir legen beides implizit an!

            // Sicherstellen, dass der API-Token in den Einstellungen eingetragen ist
            var apiToken = settings.ApiToken;
            if (string.IsNullOrEmpty(apiToken))
                throw new Exception("Kein API-Token hinterlegt. Kann Tresor nicht anlegen.");

            // Benutzer registrieren
            userResponse = await _webService.RegisterUserAsync(vaultName, userName);
            user.Uuid = userResponse.UserUuid;
            await _databaseService.SaveUserAsync(user);
        }
        else
        {
            // FALL B: User existiert
            if (user.Uuid != userResponse.UserUuid)
            {
                user.Uuid = userResponse.UserUuid;
                await _databaseService.SaveUserAsync(user);
            }

            // Sicherheits-Check!
            // Ist das Salt auf dem Server identisch zu meinem lokalen?
            // Wenn nicht, hat jemand anderes (oder ich am PC) das Passwort geändert (Notfall-Reset),
            // oder ich synchronisiere ein Zweitgerät das erst mal. 
            if (userResponse.Salt != settings.Salt)
            {
                // Wir müssen die Identität vom Server übernehmen und lokale Daten retten (umschlüsseln).
                await AdoptRemoteIdentityAsync(userResponse);
            }
        }

        //var serverUserUuid = localUser.Uuid;
        var serverUserUuid = userResponse.UserUuid;

        // --- STEP 0: SETTINGS PULL ---
        // Zuerst Freunde synchronisieren, damit Pull-Entries zugeordnet werden können.
        await PullFriendsAsync(userResponse);

        // --- STEP A: PULL (Herunterladen) ---
        var pullResponse = await _webService.PullSyncAsync(serverUserUuid, settings.LastSyncAt);
        
        // 1a. Gelöschte Einträge entfernen
        foreach (var tombstoneDto in pullResponse.Deletes)
        {
            var entry = await _databaseService.GetEntryByUuidAsync(tombstoneDto.EntryUuid);
            if (entry == null)
                continue;
            await _databaseService.SaveTombstoneAsync(new TombstoneEntity
            {
                EntryUuid = tombstoneDto.EntryUuid,
                DeletedAt = tombstoneDto.DeletedAt
            });
            await _databaseService.DeleteEntryAsync(entry.Id);
            stats.PullDeleted++;
        }

        // 1b. Fremde Einträge löschen, bei denen mir das Recht entzogen wurde
        foreach (var entryDto in pullResponse.Updates.Where(u => u.AccessLevel == 0))
        {
            var entry = await _databaseService.GetEntryByUuidAsync(entryDto.EntryUuid);
            if (entry == null)
                continue;
            // Hier kein lokaler Tombstone, da der Eintrag im Tresor ja noch existiert.
            await _databaseService.DeleteEntryAsync(entry.Id);
        }

        // Vorbereitung: Alle lokalen User laden, um UUIDs in IDs aufzulösen
        var users = await _databaseService.GetUsersAsync();
        var userUuidMap = users.ToDictionary(u => u.Uuid, u => u.Id);

        // 2. Updates einspielen
        foreach (var entryDto in pullResponse.Updates.Where(u => u.AccessLevel > 0))
        {
            // UUIDs der Benutzer in interne IDs auflösen (0 falls User lokal noch unbekannt)
            userUuidMap.TryGetValue(entryDto.CreatorUuid, out var creatorId);
            userUuidMap.TryGetValue(entryDto.UpdaterUuid, out var updaterId);

            // Eintrag aus dem DTO erstellen
            var entry = new EntryEntity
            {
                Uuid = entryDto.EntryUuid,
                EncryptedData = entryDto.EncryptedData,
                CreatorId = creatorId,
                UpdaterId = updaterId,
                UpdatedAt = entryDto.UpdatedAt
            };
            
            // Suchfelder aus dem verschlüsselten Payload extrahieren
            try 
            {
                // Wir brauchen den EntryKey (AES), um an die Suchfelder zu kommen
                var entryKey = _cryptoService.DecryptRsa(entryDto.EncryptedKey, _sessionService.PrivateKey!);
                var plainBytes = _cryptoService.Decrypt(entryDto.EncryptedData, entryKey);
                var payload = JsonSerializer.Deserialize<EntryPayload>(Encoding.UTF8.GetString(plainBytes));
                if (payload != null)
                {
                    entry.Category = payload.Category;
                    entry.Title = payload.Title;
                    entry.Url = payload.Url;
                    entry.Notes = payload.Notes;
                    entry.Favicon = payload.Favicon;
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Fehler beim Extrahieren der Suchfelder für {entry.Uuid}: {ex.Message}");
            }

            // Statistik aktualisieren
            if (await _databaseService.GetEntryByUuidAsync(entry.Uuid) == null) 
                stats.PullAdded++; 
            else 
                stats.PullUpdated++;
            
            // Eintrag speichern
            await _databaseService.SaveEntryAsync(entry);
            var savedEntry = await _databaseService.GetEntryByUuidAsync(entryDto.EntryUuid); // interne ID holen
            if (savedEntry == null) continue; // Sollte nicht passieren
            
            // A: Eigene Permission (UserId 1) speichern
            if (!string.IsNullOrEmpty(entryDto.EncryptedKey))
            {
                var myPerm = new PermissionEntity
                {
                    EntryId = savedEntry.Id,
                    UserId = 1, // Me
                    EncryptedKey = entryDto.EncryptedKey,
                    AccessLevel = entryDto.AccessLevel
                };
                await _databaseService.SavePermissionAsync(myPerm);
            }

            // B: Freunde verarbeiten
            foreach (var remoteFriends in entryDto.Friends)
            {
                // Wir speichern die Permission nur, wenn wir den User lokal kennen (aus dem Settings-Pull)
                if (userUuidMap.TryGetValue(remoteFriends.UserUuid, out var friendUserId))
                {
                    var friendPerm = new PermissionEntity
                    {
                        EntryId = savedEntry.Id,
                        UserId = friendUserId,
                        EncryptedKey = remoteFriends.EncryptedKey,
                        AccessLevel = remoteFriends.AccessLevel
                    };
                    await _databaseService.SavePermissionAsync(friendPerm);
                }
            }
            
            // Anhänge verarbeiten
            var remoteAttachmentUuids = entryDto.AttachmentUuids;
            var localAttachments = await _databaseService.GetAttachmentsByEntryAsync(savedEntry.Id);
            var localMap = localAttachments.ToDictionary(a => a.Uuid, a => a);

            foreach (var attUuid in remoteAttachmentUuids)
            {
                if (!localMap.ContainsKey(attUuid))
                {
                    // Hier laden wir nun das vollständige DTO mit Meta & Content
                    var response = await _webService.DownloadAttachmentAsync(attUuid);
                    if (string.IsNullOrEmpty(response.EncryptedContent))
                    {
                        System.Diagnostics.Debug.WriteLine($"Warnung: Anhang {attUuid} konnte nicht geladen werden.");
                        continue;
                    }

                    var att = new AttachmentEntity
                    {
                        Uuid = response.AttachmentUuid,
                        EntryId = savedEntry.Id,
                        EncryptedMeta = response.EncryptedMeta,
                        EncryptedContent = response.EncryptedContent,
                        IsSynced = true
                    };
                    await _databaseService.SaveAttachmentAsync(att);
                }
            }

            // Lokale Anhänge löschen, die auf dem Server nicht mehr existieren
            var remoteUuidsSet = remoteAttachmentUuids.ToHashSet();
            foreach (var l in localAttachments)
            {
                if (!remoteUuidsSet.Contains(l.Uuid))
                {
                    await _databaseService.DeleteAttachmentAsync(l.Id);
                }
            }
        }

        // --- STEP B: PUSH (Hochladen) ---

        var localUpdates = await _databaseService.GetEntriesSinceAsync(settings.LastSyncAt);
        var localDeletes = await _databaseService.GetTombstonesSinceAsync(settings.LastSyncAt);

        // Zusätzlich unsynced Attachments ermitteln
        var unsyncedAttachments = await _databaseService.GetAttachmentsUnsyncedAsync();

        if (localUpdates.Any() || localDeletes.Any() || unsyncedAttachments.Any())
        {
            // Vorbereitung: UUID Map laden, um IDs aufzulösen
            var users2 = await _databaseService.GetUsersAsync();
            var userMap = users2.ToDictionary(u => u.Id, u => u.Uuid);

            // Neue oder veränderte Einträge ermitteln
            var pushUpdates = new List<EntryDto>();
            foreach (var entry in localUpdates)
            {
                // Alle Berechtigungen für diesen Eintrag laden
                var perms = await _databaseService.GetPermissionsByEntryIdAsync(entry.Id);

                // Meine eigene Permission (ID 1) holen
                var myPerm = perms.FirstOrDefault(p => p.UserId == 1);
                
                // WICHTIG: Nur pushen, wenn ich Schreibrechte (Level >= 2) habe!
                // Level 2 = Schreiben, Level 3 = Besitzer
                if (myPerm == null || myPerm.AccessLevel < 2) 
                {
                    continue;
                }

                // Dateianhänge 
                var localAttachments = await _databaseService.GetAttachmentsByEntryAsync(entry.Id);
                var attachmentUuids = localAttachments.Select(a => a.Uuid)
                    .Where(u => !string.IsNullOrWhiteSpace(u))
                    .Distinct()
                    .ToList();
                
                // Liste der Freunde (UserId > 1) für den Server bauen
                var friends = perms
                    .Where(p => p.UserId > 1)
                    .Select(p => new FriendPermissionDto
                    {
                        UserUuid = userMap.GetValueOrDefault(p.UserId, string.Empty),
                        EncryptedKey = p.EncryptedKey,
                        AccessLevel = p.AccessLevel
                    })
                    .Where(p => !string.IsNullOrEmpty(p.UserUuid)) // Nur bekannte UUIDs
                    .ToList();

                pushUpdates.Add(new EntryDto
                {
                    EntryUuid = entry.Uuid,
                    EncryptedData = entry.EncryptedData,
                    EncryptedKey = myPerm.EncryptedKey,
                    AccessLevel = myPerm.AccessLevel,
                    AttachmentUuids = attachmentUuids,
                    Friends = friends,
                    CreatorUuid = userMap.GetValueOrDefault(entry.CreatorId, string.Empty),
                    UpdaterUuid = userMap.GetValueOrDefault(entry.UpdaterId, string.Empty),
                    UpdatedAt = entry.UpdatedAt,
                });
            }

            // Gelöschte Einträge ermitteln
            var pushDeletes = localDeletes.Select(d => new TombstoneDto
            {
                EntryUuid = d.EntryUuid,
                DeletedAt = d.DeletedAt
            }).ToList();
            
            // Änderungen an den Server pushen 
            var pushPayload = new SyncPushRequest { Updates = pushUpdates, Deletes = pushDeletes };
            await _webService.PushSyncAsync(serverUserUuid, pushPayload);
            stats.PushSent = pushUpdates.Count + pushDeletes.Count;

            // Unsynced Attachments hochladen (darf erst nach dem Push erfolgen, damit der Anhang an den Eintrag gehängt werden kann)
            foreach (var att in unsyncedAttachments)
            {
                var entry = await _databaseService.GetEntryAsync(att.EntryId);
                if (entry == null) continue;
                await _webService.UploadAttachmentAsync(entry.Uuid, att.Uuid, att.EncryptedMeta, att.EncryptedContent);
                att.IsSynced = true;
                await _databaseService.SaveAttachmentAsync(att);
            }        
        }

        // --- STEP C: FINALIZE ---
        // Zeitstempel setzen
        // Wir nehmen die Zeit, die der Server uns beim Pull gegeben hat.
        settings.LastSyncAt = pullResponse.ServerTime;
        await _databaseService.SaveSettingsAsync(settings);

        // --- STEP D: SETTINGS PUSH ---
        // Wir laden die verschlüsselten Settings (inkl. Freunden) hoch
        await PushFriendsAsync();
        
        return stats;
    }
    
    // ------------------------------------------------------------------------
    // --- Private Methoden ---
    // ------------------------------------------------------------------------
    
    /// <summary>
    /// Übernimmt eine neue Identität vom Server, falls das Master-Passwort auf einem anderen Gerät geändert wurde.
    /// Führt eine Umschlüsselung der lokalen Datenbank und aller vorhandenen Berechtigungen durch.
    /// </summary>
    /// <param name="userResponse">Die vom Server gelieferten Benutzerdaten (neues Salt, Public Key, Encrypted Private Key).</param>
    private async Task AdoptRemoteIdentityAsync(UserResponse userResponse)
    {
        var title = "Account verknüpfen";
        var message = userResponse.UserUuid == _sessionService.User!.Uuid
            ? "Du hast das Master-Passwort auf einem anderen Gerät geändert. Bitte gib es zur Synchronisation ein:"
            : "Dieser Tresor wird bereits auf einem anderen Gerät verwendet. Bitte gib das Master-Passwort ein, um die Identität zu übernehmen:";
        
        await _guardService.ExecuteCriticalOperationAsync(title, message, async (remoteMasterKey) =>
        {
            // 1. Private-Key des Servers entschlüsseln
            var remotePrivKey = _cryptoService.Decrypt(userResponse.EncryptedPrivateKey, remoteMasterKey);

            // 2. Falls sich das RSA-Schlüsselpaar geändert hat: Alle Permissions umschlüsseln
            var rsaKeyChanged = !_sessionService.PrivateKey!.SequenceEqual(remotePrivKey);
            if (rsaKeyChanged)
            {
                var allPermissions = await _databaseService.GetPermissionsAsync();
                foreach (var perm in allPermissions)
                {
                    // Entschlüsseln mit altem (aktuellem) PrivateKey, verschlüsseln mit neuem PublicKey
                    var entryKey = _cryptoService.DecryptRsa(perm.EncryptedKey, _sessionService.PrivateKey!);
                    perm.EncryptedKey = _cryptoService.EncryptRsa(entryKey, userResponse.PublicKey);
                }
                await _databaseService.UpdatePermissionsAsync(allPermissions);
            }

            // 3. Datenbankdatei mit dem neuen MasterKey verschlüsseln
            await _databaseService.RekeyAsync(remoteMasterKey);

            // 4. Lokalen Benutzer und Settings aktualisieren
            var localUser = _sessionService.User!;
            localUser.Uuid = userResponse.UserUuid;
            localUser.PublicKey = userResponse.PublicKey;
            await _databaseService.SaveUserAsync(localUser);

            var settings = _sessionService.Settings!;
            settings.Salt = userResponse.Salt;
            settings.EncryptedPrivateKey = userResponse.EncryptedPrivateKey;
            await _databaseService.SaveSettingsAsync(settings);

            // 5. Config/Salt-Mapping aktualisieren
            var map = _configService.Vaults;
            map[_sessionService.VaultName] = userResponse.Salt;
            _configService.Vaults = map;

            // 6. Session aktualisieren (Wichtig, damit folgende Operationen den neuen Key nutzen)
            _sessionService.PrivateKey = remotePrivKey;

        }, forceLogout: false, overrideSalt: userResponse.Salt, overrideValidationKey: userResponse.EncryptedPrivateKey);
    }

    /// <summary>
    /// Lädt die Freundesliste vom Server und verarbeitet Namensänderungen, Key-Wechsel und gelöschte Freunde.  
    /// </summary>
    /// <param name="userResponse">Die globale UUID des aktuellen Benutzers.</param>
    private async Task PullFriendsAsync(UserResponse userResponse)
    {
        // Clientseitig gespeicherte Benutzer holen
        var localUsers = await _databaseService.GetUsersAsync();

        // Öffentliche Schlüssel aller Benutzer vom Server holen
        var publicKeys = await _webService.GetPublicKeysAsync(userResponse.UserUuid);

        // Freundesliste vom Server holen
        var encryptedFriends = userResponse.EncryptedFriends;
        if (string.IsNullOrEmpty(encryptedFriends)) return;

        // Freundesliste entschlüsseln
        List<FriendPayload> friends;
        // Wir nutzen HKDF, um aus dem RSA-Private-Key einen stabilen AES-Key für die Freundesliste abzuleiten.
        // Info-String "friends" sorgt für Kontextbindung.
        var syncKeyMaterial = _sessionService.PrivateKey;
        if (syncKeyMaterial == null) 
            throw new Exception($"RSA PrivateKey nicht gefunden");
        // Salt ist hier optional, da der Input (RSA Key) bereits hochgradig entropisch ist.
        var aesKey = _cryptoService.DeriveKeyFromKey(syncKeyMaterial, null, "friends-list-encryption");
        try
        {
            var json = Encoding.UTF8.GetString(_cryptoService.Decrypt(encryptedFriends, aesKey));
            friends = JsonSerializer.Deserialize<List<FriendPayload>>(json) ?? throw new Exception("Die Freundesliste auf dem Server ist fehlerhaft.");
        }
        finally
        {
            _cryptoService.WipeKey(aesKey);
        }          
        
        // Vom Server geholte Freundesliste durchlaufen
        var needsRekeying = false;
        foreach (var remoteFriend in friends)
        {
            // Den öffentlichen Schlüssel des Freundes holen
            var publicKey = publicKeys.FirstOrDefault(pk => pk.UserUuid == remoteFriend.Uuid)?.PublicKey;
            if (string.IsNullOrEmpty(publicKey))
                continue; // der Freund existiert auf dem Server nicht mehr

            // Den vom Server geladenen Freund lokal suchen
            var localMatch = localUsers.FirstOrDefault(u => u.Uuid == remoteFriend.Uuid);
            if (localMatch == null)
            {
                // Freund lokal hinzufügen
                var newUser = new UserEntity
                {
                    Uuid = remoteFriend.Uuid,
                    Name = remoteFriend.Name,
                    PublicKey = publicKey,
                    IsVerified = remoteFriend.IsVerified,
                    IsHidden = remoteFriend.IsHidden,
                    UpdatedAt = remoteFriend.UpdatedAt
                };
                await _databaseService.SaveUserAsync(newUser);
            }
            else 
            {
                // Freund lokal aktualisieren
                
                // Fingerprint-Check (Sicherheits-Veto)
                if (localMatch.PublicKey != publicKey)
                {
                    // Der lokal gespeicherte RSA-Key ist veraltet. 

                    // Alle verschlüsselten Entry-Keys des Freundes werden geleert, da sie unbrauchbar geworden sind.
                    await _databaseService.RemoveEntryKeysForUserAsync(localMatch.Id);

                    // Neuen Key übernehmen, aber Vertrauen entziehen
                    localMatch.PublicKey = publicKey;
                    localMatch.IsVerified = false;
                    localMatch.UpdatedAt = DateTime.UtcNow;
                    await _databaseService.SaveUserAsync(localMatch);
                    
                    // Hat der Freund Zugriffsrecht auf mindestens einen Eintrag?
                    // Dann muss der Entry-Key neu generiert werden, bevor die Synchronization fortgesetzt werden kann. 
                    if (!needsRekeying)
                        if (await _databaseService.HasAccessWithoutKeyAsync(localMatch.Id))
                            needsRekeying = true;
                }

                // Metadaten Abgleich
                if (remoteFriend.UpdatedAt > localMatch.UpdatedAt)
                {
                    localMatch.Name = remoteFriend.Name;
                    localMatch.IsHidden = remoteFriend.IsHidden;
                    localMatch.IsVerified = remoteFriend.IsVerified;
                    localMatch.UpdatedAt = remoteFriend.UpdatedAt;
                    await _databaseService.SaveUserAsync(localMatch);
                }
            }
        }
        
        // 2. Freunde lokal löschen, die auf dem Server nicht mehr existieren.
        foreach (var localFriend in localUsers.Where(u => u.Id > 1))
        {
            if (!publicKeys.Exists(pk => pk.UserUuid == localFriend.Uuid))
            {
                await _databaseService.DeleteUserAsync(localFriend.Id);
            }
        }
        
        // Sync abbrechen, wenn die Umschlüsselung eines Entry-Keys noch aussteht.
        if (needsRekeying)
        {
            throw new Exception("Sicherheitsstopp: Die Identität eines Freundes hat sich geändert. " +
                                "Bitte verifiziere den neuen Fingerprint in den Einstellungen, bevor du synchronisierst.");
        }        
    }

    /// <summary>
    /// Verschlüsselt die Freunde und lädt sie auf den Server hoch.
    /// Nutzt eine hybride Verschlüsselung basierend auf dem privaten RSA-Schlüssel des Benutzers.
    /// </summary>
    private async Task PushFriendsAsync()
    {
        var localUser = _sessionService.User!;
        
        // Wir nutzen HKDF, um aus dem RSA-Private-Key einen stabilen AES-Key für die Freundesliste abzuleiten.
        var syncKeyMaterial = _sessionService.PrivateKey;
        if (syncKeyMaterial == null) 
            throw new Exception($"RSA PrivateKey nicht gefunden");
        var aesKey = _cryptoService.DeriveKeyFromKey(syncKeyMaterial, null, "friends-list-encryption");
        try
        {
            // 1. Alle lokal hinzugefügten Freunde laden
            var users = await _databaseService.GetUsersAsync();
            var friends = users.Where(u => u.Id > 1).Select(u => new FriendPayload
            {
                Uuid = u.Uuid,
                Name = u.Name,
                IsVerified = u.IsVerified,
                IsHidden = u.IsHidden,
                UpdatedAt = u.UpdatedAt
            }).ToList();

            // Wenn es keine Freunde gibt, ist kein Push erforderlich.
            if (friends.Count == 0)
                return;

            // 2. Payload bauen
            var json = JsonSerializer.Serialize(friends);
            var plainBytes = Encoding.UTF8.GetBytes(json);
            var encryptedBlob = _cryptoService.Encrypt(plainBytes, aesKey);

            // 3. Hochladen
            await _webService.SaveFriendsAsync(localUser.Uuid, encryptedBlob);
        }
        finally
        {
            _cryptoService.WipeKey(aesKey);
        }
    }
}

/// <summary>
/// Repräsentiert die Zusammenfassung eines Synchronisationsvorgangs.
/// Enthält Zähler für heruntergeladene und hochgeladene Änderungen zur Benutzerinformation.
/// </summary>
public class SyncStatistics
{
    /// <summary>
    /// Anzahl der vom Server neu hinzugefügten Einträge.
    /// </summary>
    public int PullAdded { get; set; }

    /// <summary>
    /// Anzahl der vom Server aktualisierten Einträge.
    /// </summary>
    public int PullUpdated { get; set; }

    /// <summary>
    /// Anzahl der lokal gelöschten Einträge aufgrund von Server-Tombstones.
    /// </summary>
    public int PullDeleted { get; set; }

    /// <summary>
    /// Anzahl der erfolgreich zum Server übertragenen Änderungen (Updates und Deletes).
    /// </summary>
    public int PushSent { get; set; }

    /// <summary>
    /// Gibt an, ob während des Sync-Vorgangs überhaupt Daten bewegt wurden.
    /// </summary>
    public bool HasChanges => PullAdded > 0 || PullUpdated > 0 || PullDeleted > 0 || PushSent > 0;

    /// <summary>
    /// Erzeugt eine benutzerfreundliche Zusammenfassung der Statistik.
    /// </summary>
    /// <returns>Ein mehrzeiliger String mit den Details.</returns>
    public override string ToString() => 
        $"✳️ Hinzugefügt: {PullAdded}\n" +
        $"✏️ Aktualisiert: {PullUpdated}\n" +
        $"❌ Gelöscht: {PullDeleted}\n" +
        $"💾 Gesichert: {PushSent}";
}