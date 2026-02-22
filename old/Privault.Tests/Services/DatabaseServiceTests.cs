using Privault.Core;
using Privault.Core.Models.Entities;
using Privault.Core.Services;

namespace Privault.Tests.Services;

/// <summary>
/// Tests für den <see cref="DatabaseService"/>.
/// </summary>
public class DatabaseServiceTests : IDisposable
{
    // ------------------------------------------------------------------------
    // --- Setup ---
    // ------------------------------------------------------------------------

    /// <summary>
    /// Temporäres Verzeichnis für die Test-DB.
    /// </summary>
    private readonly string _tempDir;
    
    /// <summary>
    /// Verbindung zur Test-DB.
    /// </summary>
    private readonly DatabaseService _db;
    
    /// <summary>
    /// Hilfsmethode für einen validen 32-Byte Key
    /// </summary>
    private byte[] ValidKey(byte seed = 1)
    {
        var key = new byte[32];
        key[0] = seed;
        return key;
    }
    
    /// <summary>
    /// Konstruktor
    /// </summary>
    public DatabaseServiceTests()
    {
        // Initialisierung der nativen Library für Test-Runner
        //SQLitePCL.Batteries_V2.Init();

        _tempDir = Path.Combine(Path.GetTempPath(), "PrivaultTests_" + Guid.NewGuid());
        Directory.CreateDirectory(_tempDir);
        _db = new DatabaseService(_tempDir);
    }

    /// <summary>
    /// Wird durch nach jedem Test automatisch aufgerufen (weil IDisposable implementiert wird).
    /// Entfernt das temporäre Testverzeichnis inklusive aller erzeugten SQLite-Datenbanken.
    /// </summary>
    public void Dispose()
    {
        // Sicherstellen, dass die Verbindung geschlossen wird, bevor gelöscht wird
        try
        {
            _db.CloseConnectionAsync().GetAwaiter().GetResult();
        }
        catch { /* Ignore */ }
        
        if (Directory.Exists(_tempDir))
        {
            // Kleiner Delay hilft gegen Race-Conditions beim File-Lock unter Windows
            Thread.Sleep(50);
            try { Directory.Delete(_tempDir, recursive: true); } catch { /* Ignore */ }
        }
    }
    
    // ------------------------------------------------------------------------
    // --- Tests ---
    // ------------------------------------------------------------------------

    // --- 1. Verbindung & System ---
    
    /// <summary>
    /// 1.1.1 Constructor: Testet die Validierung des Basispfads.
    /// </summary>
    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void Constructor_InvalidPath_ShouldThrow(string? path)
    {
        Assert.Throws<ArgumentNullException>(() => new DatabaseService(path!));
    }
    
    /// <summary>
    /// 1.2.1 InitializeAsync: Kehrt bei Mehrfachaufruf einfach zurück.
    /// </summary>
    [Fact]
    public async Task InitializeAsync_MultipleTimes_ShouldBeNoOp()
    {
        await _db.InitializeAsync("MultiVault", ValidKey());
        var exception = await Record.ExceptionAsync(() => _db.InitializeAsync("MultiVault", [1]));
        Assert.Null(exception);
    }
    
    /// <summary>
    /// 1.3.1 Backup-Roundtrip (CreateBackup, RestoreBackup, RemoveBackup, DatabaseExists)
    /// </summary>
    [Fact]
    public async Task Backup_Roundtrip_ShouldWork()
    {
        await _db.InitializeAsync("VaultZ", ValidKey());
        var backupFile = Path.Combine(_tempDir, "VaultZ.db3.bak");
        Assert.False(File.Exists(backupFile));
        
        _db.CreateBackup();
        Assert.True(File.Exists(backupFile));
        _db.RestoreBackup();
        Assert.False(File.Exists(backupFile));

        _db.CreateBackup();
        Assert.True(File.Exists(backupFile));
        _db.RemoveBackup();
        Assert.False(File.Exists(backupFile));
    }
    
    /// <summary>
    /// 1.4.1 RenameDatabase: Datenbank wird umbenannt.
    /// </summary>
    [Fact]
    public async Task RenameDatabase_ShouldWork()
    {
        await _db.InitializeAsync("VaultZ", ValidKey());
        await _db.CloseConnectionAsync();
        _db.RenameDatabase("VaultZ", "VaultZ2");
        Assert.False(_db.DatabaseExists("VaultZ"));
        Assert.True(_db.DatabaseExists("VaultZ2"));
    }
    
