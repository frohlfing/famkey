namespace Privault.Core.Services.Contracts;

/// <summary>
/// Abstraktion über einen persistenten Key/Value-Store.
/// </summary>
/// <remarks>
/// Die Implementierung ist plattformabhängig (MAUI/Web).
/// </remarks>
public interface IKeyValueStore
{
    /// <summary>
    /// Liest einen String-Wert aus dem Store.
    /// </summary>
    /// <param name="key">Der eindeutige Schlüssel des Eintrags.</param>
    /// <param name="defaultValue">Rückgabewert, falls der Schlüssel nicht existiert.</param>
    /// <returns>Der gespeicherte Wert oder <paramref name="defaultValue"/>, wenn nicht vorhanden.</returns>
    string GetString(string key, string defaultValue);

    /// <summary>
    /// Speichert einen String-Wert im Store (überschreibt bei gleichem Schlüssel den bestehenden Wert).
    /// </summary>
    /// <param name="key">Der eindeutige Schlüssel des Eintrags.</param>
    /// <param name="value">Der zu speichernde Wert.</param>
    void SetString(string key, string value);

    /// <summary>
    /// Liest einen Bool-Wert aus dem Store.
    /// </summary>
    /// <param name="key">Der eindeutige Schlüssel des Eintrags.</param>
    /// <param name="defaultValue">Rückgabewert, falls der Schlüssel nicht existiert.</param>
    /// <returns>Der gespeicherte Wert oder <paramref name="defaultValue"/>, wenn nicht vorhanden.</returns>
    bool GetBool(string key, bool defaultValue);

    /// <summary>
    /// Speichert einen Bool-Wert im Store (überschreibt bei gleichem Schlüssel den bestehenden Wert).
    /// </summary>
    /// <param name="key">Der eindeutige Schlüssel des Eintrags.</param>
    /// <param name="value">Der zu speichernde Wert.</param>
    void SetBool(string key, bool value);

    /// <summary>
    /// Liest einen Integer-Wert aus dem Store.
    /// </summary>
    /// <param name="key">Der eindeutige Schlüssel des Eintrags.</param>
    /// <param name="defaultValue">Rückgabewert, falls der Schlüssel nicht existiert.</param>
    /// <returns>Der gespeicherte Wert oder <paramref name="defaultValue"/>, wenn nicht vorhanden.</returns>
    int GetInt(string key, int defaultValue);

    /// <summary>
    /// Speichert einen Integer-Wert im Store (überschreibt bei gleichem Schlüssel den bestehenden Wert).
    /// </summary>
    /// <param name="key">Der eindeutige Schlüssel des Eintrags.</param>
    /// <param name="value">Der zu speichernde Wert.</param>
    void SetInt(string key, int value);
}