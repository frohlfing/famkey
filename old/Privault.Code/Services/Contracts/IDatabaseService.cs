using Privault.Core.Models.Entities;

namespace Privault.Core.Services.Contracts;

/// <summary>
/// Verwaltet den Zugriff auf die lokale, mit SQLCipher verschlüsselte SQLite-Datenbank.
/// Diese Klasse ist verantwortlich für die Datenpersistenz, das Schema-Management und Sicherungsvorgänge.
/// <para>
/// <b>Kernfunktionalitäten:</b>
/// <list type="bullet">
/// <item>Initialisierung und Entschlüsselung der Datenbankdatei mittels Master-Key.</item>
/// <item>CRUD-Operationen für Benutzer, Einträge, Anhänge und Berechtigungen.</item>
/// <item>Verwaltung von Synchronisations-Metadaten (Tombstones, Zeitstempel).</item>
/// <item>Sicherheits-Features: Datenbank-Backup, Wiederherstellung und Umschlüsselung (Rekey).</item>
/// </list>
/// </para>
/// </summary>
public interface IDatabaseService
{
    // ------------------------------------------------------------------------
    // --- Öffentliche Methoden ---
    // ------------------------------------------------------------------------

    // --- Initialisierung ---

    /// <summary>
    /// Initialisiert die Verbindung zur verschlüsselten SQLite-Datenbank und erstellt fehlende Tabellen.
    /// </summary>
    /// <param name="vaultName">Der Name des Tresors (wird als Dateiname verwendet).</param>
    /// <param name="masterKey">Der Schlüssel zur Entschlüsselung der Datenbankdatei.</param>
    /// <remarks>
    /// <list type="bullet">
    /// <item>Ist MAJOR oder MINOR der Datenbank aktueller als die App-Version, wird eine Exception ausgelöst.</item>
    /// <item>Ist die Datenbank veraltet, wird sie auf die App-Version migriert (inkl. PATCH).</item>
    /// </list>
    /// </remarks>
    Task InitializeAsync(string vaultName, byte[] masterKey);
    
    // --- Verbindung & System ---
    
    /// <summary>
    /// Schließt die aktuelle Datenbankverbindung sicher ab.
    /// </summary>
    Task CloseConnectionAsync();

    /// <summary>
    /// Erzeugt eine temporäre Kopie der aktuellen Datenbankdatei als Backup (.bak).
    /// </summary>
    void CreateBackup();

    /// <summary>
    /// Prüft, ob eine Datenbankdatei für den angegebenen Tresornamen bereits existiert.
    /// </summary>
    /// <param name="vaultName">Der zu prüfende Tresorname.</param>
    /// <returns><c>true</c>, wenn die Datei existiert, sonst <c>false</c>.</returns>
    bool DatabaseExists(string vaultName);

    /// <summary>
    /// Löscht die physische Datenbankdatei des aktuellen Tresors vom Dateisystem.
    /// </summary>
    Task DeleteCurrentDatabase();

    /// <summary>
    /// Lädt die aktuelle Schema-Version.
    /// </summary>
    /// <returns>Die Einstellungs-Entität oder <c>null</c>.</returns>
    Task<VersionEntity?> GetVersionAsync();

    /// <summary>
    /// Ändert den Verschlüsselungsschlüssel der Datenbankdatei (Rekey).
    /// </summary>
    /// <param name="newPassword">Der neue abgeleitete Datenbankschlüssel.</param>
    Task RekeyAsync(byte[] newPassword);

    /// <summary>
    /// Löscht die temporäre Sicherungsdatei (.bak).
    /// </summary>
    void RemoveBackup();

    /// <summary>
    /// Benennt die Datenbankdatei eines Tresors physisch auf dem Dateisystem um.
    /// </summary>
    /// <param name="oldName">Der aktuelle Name des Tresors.</param>
    /// <param name="newName">Der neue Name des Tresors.</param>
    void RenameDatabase(string oldName, string newName);

    /// <summary>
    /// Stellt die Datenbank aus der letzten Sicherungsdatei (.bak) wieder her.
    /// </summary>
    void RestoreBackup();

    // --- Benutzer ---

    /// <summary>
    /// Lädt alle registrierten Benutzerdatensätze.
    /// </summary>
    /// <returns>Eine Liste aller gespeicherten Benutzer.</returns>
    Task<List<UserEntity>> GetUsersAsync();
    
    /// <summary>
    /// Lädt einen Benutzer anhand seiner internen ID.
    /// </summary>
    /// <param name="userId">Die interne ID des Benutzers.</param>
    /// <returns>Die Benutzer-Entität oder <c>null</c>.</returns>
    Task<UserEntity?> GetUserAsync(int userId);

    /// <summary>
    /// Lädt einen Benutzer anhand seiner globalen UUID.
    /// </summary>
    /// <param name="userUuid">Die UUID des Benutzers.</param>
    /// <returns>Die Benutzer-Entität oder <c>null</c>.</returns>
    Task<UserEntity?> GetUserByUuidAsync(string userUuid);