    /// <summary>
    /// 1.4.2 RenameDatabase: Offene Verbindung -> <c>InvalidOperationException</c>.
    /// </summary>
    [Fact]
    public async Task RenameDatabase_WhileOpen_ShouldThrow()
    {
        await _db.InitializeAsync("VaultOpen", ValidKey());
        Assert.Throws<InvalidOperationException>(() => _db.RenameDatabase("VaultOpen", "NewName"));
    }    
    
    /// <summary>
    /// 1.5.1 DeleteCurrentDatabase: SqLite-Datei wird gelöscht.
    /// </summary>
    [Fact]
    public async Task DeleteCurrentDatabase_ShouldRemoveAllData()
    {
        var key = ValidKey();
        await _db.InitializeAsync("VaultDel", key);
        await _db.SaveUserAsync(new UserEntity { Name = "U", Uuid = "u" });
        await _db.SaveEntryAsync(new EntryEntity { Uuid = "e" });
        await _db.SaveSettingsAsync(new SettingsEntity { ApiToken = "t" });
        Assert.NotEmpty(await _db.GetUsersAsync());
        Assert.NotEmpty(await _db.GetEntriesAsync());
        Assert.NotNull(await _db.GetSettingsAsync());
        await _db.DeleteCurrentDatabase();
        Assert.False(_db.DatabaseExists("VaultDel"), "Die Datenbankdatei sollte physisch gelöscht worden sein.");
        await _db.InitializeAsync("VaultDel", key);
        Assert.Empty(await _db.GetUsersAsync());
        Assert.Empty(await _db.GetEntriesAsync());
        Assert.Null(await _db.GetSettingsAsync());
    }
    
    /// <summary>
    /// 1.6.1 RekeyAsync: Speichert die neuen Key-Bytes.
    /// </summary>
    [Fact]
    public async Task RekeyAsync_ShouldStoreNewKeyBytes()
    {
        await _db.InitializeAsync("VaultR", ValidKey());
        var newKey = ValidKey(2);
        var exception = await Record.ExceptionAsync(() => _db.RekeyAsync(newKey));
        Assert.Null(exception); // Assert: Es darf keine Exception aufgetreten sein
    }
    
    /// <summary>
    /// 1.7.1 Migration: Neue Datenbank wird korrekt auf App-Version gesetzt.
    /// </summary>
    [Fact]
    public async Task Initialize_NewDatabase_ShouldSetCurrentVersion()
    {
        await _db.InitializeAsync("NewVault", ValidKey());
        var dbVersion = await _db.GetVersionAsync(); 
        Assert.NotNull(dbVersion);
        Assert.Equal(AppVersion.Major, dbVersion.Major);
        Assert.Equal(AppVersion.Minor, dbVersion.Minor);
        Assert.Equal(AppVersion.Patch, dbVersion.Patch);
    }
    
    /// <summary>
    /// 1.7.2 Migration: Höhere Major-Version in DB wirft Exception.
    /// </summary>
    [Fact]
    public async Task Initialize_FutureVersion_ShouldThrowException()
    {
        var vault = "FutureVault";
        var key = ValidKey();
        await _db.InitializeAsync(vault, key);
        
        // Manuell die Version in die Zukunft patchen
        await _db.SaveVersionAsync(new VersionEntity { Major = AppVersion.Major + 1, Minor = 0, Patch = 0, UpdatedAt = DateTime.UtcNow });
        await _db.CloseConnectionAsync();
    
        var dbNew = new DatabaseService(_tempDir);
        var ex = await Assert.ThrowsAsync<Exception>(() => dbNew.InitializeAsync(vault, key));
        Assert.Contains("Version priVault v2.0", ex.Message);
    }
    
