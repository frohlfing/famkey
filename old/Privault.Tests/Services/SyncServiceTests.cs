using System.Diagnostics.CodeAnalysis;
using System.Text;
using System.Text.Json;
using Moq;
using Privault.Core;
using Privault.Core.Models.Entities;
using Privault.Core.Models.DTOs;
using Privault.Core.Models.Payloads;
using Privault.Core.Services;
using Privault.Core.Services.Contracts;

namespace Privault.Tests.Services;

/// <summary>
/// Tests für den <see cref="SyncService"/>.
/// </summary>
public class SyncServiceTests
{
    // ------------------------------------------------------------------------
    // --- Setup ---
    // ------------------------------------------------------------------------

    /// <summary>
    /// Stellt eine wiederverwendbare Sammlung von Mocks und Default-Testdaten bereit.
    /// </summary>
    /// <remarks>
    /// <b>Given:</b> Ein Test benötigt isolierte Mocks.
    /// <br/><b>When:</b> Ein SyncService erstellt wird.
    /// <br/><b>Then:</b> Alle Abhängigkeiten sind sauber isoliert und kontrollierbar.
    /// </remarks>
    private sealed class Fixture
    {
        public Mock<IConfigService> Config { get; } = new();
        public Mock<ICryptoService> Crypto { get; } = new();
        public Mock<IDatabaseService> Db { get; } = new();
        public Mock<IGuardService> Guard { get; } = new();
        public Mock<IWebService> Web { get; } = new();
        public Mock<ISessionService> Session { get; } = new();

        public SyncService CreateService() 
        {
            // HKDF Mock Setup: Einfach den Input zurückgeben oder was deterministisches
            Crypto.Setup(c => c.DeriveKeyFromKey(It.IsAny<byte[]>(), It.IsAny<byte[]>(), It.IsAny<string>()))
                .Returns([SuppressMessage("ReSharper", "UnusedParameter.Local")](byte[] input, byte[] salt, string info) => 
                {
                    // Simuliert eine Ableitung: Wir nehmen einfach 32 Bytes
                    var derived = new byte[32];
                    for(int i=0; i<32 && i<input.Length; i++) derived[i] = input[i];
                    return derived;
                });

            return new(
                Config.Object,
                Crypto.Object,
                Db.Object,
                Session.Object,
                Guard.Object,
                Web.Object
            );
        }
    }

    /// <summary>
    /// Erstellt einen vollständig eingerichteten SyncService für einen eingeloggten Benutzer.
    /// </summary>
    /// <remarks>
    /// <b>Given:</b> Ein Benutzer ist eingeloggt und besitzt gültige Session-Daten.
    /// <br/><b>When:</b> SyncAsync ausgeführt wird.
    /// <br/><b>Then:</b> Der Service verhält sich wie im realen Betrieb ohne UI.
    /// </remarks>
    private static (SyncService service, Fixture f) ArrangeBaseLoggedIn()
    {
        var f = new Fixture();
        var user = new UserEntity { Id = 1, Name = "Alice", Uuid = "local-uuid", PublicKey = "PUB_LOCAL" };
        var settings = new SettingsEntity { ApiToken = "token", Salt = "salt-local", LastSyncAt = DateTime.UtcNow.AddDays(-1) };
        var privateKey = Enumerable.Repeat((byte)0x42, 64).ToArray(); // >=32 bytes

        f.Session.SetupGet(s => s.IsLoggedIn).Returns(true);
        f.Session.SetupGet(s => s.VaultName).Returns("VaultX");
        f.Session.SetupGet(s => s.User).Returns(user);
        f.Session.SetupGet(s => s.Settings).Returns(settings);
        f.Session.SetupGet(s => s.PrivateKey).Returns(privateKey);

        // Default DB queries
        f.Db.Setup(d => d.GetUsersAsync()).ReturnsAsync([user]);
        f.Db.Setup(d => d.GetEntriesSinceAsync(It.IsAny<DateTime>())).ReturnsAsync([]);
        f.Db.Setup(d => d.GetTombstonesSinceAsync(It.IsAny<DateTime>())).ReturnsAsync([]);
        f.Db.Setup(d => d.GetAttachmentsUnsyncedAsync()).ReturnsAsync([]);

        // --- Default: Versionsprüfung besteht ---
        f.Web.Setup(w => w.GetServerVersionAsync(It.IsAny<string?>(), It.IsAny<string?>()))
            .ReturnsAsync(new VersionResponse
            {
                Major = AppVersion.Major,
                Minor = AppVersion.RequiredServerMinor,
                Patch = 0,
                RequiredClientMinor = 0
            });

        // PullFriendsAsync(UserResponse): Public Keys werden geladen
        f.Web.Setup(w => w.GetPublicKeysAsync(It.IsAny<string>()))
            .ReturnsAsync(new List<PublicKeyResponse>());

        var service = f.CreateService();
        return (service, f);
    }

