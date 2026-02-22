namespace Privault.Core.Services.Contracts;

/// <summary>
/// Abstraktion für Cache-/Temp-Datei-Operationen, die plattformabhängig sind.
/// </summary>
/// <remarks>
/// Die Implementierung ist plattformabhängig (MAUI/Web).
/// </remarks>
public interface ICacheService
{
    /// <summary>
    /// Löscht alle Dateien im Cache-Ordner (best effort).
    /// </summary>
    Task ClearCacheAsync();
}