    /// <summary>
    /// Speichert einen neuen Benutzer oder aktualisiert einen bestehenden Datensatz.
    /// </summary>
    /// <param name="user">Die zu speichernde Benutzer-Entität.</param>
    Task SaveUserAsync(UserEntity user);
    
    /// <summary>
    /// Blendet einen Benutzer aus, entzieht ihm alle Zugriffsrechte und entfernt seine Entry-Keys.
    /// Die Zeitstempel der betroffenen Einträge werden aktualisiert.
    /// </summary>
    /// <param name="userId">Die interne ID des Benutzers.</param>
    Task HideUserAsync(int userId);
    
    /// <summary>
    /// Löscht einen Benutzer komplett mit allen seinen Einträgen und zugehörigen Berechtigungen. 
    /// </summary>
    /// <param name="userId">Die interne ID des Benutzers.</param>
    Task DeleteUserAsync(int userId);

    // --- Einträge ---

    /// <summary>
    /// Lädt alle aktiven (nicht gelöschten) Einträge aus dem Tresor.
    /// </summary>
    /// <returns>Eine Liste aller Einträge.</returns>
    Task<List<EntryEntity>> GetEntriesAsync();

    /// <summary>
    /// Lädt alle Einträge, die nach einem bestimmten Zeitpunkt aktualisiert wurden (inkrementeller Sync).
    /// </summary>
    /// <param name="since">Der Start-Zeitpunkt (UTC).</param>
    /// <returns>Liste geänderter Einträge.</returns>
    Task<List<EntryEntity>> GetEntriesSinceAsync(DateTime since);

    /// <summary>
    /// Lädt einen einzelnen Eintrag anhand seiner internen ID.
    /// </summary>
    /// <param name="entryId">Die interne ID des Eintrags.</param>
    /// <returns>Die Eintrags-Entität oder <c>null</c>.</returns>
    Task<EntryEntity?> GetEntryAsync(int entryId);

    /// <summary>
    /// Lädt einen Eintrag anhand seiner globalen UUID.
    /// </summary>
    /// <param name="entryUuid">Die UUID des Eintrags.</param>
    /// <returns>Die Eintrags-Entität oder <c>null</c>.</returns>
    Task<EntryEntity?> GetEntryByUuidAsync(string entryUuid);

    /// <summary>
    /// Speichert einen Tresor-Eintrag und aktualisiert automatisch den Zeitstempel.
    /// </summary>
    /// <param name="entry">Der zu speichernde Eintrag.</param>
    Task SaveEntryAsync(EntryEntity entry);

    /// <summary>
    /// Speichert einen Tresor-Eintrag und die Berechtigung auf diesen Eintrag für den angegebenen Benutzer.
    /// </summary>
    /// <param name="entry">Der zu speichernde Eintrag.</param>
    /// <param name="userId">Interne ID des Benutzers.</param>
    /// <param name="encryptedKey">RSA-Verschlüsselte Entry-Key für diesen Eintrag für diesen Benutzer</param>
    /// <param name="accessLevel">Zugriffslevel (1 = Lesen, 2 = Lesen und Schreiben, 3 = Vollzugriff/Besitzer)</param>
    Task SaveEntryWithPermissionsAsync(EntryEntity entry, int userId, string encryptedKey, int accessLevel = 3);

    /// <summary>
    /// Löscht einen Eintrag mit allen zugehörigen Berechtigungen.
    /// </summary>
    /// <param name="entryId">Die interne ID des zu löschenden Eintrags.</param>
    Task DeleteEntryAsync(int entryId);
    
    // --- Dateianhänge ---

    /// <summary>
    /// Lädt alle Anhänge eines bestimmten Eintrags.
    /// </summary>
    /// <param name="entryId">Die interne ID des zugehörigen Eintrags.</param>
    /// <returns>Eine Liste von Anhängen.</returns>
    Task<List<AttachmentEntity>> GetAttachmentsByEntryAsync(int entryId);

    /// <summary>
    /// Lädt alle Anhänge, die noch nicht erfolgreich mit dem Server synchronisiert wurden.
    /// </summary>
    /// <returns>Eine Liste einsynchronisierter Anhänge.</returns>
    Task<List<AttachmentEntity>> GetAttachmentsUnsyncedAsync();

    /// <summary>
    /// Lädt einen Anhang anhand seiner internen ID.
    /// </summary>
    /// <param name="attachmentId">Die ID des Anhangs.</param>
    /// <returns>Die Anhangs-Entität oder <c>null</c>.</returns>
    Task<AttachmentEntity?> GetAttachmentAsync(int attachmentId);
    
    /// <summary>
    /// Lädt einen Anhang anhand seiner UUID.
    /// </summary>
    /// <param name="attachmentUuid">Die UUID des Anhangs.</param>
    /// <returns>Die Anhangs-Entität oder <c>null</c>.</returns>
    Task<AttachmentEntity?> GetAttachmentByUuidAsync(string attachmentUuid);

    /// <summary>
    /// Speichert einen Anhang oder aktualisiert einen bestehenden (Upsert).
    /// </summary>
    /// <param name="attachment">Die zu speichernde Anhangs-Entität.</param>
    Task SaveAttachmentAsync(AttachmentEntity attachment);

