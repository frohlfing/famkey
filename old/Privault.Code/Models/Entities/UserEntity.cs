using SQLite;

// ReSharper disable RedundantDefaultMemberInitializer
// ReSharper disable UnusedAutoPropertyAccessor.Global
// ReSharper disable AutoPropertyCanBeMadeGetOnly.Global
// ReSharper disable PropertyCanBeMadeInitOnly.Global

namespace Privault.Core.Models.Entities;

/// <summary>
/// Repräsentiert eine Benutzeridentität innerhalb eines Tresors.
/// <para>
/// Diese Tabelle verwaltet sowohl den Benutzer der App als auch alle hinzugefügten 
/// Freunde, mit denen Einträge geteilt werden können.
/// </para>
/// <para>
/// <b>Rollenverteilung:</b>
/// <list type="bullet">
/// <item><description><b>Besitzer:</b> Der Hauptbenutzer der App hat lokal stets die <c>Id = 1</c>.</description></item>
/// <item><description><b>Freunde:</b> Weitere Benutzer, mit denen Einträge geteilt werden können.</description></item>
/// </list>
/// </para>
/// </summary>
[Table("users")]
public class UserEntity
{
    /// <summary>
    /// Die interne ID (Auto-Increment).
    /// Dient als Primärschlüssel für den Object-Relational Mapper (ORM) benötigt.
    /// Der Benutzer der App wird systemintern stets mit der ID 1 identifiziert.
    /// </summary>
    [PrimaryKey, AutoIncrement]
    [Column("id")]
    public int Id { get; set; } // Ich bin immer ID 1

    /// <summary>
    /// Die globale eindeutige ID des Benutzers (Universally Unique Identifier v4).
    /// </summary>
    [Indexed(Name = "uk_users_uuid", Unique = true)]
    [Column("uuid")]
    public string Uuid { get; set; } = string.Empty;

    /// <summary>
    /// Der Name des Benutzers (eindeutig pro Tresor).
    /// UNVERÄNDERLICH nach der Registrierung.
    /// </summary>
    [Indexed(Name = "uk_users_name", Unique = true)]
    [Column("name")]
    public string Name { get; set; } = string.Empty;
    
    /// <summary>
    /// Der öffentliche RSA-Schlüssel des Benutzers (Base64-kodierter SPKI-String).
    /// </summary>
    [Column("public_key")]
    public string PublicKey { get; set; } = string.Empty;

    /// <summary>
    /// Gibt an, ob die Identität dieses Benutzers (per Fingerprint-Vergleich) verifiziert wurde.
    /// </summary>
    [Column("is_verified")]
    public bool IsVerified { get; set; } = false;
    
    /// <summary>
    /// Gibt an, ob der Benutzer in der UI ausgeblendet ist.
    /// </summary>
    [Indexed(Name = "idx_users_is_hidden")]
    [Column("is_hidden")]
    public bool IsHidden { get; set; }
    
    private DateTime _updatedAt = DateTime.SpecifyKind(new DateTime(1970, 1, 1), DateTimeKind.Utc);
    
    /// <summary>
    /// Zeitpunkt der letzten Änderung (UTC).
    /// </summary>
    [Indexed(Name = "idx_users_updated_at")]
    [Column("updated_at")]
    public DateTime UpdatedAt
    {
        get => _updatedAt;
        set => _updatedAt = value.Kind == DateTimeKind.Unspecified ? DateTime.SpecifyKind(value, DateTimeKind.Utc) : value.ToUniversalTime();
    }
}