using System.Diagnostics.CodeAnalysis;
using Privault.Core.Models.Entities;
using Privault.Core.Services.Contracts;
using SQLite;

// ReSharper disable UseRawString

namespace Privault.Core.Services;

/// <inheritdoc cref="IDatabaseService" />
public class DatabaseService : IDatabaseService
{
    // ------------------------------------------------------------------------
    // --- Felder ---
    // ------------------------------------------------------------------------

    private readonly string _basePath;
    private SQLiteAsyncConnection? _connection;
    private string? _currentDbPath;

    // ------------------------------------------------------------------------
    // --- Konstruktor ---
    // ------------------------------------------------------------------------
    
    /// <summary>
    /// Initialisiert eine neue Instanz des <see cref="DatabaseService"/>.
    /// </summary>
    /// <param name="basePath">Der Basispfad auf dem Endgerät, in dem die Datenbankdateien gespeichert werden sollen.</param>
    /// <exception cref="ArgumentNullException">Wird geworfen, wenn <paramref name="basePath"/> null oder leer ist.</exception>
    public DatabaseService(string basePath)
    {
        if (string.IsNullOrWhiteSpace(basePath))
            throw new ArgumentNullException(nameof(basePath), "Der Basispfad für die Datenbank darf nicht leer sein.");
            
        _basePath = basePath;
    }

    /// <inheritdoc />
    public async Task InitializeAsync(string vaultName, byte[] masterKey)
    {
        if (_connection != null)
            return; // Bereits verbunden

        // 1. Pfad bestimmen
        _currentDbPath = GetDatabasePath(vaultName);

        // 2. Optionen konfigurieren (Verschlüsselung!)
        var options = new SQLiteConnectionString(
            _currentDbPath,
            SQLiteOpenFlags.ReadWrite | SQLiteOpenFlags.Create | SQLiteOpenFlags.FullMutex,
            storeDateTimeAsTicks: false, // Zeitstempel nicht als Ticks (BIGINT), sondern als ISO-String
            dateTimeStringFormat: "yyyy-MM-ddTHH:mm:ss.fffZ", // ISO-Format mit 'Z' am Ende erzwingen
            //key: vaultName == "test" ? null : masterKey // TODO raus
            key: masterKey
        );

        // 3. Verbindung herstellen
        _connection = new SQLiteAsyncConnection(options);

        // 4. Migrationen
        await RunMigrationsAsync();

        // await DebugCipherInfo();
        // var keyHex = Convert.ToHexString(masterKey); 
        // System.Diagnostics.Debug.WriteLine("MASTER KEY (HEX): " + keyHex);
        // var keyBase64 = Convert.ToBase64String(masterKey);
        // System.Diagnostics.Debug.WriteLine("MASTER KEY (BASE64): " + keyBase64);
    }
    
    // ------------------------------------------------------------------------
    // --- Öffentliche Methoden ---
    // ------------------------------------------------------------------------

    // --- Verbindung & System ---
    
    /// <inheritdoc />
    public async Task CloseConnectionAsync()
    {
        if (_connection != null)
        {
            await _connection.CloseAsync();
            _connection = null;
        }
    }
     
    /// <inheritdoc />
    public void CreateBackup()
    {
        if (string.IsNullOrEmpty(_currentDbPath)) return;
        File.Copy(_currentDbPath, _currentDbPath + ".bak", true);
    }

    /// <inheritdoc />
    public bool DatabaseExists(string vaultName)
    {
        var path = GetDatabasePath(vaultName);
        return File.Exists(path);
    }

    /// <inheritdoc />
    public async Task DeleteCurrentDatabase()
    {
        await CloseConnectionAsync();
        if (!string.IsNullOrEmpty(_currentDbPath) && File.Exists(_currentDbPath))
        {
            File.Delete(_currentDbPath);
        }
    }
    
    /// <inheritdoc />
    public async Task<VersionEntity?> GetVersionAsync()
    {
        EnsureInitialized();
        return await _connection!.Table<VersionEntity>().FirstOrDefaultAsync();
    }
    
    /// <inheritdoc />
    public async Task RekeyAsync(byte[] newPassword)
    {
        EnsureInitialized();
        var hexString = BitConverter.ToString(newPassword).Replace("-", "");
        var query = $"PRAGMA rekey = \"x'{hexString}'\""; // SQLCipher-Befehl zum Ändern des Schlüssels
        await _connection!.ExecuteScalarAsync<string>(query);
    }