    private (SyncService service,
        Mock<IWebService> webMock,
        Mock<ISessionService> sessionMock,
        Mock<IDatabaseService> dbMock) CreateService()
    {
        var configMock = new Mock<IConfigService>();
        var cryptoMock = new Mock<ICryptoService>();
        cryptoMock.Setup(c => c.DeriveKeyFromKey(It.IsAny<byte[]>(), It.IsAny<byte[]>(), It.IsAny<string>())).Returns(new byte[32]); // Dummy Key
        var databaseMock = new Mock<IDatabaseService>();
        var guardMock = new Mock<IGuardService>();
        var webMock = new Mock<IWebService>();
        var sessionMock = new Mock<ISessionService>();

        // --- Default: Versionsprüfung besteht ---
        webMock.Setup(w => w.GetServerVersionAsync(It.IsAny<string?>(), It.IsAny<string?>()))
            .ReturnsAsync(new VersionResponse
            {
                Major = AppVersion.Major,
                Minor = AppVersion.RequiredServerMinor,
                Patch = 0,
                RequiredClientMinor = 0
            });

        var service = new SyncService(
            configMock.Object,
            cryptoMock.Object,
            databaseMock.Object,
            sessionMock.Object,
            guardMock.Object,
            webMock.Object
        );

        return (service, webMock, sessionMock, databaseMock);
    }

    // ------------------------------------------------------------------------
    // --- Tests ---
    // ------------------------------------------------------------------------

    // --- SyncAsync ---
    
    /// <summary>
    /// 1.1.1 SyncAsync: Führt ohne einen eingeloggten Benutzer keine Aktionen aus.
    /// </summary>
    [Fact]
    public async Task SyncAsync_ShouldReturnEmptyStats_WhenUserIsNotLoggedIn()
    {
        // Arrange
        var (service, webMock, sessionMock, _) = CreateService();
        sessionMock.Setup(s => s.IsLoggedIn).Returns(false);

        // Act
        var result = await service.SyncAsync();

        // Assert
        Assert.NotNull(result);
        Assert.False(result.HasChanges);
        webMock.Verify(w => w.FindUserAsync(It.IsAny<string>(), It.IsAny<string>()), Times.Never);
    }

    /// <summary>
    /// 1.1.2 SyncAsync: Bei unverändertem Zustand wird der letzte Sync-Zeitpunkt aktualisiert.
    /// </summary>
    [Fact]
    public async Task SyncAsync_ExistingUser_SameSalt_NoChanges_UpdatesLastSync()
    {
        // Arrange
        var (service, f) = ArrangeBaseLoggedIn();

        var remote = new UserResponse
        {
            UserUuid = "server-uuid",
            Salt = "salt-local",
            PublicKey = "PUB_REMOTE",
            EncryptedPrivateKey = "ENC_PRIV",
            EncryptedFriends = ""
        };

        f.Web.Setup(w => w.FindUserAsync("VaultX", "Alice")).ReturnsAsync(remote);

        f.Web.Setup(w => w.PullSyncAsync(remote.UserUuid, It.IsAny<DateTime>()))
            .ReturnsAsync(new SyncPullResponse
            {
                Updates = new List<EntryDto>(),
                Deletes = new List<TombstoneDto>(),
                ServerTime = DateTime.UtcNow
            });

        // Act
        var stats = await service.SyncAsync();

        // Assert
        Assert.False(stats.HasChanges);
        f.Db.Verify(d => d.SaveSettingsAsync(It.Is<SettingsEntity>(s => s.LastSyncAt > DateTime.UtcNow.AddMinutes(-5))), Times.Once);
        // No push when nothing to send
        f.Web.Verify(w => w.PushSyncAsync(It.IsAny<string>(), It.IsAny<SyncPushRequest>()), Times.Never);
    }

