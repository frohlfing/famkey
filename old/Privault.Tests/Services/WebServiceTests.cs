using System.Diagnostics.CodeAnalysis;
using Moq;
using Privault.Core.Models.Entities;
using Privault.Core.Models.DTOs;
using Privault.Core.Services;
using Privault.Core.Services.Contracts;
using System.Security.Cryptography;
using System.Text.RegularExpressions;

namespace Privault.Tests.Services;

/// <summary>
/// Test(s) für den <see cref="WebService"/> gegen einen lokal laufenden Server.
/// <para>
/// Der Test nutzt einen echten <see cref="HttpClient"/> (über eine gemockte <see cref="IHttpClientFactory"/>),
/// um Requests an den lokalen Webservice zu senden.
/// Zusätzlich wird der Header <c>X-Test</c> gesetzt, damit der Server Testdaten von Produktivdaten unterscheiden kann.
/// Mit Header <c>X-Coverage</c> wird der Request für einen serverseitigen Code-Coverage-Report protokolliert.
/// </para>
/// <para>
/// Da xUnit keinen asynchronen Konstruktor unterstützt, wird für Setup/Teardown der Testklasse
/// <see cref="IAsyncLifetime"/> verwendet.
/// </para>
/// </summary>
public class WebServiceTests : IAsyncLifetime
{
    // ------------------------------------------------------------------------
    // --- Setup ---
    // ------------------------------------------------------------------------

    /// <summary>
    /// Shared Handler, damit mehrere HttpClient-Instanzen Sockets wiederverwenden können.
    /// </summary>
    private readonly SocketsHttpHandler _handler;

    /// <summary>
    /// Der zu testende <see cref="IWebService"/> (konkret <see cref="WebService"/>).
    /// </summary>
    private readonly IWebService _service;

    /// <summary>
    /// Basis-URL des Sync-Servers (<c>https://privault.test/api</c>).
    /// </summary>
    private readonly string _host;

    /// <summary>
    /// API-Token zur Authentifizierung gegenüber dem Sync-Server.
    /// </summary>
    private readonly string _apiToken;

    /// <summary>
    /// Name des Test-Tresors.
    /// </summary>
    private readonly string _vaultName;
    
    /// <summary>
    /// Name des Test-Benutzers (wird pro Testinstanz eindeutig gewählt).
    /// </summary>
    private readonly string _userName;
    
    /// <summary>
    /// Erwartetes Salt, das beim Register an den Server gesendet wird.
    /// </summary>
    private readonly string _expectedSaltBase64;

    /// <summary>
    /// Erwarteter (verschlüsselter) Private Key, der beim Register an den Server gesendet wird.
    /// </summary>
    private readonly string _expectedEncryptedPrivateKey;

    /// <summary>
    /// Erwarteter Public Key, der beim Register an den Server gesendet wird.
    /// </summary>
    private readonly string _expectedPublicKey;
    
    /// <summary>
    /// Aktueller PrivateKey (PKCS#8) der Session; wird im Test je nach Identität umgeschaltet.
    /// </summary>
    private byte[] _sessionPrivateKey;
    
    /// <summary>
    /// Aktueller User der Session.
    /// </summary>
    private readonly UserEntity _sessionUser;
    
    // /// <summary>
    // /// Steuert den Login-Status der Session (für Tests wie 5.1.2 / 5.2.2).
    // /// </summary>
    // private bool _isLoggedIn = true;
    