    /// <summary>
    /// 1.7.3 Migration: Ältere Major-Version (außer 0) wirft Exception.
    /// </summary>
    [Fact]
    public async Task Initialize_OldMajorVersion_ShouldThrowException()
    {
        
        if (AppVersion.Major < 1) return; // Test funktioniert nur, wenn AppVersion.Major >= 1 ist
    
        var vault = "OldVault";
        var key = ValidKey();
        await _db.InitializeAsync(vault, key);
        
        // Manuell auf die Vorgänger-Version patchen
        await _db.SaveVersionAsync(new VersionEntity { Major = AppVersion.Major - 1, Minor = 1, Patch = 0, UpdatedAt = DateTime.UtcNow });
        await _db.CloseConnectionAsync();
    
        var dbNew = new DatabaseService(_tempDir);
        var ex = await Assert.ThrowsAsync<Exception>(() => dbNew.InitializeAsync(vault, key));
        Assert.Contains("Version priVault v0.1", ex.Message);
    }
    
    // --- 2. Benutzer ---
    
    /// <summary>
    /// 2.1.1 User-Roundtrip (SaveUserAsync, SavePermissionAsync, GetPermissionsByUserIdAsync & DeleteUserAsync, GetUserByUuidAsync):
    /// Speichern, Abfragen, Löschen eines Benutzers.
    /// </summary>
    [Fact]
    public async Task User_Roundtrip_ShouldRemovePermissions()
    {
        await _db.InitializeAsync("VaultA", ValidKey());
        var alice = new UserEntity { Name = "Alice", Uuid = "u-alice" };
        await _db.SaveUserAsync(alice);
        Assert.Equal(1, alice.Id); // der erste Benutzer muuss die ID 1 bekommen
        
        // Entry erstellen
        var entry = new EntryEntity { Uuid = "e1" };
        await _db.SaveEntryAsync(entry);

        await _db.SavePermissionAsync(new PermissionEntity
        {
            EntryId = entry.Id, // <-- EntryId
            UserId = alice.Id,
            EncryptedKey = "K",
            AccessLevel = 1
        });
        Assert.Single(await _db.GetPermissionsByUserIdAsync(alice.Id));
        await _db.DeleteUserAsync(alice.Id);
        Assert.Null(await _db.GetUserByUuidAsync("u-alice"));
        Assert.Empty(await _db.GetPermissionsByUserIdAsync(alice.Id));
    }

    /// <summary>
    /// 2.2.1 SaveUserAsync: Aktualisiert einen Benutzer.
    /// </summary>
    [Fact]
    public async Task SaveUserAsync_UpdateExisting_ShouldWork()
    {
        await _db.InitializeAsync("VaultU", ValidKey());
        var user = new UserEntity { Name = "Old", Uuid = "u1" };
        await _db.SaveUserAsync(user);
        user.Name = "New";
        await _db.SaveUserAsync(user);
        var got = await _db.GetUserByUuidAsync("u1");
        Assert.Equal("New", got!.Name);
    }

    /// <summary>
    /// 2.3.1 DeleteUserAsync: Löscht einen Benutzer mit komplexen Abhängigkeiten.
    /// </summary>
    [Fact]
    public async Task DeleteUserAsync_WithDependencies_ShouldCleanup()
    {
        await _db.InitializeAsync("VaultDep", ValidKey());
        var user = new UserEntity { Name = "U1", Uuid = "u1" };
        await _db.SaveUserAsync(user);
        await _db.SaveEntryAsync(new EntryEntity { Uuid = "e1", CreatorId = user.Id });
        await _db.SaveEntryAsync(new EntryEntity { Uuid = "e2", UpdaterId = user.Id });
        await _db.DeleteUserAsync(user.Id);
        Assert.Null(await _db.GetEntryByUuidAsync("e1")); // Gelöscht, da Besitzer
        var e2 = await _db.GetEntryByUuidAsync("e2");
        Assert.Equal(0, e2!.UpdaterId); // ID genullt
    }
    
    /// <summary>
    /// 2.4.1 HideUserAsync: Versteckt den Benutzer.
    /// </summary>
    [Fact]
    public async Task HideUserAsync_ShouldMarkUserHiddenAndRemoveKeys()
    {
        await _db.InitializeAsync("VaultH", ValidKey());
        var user = new UserEntity { Name = "X", Uuid = "ux" };
        await _db.SaveUserAsync(user);
        
        // Entry erstellen
        var entry = new EntryEntity { Uuid = "e1" };
        await _db.SaveEntryAsync(entry);

        await _db.SavePermissionAsync(new PermissionEntity { EntryId = entry.Id, UserId = user.Id, EncryptedKey = "K", AccessLevel = 1 }); // <-- EntryId
        await _db.HideUserAsync(user.Id);
        var got = await _db.GetUserAsync(user.Id);
        Assert.True(got!.IsHidden);
        var perms = await _db.GetPermissionsByUserIdAsync(user.Id);
        Assert.NotEmpty(perms);
        Assert.True(perms.All(p => p is { AccessLevel: 0, EncryptedKey: "" }));
    }
    