    /// <summary>
    /// 1.1.3 SyncAsync: Lokale Änderungen werden an den Server gepuscht.
    /// </summary>
    [Fact]
    public async Task SyncAsync_LocalChanges_ShouldCallPushSync()
    {
        // Arrange
        var (service, f) = ArrangeBaseLoggedIn();

        var remote = new UserResponse
        {
            UserUuid = "u",
            Salt = "salt-local",
            EncryptedFriends = ""
        };

        f.Web.Setup(w => w.FindUserAsync("VaultX", "Alice")).ReturnsAsync(remote);

        // Pull liefert nichts, aber es existieren lokale Änderungen
        f.Web.Setup(w => w.PullSyncAsync("u", It.IsAny<DateTime>()))
            .ReturnsAsync(new SyncPullResponse
            {
                Updates = new List<EntryDto>(),
                Deletes = new List<TombstoneDto>(),
                ServerTime = DateTime.UtcNow
            });

        // Lokale Änderungen simulieren
        var localEntry = new EntryEntity { Id = 100, Uuid = "e1", EncryptedData = "D", UpdatedAt = DateTime.UtcNow.AddMinutes(-1) };
        f.Db.Setup(d => d.GetEntriesSinceAsync(It.IsAny<DateTime>())).ReturnsAsync([localEntry]);
        f.Db.Setup(d => d.GetTombstonesSinceAsync(It.IsAny<DateTime>())).ReturnsAsync([
            new TombstoneEntity { EntryUuid = "del", DeletedAt = DateTime.UtcNow.AddMinutes(-2) }
        ]);
        f.Db.Setup(d => d.GetAttachmentsUnsyncedAsync()).ReturnsAsync([
            new AttachmentEntity { Uuid = "a1", EntryId = 100, EncryptedMeta = "M", EncryptedContent = "C", IsSynced = false }
        ]);
        
        // Damit das Attachment auch den richtigen Entry findet (im Sync loop):
        f.Db.Setup(d => d.GetEntryAsync(100)).ReturnsAsync(localEntry);

        // Permissions (Liste enthält meine Schreibberechtigung, UserId=1)
        var myPerm = new PermissionEntity { EntryId = 100, UserId = 1, EncryptedKey = "K", AccessLevel = 2 };
        f.Db.Setup(d => d.GetPermissionsByEntryIdAsync(100)).ReturnsAsync([myPerm]);

        // Benutzer-Mapping
        f.Db.Setup(d => d.GetUsersAsync()).ReturnsAsync([new UserEntity { Id = 1, Uuid = "local-uuid", Name = "Alice" }]);

        // Attachments by Entry (für AttachmentUuids im Push)
        f.Db.Setup(d => d.GetAttachmentsByEntryAsync(100)).ReturnsAsync([]);

        // UploadAttachment ist jetzt Task (kein bool)
        f.Web.Setup(w => w.UploadAttachmentAsync("e1", "a1", It.IsAny<string>(), It.IsAny<string>()))
            .Returns(Task.CompletedTask);

        // PushSync -> capture Request
        SyncPushRequest? captured = null;
        f.Web.Setup(w => w.PushSyncAsync("u", It.IsAny<SyncPushRequest>()))
            .Callback<string, SyncPushRequest>((_, req) => captured = req)
            .Returns(Task.CompletedTask);

        // Act
        var stats = await service.SyncAsync();

        // Assert
        f.Web.Verify(w => w.PushSyncAsync("u", It.IsAny<SyncPushRequest>()), Times.Once);
        Assert.NotNull(captured);
        Assert.True(stats.PushSent > 0);
        Assert.NotEmpty(captured!.Updates);
        Assert.NotEmpty(captured.Deletes);
    }

     /// <summary>
    /// 1.1.4 SyncAsync: Ein neuer Benutzer wird korrekt registriert.
    /// </summary>
    [Fact]
    public async Task SyncAsync_WhenUserIsNew_ShouldRegisterUserAndSaveUuid()
    {
        // Arrange
        var (service, webMock, sessionMock, dbMock) = CreateService();

        const string testVault = "MeinTresor";
        const string testUserName = "Frank";
        const string expectedUuid = "server-gen-uuid-123";
        var dummyPrivateKey = new byte[32];

        var localUser = new UserEntity { Name = testUserName, Id = 1 };
        var localSettings = new SettingsEntity { ApiToken = "valid-token", Salt = "salt-local", LastSyncAt = DateTime.UtcNow.AddDays(-1) };

        sessionMock.Setup(s => s.IsLoggedIn).Returns(true);
        sessionMock.Setup(s => s.VaultName).Returns(testVault);
        sessionMock.Setup(s => s.User).Returns(localUser);
        sessionMock.Setup(s => s.Settings).Returns(localSettings);
        sessionMock.Setup(s => s.PrivateKey).Returns(dummyPrivateKey);

        // API-Mocks:
        // 1) FindUserAsync -> null (User neu)
        // 2) RegisterUserAsync -> UserResponse (mit UUID)
        // 3) FindUserAsync -> UserResponse (Recheck)
        webMock.SetupSequence(w => w.FindUserAsync(testVault, testUserName))
            .ReturnsAsync((UserResponse?)null)
            .ReturnsAsync(new UserResponse { UserUuid = expectedUuid, Salt = "some-salt", EncryptedFriends = "" });

        webMock.Setup(w => w.RegisterUserAsync(testVault, testUserName))
            .ReturnsAsync(new UserResponse { UserUuid = expectedUuid, Salt = "some-salt", EncryptedFriends = "" });

        webMock.Setup(w => w.GetPublicKeysAsync(expectedUuid))
            .ReturnsAsync(new List<PublicKeyResponse>());

        // Neu: PullFriendsAsync ruft GetUserAsync(expectedUuid) auf
        webMock.Setup(w => w.GetUserAsync(expectedUuid))
            .ReturnsAsync(new UserResponse { UserUuid = expectedUuid, EncryptedFriends = "" });

        webMock.Setup(w => w.PullSyncAsync(expectedUuid, It.IsAny<DateTime>()))
            .ReturnsAsync(new SyncPullResponse
            {
                Updates = new List<EntryDto>(),
                Deletes = new List<TombstoneDto>(),
                ServerTime = DateTime.UtcNow
            });

        // Datenbank-Mocks
        dbMock.Setup(d => d.GetUsersAsync()).ReturnsAsync([localUser]);
        dbMock.Setup(d => d.GetEntriesSinceAsync(It.IsAny<DateTime>())).ReturnsAsync([]);
        dbMock.Setup(d => d.GetTombstonesSinceAsync(It.IsAny<DateTime>())).ReturnsAsync([]);
        dbMock.Setup(d => d.GetAttachmentsUnsyncedAsync()).ReturnsAsync([]);
        dbMock.Setup(d => d.SaveUserAsync(It.IsAny<UserEntity>())).Returns(Task.CompletedTask);
        dbMock.Setup(d => d.SaveSettingsAsync(It.IsAny<SettingsEntity>())).Returns(Task.CompletedTask);

        // Act
        await service.SyncAsync();

        // Assert
        webMock.Verify(w => w.RegisterUserAsync(testVault, testUserName), Times.Once);
        Assert.Equal(expectedUuid, localUser.Uuid);
        dbMock.Verify(d => d.SaveUserAsync(It.Is<UserEntity>(u => u.Uuid == expectedUuid)), Times.Once);
    }

