using SQLite;

// ReSharper disable UnusedAutoPropertyAccessor.Global
// ReSharper disable AutoPropertyCanBeMadeGetOnly.Global
// ReSharper disable PropertyCanBeMadeInitOnly.Global

namespace Privault.Core.Models.Entities;

/// <summary>
/// Repräsentiert die privaten Konfigurationseinstellungen des aktuell geöffneten Tresors.
/// Diese Entität speichert sensible Synchronisationsparameter und kryptografische Basiselemente.
/// <para>
/// <b>Besonderheit:</b>
/// Diese Tabelle fungiert als Singleton-Speicher und enthält systembedingt exakt einen Datensatz, 
/// welcher die Konfiguration für die aktuelle Tresor-Instanz beschreibt.
/// </para>
/// </summary>
[Table("settings")]
public class SettingsEntity
{
    /// <summary>
    /// Die interne ID (Auto-Increment).
    /// Dient als Primärschlüssel für den Object-Relational Mapper (ORM) benötigt.
    /// Da es sich um einen Singleton-Datensatz handelt, ist der Wert hierbei stets 1.
    /// </summary>
    [PrimaryKey]
    [Column("id")]
    public int Id { get; set; } = 1;

    // --- Kryptografie ---

    /// <summary>
    /// Das Salt, welches zur Ableitung des Master-Keys (Argon2id) verwendet wird.
    /// </summary>
    [Column("salt")]
    public string Salt { get; set; } = string.Empty;
    
    /// <summary>
    /// Der private RSA-Schlüssel des Benutzers - verschlüsselt mit dem Master-Key (AES-256-GCM).
    /// Wird benötigt, um Daten im Tresor zu entschlüsseln oder zu signieren.
    /// </summary>
    [Column("encrypted_private_key")]
    public string EncryptedPrivateKey { get; set; } = string.Empty;
    
    // --- Sync-Einstellungen ---

    /// <summary>
    /// Die URL des Sync-Servers (Host).
    /// </summary>
    [Column("host")]
    public string Host { get; set; } = string.Empty;

    /// <summary>
    /// Das API-Token zur Authentifizierung gegenüber dem Sync-Server.
    /// </summary>
    [Column("api_token")]
    public string ApiToken { get; set; } = string.Empty;

    // --- Biometrie ---
    
    /// <summary>
    /// Gibt an, ob Fingerabdruck bzw. Gesichtserkennung als Anmeldeoption zur Verfügung steht.
    /// </summary>
    [Column("use_biometric")]
    public bool UseBiometric { get; set; } = true;
    
    // --- Passwort-Generator ---

    /// <summary>
    /// Die vom Passwortgenerator verwendete Passwortlänge.
    /// </summary>
    [Column("pw_length")]
    public int PwLength { get; set; } = 16;

    /// <summary>
    /// Die vom Passwortgenerator verwendeten Sonderzeichen.
    /// </summary>
    [Column("pw_special_chars")]
    public string PwSpecialChars { get; set; } = string.Empty;

    /// <summary>
    /// Gibt an, ob der Passwortgenerator verwechselbare Zeichen (I, l, O, 0) ausschließen soll.
    /// </summary>
    [Column("pw_avoid_ilo0")]
    public bool PwAvoidIlO0 { get; set; } = true;

    // --- Aussehen ---
    
    /// <summary>
    /// Der Name, der in der UI als Platzhalter für Einträge ohne explizite Kategorie verwendet wird (z. B. "Allgemein").
    /// </summary>
    [Column("category_placeholder")]
    public string CategoryPlaceholder { get; set; } = string.Empty;

    // --- Synchronisation ---

    private DateTime _lastSyncAt = DateTime.SpecifyKind(new DateTime(1970, 1, 1), DateTimeKind.Utc);
    
    /// <summary>
    /// Zeitpunkt der letzten erfolgreichen Synchronisation (UTC, Serverzeit).
    /// </summary>
    [Column("last_sync_at")]
    public DateTime LastSyncAt
    {
        get => _lastSyncAt;
        set => _lastSyncAt = value.Kind == DateTimeKind.Unspecified ? DateTime.SpecifyKind(value, DateTimeKind.Utc) : value.ToUniversalTime();
    }
}