    /// <summary>
    /// Konstruktor: Initialisiert die Testklasse inkl. Mocks und des zu testenden <see cref="WebService"/>.
    /// <para>
    /// Hinweis: In xUnit wird pro Test standardmäßig eine neue Instanz der Testklasse erstellt.
    /// </para>
    /// </summary>
    public WebServiceTests()
    {
        _host = "https://privault.test/api";
        _apiToken = ReadApiTokenFromSecretsPhp();
        _vaultName = "~test-" + Guid.NewGuid().ToString("N");
        _userName = "~user-" + Guid.NewGuid().ToString("N");
        _expectedSaltBase64 = Convert.ToBase64String(RandomNumberGenerator.GetBytes(16));
        _expectedEncryptedPrivateKey = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32));

        // ECHTES RSA Keypair für ChangePassword (Server prüft authenticateUser()!)
        using var rsa = RSA.Create(2048);
        _expectedPublicKey = Convert.ToBase64String(rsa.ExportSubjectPublicKeyInfo());
        _sessionPrivateKey = rsa.ExportPkcs8PrivateKey();

        _handler = new SocketsHttpHandler();

        var httpClientFactoryMock = new Mock<IHttpClientFactory>();
        httpClientFactoryMock
            .Setup(factory => factory.CreateClient(It.IsAny<string>()))
            .Returns(() =>
            {
                // Wichtig: pro Aufruf ein neuer HttpClient, aber Handler teilen!
                var c = new HttpClient(_handler, disposeHandler: false);
                c.DefaultRequestHeaders.Add("X-Test", "1");
                c.DefaultRequestHeaders.Add("X-Coverage", "1");
                return c;
            });

        // Benötigte Session-Werte: User, Settings, PrivateKey, IsLoggedIn
        var sessionMock = new Mock<ISessionService>();
        _sessionUser = new UserEntity { Uuid = "", PublicKey = _expectedPublicKey };
        var settings = new SettingsEntity
        {
            Host = _host, 
            ApiToken = _apiToken, 
            Salt = _expectedSaltBase64, 
            EncryptedPrivateKey = _expectedEncryptedPrivateKey
        };

        sessionMock.SetupGet(s => s.User).Returns(() => _sessionUser);
        sessionMock.SetupGet(s => s.Settings).Returns(settings);
        sessionMock.SetupGet(s => s.PrivateKey).Returns(() => _sessionPrivateKey);
        //sessionMock.SetupGet(s => s.IsLoggedIn).Returns(() => _isLoggedIn);

        // Benötigte Crypto-Methoden: ComputeHash(...), SignData(payloadBytes, privKey)
        var cryptoMock = new Mock<ICryptoService>();
        
        // Deterministisch einfachen "Hash" liefern
        cryptoMock
            .Setup(c => c.ComputeHash(It.IsAny<string>()))
            .Returns((string input) => $"hash({input})");

        // SignData liefert echte RSA-Signatur (Base64)
        cryptoMock
            .Setup(c => c.SignData(It.IsAny<byte[]>(), It.IsAny<byte[]>()))
            .Returns((byte[] data, byte[] privKey) =>
            {
                using var rsaLocal = RSA.Create();
                rsaLocal.ImportPkcs8PrivateKey(privKey, out _);
                var sig = rsaLocal.SignData(data, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
                return Convert.ToBase64String(sig);
            });
        
        // HKDF Setup für Mock
        cryptoMock
            .Setup(c => c.DeriveKeyFromKey(It.IsAny<byte[]>(), It.IsAny<byte[]>(), It.IsAny<string>()))
            .Returns([SuppressMessage("ReSharper", "UnusedParameter.Local")](byte[] input, byte[] salt, string info) => 
            {
                // Einfache deterministische Ableitung für den Mock
                using var sha = SHA256.Create();
                return sha.ComputeHash(input); 
            });
        
        _service = new WebService(cryptoMock.Object, sessionMock.Object, httpClientFactoryMock.Object);
    }

    /// <summary>
    /// Wird von xUnit vor jedem Test aufgerufen (Lifecycle-Hook).
    /// <para>
    /// Hier kann optional ein asynchrones Setup stattfinden.
    /// </para>
    /// </summary>
    public Task InitializeAsync()
    {
        return Task.CompletedTask;
    }

    /// <summary>
    /// Wird von xUnit nach jedem Test aufgerufen (Lifecycle-Hook).
    /// <para>
    /// Führt serverseitiges Cleanup durch und gibt anschließend Ressourcen frei.
    /// </para>
    /// </summary>
    public async Task DisposeAsync()
    {
        try
        {
            await _service.CleanTestAsync(_vaultName);
        }
        finally
        {
            _handler.Dispose();
        }
    }
    
    /// <summary>
    /// Liest den API-Token aus der Datei <c>Host/config.php</c>.
    /// Erwartet eine Zeile der Form: <c>const API_TOKEN = '...';</c> (oder mit doppelten Anführungszeichen).
    /// <para>
    /// Hinweis: Diese Funktion ist absichtlich „simpel“ und für lokale Tests gedacht (kein PHP-Parser).
    /// </para>
    /// </summary>
    /// <exception cref="FileNotFoundException">Wenn <c>Host/config.php</c> nicht gefunden wird.</exception>
    /// <exception cref="InvalidOperationException">Wenn die Konstante <c>API_TOKEN</c> nicht gefunden/parsbar ist.</exception>
    private static string ReadApiTokenFromSecretsPhp()
    {
        var appBaseDir = AppContext.BaseDirectory; // C:\Users\frank\Source\Rider\Privault\Privault.Tests\bin\Debug\net8.0\
        var secretsPath = Path.GetFullPath(Path.Combine(appBaseDir, "..", "..", "..", "..", "Host", "config.php"));
        if (!File.Exists(secretsPath))
            throw new FileNotFoundException($"Konnte config.php nicht finden: '{secretsPath}'");
        var lines = File.ReadAllLines(secretsPath);
        // const API_TOKEN = '...';
        // const API_TOKEN="...";
        var rx = new Regex(@"^\s*const\s+API_TOKEN\s*=\s*(?<q>['""])(?<token>.*?)(\k<q>)\s*;\s*$", RegexOptions.Compiled);
        foreach (var line in lines)
        {
            var m = rx.Match(line);
            if (!m.Success) continue;
            var token = m.Groups["token"].Value.Trim();
            if (string.IsNullOrWhiteSpace(token))
                throw new InvalidOperationException($"API_TOKEN in config.php ist leer.");
            return token;
        }
        throw new InvalidOperationException($"Konnte API_TOKEN in config.php nicht finden.");
    }
    
    /// <summary>
    /// Setzt die aktuelle Identität in der Session (für RSA-authentifizierte Endpunkte).
    /// </summary>
    private void SetSessionIdentity(string userUuid, string publicKeyBase64, byte[] privateKeyPkcs8)
    {
        _sessionUser.Uuid = userUuid;
        _sessionUser.PublicKey = publicKeyBase64;
        _sessionPrivateKey = privateKeyPkcs8;
    }
    
    // ------------------------------------------------------------------------
    // --- Test ---
    // ------------------------------------------------------------------------

    // --- 1. Resource Version ---    

    /// <summary>
    /// 1.1.1 GetServerVersionAsync: Gibt die Serverversion korrekt formatiert zurück.
    /// </summary>
    [Fact]
    public async Task GetServerVersionAsync_ReturnsFormattedVersion()
    {
        var versionResponse = await _service.GetServerVersionAsync(_host, _apiToken);
        var version = $"{versionResponse.Service} v{versionResponse.Major}.{versionResponse.Minor}.{versionResponse.Patch}";
        Assert.False(string.IsNullOrWhiteSpace(version));
        Assert.Contains("priVault", version, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("v", version, StringComparison.OrdinalIgnoreCase);
    }
    
    /// <summary>
    /// 1.1.2 GetServerVersionAsync: Wirft Exception bei Serverfehler.
    /// </summary>
    [Fact]
    public async Task GetServerVersionAsync_ThrowsOnServerError()
    {
        // Falsches Token -> Server liefert 401 -> WebService wirft Exception.
        var ex = await Assert.ThrowsAnyAsync<Exception>(() => _service.GetServerVersionAsync(_host, "invalid-token"));
        Assert.Contains("Serveranfrage fehlgeschlagen", ex.Message, StringComparison.OrdinalIgnoreCase);
    }
    
    // --- 2. Resource User ----
    
    /// <summary>
    /// 2.1.1 Benutzer-Lifecycle: Benutzer existiert nicht, wird registriert und ist danach auffindbar.
    /// </summary>
    [Fact]
    public async Task CheckUserExistsAsync_RegisterUser_ThenUserExists()
    {
        // 0) Lokale UUID vorbereiten (Simuliert die App-Logik)
        var localUuid = Guid.NewGuid().ToString();
        _sessionUser.Uuid = localUuid;
        
        // 1) Benutzer existiert initial nicht
        var before = await _service.FindUserAsync(_vaultName, _userName);
        Assert.Null(before);

        // 2) Benutzer registrieren
        await _service.RegisterUserAsync(_vaultName, _userName);

        // 3) Benutzer danach existent
        var after = await _service.FindUserAsync(_vaultName, _userName);
        Assert.NotNull(after);
        Assert.Equal(localUuid, after.UserUuid);
        Assert.Equal(_expectedSaltBase64, after.Salt);
        Assert.Equal(_expectedPublicKey, after.PublicKey);
        Assert.Equal(_expectedEncryptedPrivateKey, after.EncryptedPrivateKey);
        Assert.Null(after.EncryptedFriends);
    }

    /// <summary>
    /// 2.2.1 GetUserAsync: Liefert die Benutzerdaten, wenn der Benutzer existiert, sonst Exception.
    /// </summary>
    [Fact]
    public async Task GetUserAsync_ShouldWork()
    {   
        // 0) Lokale UUID simulieren
        var localUuid = Guid.NewGuid().ToString();
        _sessionUser.Uuid = localUuid;
        
        // 1) Benutzer registrieren
        var registeredUser = await _service.RegisterUserAsync(_vaultName, _userName);

        // 2) Benutzer holen
        var user = await _service.GetUserAsync(registeredUser.UserUuid);
        Assert.NotNull(user);
        Assert.Equal(localUuid, user.UserUuid); // Die UUID muss mit unserer lokalen übereinstimmen
        Assert.Equal(_expectedSaltBase64, user.Salt);
        Assert.Equal(_expectedPublicKey, user.PublicKey);
        Assert.Equal(_expectedEncryptedPrivateKey, user.EncryptedPrivateKey);
        Assert.Null(user.EncryptedFriends);
        
        // 2) Falsche UUID übergeben
        await Assert.ThrowsAnyAsync<Exception>(() => _service.GetUserAsync("UUID-that-does-not-exist"));
    }

    /// <summary>
    /// 2.3.1 ChangePasswordAsync: Erfolgreich, wenn der RSA-Schlüssel gültig ist, sonst Exception.
    /// </summary>
    [Fact]
    public async Task ChangePasswordAsync_ShouldWork()
    {
        // Lokale UUID simulieren
        var localUuid = Guid.NewGuid().ToString();
        _sessionUser.Uuid = localUuid;
        
        // Arrange: erst registrieren, damit der Server den PublicKey kennt
        var registeredUser = await _service.RegisterUserAsync(_vaultName, _userName);
        Assert.Equal(localUuid, registeredUser.UserUuid);

        // Act: absichtlich ungültig (salt und encrypted_private_key fehlen => 422)
        await Assert.ThrowsAnyAsync<Exception>(() => _service.ChangePasswordAsync(registeredUser.UserUuid, "", ""));
    
        // Assert: keine Exception == Erfolg
        await _service.ChangePasswordAsync(registeredUser.UserUuid, "new-salt", "new-encrypted-private-key");
        Assert.True(true);
    }
    
    /// <summary>
    /// 2.4.1 GetPublicKeysAsync: Liefert PublicKeys.
    /// </summary>
    [Fact]
    public async Task GetFriendsAsync_After_Post_ReturnsEncryptedData()
    {
        // Lokale UUID simulieren
        var localUuid = Guid.NewGuid().ToString();
        _sessionUser.Uuid = localUuid;
        
        // Arrange: User registrieren
        var userResponse = await _service.RegisterUserAsync(_vaultName, _userName);
        var registeredUuid = userResponse.UserUuid;

        Assert.False(string.IsNullOrWhiteSpace(registeredUuid));
        var publicKeys = await _service.GetPublicKeysAsync(registeredUuid);
        Assert.NotEmpty(publicKeys);
        Assert.True(publicKeys.Exists(pk => pk.UserUuid == registeredUuid));
        Assert.Equal(_expectedPublicKey, publicKeys.FirstOrDefault(pk => pk.UserUuid == registeredUuid)?.PublicKey);
    }
    
    /// <summary>
    /// 2.5.1 SaveFriendsAsync: Die Freundesliste sollte gespeichert werden, wenn der Benutzer existiert.
    /// </summary>
    [Fact]
    public async Task SaveFriendsAsync_UserExists_ShouldWork()
    {
        // Lokale UUID simulieren
        var localUuid = Guid.NewGuid().ToString();
        _sessionUser.Uuid = localUuid;
        
        // Benutzer registrieren
        var registeredUser = await _service.RegisterUserAsync(_vaultName, _userName);
        Assert.Null(registeredUser.EncryptedFriends);
        
        // Freundesliste speichern
        var newEncryptedFriends = "encrypted-friends-" + Guid.NewGuid().ToString("N");
        await _service.SaveFriendsAsync(registeredUser.UserUuid, newEncryptedFriends);        
        var after = await _service.FindUserAsync(_vaultName, _userName);
        Assert.Equal(newEncryptedFriends, after?.EncryptedFriends);
    }
    
    /// <summary>
    /// 2.5.2 SaveFriendsAsync: Wirft Exception, wenn der Benutzer nicht existiert.
    /// </summary>
    [Fact]
    public async Task SaveFriendsAsync_UserNotExists_ThrowsException()
    {
        // Lokale UUID simulieren
        var localUuid = Guid.NewGuid().ToString();
        _sessionUser.Uuid = localUuid;
        
        // Benutzer registrieren
        var registeredUser = await _service.RegisterUserAsync(_vaultName, _userName);
        Assert.Null(registeredUser.EncryptedFriends);
        
        // Freundesliste speichern
        var newEncryptedFriends = "encrypted-friends-" + Guid.NewGuid().ToString("N");
        await Assert.ThrowsAnyAsync<Exception>(() => _service.SaveFriendsAsync(Guid.NewGuid().ToString(), newEncryptedFriends));
    }
    
    // --- 3. Bulk-Aktion Sync ---
    
    /// <summary>
    /// 3.1.1 PullSyncAsync: Liefert ein valides Response-Objekt zurück (inkl. Updates/Deletes/server_time).
    /// <para>
    /// Setup: Es wird zuvor ein Eintrag per <see cref="IWebService.PushSyncAsync"/> erzeugt, damit der Pull etwas liefern kann.
    /// </para>
    /// </summary>
    [Fact]
    public async Task PullSyncAsync_ReturnsValidResponse()
    {
        // Lokale UUID simulieren
        var localUuid = Guid.NewGuid().ToString();
        _sessionUser.Uuid = localUuid;
        
        // Arrange: User registrieren
        var userResponse = await _service.RegisterUserAsync(_vaultName, _userName);
        var registeredUuid = userResponse.UserUuid;

        // Einen Entry serverseitig anlegen (Push)
        var entryUuid = Guid.NewGuid().ToString();
        var now = DateTime.UtcNow;

        var push = new SyncPushRequest
        {
            Updates =
            [
                new EntryDto
                {
                    EntryUuid = entryUuid,
                    EncryptedData = "data-sync",
                    EncryptedKey = "key-sync",
                    AccessLevel = 3,
                    AttachmentUuids = [],
                    Friends = [],
                    CreatorUuid = registeredUuid,
                    UpdaterUuid = registeredUuid,
                    UpdatedAt = now
                }
            ],
            Deletes = []
        };

        await _service.PushSyncAsync(registeredUuid, push);

        // Act: since sehr alt, damit der gerade gepushte Entry sicher im Pull landet
        var result = await _service.PullSyncAsync(registeredUuid, DateTime.SpecifyKind(new DateTime(1970, 1, 1), DateTimeKind.Utc));

        // Assert: Struktur prüfen (nicht auf konkrete Anzahl festnageln, aber mindestens unser Entry sollte drin sein)
        Assert.NotNull(result);
        Assert.NotNull(result.Updates);
        Assert.Contains(result.Updates, u => u.EntryUuid == entryUuid);
        var pulled = result.Updates.First(u => u.EntryUuid == entryUuid);
        Assert.Equal("data-sync", pulled.EncryptedData);
        Assert.Equal("key-sync", pulled.EncryptedKey);
        Assert.Equal(registeredUuid, pulled.CreatorUuid);
        Assert.Equal(registeredUuid, pulled.UpdaterUuid);
        Assert.True(pulled.UpdatedAt > DateTime.MinValue);
        Assert.NotNull(result.Deletes);
        Assert.True(result.ServerTime > DateTime.MinValue);
    }
    
    /// <summary>
    /// 3.1.2 PullSyncAsync: Wirft Exception bei fehlenden Parametern (422).
    /// </summary>
    [Fact]
    public async Task PullSyncAsync_MissingUserUuid_ThrowsException()
    {
        // Lokale UUID simulieren
        var localUuid = Guid.NewGuid().ToString();
        _sessionUser.Uuid = localUuid;
        
        // Arrange: User registrieren 
        await _service.RegisterUserAsync(_vaultName, _userName);

        // Act + Assert: user_uuid fehlt im Query -> 422
        await Assert.ThrowsAnyAsync<Exception>(() => _service.PullSyncAsync("", DateTime.UtcNow));
    }

    /// <summary>
    /// 3.1.3 PullSyncAsync: Wirft Exception bei Autorisierungsfehler (403), wenn Query-user_uuid != authUserUuid ist.
    /// </summary>
    [Fact]
    public async Task PullSyncAsync_Unauthorized_ThrowsException()
    {
        // Lokale UUID simulieren
        var localUuid = Guid.NewGuid().ToString();
        _sessionUser.Uuid = localUuid;
        
        // Arrange: User registrieren
        await _service.RegisterUserAsync(_vaultName, _userName);

        // Act + Assert: andere user_uuid im Query -> 403
        var otherUuid = Guid.NewGuid().ToString();
        await Assert.ThrowsAnyAsync<Exception>(() => _service.PullSyncAsync(otherUuid, DateTime.UtcNow));
    }
    
    /// <summary>
    /// 3.2.1 PushSyncAsync: Gibt true bei erfolgreichem Push zurück.
    /// </summary>
    [Fact]
    public async Task PushSyncAsync_ReturnsTrueOnSuccess()
    {
        // Lokale UUID simulieren
        var localUuid = Guid.NewGuid().ToString();
        _sessionUser.Uuid = localUuid;
        
        // Arrange: Owner registrieren und Session-Identität aktivieren
        var userResponse = await _service.RegisterUserAsync(_vaultName, _userName);
        var ownerUuid = userResponse.UserUuid;
        Assert.False(string.IsNullOrWhiteSpace(ownerUuid));
        var entryUuid = Guid.NewGuid().ToString();
        var now = DateTime.UtcNow;
        var request = new SyncPushRequest
        {
            Updates =
            [
                new EntryDto
                {
                    EntryUuid = entryUuid,
                    EncryptedData = "data",
                    EncryptedKey = "key",
                    AccessLevel = 3,
                    AttachmentUuids = new List<string>(),
                    Friends = new List<FriendPermissionDto>(),
                    CreatorUuid = ownerUuid,
                    UpdaterUuid = ownerUuid,
                    UpdatedAt = now
                }
            ],
            Deletes = []
        };
        await _service.PushSyncAsync(ownerUuid, request);
        Assert.True(true); // Kein Exception -> Erfolg
    }

    /// <summary>
    /// 3.2.2 PushSyncAsync: Wirft Exception, wenn user_uuid fehlt (Server: 422).
    /// </summary>
    [Fact]
    public async Task PushSyncAsync_MissingUserUuid_ThrowsException()
    {
        // Lokale UUID simulieren
        var localUuid = Guid.NewGuid().ToString();
        _sessionUser.Uuid = localUuid;
        
        // Arrange: User registrieren 
        await _service.RegisterUserAsync(_vaultName, _userName);
        var request = new SyncPushRequest
        {
            Updates = [],
            Deletes = []
        };
        await Assert.ThrowsAnyAsync<Exception>(() => _service.PushSyncAsync("", request));
    }

    /// <summary>
    /// 3.2.3 PushSyncAsync: Wirft Exception bei fehlendem Schreibrecht (Server: 403).
    /// <para>
    /// Szenario: Owner erstellt Entry und gibt einem Friend nur Leserechte (access_level=1).
    /// Friend versucht anschließend, denselben Entry zu aktualisieren.
    /// </para>
    /// </summary>
    [Fact]
    public async Task PushSyncAsync_NoWritePermission_ThrowsException()
    {
        // Arrange: Owner-Identität (Keypair 1)
        using var ownerRsa = RSA.Create(2048);
        var ownerPublicKey = Convert.ToBase64String(ownerRsa.ExportSubjectPublicKeyInfo());
        var ownerPrivateKey = ownerRsa.ExportPkcs8PrivateKey();

        _sessionUser.PublicKey = ownerPublicKey;
        _sessionPrivateKey = ownerPrivateKey;
        
        // --- Owner simulieren ---
        var localOwnerUuid = Guid.NewGuid().ToString(); // 1. Lokale UUID generieren
        _sessionUser.Uuid = localOwnerUuid;

        var userResponse = await _service.RegisterUserAsync(_vaultName, _userName);
        var ownerUuid = userResponse.UserUuid;
        
        // Sicherstellen, dass der Server unsere UUID genommen hat
        Assert.Equal(localOwnerUuid, ownerUuid); 

        SetSessionIdentity(ownerUuid, ownerPublicKey, ownerPrivateKey);

        // Friend-Identität (Keypair 2)
        using var friendRsa = RSA.Create(2048);
        var friendPublicKey = Convert.ToBase64String(friendRsa.ExportSubjectPublicKeyInfo());
        var friendPrivateKey = friendRsa.ExportPkcs8PrivateKey();

        var friendName = "~friend-" + Guid.NewGuid().ToString("N");

        // für RegisterUserAsync muss der PublicKey aus der Session kommen → kurz umschalten
        // --- Friend simulieren ---
        var localFriendUuid = Guid.NewGuid().ToString(); // 2. Lokale UUID für Friend generieren
        _sessionUser.Uuid = localFriendUuid;
        _sessionUser.PublicKey = friendPublicKey;

        var friendResponse = await _service.RegisterUserAsync(_vaultName, friendName);
        var friendUuid = friendResponse.UserUuid;
        
        // Sicherstellen, dass Server Friend-UUID genommen hat
        Assert.Equal(localFriendUuid, friendUuid);

        // Owner wieder aktivieren
        SetSessionIdentity(ownerUuid, ownerPublicKey, ownerPrivateKey);

        // Owner erstellt Entry und gibt Friend nur Read (1)
        var entryUuid = Guid.NewGuid().ToString();
        var now = DateTime.UtcNow;

        var createRequest = new SyncPushRequest
        {
            Updates =
            [
                new EntryDto
                {
                    EntryUuid = entryUuid,
                    EncryptedData = "data-v1",
                    EncryptedKey = "key-owner",
                    AccessLevel = 3,
                    AttachmentUuids = new List<string>(),
                    Friends =
                    [
                        new FriendPermissionDto
                        {
                            UserUuid = friendUuid,
                            EncryptedKey = "key-friend",
                            AccessLevel = 1
                        }
                    ],
                    CreatorUuid = ownerUuid,
                    UpdaterUuid = ownerUuid,
                    UpdatedAt = now
                }
            ],
            Deletes = new List<TombstoneDto>()
        };

        await _service.PushSyncAsync(ownerUuid, createRequest);

        // Act: Friend versucht Update → Server muss 403 liefern ("Kein Schreibrecht ...")
        SetSessionIdentity(friendUuid, friendPublicKey, friendPrivateKey);

        var updateRequest = new SyncPushRequest
        {
            Updates =
            [
                new EntryDto
                {
                    EntryUuid = entryUuid,
                    EncryptedData = "data-v2",
                    EncryptedKey = "key-friend-updated",
                    AccessLevel = 1,
                    AttachmentUuids = new List<string>(),
                    Friends = new List<FriendPermissionDto>(),
                    CreatorUuid = ownerUuid,
                    UpdaterUuid = friendUuid,
                    UpdatedAt = now.AddSeconds(1)
                }
            ],
            Deletes = new List<TombstoneDto>()
        };

        await Assert.ThrowsAnyAsync<Exception>(() => _service.PushSyncAsync(friendUuid, updateRequest));
    }
    
    // --- 4. Resource Attachment ---
    
    /// <summary>
    /// 4.1.1 UploadAttachmentAsync und DownloadAttachmentAsync: Upload speichert Anhang, der Download liefert dieselben Base64-Daten zurück.
    /// </summary>
    [Fact]
    public async Task UploadAttachmentAsync_Then_Download_ShouldWork()
    {
        // Lokale UUID simulieren
        var localUuid = Guid.NewGuid().ToString();
        _sessionUser.Uuid = localUuid;
        
        // Arrange: User registrieren und RSA aktivieren (Attachment ist sehr wahrscheinlich RSA-geschützt)
        var userResponse = await _service.RegisterUserAsync(_vaultName, _userName);
        var userUuid = userResponse.UserUuid;
        Assert.False(string.IsNullOrWhiteSpace(userUuid));

        //_isLoggedIn = true;

        // 1) Entry serverseitig anlegen, damit wir für den Attachment-Upload berechtigt sind
        var entryUuid = Guid.NewGuid().ToString();
        var now = DateTime.UtcNow;

        var createEntry = new SyncPushRequest
        {
            Updates =
            [
                new EntryDto
                {
                    EntryUuid = entryUuid,
                    EncryptedData = "data-for-attachment",
                    EncryptedKey = "key-for-attachment",
                    AccessLevel = 3,
                    AttachmentUuids = new List<string>(),
                    Friends = new List<FriendPermissionDto>(),
                    CreatorUuid = userUuid,
                    UpdaterUuid = userUuid,
                    UpdatedAt = now
                }
            ],
            Deletes = new List<TombstoneDto>()
        };

        await _service.PushSyncAsync(userUuid, createEntry);

        // 2) Attachment vorbereiten (Server erwartet Base64)
        var attachmentUuid = Guid.NewGuid().ToString();

        var metaBase64 = Convert.ToBase64String(RandomNumberGenerator.GetBytes(24));
        var contentBase64 = Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));

        // Act 1: Upload
        await _service.UploadAttachmentAsync(entryUuid, attachmentUuid, metaBase64, contentBase64);

        // Act 2: Download
        var attachmentResponse = await _service.DownloadAttachmentAsync(attachmentUuid);

        // Assert
        Assert.Equal(attachmentUuid, attachmentResponse.AttachmentUuid);
        Assert.Equal(entryUuid, attachmentResponse.EntryUuid);
        Assert.Equal(metaBase64, attachmentResponse.EncryptedMeta);
        Assert.Equal(contentBase64, attachmentResponse.EncryptedContent);
    }

    // /// <summary>
    // /// 4.1.2 UploadAttachmentAsync: Wirft Exception, wenn nicht eingeloggt.
    // /// </summary>
    // [Fact]
    // public async Task UploadAttachmentAsync_ThrowsWhenLoggedOut()
    // {
    //     _isLoggedIn = false;
    //     await Assert.ThrowsAnyAsync<Exception>(() => _service.UploadAttachmentAsync("e", "a", "m", "c"));
    // }
    //
    // /// <summary>
    // /// 4.2.1 DownloadAttachmentAsync: Gibt null zurück, wenn nicht eingeloggt.
    // /// </summary>
    // [Fact]
    // public async Task DownloadAttachmentAsync_ReturnsNullWhenLoggedOut()
    // {
    //     _isLoggedIn = false;
    //     var result = await _service.DownloadAttachmentAsync(Guid.NewGuid().ToString());
    //     Assert.Null(result);
    // }
}