    /// <summary>
    /// 1.1.5 SyncAsync: Ein neuer Benutzer wird ohne API-Token nicht registriert.
    /// </summary>
    [Fact]
    public async Task SyncAsync_NewUser_NoApiToken_ShouldThrow()
    {
        // Arrange
        var (service, f) = ArrangeBaseLoggedIn();
        f.Session.SetupGet(s => s.Settings).Returns(new SettingsEntity { ApiToken = "" });
        f.Web.Setup(w => w.FindUserAsync("VaultX", "Alice")).ReturnsAsync((UserResponse?)null);

        // Act + Assert
        await Assert.ThrowsAsync<Exception>(() => service.SyncAsync());
    }

    /// <summary>
    /// 1.1.6 SyncAsync: Die Registrierung schlägt fehl, wenn der Server eine leere UUID zurückgibt.
    /// </summary>
    [Fact]
    public async Task SyncAsync_RegisterUser_ReturnsWhitespace_ShouldThrow()
    {
        // Arrange
        var (service, f) = ArrangeBaseLoggedIn();
        f.Web.Setup(w => w.FindUserAsync("VaultX", "Alice")).ReturnsAsync((UserResponse?)null);
        f.Web.Setup(w => w.RegisterUserAsync("VaultX", "Alice"))
            .ReturnsAsync(new UserResponse { UserUuid = "   ", EncryptedFriends = "" });

        // Act + Assert
        await Assert.ThrowsAnyAsync<Exception>(() => service.SyncAsync());
    }

    /// <summary>
    /// 1.1.7 SyncAsync: Nach erfolgreicher Registrierung muss der Server zumindest die Public Keys liefern können, 
    /// da PullFriendsAsync(userResponse) als nächstes GetPublicKeysAsync(userResponse.UserUuid) aufruft.
    /// </summary>
    /// <remarks>
    /// Hinweis: Seit PullFriendsAsync ein UserResponse entgegennimmt, wird GetUserAsync(...) hier nicht mehr aufgerufen.
    /// Der „Recheck“ findet (im aktuellen Flow) über GetPublicKeysAsync statt.
    /// </remarks>
    [Fact]
    public async Task SyncAsync_AfterRegister_GetPublicKeysFails_ShouldThrow()
    {
        // Arrange
        var (service, f) = ArrangeBaseLoggedIn();

        f.Web.Setup(w => w.FindUserAsync("VaultX", "Alice"))
            .ReturnsAsync((UserResponse?)null);

        f.Web.Setup(w => w.RegisterUserAsync("VaultX", "Alice"))
            .ReturnsAsync(new UserResponse { UserUuid = "new-uuid", EncryptedFriends = "" });

        // PullFriendsAsync(userResponse) ruft GetPublicKeysAsync(userResponse.UserUuid) auf -> Fehler simulieren
        f.Web.Setup(w => w.GetPublicKeysAsync("new-uuid"))
            .ThrowsAsync(new Exception("Public keys not available after register"));

        // Act + Assert
        await Assert.ThrowsAnyAsync<Exception>(() => service.SyncAsync());

        // Zusatz: Absichern, dass der erwartete Call tatsächlich passiert ist
        f.Web.Verify(w => w.GetPublicKeysAsync("new-uuid"), Times.Once);
    }

