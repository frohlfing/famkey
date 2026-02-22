using Privault.Core.Services.Contracts;

namespace Privault.Services;

/// <summary>
/// MAUI-Implementierung für Cache-Operationen über <see cref="FileSystem.CacheDirectory"/>.
/// </summary>
public sealed class MauiCacheService : ICacheService
{
    // ------------------------------------------------------------------------
    // --- Öffentliche Methoden ---
    // ------------------------------------------------------------------------
    
    /// <inheritdoc />
    public Task ClearCacheAsync()
    {
        try
        {
            var cacheDir = FileSystem.CacheDirectory;
            foreach (var file in Directory.GetFiles(cacheDir))
            {
                try { File.Delete(file); }
                catch { /* ignored */ }
            }
        }
        catch
        {
            /* ignored */
        }

        return Task.CompletedTask;
    }
}