    /// <inheritdoc />
    public void RemoveBackup()
    {
        if (string.IsNullOrEmpty(_currentDbPath)) return;
        var backupPath = _currentDbPath + ".bak";
        if (!File.Exists(backupPath)) return;
        try
        {
            File.Delete(backupPath);
        }
        catch
        {
             /* ignored */
        }
    }

    /// <inheritdoc />
    public void RenameDatabase(string oldName, string newName)
    {
        if (_connection != null) throw new InvalidOperationException("Erst Verbindung schließen!");
        var oldPath = Path.Combine(_basePath, $"{oldName}.db3");
        var newPath = Path.Combine(_basePath, $"{newName}.db3");
        if (!File.Exists(oldPath)) return;
        File.Move(oldPath, newPath);
        _currentDbPath = newPath;
    }
    
    /// <inheritdoc />
    public void RestoreBackup()
    {
        if (string.IsNullOrEmpty(_currentDbPath)) return;
        var backupPath = _currentDbPath + ".bak";
        if (!File.Exists(backupPath)) return;
        File.Copy(backupPath, _currentDbPath, true);
        try
        {
            File.Delete(backupPath);
        }
        catch
        {
             /* ignored */
        }
    }

    // --- Benutzer ---
    
    /// <inheritdoc />
    public async Task<List<UserEntity>> GetUsersAsync()
    {
        EnsureInitialized();
        return await _connection!.Table<UserEntity>().ToListAsync();
    }
    
    /// <inheritdoc />
    public async Task<UserEntity?> GetUserAsync(int userId)
    {
        EnsureInitialized();
        return await _connection!.Table<UserEntity>().Where(u => u.Id == userId).FirstOrDefaultAsync();
    }
    
    /// <inheritdoc />
    public async Task<UserEntity?> GetUserByUuidAsync(string userUuid)
    {
        EnsureInitialized();
        if (string.IsNullOrWhiteSpace(userUuid)) return null;
        return await _connection!.Table<UserEntity>().Where(u => u.Uuid == userUuid).FirstOrDefaultAsync();
    }

    /// <inheritdoc />
    public async Task SaveUserAsync(UserEntity user)
    {
        EnsureInitialized();
        var existing = await _connection!.Table<UserEntity>().Where(u => u.Id == user.Id || u.Uuid == user.Uuid).FirstOrDefaultAsync();
        if (existing != null)
        {
            user.Id = existing.Id;
            await _connection!.UpdateAsync(user);
        }
        else
        {
            await _connection!.InsertAsync(user);
        }
    }
    
    // public async Task HideUserAsync(int userId)
    // {
    //     EnsureInitialized();
    //     await _connection!.RunInTransactionAsync(tran =>
    //     {
    //         // 1. Alle Berechtigungen des Benutzers laden
    //         var permissions = tran.Table<PermissionEntity>()
    //             .Where(p => p.UserId == userId && (p.AccessLevel > 0 || p.EncryptedKey != string.Empty))
    //             .ToList();
    //
    //         // 2. Zugriffslevel auf 0 setzen und Entry-Key entfernen 
    //         foreach (var perm in permissions)
    //         {
    //             perm.AccessLevel = 0;
    //             perm.EncryptedKey = string.Empty;
    //             tran.Update(perm);
    //         }
    //
    //         // 3. Zeitstempel der Einträge aktualisieren
    //         var entryIds = permissions.Select(p => p.EntryId).Distinct().ToList();
    //         foreach (var id in entryIds)
    //         {
    //             var entry = tran.Table<EntryEntity>().FirstOrDefault(e => e.Id == id);
    //             if (entry != null)
    //             {
    //                 entry.UpdatedAt = DateTime.UtcNow;
    //                 tran.Update(entry);
    //             }
    //         }
    //         
    //         // 4. Benutzer-Status aktualisieren
    //         var user = tran.Table<UserEntity>().FirstOrDefault(u => u.Id == userId);
    //         user.IsVerified = false;
    //         user.IsHidden = true;
    //         user.UpdatedAt = DateTime.UtcNow;
    //         tran.Update(user);
    //     });
    // }
    