    /// <summary>
    /// 1.1.8 SyncAsync: Das Update wird korrekt entschlüsselt und Suchfelder gesetzt.
    /// </summary>
    [Fact]
    public async Task SyncAsync_PullUpdates_AccessGranted_ShouldSaveEntry_WithSearchFields()
    {
        // Arrange
        var (service, f) = ArrangeBaseLoggedIn();
        var remote = new UserResponse { UserUuid = "u", Salt = "salt-local", EncryptedFriends = "" };
        f.Web.Setup(w => w.FindUserAsync("VaultX", "Alice")).ReturnsAsync(remote);

        var payload = new EntryPayload { Category = "Bank", Title = "Konto", Url = "https://bank" };
        var payloadJson = JsonSerializer.Serialize(payload);
        var payloadBytes = Encoding.UTF8.GetBytes(payloadJson);

        // Krypto: DecryptRsa -> entryKey; Decrypt -> Payload-Bytes
        f.Crypto.Setup(c => c.DecryptRsa(It.IsAny<string>(), It.IsAny<byte[]>())).Returns([1, 2, 3, 4]);
        f.Crypto.Setup(c => c.Decrypt(It.IsAny<string>(), It.IsAny<byte[]>())).Returns(payloadBytes);

        // Stellt sicher, dass GetUsersAsync bei mehrfachen Aufrufen innerhalb von Sync niemals null zurückgibt
        f.Db.Setup(d => d.GetUsersAsync()).ReturnsAsync(() => [new UserEntity { Id = 1, Uuid = "local-uuid", Name = "Alice" }]);
        // Stellt sicher, dass die Anhangs-Liste nicht null ist
        f.Db.Setup(d => d.GetAttachmentsByEntryAsync(It.IsAny<int>())).ReturnsAsync([]);

        var upd = new EntryDto
        {
            EntryUuid = "e42",
            AccessLevel = 1,
            UpdatedAt = DateTime.UtcNow,
            EncryptedKey = "ENC_KEY",
            EncryptedData = "ENC_DATA",
            CreatorUuid = "local-uuid",
            UpdaterUuid = "local-uuid",
        };

        f.Web.Setup(w => w.PullSyncAsync("u", It.IsAny<DateTime>()))
            .ReturnsAsync(new SyncPullResponse
            {
                Updates = [upd],
                Deletes = [],
                ServerTime = DateTime.UtcNow
            });
            
        // Simuliere, dass nach dem Speichern der Eintrag mit ID geladen werden kann (für Permissions/Attachments Logik)
        f.Db.Setup(d => d.GetEntryByUuidAsync("e42")).ReturnsAsync(new EntryEntity { Id = 42, Uuid = "e42" });

        // Act
        await service.SyncAsync();

        // Assert: Eintrag gespeichert mit Suchfeldern
        f.Db.Verify(d => d.SaveEntryAsync(It.Is<EntryEntity>(e =>
            e.Uuid == "e42" && e.Category == "Bank" && e.Title == "Konto" && e.Url == "https://bank")), Times.Once);
    }

    /// <summary>
    /// 1.1.9 SyncAsync: Bei einem Fehler im PullSync wird kein PushSync ausgeführt.
    /// </summary>
    [Fact]
    public async Task SyncAsync_PullFails_ShouldNotPush()
    {
        // Arrange
        var (service, f) = ArrangeBaseLoggedIn();
        var remote = new UserResponse { UserUuid = "u", Salt = "salt-local", EncryptedFriends = "" };
        f.Web.Setup(w => w.FindUserAsync("VaultX", "Alice")).ReturnsAsync(remote);
        f.Web.Setup(w => w.PullSyncAsync(It.IsAny<string>(), It.IsAny<DateTime>()))
            .ThrowsAsync(new InvalidOperationException("Network Error"));

        // Act & Assert
        await Assert.ThrowsAnyAsync<Exception>(() => service.SyncAsync());
        f.Web.Verify(w => w.PushSyncAsync(It.IsAny<string>(), It.IsAny<SyncPushRequest>()), Times.Never);
    }

    /// <summary>
    /// 1.1.10 SyncAsync: Bei einem Fehler im PushSync wird der LastSyncAt-Wert nicht aktualisiert.
    /// </summary>
    [Fact]
    public async Task SyncAsync_PushFails_ShouldNotUpdateLastSync()
    {
        // Arrange
        var (service, f) = ArrangeBaseLoggedIn();
        var remote = new UserResponse { UserUuid = "u", Salt = "salt-local", EncryptedFriends = "" };
        f.Web.Setup(w => w.FindUserAsync("VaultX", "Alice")).ReturnsAsync(remote);

        f.Web.Setup(w => w.PullSyncAsync(It.IsAny<string>(), It.IsAny<DateTime>()))
            .ReturnsAsync(new SyncPullResponse { Updates = [], Deletes = [], ServerTime = DateTime.UtcNow });

        // Lokale Änderung erzwingen, damit Push gerufen wird
        f.Db.Setup(d => d.GetEntriesSinceAsync(It.IsAny<DateTime>())).ReturnsAsync([new EntryEntity { Uuid = "e1" }]);
        f.Web.Setup(w => w.PushSyncAsync(It.IsAny<string>(), It.IsAny<SyncPushRequest>()))
            .ThrowsAsync(new InvalidOperationException("Push Failed"));

        // Act & Assert
        await Assert.ThrowsAnyAsync<Exception>(() => service.SyncAsync());
        f.Db.Verify(d => d.SaveSettingsAsync(It.Is<SettingsEntity>(s => s.LastSyncAt > DateTime.UtcNow.AddMinutes(-1))), Times.Never);
    }

