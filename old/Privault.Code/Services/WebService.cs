using Privault.Core.Models.DTOs;
using Privault.Core.Services.Contracts;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;

namespace Privault.Core.Services;

/// <inheritdoc cref="IWebService" />
public class WebService : IWebService
{
    // ------------------------------------------------------------------------
    // --- Felder ---
    // ------------------------------------------------------------------------
    
    private readonly ICryptoService _cryptoService;
    private readonly ISessionService _sessionService;
    private readonly IHttpClientFactory _httpClientFactory;

    // ------------------------------------------------------------------------
    // --- Konstruktor ---
    // ------------------------------------------------------------------------
    
    /// <summary>
    /// Initialisiert eine neue Instanz des <see cref="WebService"/>.
    /// </summary>
    /// <param name="cryptoService">Dienst für kryptografische Signaturen und Hashes.</param>
    /// <param name="sessionService">Dienst für den Zugriff auf aktuelle Sitzungsdaten und Schlüssel.</param>
    /// <param name="httpClientFactory">Factory zur Erzeugung von HttpClient-Instanzen.</param>
    /// <exception cref="ArgumentNullException">Wird geworfen, wenn ein Dienst null ist.</exception>
    public WebService(
        ICryptoService cryptoService, 
        ISessionService sessionService,
        IHttpClientFactory httpClientFactory)
    {
        _cryptoService = cryptoService ?? throw new ArgumentNullException(nameof(cryptoService));
        _sessionService = sessionService ?? throw new ArgumentNullException(nameof(sessionService));
        _httpClientFactory = httpClientFactory ?? throw new ArgumentNullException(nameof(httpClientFactory));
    }

    // ------------------------------------------------------------------------
    // --- Öffentliche Methoden ---
    // ------------------------------------------------------------------------

    // --- Resource Version ---
    
    /// <inheritdoc />
    public async Task<VersionResponse> GetServerVersionAsync(string? host = null, string? apiToken = null)
    {
        // WebService aufrufen
        using var client = CreateClient(host, apiToken);
        var response = await client.GetAsync("version");
        
        // Antwort auswerten
        if (!response.IsSuccessStatusCode)
        {
            var error = await response.Content.ReadAsStringAsync();
            throw new Exception($"Serveranfrage fehlgeschlagen ({response.StatusCode}): {error}");
        }
        var result = await response.Content.ReadFromJsonAsync<VersionResponse>() ?? throw new Exception("Serveranfrage fehlgeschlagen");
        
        // Ergebnis zurückgeben
        return result;
    }
    
    // --- Resource User ---
    
    /// <inheritdoc />
    public async Task<UserResponse> GetUserAsync(string userUuid)
    {
        // WebService aufrufen
        using var client = CreateClient();
        var response = await client.GetAsync($"users/{userUuid}");

        // Antwort auswerten
        if (!response.IsSuccessStatusCode) 
        {
            var error = await response.Content.ReadAsStringAsync();
            throw new Exception($"Serveranfrage fehlgeschlagen ({response.StatusCode}): {error}");
        }
        var result = await response.Content.ReadFromJsonAsync<UserResponse>() ?? throw new Exception("Serveranfrage fehlgeschlagen");
        
        // Ergebnis zurückgeben
        return result;
    }
    
    /// <inheritdoc />
    public async Task<UserResponse?> FindUserAsync(string vaultName, string userName)
    {
        // Daten für Anfrage zusammenstellen
        var vaultHash = _cryptoService.ComputeHash(vaultName);
        var userHash = _cryptoService.ComputeHash(userName);
        
        // WebService aufrufen
        using var client = CreateClient();
        var response = await client.GetAsync($"users?vault_hash={vaultHash}&user_hash={userHash}");

        // Antwort auswerten
        if (!response.IsSuccessStatusCode) 
        {
            var error = await response.Content.ReadAsStringAsync();
            throw new Exception($"Serveranfrage fehlgeschlagen ({response.StatusCode}): {error}");
        }
        var result = await response.Content.ReadFromJsonAsync<UserResponse>();
        
        // Ergebnis zurückgeben
        return result;
    }
    
    /// <inheritdoc />
    public async Task<UserResponse> RegisterUserAsync(string vaultName, string userName)
    {
        // Daten für Anfrage zusammenstellen
        var user = _sessionService.User ?? throw new Exception("Kein lokaler Benutzer geladen.");
        var settings = _sessionService.Settings ?? throw new Exception("Keine Tresor-Einstellungen geladen.");
        var body = new
        {
            user_uuid = user.Uuid,
            vault_hash = _cryptoService.ComputeHash(vaultName),
            user_hash = _cryptoService.ComputeHash(userName),
            salt = settings.Salt,
            public_key = user.PublicKey,
            encrypted_private_key = settings.EncryptedPrivateKey
        };

        // WebService aufrufen
        using var client = CreateClient();
        var response = await client.PostAsJsonAsync("users", body);
        
        // Antwort auswerten
        if (!response.IsSuccessStatusCode)
        {
            var error = await response.Content.ReadAsStringAsync();
            throw new Exception($"Registrierung fehlgeschlagen: {response.StatusCode} - {error}");
        }
        var result = await response.Content.ReadFromJsonAsync<UserResponse>() ?? throw new Exception("Serveranfrage fehlgeschlagen");
        
        // Ergebnis zurückgeben
        return result;
    }