    /// <inheritdoc />
    public async Task HideUserAsync(int userId)
    {
        EnsureInitialized();
        var now = DateTime.UtcNow;
        await _connection!.RunInTransactionAsync(tran =>
        {
            // 1. Alle Permissions des Users entwerten.
            tran.Execute(@"
                UPDATE permissions 
                SET access_level = 0, encrypted_key = '' 
                WHERE user_id = ? AND (access_level > 0 OR encrypted_key != '')
                ", userId);

            // 2. Zeitstempel aller betroffenen Einträge aktualisieren
            tran.Execute(@"
                UPDATE entries 
                SET updated_at = ? 
                WHERE id IN (SELECT entry_id FROM permissions WHERE user_id = ?)
                ", now, userId);
        
            // 3. Benutzer-Status aktualisieren
            tran.Execute(@"
                UPDATE users 
                SET is_verified = 0, is_hidden = 1, updated_at = ? 
                WHERE id = ?
                ", now, userId);
        });
    }
    
    // public async Task DeleteUserAsync(int userId)
    // {
    //     EnsureInitialized();
    //     await _connection!.RunInTransactionAsync(tran =>
    //     {
    //         // 1. Alle Berechtigungen (Permissions) dieses Benutzers löschen
    //         tran.Table<PermissionEntity>().Delete(p => p.UserId == userId);
    //         
    //         // 2. Alle Einträge löschen, die dieser Benutzer erstellt hat
    //         var userEntries = tran.Table<EntryEntity>().Where(e => e.CreatorId == userId).ToList();
    //         foreach (var entry in userEntries)
    //         {
    //             DeleteEntry(tran, entry.Id);
    //         }
    //         
    //         // 3. Einträge bereinigen, die dieser Benutzer zuletzt bearbeitet hat
    //         //await _connection!.ExecuteAsync("UPDATE entries SET updated_by_user_id = 0 WHERE updated_by_user_id = ?", user.Id);
    //         var editedEntries = tran.Table<EntryEntity>().Where(e => e.UpdaterId == userId).ToList();
    //         foreach (var entry in editedEntries)
    //         {
    //             entry.UpdaterId = 0; 
    //             tran.Update(entry);
    //         }
    //
    //         // 4. Den Benutzer selbst löschen
    //         tran.Table<UserEntity>().Delete(u => u.Id == userId);
    //     });
    // }
    
    /// <inheritdoc />
    public async Task DeleteUserAsync(int userId)
    {
        EnsureInitialized();
        await _connection!.RunInTransactionAsync(tran =>
        {
            // 1. Lösche alle Permissions, die der Benutzer selbst hat
            tran.Execute("DELETE FROM permissions WHERE user_id = ?", userId);
        
            // 2. Lösche ALLE Permissions für ALLE Einträge, die dieser Benutzer erstellt hat
            // (Wenn der Besitzer gelöscht wird, haben auch Freunde keinen Zugriff mehr)
            tran.Execute("DELETE FROM permissions WHERE entry_id IN (SELECT id FROM entries WHERE creator_id = ?)", userId);

            // 3. Lösche alle Anhänge von Einträgen, die dieser Benutzer erstellt hat
            tran.Execute("DELETE FROM attachments WHERE entry_id IN (SELECT id FROM entries WHERE creator_id = ?)", userId);

            // 4. Lösche die Einträge des Benutzers 
            tran.Execute("DELETE FROM entries WHERE creator_id = ?", userId);
        
            // 5. UpdaterId bei verbliebenen Einträgen nullen
            tran.Execute("UPDATE entries SET updater_id = 0 WHERE updater_id = ?", userId);

            // 6. Den Benutzer selbst löschen
            tran.Execute("DELETE FROM users WHERE id = ?", userId);
        });
    }
    
    // --- Einträge ---

    /// <inheritdoc />
    public async Task<List<EntryEntity>> GetEntriesAsync()
    {
        EnsureInitialized();
        return await _connection!.Table<EntryEntity>().ToListAsync();
    }

    /// <inheritdoc />
    public async Task<List<EntryEntity>> GetEntriesSinceAsync(DateTime since)
    {
        EnsureInitialized();
        return await _connection!.Table<EntryEntity>().Where(e => e.UpdatedAt > since).ToListAsync();
    }

    /// <inheritdoc />
    public async Task<EntryEntity?> GetEntryAsync(int entryId)
    {
        EnsureInitialized();
        return await _connection!.Table<EntryEntity>().Where(e => e.Id == entryId).FirstOrDefaultAsync();
    }

    /// <inheritdoc />
    public async Task<EntryEntity?> GetEntryByUuidAsync(string entryUuid)
    {
        EnsureInitialized();
        return await _connection!.Table<EntryEntity>().Where(e => e.Uuid == entryUuid).FirstOrDefaultAsync();
    }

    /// <inheritdoc />
    public async Task SaveEntryAsync(EntryEntity entry)
    {
        EnsureInitialized();
        var existing = await _connection!.Table<EntryEntity>().Where(e => e.Id == entry.Id || e.Uuid == entry.Uuid).FirstOrDefaultAsync();
        if (existing != null)
        {
            entry.Id = existing.Id;
            await _connection.UpdateAsync(entry);
        }
        else
        {
            await _connection.InsertAsync(entry);
        }
    }
    
    /// <inheritdoc />
    public async Task SaveEntryWithPermissionsAsync(EntryEntity entry, int userId, string encryptedKey, int accessLevel = 3)
    {
        EnsureInitialized();
        await _connection!.RunInTransactionAsync(tran =>
        {
            // 1. Eintrag speichern (wie SaveEntryAsync, aber synchron)
            var existing = tran.Table<EntryEntity>().FirstOrDefault(e => e.Id == entry.Id || e.Uuid == entry.Uuid);
            if (existing != null)
            {
                entry.Id = existing.Id;
                tran.Update(entry);
            }
            else
            {
                tran.Insert(entry);
            }

            // Berechtigung für den Benutzer erzeugen
            var permission = new PermissionEntity
            {
                EntryId = entry.Id,
                UserId = userId,
                EncryptedKey = encryptedKey,
                AccessLevel = accessLevel
            };
            
            // 2. Berechtigung für den Benutzer speichern (wie SaveEntryAsync, aber synchron)
            var existingPerm = tran.Table<PermissionEntity>().FirstOrDefault(p => p.EntryId == permission.EntryId && p.UserId == permission.UserId);
            if (existingPerm != null)
            {
                permission.Id = existingPerm.Id;
                tran.Update(permission);
            }
            else
            {
                tran.Insert(permission);
            }
        });
    }
    
    /// <inheritdoc />
    public async Task DeleteEntryAsync(int entryId)
    {
        EnsureInitialized();
        await _connection!.RunInTransactionAsync(tran =>
        {
            DeleteEntry(tran, entryId);
        });
    }  

    // --- Dateianhänge ---
    
    /// <inheritdoc />
    public async Task<List<AttachmentEntity>> GetAttachmentsByEntryAsync(int entryId)
    {
        EnsureInitialized();
        return await _connection!.Table<AttachmentEntity>().Where(a => a.EntryId == entryId).ToListAsync();
    }
    
    /// <inheritdoc />
    public async Task<List<AttachmentEntity>> GetAttachmentsUnsyncedAsync()
    {
        EnsureInitialized();
        return await _connection!.Table<AttachmentEntity>().Where(a => a.IsSynced == false).ToListAsync();
    }
    
    /// <inheritdoc />
    public async Task<AttachmentEntity?> GetAttachmentAsync(int attachmentId)
    {
        EnsureInitialized();
        return await _connection!.Table<AttachmentEntity>().Where(a => a.Id == attachmentId).FirstOrDefaultAsync();
    }
    
    /// <inheritdoc />
    public async Task<AttachmentEntity?> GetAttachmentByUuidAsync(string attachmentUuid)
    {
        EnsureInitialized();
        return await _connection!.Table<AttachmentEntity>().Where(a => a.Uuid == attachmentUuid).FirstOrDefaultAsync();
    }

    /// <inheritdoc />
    public async Task SaveAttachmentAsync(AttachmentEntity attachment)
    {
        EnsureInitialized();
        var existing = await _connection!.Table<AttachmentEntity>().Where(a => a.Id == attachment.Id || a.Uuid == attachment.Uuid).FirstOrDefaultAsync();
        if (existing != null)
        {
            attachment.Id = existing.Id;
            await _connection.UpdateAsync(attachment);
        }
        else
        {
            await _connection.InsertAsync(attachment);
        }
    }
    
    /// <inheritdoc />
    public async Task DeleteAttachmentAsync(int attachmentId)
    {
        EnsureInitialized();
        await _connection!.Table<AttachmentEntity>().DeleteAsync(a => a.Id == attachmentId);
    }
    
    // --- Berechtigungen ---
    
    /// <inheritdoc />
    public async Task<List<PermissionEntity>> GetPermissionsAsync()
    {
        EnsureInitialized();
        return await _connection!.Table<PermissionEntity>().ToListAsync();
    }
    
    /// <inheritdoc />
    public async Task<List<PermissionEntity>> GetPermissionsByEntryIdAsync(int entryId)
    {
        EnsureInitialized();
        return await _connection!.Table<PermissionEntity>().Where(p=> p.EntryId == entryId).ToListAsync();
    }

    /// <inheritdoc />
    public async Task<List<PermissionEntity>> GetPermissionsByUserIdAsync(int userId)
    {
        EnsureInitialized();
        return await _connection!.Table<PermissionEntity>().Where(p=> p.UserId == userId).ToListAsync();
    }
    
    /// <inheritdoc />
    public async Task<PermissionEntity?> GetPermissionAsync(int permissionId)
    {
        EnsureInitialized();
        return await _connection!.Table<PermissionEntity>().Where(p=> p.Id == permissionId).FirstOrDefaultAsync();
    }
    
    /// <inheritdoc />
    public async Task<PermissionEntity?> GetPermissionByEntryIdAndUserIdAsync(int entryId, int userId)
    {
        EnsureInitialized();
        return await _connection!.Table<PermissionEntity>().Where(p=> p.EntryId == entryId && p.UserId == userId).FirstOrDefaultAsync();
    }
    
    public async Task<bool> HasAccessWithoutKeyAsync(int userId)
    {
        EnsureInitialized();
        
        // Gibt es Zugriffe ohne Key?
        var count = await _connection!.Table<PermissionEntity>()
            .Where(p=> p.UserId == userId && p.EncryptedKey == string.Empty && p.AccessLevel > 0)
            .CountAsync();
        
        return count > 0;
    }
    
    /// <inheritdoc />
    public async Task SavePermissionAsync(PermissionEntity permission)
    {
        EnsureInitialized();
        var existing= await _connection!.Table<PermissionEntity>().Where(p => p.Id == permission.Id || (p.EntryId == permission.EntryId && p.UserId == permission.UserId)).FirstOrDefaultAsync();
        if (existing != null)
        {
            permission.Id = existing.Id;
            await _connection.UpdateAsync(permission);
        }
        else
        {
            await _connection.InsertAsync(permission);
        }
    }
    
    public async Task UpdatePermissionsAsync(IEnumerable<PermissionEntity> permissions)
    {
        EnsureInitialized();
        await _connection!.RunInTransactionAsync(tran =>
        {
            foreach (var perm in permissions)
            {
                tran.Update(perm);
            }
        });
    }
    
    // public async Task RemoveEntryKeysForUserAsync(int userId)
    // {
    //     EnsureInitialized();
    //
    //     await _connection!.RunInTransactionAsync(tran =>
    //     {
    //         // 1. Alle Permissions des Users laden, die noch einen Entry-Key haben
    //         var permissionsWithKeys = tran.Table<PermissionEntity>()
    //             .Where(p => p.UserId == userId && p.EncryptedKey != string.Empty)
    //             .ToList();
    //
    //         if (permissionsWithKeys.Count == 0) return;
    //
    //         // 2. Entry-Keys entfernen
    //         foreach (var perm in permissionsWithKeys)
    //         {
    //             perm.EncryptedKey = string.Empty;
    //             tran.Update(perm);
    //         }
    //         
    //         // 3. Zeitstempel der Einträge aktualisieren
    //         var entryIds = permissionsWithKeys.Select(p => p.EntryId).Distinct().ToList();
    //         foreach (var id in entryIds)
    //         {
    //             var entry = tran.Table<EntryEntity>().FirstOrDefault(e => e.Id == id);
    //             if (entry != null)
    //             {
    //                 entry.UpdatedAt = DateTime.UtcNow;
    //                 tran.Update(entry);
    //             }
    //         }
    //     });
    // }
    
    /// <inheritdoc />
    public async Task RemoveEntryKeysForUserAsync(int userId)
    {
        EnsureInitialized();
        var now = DateTime.UtcNow;

        await _connection!.RunInTransactionAsync(tran =>
        {
            // 1. Alle Entry-Keys des Users in einem Rutsch entfernen.
            // Wir filtern direkt im SQL auf leere Keys, um unnötige Schreibvorgänge zu vermeiden.
            int affectedPermissions = tran.Execute(@"
                UPDATE permissions 
                SET encrypted_key = '' 
                WHERE user_id = ? AND encrypted_key != ''
                ", userId);

            // Wenn keine Keys entfernt wurden, müssen wir auch keine Zeitstempel aktualisieren.
            if (affectedPermissions == 0) return;

            // 2. Zeitstempel der betroffenen Einträge aktualisieren.
            // Mit einer Subquery finden wir alle Entry-IDs, die mit diesem User verknüpft sind.
            // Das ist extrem effizient, da SQLite die IDs intern im Index abgleicht.
            tran.Execute(@"
                UPDATE entries 
                SET updated_at = ? 
                WHERE id IN (SELECT entry_id FROM permissions WHERE user_id = ?)
                ", now, userId);
        });
    }
    
    /// <inheritdoc />
    public async Task DeletePermissionAsync(int permissionId)
    {
        EnsureInitialized();
        await _connection!.Table<PermissionEntity>().DeleteAsync(p => p.Id == permissionId);
    }    
    
    // --- Grabsteine ---

    /// <inheritdoc />
    public async Task<List<TombstoneEntity>> GetTombstonesSinceAsync(DateTime since)
    {
        EnsureInitialized();
        return await _connection!.Table<TombstoneEntity>().Where(d => d.DeletedAt > since).ToListAsync();
    }

    /// <inheritdoc />
    public async Task SaveTombstoneAsync(TombstoneEntity tombstone)
    {
        EnsureInitialized();
        var existing = await _connection!.Table<TombstoneEntity>().Where(t => t.Id == tombstone.Id || t.EntryUuid == tombstone.EntryUuid).FirstOrDefaultAsync();
        if (existing != null)
        {
            tombstone.Id = existing.Id;
            await _connection!.UpdateAsync(tombstone);
        }
        else
        {
            await _connection!.InsertAsync(tombstone);
        }
    }
    
    // --- Einstellungen ---

    /// <inheritdoc />
    public async Task<SettingsEntity?> GetSettingsAsync()
    {
        EnsureInitialized();
        return await _connection!.Table<SettingsEntity>().FirstOrDefaultAsync();
    }

    /// <inheritdoc />
    public async Task SaveSettingsAsync(SettingsEntity settings)
    {
        EnsureInitialized();
        settings.Id = 1;
        await _connection!.InsertOrReplaceAsync(settings);
    }

    // ------------------------------------------------------------------------
    // --- Private Methoden ---
    // ------------------------------------------------------------------------
    
    /// <summary>
    /// Löscht einen Eintrag mit allen zugehörigen Berechtigungen (synchron, ohne Transaktion).
    /// </summary>
    /// <param name="conn">Datenbankverbindung</param>
    /// <param name="entryId">Die interne ID des zu löschenden Eintrags.</param>
    private static void DeleteEntry(SQLiteConnection conn, int entryId)
    {
        // 1. Alle Berechtigungen für diesen Eintrag löschen
        conn.Table<PermissionEntity>().Delete(p => p.EntryId == entryId);

        // 2. Alle Anhänge (Metadaten und physische Blobs) dieses Eintrags löschen
        conn.Table<AttachmentEntity>().Delete(a => a.EntryId == entryId);

        // 3. Den Eintrag selbst physisch löschen
        conn.Table<EntryEntity>().Delete(e => e.Id == entryId);
    }

    /// <summary>
    /// Stellt sicher, dass die Datenbankverbindung initialisiert wurde.
    /// </summary>
    /// <exception cref="InvalidOperationException">Wird geworfen, wenn die Verbindung null ist.</exception>
    private void EnsureInitialized()
    {
        if (_connection == null)
            throw new InvalidOperationException("Datenbank ist nicht initialisiert! Erst InitializeAsync aufrufen.");
    }

    /// <summary>
    /// Erstellt einen sicheren Dateipfad basierend auf dem Tresornamen.
    /// </summary>
    private string GetDatabasePath(string vaultName)
    {
        var safeName = string.Join("_", vaultName.Split(Path.GetInvalidFileNameChars()));
        return Path.Combine(_basePath, $"{safeName}.db3");
    }
    
    /// <summary>
    /// Interne Hilfsklasse zum Einlesen von SQLite Metadaten.
    /// </summary>
    private class TableInfoRow
    {
        [Column("name")]
        public string Name { get; set; } = string.Empty;
    }
    
    // --- Migration ---
    
    /// <summary>
    /// Prüft innerhalb der SQLite-Metadaten, ob eine bestimmte Spalte in einer Tabelle existiert.
    /// </summary>
    /// <param name="conn">Datenbankverbindung.</param>
    /// <param name="table">Der Name der Tabelle.</param>
    /// <param name="column">Der Name der zu prüfenden Spalte.</param>
    /// <returns><c>true</c>, wenn die Spalte existiert.</returns>
    private static bool ColumnExists(SQLiteConnection conn, string table, string column)
    {
        var rows = conn.Query<TableInfoRow>($"PRAGMA table_info('{table}')");
        return rows.Any(r => string.Equals(r.Name, column, StringComparison.OrdinalIgnoreCase));
    }
    
    /// <summary>
    /// Speichert die Schema-Version.
    /// </summary>
    /// <param name="conn">Datenbankverbindung.</param>
    /// <param name="version">Die zu speichernde Version.</param>
    private static void SaveVersion(SQLiteConnection conn, VersionEntity version)
    {
        version.Id = 1;
        conn.InsertOrReplace(version);
    }
    
    /// <summary>
    /// Speichert die Schema-Version.
    /// </summary>
    /// <remarks>
    /// Diese Methode ist als <c>internal</c> markiert. Sie ist nur im Core und für Tests sichtbar. 
    /// </remarks>
    /// <param name="version">Die zu speichernde Version.</param>
    internal async Task SaveVersionAsync(VersionEntity version)
    {
        await _connection!.RunInTransactionAsync(tran =>
        {
            SaveVersion(tran, version);
        });
    }

    /// <summary>
    /// Führt Schema-Migrationen durch, um die Datenbank auf den neuesten Stand zu bringen.
    /// </summary>
    private async Task RunMigrationsAsync()
    {
        // 1. Version vergleichen
        await _connection!.CreateTableAsync<VersionEntity>();
        var dbVersion = await GetVersionAsync() ?? new VersionEntity { Major = 0, Minor = 0, Patch = 0, UpdatedAt = DateTime.UtcNow };
        if (dbVersion.Major > 0 || dbVersion.Minor > 0)
        {
            // Prüfung auf zu NEUE Version
            if (dbVersion.Major > AppVersion.Major || (dbVersion.Major == AppVersion.Major && dbVersion.Minor > AppVersion.Minor)) // Patch-Nummer ist egal
            {
                // Die Version des Tresors ist größer als die der App! 
                throw new Exception(
                    $"Der Tresor wurde zuletzt mit der neueren Version priVault v{dbVersion.Major}.{dbVersion.Minor} bearbeitet.\n" +
                    $"Installiere diese Version oder höher, um den Tresor öffnen zu können.");
            }

            // Prüfung auf zu ALTE Version (Breaking Changes bei Major Update)
            if (dbVersion.Major < AppVersion.Major)
            {
                // Die Major-Version des Tresors ist kleiner als die der App! 
                throw new Exception(
                    $"Der Tresor wurde zuletzt mit der älteren Version priVault v{dbVersion.Major}.{dbVersion.Minor} bearbeitet.\n" +
                    $"Du kannst den Tresor importieren, indem du einen neuen Tresor anlegst und die Importfunktion aufrufst.");
            }
        }
       
        // 2. Migrationen ausführen
        await _connection!.RunInTransactionAsync(tran =>
        {
            // Tabellen-Schema auf den aktuellen Stand bringen (Spalten hinzufügen)
            CreateAllTables(tran);

            if (dbVersion.Major < AppVersion.Major || dbVersion.Minor < AppVersion.Minor || dbVersion.Patch < AppVersion.Patch)
            {
                // Komplexe Logik ausführen (Daten-Transformationen)
                ExecuteMigration(tran, dbVersion);

                // Versionsnummer im Tresor speichern
                dbVersion.Major = AppVersion.Major;
                dbVersion.Minor = AppVersion.Minor;
                dbVersion.Patch = AppVersion.Patch;
                dbVersion.UpdatedAt = DateTime.UtcNow;
                SaveVersion(tran, dbVersion);
            }
        });
    }

    /// <summary>
    /// Aktualisiert das Tabellen-Schema entsprechend den Entitäten.
    /// <para>
    /// Einschränkung:
    /// <list type="bullet">
    /// <item>Es werden nur neue Spalten und Indexe hinzugefügt.</item>
    /// <item>Es werden keine alten Spalten oder Tabellen gelöscht.</item>
    /// <item>Es werden keine Datentypen geändert.</item>
    /// <item>Es werden keine Constraints geändert (z.B. von NULL auf NOT NULL).</item>
    /// </list>
    /// </para>
    /// </summary>
    /// <param name="conn">Datenbankverbindung.</param>
    private static void CreateAllTables(SQLiteConnection conn)
    {
        // Dieser Befehl prüft: "Gibt es die Tabelle? Nein? -> CREATE TABLE..."
        // Er prüft auch: "Gibt es neue Spalten in der Klasse? Ja? -> ALTER TABLE..."
        conn.CreateTable<UserEntity>();
        conn.CreateTable<SettingsEntity>();
        conn.CreateTable<EntryEntity>();
        conn.CreateTable<PermissionEntity>();
        conn.CreateTable<AttachmentEntity>();
        conn.CreateTable<TombstoneEntity>();
    }

    /// <summary>
    /// Migriert die Datenbank auf die aktuelle Version der App.
    /// </summary>
    /// <param name="conn">Datenbankverbindung.</param>
    /// <param name="dbVersion">Version der Datenbank</param>
    [SuppressMessage("ReSharper", "MergeIntoPattern")]
    private static void ExecuteMigration(SQLiteConnection conn, VersionEntity dbVersion)
    {
        // 1.0.x -> 1.1.0
        if (dbVersion.Minor == 0) 
        {
            // Führe Änderungen für 1.1.0 durch
            // await _connection.ExecuteAsync("..."); 
            // Nur ein Beispiel
            if (!ColumnExists(conn, "entries", "foo")) { /* DROP COLUMN... */ }
            dbVersion.Minor = 1;
            dbVersion.Patch = 0;
        }
        
        // 1.1.0 -> 1.1.2
        if (dbVersion.Minor == 1 && dbVersion.Patch < 2)
        {
            // Migrationen für Patches innerhalb von Minor 1
            // ...
            dbVersion.Patch = 2;
        }
    }
    
    /// <summary>
    /// Gibt alle relevanten SQLCipher-Parameter in der Konsole aus
    /// </summary>
    private async Task DebugCipherInfo()
    {
        EnsureInitialized();
        
        async Task Print(string label, string pragma)
        {
            try
            {
                var value = await _connection!.ExecuteScalarAsync<string>($"PRAGMA {pragma};");
                System.Diagnostics.Debug.WriteLine($"{label}: {value}");
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"{label}: ERROR - {ex.Message}");
            }
        }

        Console.WriteLine("============================");
        Console.WriteLine("=== SQLCipher Debug Info ===");

        await Print("cipher_version", "cipher_version");
        await Print("cipher_provider", "cipher_provider");
        await Print("cipher_compatibility", "cipher_compatibility");
        await Print("kdf_iter", "kdf_iter");
        await Print("cipher_page_size", "cipher_page_size");
        await Print("hmac_use", "hmac_use");
        await Print("kdf_algorithm", "kdf_algorithm");
        await Print("hmac_algorithm", "hmac_algorithm");
        await Print("cipher_default_kdf_iter", "cipher_default_kdf_iter");
        await Print("cipher_default_page_size", "cipher_default_page_size");
        await Print("cipher", "cipher"); 
        await Print("cipher_default", "cipher_default"); 
        await Print("cipher_provider", "cipher_provider");

        Console.WriteLine("============================");
    }
}