    /// <summary>
    /// 1.1.11 SyncAsync: Gelöschte Einträge bekommen ein Grabstein.
    /// </summary>
    [Fact]
    public async Task SyncAsync_PullDeletes_ShouldStoreTombstones_AndDeleteEntries()
    {
        // Arrange
        var (service, f) = ArrangeBaseLoggedIn();
        var remote = new UserResponse { UserUuid = "u", Salt = "salt-local", EncryptedFriends = "" };
        f.Web.Setup(w => w.FindUserAsync("VaultX", "Alice")).ReturnsAsync(remote);

        var del1 = new TombstoneDto { EntryUuid = "e1", DeletedAt = DateTime.UtcNow.AddHours(-1) };
        var del2 = new TombstoneDto { EntryUuid = "e2", DeletedAt = DateTime.UtcNow.AddHours(-2) };

        f.Web.Setup(w => w.PullSyncAsync("u", It.IsAny<DateTime>()))
            .ReturnsAsync(new SyncPullResponse
            {
                Updates = [],
                Deletes = [del1, del2],
                ServerTime = DateTime.UtcNow
            });

        // Mocks für die Auflösung UUID -> ID
        var entry1 = new EntryEntity { Id = 101, Uuid = "e1" };
        var entry2 = new EntryEntity { Id = 102, Uuid = "e2" };
            
        f.Db.Setup(d => d.GetEntryByUuidAsync("e1")).ReturnsAsync(entry1);
        f.Db.Setup(d => d.GetEntryByUuidAsync("e2")).ReturnsAsync(entry2);

        // Act
        var stats = await service.SyncAsync();

        // Assert
        f.Db.Verify(d => d.SaveTombstoneAsync(It.Is<TombstoneEntity>(t => t.EntryUuid == del1.EntryUuid)), Times.Once);
        f.Db.Verify(d => d.SaveTombstoneAsync(It.Is<TombstoneEntity>(t => t.EntryUuid == del2.EntryUuid)), Times.Once);
        f.Db.Verify(d => d.DeleteEntryAsync(101), Times.Once);
        f.Db.Verify(d => d.DeleteEntryAsync(102), Times.Once);
        Assert.Equal(2, stats.PullDeleted);
    }

    /// <summary>
    /// 1.1.12 SyncAsync: Einträge mit AccessLevel 0 werden lokal gelöscht.
    /// </summary>
    [Fact]
    public async Task SyncAsync_PullUpdates_AccessLevelZero_ShouldDeleteLocalEntry()
    {
        // Arrange
        var (service, f) = ArrangeBaseLoggedIn();
        var remote = new UserResponse { UserUuid = "u", Salt = "salt-local", EncryptedFriends = "" };
        f.Web.Setup(w => w.FindUserAsync("VaultX", "Alice")).ReturnsAsync(remote);

        var upd = new EntryDto { EntryUuid = "x", AccessLevel = 0, UpdatedAt = DateTime.UtcNow };

        f.Web.Setup(w => w.PullSyncAsync("u", It.IsAny<DateTime>()))
            .ReturnsAsync(new SyncPullResponse
            {
                Updates = [upd],
                Deletes = [],
                ServerTime = DateTime.UtcNow
            });

        // MOCK Setup für GetEntryByUuidAsync hinzufügen!
        // Wir simulieren, dass der Eintrag "x" die lokale ID 999 hat.
        f.Db.Setup(d => d.GetEntryByUuidAsync("x"))
            .ReturnsAsync(new EntryEntity { Id = 999, Uuid = "x" });

        // Act
        await service.SyncAsync();

        // Assert
        f.Db.Verify(d => d.DeleteEntryAsync(999), Times.Once);
    }

    /// <summary>
    /// 1.1.13 SyncAsync: Bei einem Salt-Mismatch wird der PrivateKey neu verschlüsselt.
    /// </summary>
    [Fact]
    public async Task SyncAsync_SaltMismatch_ShouldTriggerReKey()
    {
        // Arrange
        var (service, f) = ArrangeBaseLoggedIn();
        var remote = new UserResponse
        {
            UserUuid = "u",
            Salt = "NEW_SERVER_SALT",
            PublicKey = "PUB_REMOTE",
            EncryptedPrivateKey = "ENC_PRIV",
            EncryptedFriends = ""
        };

        f.Web.Setup(w => w.FindUserAsync("VaultX", "Alice")).ReturnsAsync(remote);

        // Neu: PullFriendsAsync ruft GetUserAsync("u") auf
        f.Web.Setup(w => w.GetUserAsync("u"))
            .ReturnsAsync(new UserResponse { UserUuid = "u", EncryptedFriends = "" });

        f.Web.Setup(w => w.PullSyncAsync(It.IsAny<string>(), It.IsAny<DateTime>()))
            .ReturnsAsync(new SyncPullResponse { Updates = [], Deletes = [], ServerTime = DateTime.UtcNow });

        // Krypto-Operationen für Re-Key bereitstellen (entsprechend AdoptRemoteIdentity: Decrypt mit remoteMasterKey)
        f.Crypto.Setup(c => c.Decrypt(It.IsAny<string>(), It.IsAny<byte[]>()))
            .Returns(Enumerable.Repeat((byte)0x33, 64).ToArray());

        // Sicherstellen, dass die Datenbank das Speichern erlaubt
        f.Db.Setup(d => d.SaveSettingsAsync(It.IsAny<SettingsEntity>()))
            .Returns(Task.CompletedTask);
        f.Db.Setup(d => d.GetPermissionsAsync()).ReturnsAsync(new List<PermissionEntity>());

        // Config.Vaults-Property initialisieren (wird in AdoptRemoteIdentityAsync benutzt)
        f.Config.SetupProperty(c => c.Vaults, new Dictionary<string, string>());

        // Guard führt die kritische Operation wirklich aus
        f.Guard.Setup(g => g.ExecuteCriticalOperationAsync(
                It.IsAny<string>(), It.IsAny<string>(), It.IsAny<Func<byte[], Task>>(), It.IsAny<bool>(), It.IsAny<string>(), It.IsAny<string>()))
            .Returns<string, string, Func<byte[], Task>, bool, string?, string?>(async (_, _, op, _, _, _) =>
            {
                await op([1, 2, 3, 4]);
                return true;
            });

        // Act
        await service.SyncAsync();

        // Assert
        // Wir prüfen auf AtLeastOnce, da der Service evtl. auch LastSyncAt separat speichert
        f.Db.Verify(d => d.SaveSettingsAsync(It.Is<SettingsEntity>(s => s.Salt == "NEW_SERVER_SALT")), Times.AtLeastOnce);
    }
    