    /// <inheritdoc />
    public async Task ChangePasswordAsync(string userUuid, string salt, string encryptedPrivateKey)
    {
        // Daten für Anfrage zusammenstellen
        var body = new { salt, encrypted_private_key = encryptedPrivateKey };
        
        // WebService aufrufen
        using var client = CreateClient();
        var response = await client.PutAsJsonAsync($"users/{userUuid}/password", body);
        
        // Antwort auswerten
        if (!response.IsSuccessStatusCode)
        {
            var error = await response.Content.ReadAsStringAsync();
            throw new Exception($"Server-Update fehlgeschlagen: {response.StatusCode} - {error}");
        }
    }

    /// <inheritdoc />
    public async Task SaveFriendsAsync(string userUuid, string encryptedFriends)
    {
        // Daten für Anfrage zusammenstellen
        var body = new { encrypted_friends = encryptedFriends };
        
        // WebService aufrufen
        using var client = CreateClient();
        var response = await client.PutAsJsonAsync($"users/{userUuid}/friends", body);
        
        // Antwort auswerten
        if (!response.IsSuccessStatusCode)
        {
            var error = await response.Content.ReadAsStringAsync();
            throw new Exception($"Friends Push fehlgeschlagen ({response.StatusCode}): {error}");
        }
    }

    /// <inheritdoc />
    public async Task<List<PublicKeyResponse>> GetPublicKeysAsync(string userUuid)
    {
        // WebService aufrufen
        using var client = CreateClient();
        var response = await client.GetAsync($"users/{userUuid}/public_keys");
        
        // Antwort auswerten
        if (!response.IsSuccessStatusCode)
        {
            var error = await response.Content.ReadAsStringAsync();
            throw new Exception($"Friends Pull fehlgeschlagen ({response.StatusCode}): {error}");
        }
        var result = await response.Content.ReadFromJsonAsync<List<PublicKeyResponse>>() ?? [];
        
        // Ergebnis zurückgeben
        return result;
    }
    
    // --- Bulk-Aktion Sync ---
    
    /// <inheritdoc />
    public async Task<SyncPullResponse> PullSyncAsync(string userUuid, DateTime since)
    {
        // Daten für Anfrage zusammenstellen
        var utcSince = since.Kind == DateTimeKind.Utc ? since : since.ToUniversalTime();
        
        // WebService aufrufen
        using var client = CreateClient();
        // ":O" (Round-trip) erzeugt den ISO-8601-String (mit 'Z' am Ende)
        var response = await client.GetAsync($"users/{userUuid}/entries/sync?since={utcSince:O}");
        
        // Antwort auswerten
        if (!response.IsSuccessStatusCode)
        {
            var error = await response.Content.ReadAsStringAsync();
            throw new Exception($"Synchronisation fehlgeschlagen ({response.StatusCode}): {error}");
        }
        var result = await response.Content.ReadFromJsonAsync<SyncPullResponse>() ?? throw new Exception("Serveranfrage fehlgeschlagen");
        
        // Ergebnis zurückgeben
        return result;
    }

    /// <inheritdoc />
    public async Task PushSyncAsync(string userUuid, SyncPushRequest request)
    {
        // Daten für Anfrage zusammenstellen
        var json = JsonSerializer.Serialize(request);
        var body = new StringContent(json, Encoding.UTF8, "application/json");
        
        // WebService aufrufen
        using var client = CreateClient();
        // System.Text.Json Serialize, damit DateTime im DTO als ISO-8601 übertragen wird
        var response = await client.PostAsync($"users/{userUuid}/entries/sync", body);
        
        // Antwort auswerten
        if (!response.IsSuccessStatusCode)
        {
            var error = await response.Content.ReadAsStringAsync();
            throw new Exception($"Push fehlgeschlagen ({response.StatusCode}): {error}");
        }
    }

    // --- Resource Attachment ---

