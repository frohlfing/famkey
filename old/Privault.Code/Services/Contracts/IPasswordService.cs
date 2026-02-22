namespace Privault.Core.Services.Contracts;

/// <summary>
/// Dienst für die Generierung und Bewertung von Passwörtern.
/// </summary>
public interface IPasswordService
{
    /// <summary>
    /// Bewertet die Stärke eines Passworts.
    /// </summary>
    /// <param name="password">Das zu prüfende Passwort.</param>
    /// <returns>Ein Score von 0 (sehr schwach) bis 4 (sehr stark).</returns>
    int EstimateStrength(string password);

    /// <summary>
    /// Generiert ein kryptografisch sicheres Zufallspasswort.
    /// </summary>
    /// <param name="length">Die gewünschte Länge.</param>
    /// <param name="avoidIlO0">Ob ähnliche Zeichen (I, l, O, 0) vermieden werden sollen.</param>
    /// <param name="specialChars">Der Satz an erlaubten Sonderzeichen (null = empfohlene Auswahl)</param>
    /// <returns>Das generierte Passwort.</returns>
    string GeneratePassword(int length, bool avoidIlO0 = true, string? specialChars = null);
}