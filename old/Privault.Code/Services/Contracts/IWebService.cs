using Privault.Core.Models.DTOs;

namespace Privault.Core.Services.Contracts;

/// <summary>
/// Definiert die Schnittstelle für die Kommunikation mit der Privault-REST-API.
/// Diese Klasse ist verantwortlich für den Datenaustausch zwischen dem lokalen Client und dem Sync-Server.
/// <para>
/// <b>Sicherheitskonzept:</b>
/// Alle Anfragen werden mittels RSA-Signatur authentifiziert und (wo nötig) über TLS/SSL verschlüsselt übertragen.
/// Sensible Daten (Passwörter, Notizen, Anhänge) werden vom WebService bereits in verschlüsselter Form (AES-GCM) 
/// entgegengenommen und versendet, sodass der Server niemals Zugriff auf Klartextdaten hat.
/// </para>
/// </summary>
public interface IWebService
{
    // ------------------------------------------------------------------------
    // --- Öffentliche Methoden ---
    // ------------------------------------------------------------------------

    // --- Resource Version ---

    /// <summary>
    /// Fragt die aktuelle API-Version des angegebenen bzw. konfigurierten Servers ab.
    /// </summary>
    /// <remarks>
    /// Durch die optionalen Parameter kann die Funktion auch als Verbindungstest verwendet werden.
    /// </remarks>
    /// <param name="host">Die Basis-URL des Servers (optional).</param>
    /// <param name="apiToken">Das API-Token zur Authentifizierung (optional).</param>
    /// <returns>Die API-Version und die minimal erforderliche App-Minor-Version.</returns>
    Task<VersionResponse> GetServerVersionAsync(string? host = null, string? apiToken = null);

    // --- Resource User ---

    /// <summary>
    /// Liefert die Benutzerdaten vom Server anhand seiner UUID.
    /// </summary>
    /// <param name="userUuid">Die UUID des Benutzers.</param>
    /// <returns>Die Benutzerdaten.</returns>
    Task<UserResponse> GetUserAsync(string userUuid);
    
    /// <summary>
    /// Sucht im angegebenen Tresor nach einem bestimmten Benutzer.
    /// </summary>
    /// <param name="vaultName">Der Name des Tresors.</param>
    /// <param name="userName">Der gesuchte Benutzername.</param>
    /// <returns>Die Benutzerdaten bei Erfolg, andernfalls <c>null</c>.</returns>
    Task<UserResponse?> FindUserAsync(string vaultName, string userName);
    
    /// <summary>
    /// Registriert einen neuen Benutzer auf dem Server.
    /// </summary>
    /// <param name="vaultName">Der Name des zu erstellenden oder beizutretenden Tresors.</param>
    /// <param name="userName">Der gewünschte Benutzername.</param>
    /// <returns>Die Benutzerdaten bei Erfolg, andernfalls <c>null</c>.</returns>
    Task<UserResponse> RegisterUserAsync(string vaultName, string userName);
    
    /// <summary>
    /// Überträgt eine Passwortänderung (neues Salt und verschlüsselter Private Key) zum Server.
    /// </summary>
    /// <param name="userUuid">Die UUID des Benutzers.</param>
    /// <param name="salt">Das neue Base64-kodierte Salt.</param>
    /// <param name="encryptedPrivateKey">Der mit dem neuen Master-Passwort verschlüsselte RSA-Privatschlüssel.</param>
    Task ChangePasswordAsync(string userUuid, string salt, string encryptedPrivateKey);

    /// <summary>
    /// Speichert die verschlüsselte Freundesliste des Benutzers auf dem Server.
    /// </summary>
    /// <param name="userUuid">Die UUID des Benutzers.</param>
    /// <param name="encryptedFriends">Die verschlüsselte Freundesliste.</param>
    Task SaveFriendsAsync(string userUuid, string encryptedFriends);

    /// <summary>
    /// Ruft die öffentlichen RSA-Schlüssel aller Benutzer des Tresors ab.
    /// </summary>
    /// <param name="userUuid">Die UUID des Benutzers.</param>
    /// <returns>Eine Liste mit den RSA-Schlüsseln.</returns>
    Task<List<PublicKeyResponse>> GetPublicKeysAsync(string userUuid);

    // --- Bulk-Aktion Sync ---
    
    /// <summary>
    /// Ruft alle Änderungen seit der letzten Synchronisation ab.
    /// </summary>
    /// <param name="userUuid">Die UUID des anfragenden Benutzers.</param>
    /// <param name="since">Zeitpunkt des letzten erfolgreichen Abgleichs (UTC).</param>
    /// <returns>Ein <see cref="SyncPullResponse"/> mit Updates und Deletes.</returns>
    Task<SyncPullResponse> PullSyncAsync(string userUuid, DateTime since);
    
    /// <summary>
    /// Überträgt lokale Änderungen zum Server.
    /// </summary>
    /// <param name="userUuid">Die UUID des anfragenden Benutzers.</param>
    /// <param name="request">Das Payload mit den zu synchronisierenden Daten.</param>
    Task PushSyncAsync(string userUuid, SyncPushRequest request);
    
    // --- Resource Attachment ---
    
    /// <summary>
    /// Lädt die verschlüsselten Daten eines Dateianhangs vom Server herunter.
    /// </summary>
    /// <param name="attachmentUuid">Die UUID des Anhangs.</param>
    /// <returns>Die verschlüsselten Metadaten und der Dateiinhalt.</returns>
    Task<AttachmentResponse> DownloadAttachmentAsync(string attachmentUuid);
    
    /// <summary>
    /// Lädt einen neuen oder geänderten Anhang zum Server hoch.
    /// </summary>
    /// <param name="entryUuid">UUID des zugehörigen Eintrags.</param>
    /// <param name="attachmentUuid">Eindeutige UUID für diesen Anhang.</param>
    /// <param name="encryptedMetaBase64">Verschlüsseltes JSON der Metadaten (Base64).</param>
    /// <param name="encryptedContentBase64">Verschlüsselter Dateiinhalt (Base64).</param>
    Task UploadAttachmentAsync(string entryUuid, string attachmentUuid, string encryptedMetaBase64, string encryptedContentBase64);
    
    // -- Resource Vault --
    
    /// <summary>
    /// Räumt den Test-Tresor serverseitig auf (DELETE /test?vault_hash=...).
    /// Wird typischerweise von Integrationstests verwendet.
    /// <param name="vaultName">Der Name des Tresors.</param>
    /// </summary>
    Task CleanTestAsync(string vaultName);
}
