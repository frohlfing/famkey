namespace Privault.Core.Services.Contracts;

/// <summary>
/// Definiert die Logik für kritische Tresor-Operationen, die eine erhöhte Sicherheitsstufe und Datenintegrität erfordern.
/// Diese Klasse fungiert als Sicherheits-Wrapper um destructive oder strukturelle Änderungen am Tresor.
/// <para>
/// <b>Schutzmechanismen:</b>
/// <list type="bullet">
/// <item><b>Autorisierung:</b> Jede Operation erzwingt eine erneute Eingabe des Master-Passworts.</item>
/// <item><b>Transaktionsschutz:</b> Automatisches Dateisystem-Backup vor der Operation und Rollback im Fehlerfall.</item>
/// <item><b>Sitzungsmanagement:</b> Optionale Abmeldung des Benutzers nach Abschluss (z.B. nach Löschung).</item>
/// </list>
/// </para>
/// </summary>
public interface IGuardService
{
    /// <summary>
    /// Führt eine kritische Operation mit automatischem Backup-Schutz und Passwort-Validierung aus.
    /// </summary>
    /// <param name="title">Der Titel für den Passwort-Dialog.</param>
    /// <param name="message">Die Nachricht an den Benutzer, die den Vorgang erklärt.</param>
    /// <param name="operation">Die auszuführende asynchrone Logik. Erhält den validierten Master-Key als Parameter.</param>
    /// <param name="forceLogout">Gibt an, ob nach Abschluss der Sitzungsstatus geleert werden soll.</param>
    /// <param name="overrideSalt">Optional: Ein abweichender Salt (z.B. vom Server beim Adoptieren).</param>
    /// <param name="overrideValidationKey">Optional: Ein abweichender verschlüsselter Key zur Passwort-Prüfung.</param>
    /// <returns><c>true</c>, wenn die Operation erfolgreich und autorisiert ausgeführt wurde; andernfalls <c>false</c>.</returns>
    Task<bool> ExecuteCriticalOperationAsync(string title, string message, Func<byte[], Task> operation, bool forceLogout = false, string? overrideSalt = null, string? overrideValidationKey = null);
}