    /// <summary>
    /// Löscht einen Anhang anhand seiner UUID.
    /// </summary>
    /// <param name="attachmentId">Die ID des Anhangs.</param>
    Task DeleteAttachmentAsync(int attachmentId);

    // --- Berechtigungen ---

    /// <summary>
    /// Lädt alle in der Datenbank gespeicherten Berechtigungen.
    /// </summary>
    /// <returns>Eine Liste aller Berechtigungen.</returns>
    Task<List<PermissionEntity>> GetPermissionsAsync();
    
    /// <summary>
    /// Lädt alle Berechtigungen auf einen bestimmten Eintrag.
    /// </summary>
    /// <param name="entryId">Die interne ID des Eintrags.</param>
    /// <returns>Eine Liste von Berechtigungen.</returns>
    Task<List<PermissionEntity>> GetPermissionsByEntryIdAsync(int entryId);

    /// <summary>
    /// Lädt alle Berechtigungen eines bestimmten Benutzers.
    /// </summary>
    /// <param name="userId">Die interne ID des Benutzers.</param>
    /// <returns>Eine Liste von Berechtigungen.</returns>
    Task<List<PermissionEntity>> GetPermissionsByUserIdAsync(int userId);
    
    /// <summary>
    /// Lädt eine Berechtigung anhand seiner internen ID.
    /// </summary>
    /// <param name="permissionId">Die interne ID der Berechtigung.</param>
    /// <returns>Die Berechtigung oder <c>null</c>.</returns>
    Task<PermissionEntity?> GetPermissionAsync(int permissionId);
    
    /// <summary>
    /// Lädt die Berechtigung eines Benutzers für einen Eintrag.
    /// </summary>
    /// <param name="entryId">Die interne ID des Eintrags.</param>
    /// <param name="userId">Die interne ID des Benutzers.</param>
    /// <returns>Die Berechtigung oder <c>null</c>.</returns>
    Task<PermissionEntity?> GetPermissionByEntryIdAndUserIdAsync(int entryId, int userId);

    /// <summary>
    /// Prüft, ob für einen Freund der Entry-Key fehlt, obwohl er Zugriff auf den Eintrag hat.
    /// </summary>
    /// <param name="userId">Die interne ID des Benutzers.</param>
    Task<bool> HasAccessWithoutKeyAsync(int userId);
    
    /// <summary>
    /// Speichert eine neue oder aktualisierte Berechtigung.
    /// </summary>
    /// <param name="permission">Die Berechtigungs-Entität.</param>
    Task SavePermissionAsync(PermissionEntity permission);

    /// <summary>
    /// Aktualisiert eine Liste von Berechtigungen.
    /// <para>
    /// Es wird vorausgesetzt, dass die Berechtigungen bereits in der Datenbank vorhanden sind.
    /// </para>
    /// </summary>
    /// <param name="permissions">Die Berechtigungs-Entitäten.</param>
    Task UpdatePermissionsAsync(IEnumerable<PermissionEntity> permissions);
    
    /// <summary>
    /// Entfernt alle verschlüsselten Entry-Keys für einen bestimmten Benutzer (EncryptedKey wird auf Empty gesetzt).
    /// Die Zeitstempel der betroffenen Einträge werden aktualisiert.
    /// </summary>
    /// <param name="userId">Die interne ID des Benutzers.</param>
    /// <remarks>
    /// Diese Funktion wird aufgerufen, wenn der gespeicherte RSA-Key aktualisiert wurde.
    /// </remarks>
    Task RemoveEntryKeysForUserAsync(int userId);
    
    /// <summary>
    /// Löscht die Zugriffsberechtigung für einen Benutzer auf einen bestimmten Eintrag.
    /// </summary>
    /// <param name="permissionId">Die interne ID der Berechtigung.</param>
    Task DeletePermissionAsync(int permissionId);
    
    // --- Grabsteine ---

    /// <summary>
    /// Lädt alle Löschmarker (Tombstones) seit dem angegebenen Zeitpunkt ab.
    /// </summary>
    /// <param name="since">Start-Zeitpunkt (UTC).</param>
    /// <returns>Liste von Löschmarkern.</returns>
    Task<List<TombstoneEntity>> GetTombstonesSinceAsync(DateTime since);

    /// <summary>
    /// Speichert einen Löschmarker, um die Entfernung eines Eintrags synchronisieren zu können.
    /// </summary>
    /// <param name="tombstone">Die Tombstone-Entität.</param>
    Task SaveTombstoneAsync(TombstoneEntity tombstone);

    // --- Einstellungen ---

    /// <summary>
    /// Lädt die globalen Einstellungen für den aktuellen Tresor.
    /// </summary>
    /// <returns>Die Einstellungs-Entität oder <c>null</c>.</returns>
    Task<SettingsEntity?> GetSettingsAsync();

    /// <summary>
    /// Speichert oder ersetzt die globalen Tresor-Einstellungen.
    /// </summary>
    /// <param name="settings">Die zu speichernden Einstellungen.</param>
    Task SaveSettingsAsync(SettingsEntity settings);
}