    /// <inheritdoc />
    public async Task<AttachmentResponse> DownloadAttachmentAsync(string attachmentUuid)
    {
        // WebService aufrufen
        using var client = CreateClient();
        var response = await client.GetAsync($"attachments/{attachmentUuid}");
        
        // Antwort auswerten
        if (!response.IsSuccessStatusCode)
        {
            var error = await response.Content.ReadAsStringAsync();
            throw new Exception($"Download fehlgeschlagen ({response.StatusCode}): {error}");
        }
        var result = await response.Content.ReadFromJsonAsync<AttachmentResponse>() ?? throw new Exception("Serveranfrage fehlgeschlagen");
        
        // Ergebnis zurückgeben
        return result;
    }

    /// <inheritdoc />
    public async Task UploadAttachmentAsync(string entryUuid, string attachmentUuid, string encryptedMetaBase64, string encryptedContentBase64)
    {
        // Daten für Anfrage zusammenstellen
        var body = new 
        { 
            entry_uuid = entryUuid, 
            encrypted_meta = encryptedMetaBase64, 
            encrypted_content = encryptedContentBase64 
        };

        // WebService aufrufen
        using var client = CreateClient();
        var response = await client.PutAsJsonAsync($"attachments/{attachmentUuid}", body);
        
        // Antwort auswerten
        if (!response.IsSuccessStatusCode)
        {
            var error = await response.Content.ReadAsStringAsync();
            throw new Exception($"Attachment-Upload fehlgeschlagen ({response.StatusCode}): {error}");
        }
    }

    // -- Resource Vault --
    
    /// <inheritdoc />
    public async Task CleanTestAsync(string vaultName)
    {
        // Daten für Anfrage zusammenstellen
        var vaultHash = _cryptoService.ComputeHash(vaultName);
        
        // WebService aufrufen
        using var client = CreateClient();
        var response = await client.DeleteAsync($"vaults?vault_hash={vaultHash}");
        
        // Antwort auswerten
        if (!response.IsSuccessStatusCode)
        {
            var error = await response.Content.ReadAsStringAsync();
            throw new Exception($"Test-Cleanup fehlgeschlagen ({response.StatusCode}): {error}");
        }
    }

    // ------------------------------------------------------------------------
    // --- Private Methoden ---
    // ------------------------------------------------------------------------
    
    /// <summary>
    /// Erzeugt einen vorkonfigurierten HttpClient mit API-Token und RSA-Sicherheitsheadern.
    /// <param name="host">Die Basis-URL des Servers.</param>
    /// <param name="apiToken">Das API-Token zur Authentifizierung.</param>
    /// </summary>
    private HttpClient CreateClient(string? host = null, string? apiToken = null)
    {
        // Aus den aktuellen Settings der Session (DB)
        var user = _sessionService.User;
        var privKey = _sessionService.PrivateKey;
        host ??= _sessionService.Settings?.Host ?? string.Empty; 
        apiToken ??= _sessionService.Settings?.ApiToken ?? string.Empty;

        // Validierung der URL und API-Token
        if (string.IsNullOrWhiteSpace(host))
            throw new Exception("Kein Sync-Server konfiguriert. Bitte überprüfe die Einstellungen.");
        if (!Uri.TryCreate(host, UriKind.Absolute, out _))
            throw new Exception($"Sync-Server '{host}' ist ungültig. Bitte überprüfe die Einstellungen.");
        if (string.IsNullOrWhiteSpace(apiToken))
            throw new Exception("Kein API-Token konfiguriert. Bitte überprüfe die Einstellungen.");

        // Client über Factory erzeugen
        var client = _httpClientFactory.CreateClient("PrivaultApi");
        client.BaseAddress = new Uri(host.EndsWith('/') ? host : host + "/");

        // Authentifizierung (Bearer)
        client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", apiToken);
        client.DefaultRequestHeaders.Add("X-API-Token", apiToken); // todo Bearer sollte allein reichen

        // RSA Authentifizierung
        if (user != null && privKey != null && !string.IsNullOrEmpty(user.Uuid))
        {
            // Wir signieren die Kombination aus UUID und einem aktuellen Zeitstempel (gegen Replay-Attacks)
            var timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString();
            var payload = $"{user.Uuid}:{timestamp}";
                
            // Signatur erstellen (CryptoService nutzen)
            var signature = _cryptoService.SignData(Encoding.UTF8.GetBytes(payload), privKey);
                
            // Sicherstellen, dass die Signatur für Header valide ist (keine Zeilenumbrüche)
            signature = signature.Replace("\r", "").Replace("\n", "").Trim();

            client.DefaultRequestHeaders.Add("X-User-Uuid", user.Uuid);
            client.DefaultRequestHeaders.Add("X-Timestamp", timestamp);
            client.DefaultRequestHeaders.Add("X-Signature", signature);
        }

        // Xdebug-Cookie (für Server-Debugging; non-blocking)
//#if DEBUG
        client.DefaultRequestHeaders.Add("Cookie", "XDEBUG_SESSION=PHPSTORM");
//#endif

        return client;
    }
}
