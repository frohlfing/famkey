namespace Privault.Core.Services.Contracts;

/// <summary>
/// Verwaltet die globalen App-Einstellungen und Tresor-Metadaten unter Nutzung der plattformnativen Preferences.
/// Diese Klasse sorgt dafür, dass Konfigurationen über App-Sitzungen hinweg persistent gespeichert werden.
/// <para>
/// <b>Verantwortlichkeiten:</b>
/// <list type="bullet">
/// <item>Speicherung und Abruf der Tresor-Liste inklusive deren kryptografischen Salts.</item>
/// <item>Verwaltung der Benutzerpräferenzen für das Erscheinungsbild (Theme).</item>
/// <item>Tracking des zuletzt verwendeten Tresors für einen schnelleren Login.</item>
/// <item>Persistenz von UI-Filtereinstellungen.</item>
/// </list>
/// </para>
/// </summary>
public interface IConfigService
{
    // ------------------------------------------------------------------------
    // --- Eigenschaften ---
    // ------------------------------------------------------------------------
    
    /// <summary>
    /// Ruft den Namen des zuletzt erfolgreich geöffneten Tresors ab oder legt diesen fest.
    /// </summary>
    string LastVaultName { get; set; }
    
    /// <summary>
    /// Gibt an, ob standardmäßig nur eigene Einträge angezeigt werden sollen, oder legt es fest.
    /// </summary>
    bool ShowOnlyMine { get; set; }
    
    /// <summary>
    /// Ruft das gewählte App-Theme ab oder legt dieses fest.
    /// <para>
    /// Das erwartete Format ist "{ThemeKind}.{ThemeMode}".
    /// </para>
    /// </summary>
    string Theme { get; set; }
    
    /// <summary>
    /// Eine Liste aller auf diesem Gerät bekannten Tresore.
    /// Der Key ist der Tresorname, der Value das zugehörige Base64-kodierte Salt.
    /// </summary>
    Dictionary<string, string> Vaults { get; set; }
}