using Privault.Core.Services.Contracts;

namespace Privault.Services;

/// <summary>
/// MAUI-Adapter, der <see cref="Preferences.Default"/> als Key/Value-Store bereitstellt.
/// </summary>
public sealed class MauiKeyValueStore : IKeyValueStore
{
    // ------------------------------------------------------------------------
    // --- Öffentliche Methoden ---
    // ------------------------------------------------------------------------
    
    /// <inheritdoc />
    public string GetString(string key, string defaultValue) => Preferences.Default.Get(key, defaultValue);
    
    /// <inheritdoc />
    public void SetString(string key, string value) => Preferences.Default.Set(key, value);

    /// <inheritdoc />
    public bool GetBool(string key, bool defaultValue) => Preferences.Default.Get(key, defaultValue);
    
    /// <inheritdoc />
    public void SetBool(string key, bool value) => Preferences.Default.Set(key, value);
    
    /// <inheritdoc />
    public int GetInt(string key, int defaultValue) => Preferences.Default.Get(key, defaultValue);
    
    /// <inheritdoc />
    public void SetInt(string key, int value) => Preferences.Default.Set(key, value);
}