    // --- 3. Einträge ---
    
    /// <summary>
    /// 3.1.1 Entry-Roundtrip (SaveEntryAsync, SavePermissionAsync, RemoveEntryKeysForUserAsync, DeleteEntryAsync)
    /// </summary>
    [Fact]
    public async Task Entry_Roundtrip_ShouldReturnPermissions()
    {
        await _db.InitializeAsync("VaultB", ValidKey());
        var user = new UserEntity { Name = "Bob", Uuid = "u-bob" };
        await _db.SaveUserAsync(user);
        var userId = user.Id; 
        var entry = new EntryEntity
        {
            Uuid = "e-1",
            EncryptedData = "DATA",
            UpdatedAt = DateTime.UtcNow.AddMinutes(-10)
        };
        await _db.SaveEntryAsync(entry);
        var perm = new PermissionEntity
        {
            EntryId = entry.Id,
            UserId = 1,
            EncryptedKey = "K",
            AccessLevel = 2
        };
        await _db.SavePermissionAsync(perm);
        Assert.Single(await _db.GetPermissionsByEntryIdAsync(perm.Id));
        await _db.RemoveEntryKeysForUserAsync(1);
        var perms = await _db.GetPermissionsByUserIdAsync(userId);
        Assert.All(perms, p => Assert.Equal(string.Empty, p.EncryptedKey));

        // Korrektur: Zeitstempel explizit setzen, damit GetEntriesSinceAsync fündig wird
        var entryUpdate = new EntryEntity 
        { 
            Uuid = "e-1", 
            EncryptedData = "D2", 
            UpdatedAt = DateTime.UtcNow 
        };
        await _db.SaveEntryAsync(entryUpdate);
        
        Assert.Equal("D2", (await _db.GetEntryByUuidAsync("e-1"))!.EncryptedData);
        Assert.NotNull(await _db.GetEntryAsync(entryUpdate.Id));
        
        // Jetzt wird der Eintrag gefunden, da UpdatedAt aktuell ist
        Assert.NotEmpty(await _db.GetEntriesSinceAsync(DateTime.UtcNow.AddHours(-1)));
        
        await _db.DeleteEntryAsync(entryUpdate.Id);
        Assert.Empty(await _db.GetEntriesAsync());
    }

    // --- 4. Dateianhänge ---
    
    /// <summary>
    /// 4.1.1 Attachment‑Roundtrip: (SaveAttachmentAsync, GetAttachmentsByEntryAsync, GetAttachmentsUnsyncedAsync, DeleteAttachmentAsync, GetAttachmentByUuidAsync)
    /// Speichern und Löschen eines Dateianhangs.
    /// </summary>
    [Fact]
    public async Task GetAttachmentsByEntry_AfterSave_ShouldReturnAllAttachments()
    {
        await _db.InitializeAsync("VaultC", ValidKey());
        var entry = new EntryEntity { Uuid = "e-2" };
        await _db.SaveEntryAsync(entry);
        var a1 = new AttachmentEntity { Uuid = "a1", EntryId = entry.Id, EncryptedMeta = "M1", EncryptedContent = "C1", IsSynced = false };
        var a2 = new AttachmentEntity { Uuid = "a2", EntryId = entry.Id, EncryptedMeta = "M2", EncryptedContent = "C2", IsSynced = true };
        await _db.SaveAttachmentAsync(a1);
        await _db.SaveAttachmentAsync(a2);
        var list = await _db.GetAttachmentsByEntryAsync(entry.Id);
        Assert.Equal(2, list.Count);
        var unsynced = await _db.GetAttachmentsUnsyncedAsync();
        Assert.Single(unsynced);
        Assert.Equal("a1", unsynced[0].Uuid);
        Assert.NotNull(await _db.GetAttachmentAsync(1));
        Assert.NotNull(await _db.GetAttachmentByUuidAsync("a1"));
        await _db.DeleteAttachmentAsync(1);
        Assert.Null(await _db.GetAttachmentAsync(1));
        Assert.Null(await _db.GetAttachmentByUuidAsync("a1"));
    }

