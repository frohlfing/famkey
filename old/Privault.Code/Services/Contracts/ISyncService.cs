namespace Privault.Core.Services.Contracts;

/// <summary>
/// Orchestriert den bidirektionalen Datenaustausch zwischen der lokalen Datenbank und dem Privault-Sync-Server.
/// Diese Klasse ist verantwortlich für die Konfliktlösung, Identitätsadoption und die Konsistenz der verschlüsselten Daten.
/// <para>
/// <b>Synchronisations-Phasen:</b>
/// <list type="number">
/// <item><description><b>Identitätsprüfung:</b> Validierung von Salt und Keys gegenüber dem Server.</description></item>
/// <item><description><b>Settings Pull:</b> Abgleich von Freunden und App-Konfigurationen.</description></item>
/// <item><description><b>Data Pull:</b> Herunterladen neuer Einträge, Berechtigungen und Anhänge.</description></item>
/// <item><description><b>Data Push:</b> Hochladen lokaler Änderungen und Löschungen (Tombstones).</description></item>
/// <item><description><b>Finalisierung:</b> Aktualisierung des lokalen Zeitstempels der letzten Synchronisation.</description></item>
/// </list>
/// </para>
/// </summary>
public interface ISyncService
{
    /// <summary>
    /// Führt einen vollständigen Synchronisationsvorgang durch. 
    /// Verarbeitet Benutzeridentitäten, Einstellungen, Tresoreinträge und Dateianhänge.
    /// </summary>
    /// <returns>Ein <see cref="SyncStatistics"/> Objekt mit der Zusammenfassung der verarbeiteten Daten.</returns>
    /// <exception cref="Exception">Wird geworfen, wenn Netzwerk- oder kryptografische Fehler auftreten.</exception>
    Task<SyncStatistics> SyncAsync();
}
