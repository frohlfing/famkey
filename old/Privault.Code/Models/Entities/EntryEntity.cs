using SQLite;

// ReSharper disable UnusedAutoPropertyAccessor.Global
// ReSharper disable AutoPropertyCanBeMadeGetOnly.Global
// ReSharper disable PropertyCanBeMadeInitOnly.Global

namespace Privault.Core.Models.Entities;

/// <summary>
/// Repräsentiert einen Tresoreintrag in der SQLite-Datenbank.
/// <para>
/// <b>Datenstruktur:</b>
/// <list type="bullet">
/// <item><description><b>Verschlüsselter Kern:</b> Die vollständigen und sensiblen Daten (Passwort, Notizen, etc.) liegen als AES-256-GCM verschlüsselter JSON-Blob in <see cref="EncryptedData"/> vor (entspricht dem <c>EntryPayload</c>).</description></item>
/// <item><description><b>Unverschlüsselte Indizes:</b> Redundante Kopien von Titel, Kategorie und URL werden unverschlüsselt (aber SQLCipher-geschützt) gespeichert, um eine performante Suche, Sortierung und Gruppierung zu ermöglichen.</description></item>
/// </list>
/// </para>
/// </summary>
[Table("entries")]
public class EntryEntity
{
    /// <summary>
    /// Die interne ID (Auto-Increment).
    /// Dient als Primärschlüssel für den Object-Relational Mapper (ORM) benötigt.
    /// </summary>
    [PrimaryKey, AutoIncrement]
    [Column("id")]
    public int Id { get; set; }

    /// <summary>
    /// Die globale eindeutige ID des Eintrags (Universally Unique Identifier v4).
    /// </summary>
    [Indexed(Name = "uk_entries_uuid", Unique = true)]
    [Column("uuid")]
    public string Uuid { get; set; } = string.Empty;

    /// <summary>
    /// Die Kategorie des Eintrags.
    /// </summary>
    [Indexed]
    [Column("category")]
    public string Category { get; set; } = string.Empty;
    
    /// <summary>
    /// Der Anzeigename des Eintrags.
    /// </summary>
    [Indexed]
    [Column("title")]
    public string Title { get; set; } = string.Empty;

    /// <summary>
    /// Die zugehörige Adresse der Webseite oder des Dienstes.
    /// </summary>
    [Column("url")]
    public string Url { get; set; } = string.Empty;

    // todo notes -> note (ist nur eine Notiz)
    /// <summary>
    /// Ergänzende Notiz.
    /// </summary>
    [Column("notes")]
    public string Notes { get; set; } = string.Empty;

    /// <summary>
    /// Der binäre Dateninhalt des Website-Icons, gespeichert als Base64-kodierter String.
    /// Ermöglicht die visuelle Identifikation in der Liste ohne zusätzliche Netzwerkanfragen.
    /// </summary>
    [Column("favicon")]
    public string Favicon { get; set; } = string.Empty;
    
    /// <summary>
    /// Der AES-256-GCM verschlüsselte Daten-Container (Ciphertext + Nonce + Auth-Tag).
    /// Enthält das serialisierte JSON-Objekt der Klasse <see cref="Payloads.EntryPayload"/>.
    /// </summary>
    [Column("encrypted_data")]
    public string EncryptedData { get; set; } = string.Empty;

    /// <summary>
    /// Die lokale ID des Benutzers, der diesen Eintrag erstellt hat.
    /// </summary>
    [Column("creator_id")]
    public int CreatorId { get; set; }

    /// <summary>
    /// Die lokale ID des Benutzers, der den Eintrag zuletzt aktualisiert hat.
    /// </summary>
    [Column("updater_id")]
    public int UpdaterId { get; set; }
    
    private DateTime _updatedAt = DateTime.SpecifyKind(new DateTime(1970, 1, 1), DateTimeKind.Utc);

    /// <summary>
    /// Zeitpunkt der letzten Änderung (UTC).
    /// </summary>
    [Indexed(Name = "idx_entries_updated_at")]
    [Column("updated_at")]
    public DateTime UpdatedAt
    {
        get => _updatedAt;
        set => _updatedAt = value.Kind == DateTimeKind.Unspecified ? DateTime.SpecifyKind(value, DateTimeKind.Utc) : value.ToUniversalTime();
    }
}