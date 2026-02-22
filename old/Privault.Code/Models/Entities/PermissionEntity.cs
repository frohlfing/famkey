using SQLite;

// ReSharper disable UnusedAutoPropertyAccessor.Global
// ReSharper disable AutoPropertyCanBeMadeGetOnly.Global
// ReSharper disable PropertyCanBeMadeInitOnly.Global

namespace Privault.Core.Models.Entities;

/// <summary>
/// Repräsentiert die Zugriffsberechtigung eines Benutzers für einen spezifischen Tresoreintrag.
/// Diese Entität verwaltet die hybride Verschlüsselung, indem sie den AES-Entry-Key in RSA-verschlüsselter Form speichert.
/// <para>
/// Eine Berechtigung ist eindeutig über die Kombination aus <see cref="EntryId"/> und <see cref="UserId"/>.
/// </para>
/// <para>
/// <b>Sicherheitskonzept:</b>
/// Jede Permission enthält den 32-Byte AES-Key des Eintrags, der mit dem öffentlichen RSA-Schlüssel des jeweiligen 
/// Empfängers verschlüsselt wurde. Nur der Besitzer des zugehörigen privaten RSA-Schlüssels kann den Entry-Key 
/// extrahieren und somit die Daten lesen.
/// </para>
/// </summary>
[Table("permissions")]
public class PermissionEntity
{
    /// <summary>
    /// Die interne ID (Auto-Increment).
    /// Dient als Primärschlüssel für den Object-Relational Mapper (ORM) benötigt.
    /// </summary>
    [PrimaryKey, AutoIncrement]
    [Column("id")]
    public int Id { get; set; }

    /// <summary>
    /// Die interne ID des zugehörigen Eintrags.
    /// </summary>
    [Indexed(Name = "uk_permissions_entry_id_user_id", Order = 1, Unique = true)] // für Detailansicht
    [Indexed(Name = "uk_permissions_user_id_entry_id", Order = 2, Unique = true)] // für Sync-Pull
    [Column("entry_id")]
    public int EntryId { get; set; }

    /// <summary>
    /// Die lokale ID des Benutzers (<see cref="UserEntity"/>), dem dieser Zugriff gewährt wurde.
    /// </summary>
    [Indexed(Name = "uk_permissions_entry_id_user_id", Order = 2, Unique = true)] // für Detailansicht
    [Indexed(Name = "uk_permissions_user_id_entry_id", Order = 1, Unique = true)] // für Sync-Pull
    [Column("user_id")]
    public int UserId { get; set; }
    
    /// <summary>
    /// Der AES-Entry-Key für den Eintrag (32 Bytes), verschlüsselt mit dem öffentlichen RSA-Key des Benutzers.
    /// <para>
    /// Wenn beim Synchronisieren festgestellt wird, dass der RSA-Schlüssel veraltet ist, wird <c>EncryptedKey</c> geleert.
    /// </para>
    /// </summary>
    [Column("encrypted_key")]
    public string EncryptedKey { get; set; } = string.Empty;

    /// <summary>
    /// Definiert die Berechtigungsstufe des Benutzers für diesen Eintrag.
    /// <list type="bullet">
    /// <item><description><b>0:</b> Kein Zugriff</description></item>
    /// <item><description><b>1:</b> Nur Lesen</description></item>
    /// <item><description><b>2:</b> Lesen und Schreiben</description></item>
    /// <item><description><b>3:</b> Vollzugriff/Besitzerrecht (inkl. Löschen und Berechtigungen verwalten)</description></item>
    /// </list>
    /// </summary>
    [Column("access_level")]
    public int AccessLevel { get; set; }
}