    // --- 5. Berechtigungen ---

    /// <summary>
    /// 5.1.1 Permission‑Roundtrip: (SavePermissionAsync, GetPermissionByEntryIdAndUserIdAsync, GetPermissionsAsync, DeletePermissionAsync)
    /// </summary>
    [Fact]
    public async Task Permission_Roundtrip_ShouldWork()
    {
        await _db.InitializeAsync("VaultP", ValidKey());
        var entry = new EntryEntity { Uuid = "e-2" };
        await _db.SaveEntryAsync(entry);
        var p = new PermissionEntity { EntryId = entry.Id, UserId = 1, AccessLevel = 1 };
        await _db.SavePermissionAsync(p);
        p.AccessLevel = 2;
        await _db.SavePermissionAsync(p);
        var perm = await _db.GetPermissionAsync(1);
        Assert.NotNull(perm);
        Assert.Equal(2, perm.AccessLevel);
        Assert.Equal(2, (await _db.GetPermissionByEntryIdAndUserIdAsync(p.EntryId, 1))?.AccessLevel);
        Assert.NotEmpty(await _db.GetPermissionsAsync());
        await _db.DeletePermissionAsync(1);
        Assert.Null(await _db.GetPermissionByEntryIdAndUserIdAsync(p.EntryId, 1));
    }
    
    /// <summary>
    /// 5.2.1 HasAccessWithoutKeyAsync: Erkennt korrekt, wenn ein Benutzer Zugriff ohne Schlüssel hat.
    /// </summary>
    [Fact]
    public async Task HasAccessWithoutKeyAsync_WhenKeyMissing_ShouldReturnTrue()
    {
        await _db.InitializeAsync("VaultK", ValidKey());
        var user = new UserEntity { Name = "Y", Uuid = "uy" };
        await _db.SaveUserAsync(user);
        var entry = new EntryEntity { Uuid = "e-2" };
        await _db.SaveEntryAsync(entry);
        await _db.SavePermissionAsync(new PermissionEntity { EntryId = entry.Id, UserId = user.Id, EncryptedKey = "", AccessLevel = 1 });
        Assert.True(await _db.HasAccessWithoutKeyAsync(user.Id));
    }

    // --- 6. Grabsteine ---
    
    /// <summary>
    /// 6.1.1 SaveTombstoneAsync, GetTombstonesSinceAsync: Grabsteine anlegen und abrufen
    /// </summary>
    [Fact]
    public async Task GetTombstonesSince_ShouldReturnOnlyNewer()
    {
        await _db.InitializeAsync("VaultD", ValidKey());
        await _db.SaveTombstoneAsync(new TombstoneEntity { EntryUuid = "eX", DeletedAt = DateTime.UtcNow.AddHours(-3) });
        var t = new TombstoneEntity { EntryUuid = "eY", DeletedAt = DateTime.UtcNow.AddHours(-1) };
        await _db.SaveTombstoneAsync(t);
        await _db.SaveTombstoneAsync(t); // Triggered Update-Pfad
        var since = DateTime.UtcNow.AddHours(-2);
        var filtered = await _db.GetTombstonesSinceAsync(since);
        Assert.Single(filtered);
        Assert.Equal("eY", filtered[0].EntryUuid);
    }
    
    // --- 7. Einstellungen ----
    
    /// <summary>
    /// 7.1.1 Settings-Roundtrip: Einstellungen speichern und Abfragen.
    /// </summary>
    [Fact]
    public async Task Settings_Roundtrip_ShouldUpdateInternalState()
    {
        await _db.InitializeAsync("VaultD", ValidKey());
        var settings = new SettingsEntity { ApiToken = "t", Salt = "s" };
        await _db.SaveSettingsAsync(settings);
        var loaded = await _db.GetSettingsAsync();
        Assert.NotNull(loaded);
        Assert.Equal("t", loaded.ApiToken);
        Assert.Equal("s", loaded.Salt);
    }
}
