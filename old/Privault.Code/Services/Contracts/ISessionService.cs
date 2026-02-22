using Privault.Core.Models.Entities;

namespace Privault.Core.Services.Contracts;

/// <summary>
/// Verwaltet den aktuellen Sitzungsstatus der Anwendung im Arbeitsspeicher (RAM).
/// Diese Klasse dient als zentraler Einstiegspunkt für den Zugriff auf Identitäts- und Tresordaten während der Laufzeit.
/// <para>
/// <b>Sicherheitshinweis:</b>
/// Sensible Daten (insbesondere <see cref="PrivateKey"/>) werden hier unverschlüsselt für die Dauer der Sitzung gehalten,
/// um kryptografische Operationen ohne ständige Passworteingabe zu ermöglichen. 
/// Beim Logout oder Schließen des Tresors müssen diese Daten zwingend über <see cref="ClearSession"/> bereinigt werden.
/// </para>
/// </summary>
public interface ISessionService
{
    // ------------------------------------------------------------------------
    // --- Eigenschaften ---
    // ------------------------------------------------------------------------
    
    /// <summary>
    /// Ruft ab, ob aktuell ein Benutzer erfolgreich am Tresor angemeldet ist.
    /// </summary>
    bool IsLoggedIn { get; }
    
    /// <summary>
    /// Der private RSA-Identitätsschlüssel des Benutzers als Byte-Array (PKCS#8).
    /// </summary>
    byte[]? PrivateKey { get; set; }
    
    /// <summary>
    /// Die Tresor-spezifischen Einstellungen (z.B. Host, Passwortgenerator-Konfiguration).
    /// </summary>
    SettingsEntity? Settings { get; set; }
    
    /// <summary>
    /// Die Identität des aktuell angemeldeten Benutzers.
    /// </summary>
    UserEntity? User { get; set; }

    /// <summary>
    /// Der Name des aktuell geöffneten Tresors (entspricht dem Dateinamen der DB).
    /// </summary>
    string VaultName { get; set; }

    // ------------------------------------------------------------------------
    // --- Methoden ---
    // ------------------------------------------------------------------------
    
    /// <summary>
    /// Setzt alle Sitzungsdaten zurück und überschreibt sensitive Schlüssel im RAM mit Nullen.
    /// </summary>
    void ClearSession();
}