        /// <summary>
        /// 1.1.14 SyncAsync / PullFriendsAsync: Neuer Freund vom Server wird lokal angelegt.
        /// </summary>
        /// <remarks>
        /// <b>Given:</b> Der Server liefert im Feld <c>EncryptedFriends</c> eine Freundesliste mit einem Friend,
        /// der lokal noch nicht existiert.
        /// <br/><b>When:</b> <see cref="SyncService.SyncAsync"/> ausgeführt wird (und damit <c>PullFriendsAsync(userResponse)</c>).
        /// <br/><b>Then:</b> Der Friend wird lokal als <see cref="UserEntity"/> gespeichert (<see cref="IDatabaseService.SaveUserAsync"/>),
        /// wobei der PublicKey aus <see cref="IWebService.GetPublicKeysAsync"/> übernommen wird.
        /// </remarks>
        [Fact]
        public async Task SyncAsync_PullFriends_NewFriend_ShouldInsertLocalUser()
        {
            // Arrange
            var (service, f) = ArrangeBaseLoggedIn();

            var remoteUser = new UserResponse
            {
                UserUuid = "u",
                Salt = "salt-local",
                EncryptedFriends = "blob"
            };

            f.Web.Setup(w => w.FindUserAsync("VaultX", "Alice")).ReturnsAsync(remoteUser);

            var now = DateTime.UtcNow;
            var friends = new List<FriendPayload>
            {
                new() { Uuid = "friend-uuid", Name = "Bob", IsVerified = true, IsHidden = false, UpdatedAt = now }
            };

            f.Crypto.Setup(c => c.Decrypt("blob", It.IsAny<byte[]>()))
                .Returns(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(friends)));

            f.Web.Setup(w => w.GetPublicKeysAsync("u"))
                .ReturnsAsync([new PublicKeyResponse { UserUuid = "friend-uuid", PublicKey = "PUB_BOB" }]);

            f.Db.Setup(d => d.GetUsersAsync())
                .ReturnsAsync([new UserEntity { Id = 1, Name = "Alice", Uuid = "local-uuid", PublicKey = "PUB_LOCAL" }]);

            f.Db.Setup(d => d.SaveUserAsync(It.IsAny<UserEntity>())).Returns(Task.CompletedTask);

            f.Web.Setup(w => w.PullSyncAsync("u", It.IsAny<DateTime>()))
                .ReturnsAsync(new SyncPullResponse { Updates = [], Deletes = [], ServerTime = DateTime.UtcNow });

            f.Db.Setup(d => d.SaveSettingsAsync(It.IsAny<SettingsEntity>())).Returns(Task.CompletedTask);

            // Act
            await service.SyncAsync();

