using SQLite;

// ReSharper disable RedundantDefaultMemberInitializer
// ReSharper disable UnusedAutoPropertyAccessor.Global
// ReSharper disable AutoPropertyCanBeMadeGetOnly.Global
// ReSharper disable PropertyCanBeMadeInitOnly.Global

namespace Privault.Core.Models.Entities;

/// <summary>
/// Repräsentiert einen Dateianhang zu einem Tresoreintrag in der lokalen SQLite-Datenbank.
/// Der gesamte Inhalt wird verschlüsselt gespeichert, um die Privatsphäre zu gewährleisten.
/// <para>
/// <b>Sicherheitshinweise:</b>
/// <list type="bullet">
/// <item><b>Inhalt:</b> Der binäre Dateiinhalt ist mit dem AES-Schlüssel des zugehörigen Eintrags verschlüsselt.</item>
/// <item><b>Metadaten:</b> Metadaten wie Dateiname und MIME-Typ liegen als verschlüsselter JSON-Blob vor.</item>
/// </list>
/// </para>
/// </summary>
[Table("attachments")]
public class AttachmentEntity
{
    /// <summary>
    /// Die interne ID (Auto-Increment).
    /// Dient als Primärschlüssel für den Object-Relational Mapper (ORM).
    /// </summary>
    [PrimaryKey, AutoIncrement]
    [Column("id")]
    public int Id { get; set; }
    
    /// <summary>
    /// Die globale eindeutige ID des Anhangs (Universally Unique Identifier v4).
    /// </summary>
    [Indexed(Name = "uk_attachments_uuid", Unique = true)]
    [Column("uuid")]
    public string Uuid { get; set; } = string.Empty;

    /// <summary>
    /// Die interne ID des zugehörigen Eintrags.
    /// </summary>
    [Indexed(Name = "idx_attachments_entry_id")]
    [Column("entry_id")]
    public int EntryId { get; set; }
    
    /// <summary>
    /// Der AES-256-GCM verschlüsselte Metadaten-Container (Ciphertext + Nonce + Auth-Tag).
    /// Enthält das serialisierte JSON-Objekt der Klasse <see cref="Payloads.AttachmentMetaPayload"/>.
    /// </summary>
    [Column("encrypted_meta")]
    public string EncryptedMeta { get; set; } = string.Empty;

    /// <summary>
    /// Der AES-256-GCM verschlüsselte Binärdaten-Container (Ciphertext + Nonce + Auth-Tag).
    /// Enthält den binären Dateninhalt des Anhangs.
    /// </summary>
    [Column("encrypted_content")]
    public string EncryptedContent { get; set; } = string.Empty;
    
    /// <summary>
    /// <c>true</c>, wenn der Anhang synchronisiert wurde, sonst <c>false</c>
    /// </summary>
    [Indexed(Name = "idx_attachments_is_synced")]
    [Column("is_synced")]
    public bool IsSynced { get; set; } = false;
}