            // Assert: neuer Friend wurde angelegt
            f.Db.Verify(d => d.SaveUserAsync(It.Is<UserEntity>(u =>
                u.Uuid == "friend-uuid" &&
                u.Name == "Bob" &&
                u.PublicKey == "PUB_BOB")), Times.Once);
        }

        /// <summary>
        /// 1.1.15 SyncAsync / PullFriendsAsync: Lokaler Freund wird gelöscht, wenn er serverseitig nicht mehr existiert.
        /// </summary>
        /// <remarks>
        /// <b>Given:</b> Lokal existiert ein Friend (UserId &gt; 1), aber der Server liefert keine PublicKeys mehr für dessen UUID
        /// (Friend ist gelöscht/aus dem Tresor entfernt).
        /// <br/><b>When:</b> <see cref="SyncService.SyncAsync"/> ausgeführt wird (und damit <c>PullFriendsAsync(userResponse)</c>).
        /// <br/><b>Then:</b> Der lokale Friend wird entfernt (<see cref="IDatabaseService.DeleteUserAsync"/>).
        /// </remarks>
        [Fact]
        public async Task SyncAsync_PullFriends_RemovesLocalFriendMissingOnServer_ShouldDeleteUser()
        {
            // Arrange
            var (service, f) = ArrangeBaseLoggedIn();

            var remoteUser = new UserResponse
            {
                UserUuid = "u",
                Salt = "salt-local",
                EncryptedFriends = "blob"
            };

            f.Web.Setup(w => w.FindUserAsync("VaultX", "Alice")).ReturnsAsync(remoteUser);

            // Server liefert leere Freundesliste, aber PublicKeys enthält auch keinen lokalen Friend => local friend wird gelöscht
            f.Crypto.Setup(c => c.Decrypt("blob", It.IsAny<byte[]>()))
                .Returns(Encoding.UTF8.GetBytes("[]"));

            f.Web.Setup(w => w.GetPublicKeysAsync("u"))
                .ReturnsAsync(new List<PublicKeyResponse>
                {
                    // absichtlich nur Owner / niemand (kein "friend-uuid")
                });

            var localFriend = new UserEntity { Id = 2, Name = "Bob", Uuid = "friend-uuid", PublicKey = "PUB_OLD" };

            f.Db.Setup(d => d.GetUsersAsync())
                .ReturnsAsync([
                    new UserEntity { Id = 1, Name = "Alice", Uuid = "local-uuid", PublicKey = "PUB_LOCAL" },
                    localFriend
                ]);

            f.Db.Setup(d => d.DeleteUserAsync(It.IsAny<int>())).Returns(Task.CompletedTask);

            f.Web.Setup(w => w.PullSyncAsync("u", It.IsAny<DateTime>()))
                .ReturnsAsync(new SyncPullResponse { Updates = [], Deletes = [], ServerTime = DateTime.UtcNow });

            f.Db.Setup(d => d.SaveSettingsAsync(It.IsAny<SettingsEntity>())).Returns(Task.CompletedTask);

            // Act
            await service.SyncAsync();

            // Assert: lokaler Friend wurde entfernt
            f.Db.Verify(d => d.DeleteUserAsync(It.Is<int>(userId => userId == 2)), Times.Once);
        }

        /// <summary>
        /// 1.1.16 SyncAsync / PullFriendsAsync: Sicherheitsstopp bei geänderter Friend-Identität, wenn Entry-Keys fehlen.
        /// </summary>
        /// <remarks>
        /// <b>Given:</b> Ein Friend existiert lokal und der Server liefert einen anderen PublicKey (Fingerprint/Identität geändert).
        /// Zusätzlich gibt es mindestens einen Eintrag, bei dem der Friend Zugriff hat, aber der Entry-Key fehlt
        /// (<see cref="IDatabaseService.HasAccessWithoutKeyAsync"/> == true).
        /// <br/><b>When:</b> <see cref="SyncService.SyncAsync"/> ausgeführt wird (und damit <c>PullFriendsAsync(userResponse)</c>).
        /// <br/><b>Then:</b>
        /// <list type="bullet">
        /// <item>Alle Friend-Entry-Keys werden lokal geleert (<see cref="IDatabaseService.RemoveEntryKeysForUserAsync"/>).</item>
        /// <item>Der neue PublicKey wird übernommen und der Friend wird als „nicht verifiziert“ markiert.</item>
        /// <item>Der Sync bricht mit einer Exception ab (Sicherheitsstopp), damit der Benutzer den Fingerprint prüfen kann.</item>
        /// </list>
        /// </remarks>
        [Fact]
        public async Task SyncAsync_PullFriends_KeyChanged_AndFriendHasAccessWithoutKey_ShouldThrowSecurityStop()
        {
            // Arrange
            var (service, f) = ArrangeBaseLoggedIn();

            var remoteUser = new UserResponse
            {
                UserUuid = "u",
                Salt = "salt-local",
                EncryptedFriends = "blob"
            };

            f.Web.Setup(w => w.FindUserAsync("VaultX", "Alice")).ReturnsAsync(remoteUser);

            var now = DateTime.UtcNow;
            var friends = new List<FriendPayload>
            {
                new() { Uuid = "friend-uuid", Name = "Bob", IsVerified = true, IsHidden = false, UpdatedAt = now }
            };

            f.Crypto.Setup(c => c.Decrypt("blob", It.IsAny<byte[]>()))
                .Returns(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(friends)));

            // Server-PublicKey unterscheidet sich vom lokalen => KeyChanged-Pfad
            f.Web.Setup(w => w.GetPublicKeysAsync("u"))
                .ReturnsAsync([new PublicKeyResponse { UserUuid = "friend-uuid", PublicKey = "PUB_NEW" }]);

            var localFriend = new UserEntity { Id = 2, Name = "Bob", Uuid = "friend-uuid", PublicKey = "PUB_OLD", IsVerified = true, UpdatedAt = now.AddDays(-1) };

            f.Db.Setup(d => d.GetUsersAsync())
                .ReturnsAsync([
                    new UserEntity { Id = 1, Name = "Alice", Uuid = "local-uuid", PublicKey = "PUB_LOCAL" },
                    localFriend
                ]);

            f.Db.Setup(d => d.RemoveEntryKeysForUserAsync(2)).Returns(Task.CompletedTask);
            f.Db.Setup(d => d.SaveUserAsync(It.IsAny<UserEntity>())).Returns(Task.CompletedTask);

            // Damit needsRekeying=true wird:
            f.Db.Setup(d => d.HasAccessWithoutKeyAsync(2)).ReturnsAsync(true);

            // Act + Assert: Sicherheitsstopp muss greifen (Exception kommt aus PullFriendsAsync)
            await Assert.ThrowsAnyAsync<Exception>(() => service.SyncAsync());

            // Nebenwirkungen verifizieren
            f.Db.Verify(d => d.RemoveEntryKeysForUserAsync(2), Times.Once);
            f.Db.Verify(d => d.HasAccessWithoutKeyAsync(2), Times.Once);
            f.Db.Verify(d => d.SaveUserAsync(It.Is<UserEntity>(u =>
                u.Id == 2 &&
                u.PublicKey == "PUB_NEW" &&
                u.IsVerified == false)), Times.Once);
        }
}