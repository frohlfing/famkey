using Privault.Core.Services;
using Privault.Core.Services.Contracts;

namespace Privault.Tests.Services;

/// <summary>
/// Tests für den <see cref="ConfigService"/>.
/// </summary>
public class ConfigServiceTests
{
    // ------------------------------------------------------------------------
    // --- Setup ---
    // ------------------------------------------------------------------------

    private sealed class InMemoryStore : IKeyValueStore
    {
        private readonly Dictionary<string, object> _data = new();

        public string GetString(string key, string defaultValue) =>
            _data.TryGetValue(key, out var v) && v is string s ? s : defaultValue;

        public void SetString(string key, string value) => _data[key] = value;

        public bool GetBool(string key, bool defaultValue) =>
            _data.TryGetValue(key, out var v) && v is bool b ? b : defaultValue;

        public void SetBool(string key, bool value) => _data[key] = value;

        public int GetInt(string key, int defaultValue) =>
            _data.TryGetValue(key, out var v) && v is int i ? i : defaultValue;

        public void SetInt(string key, int value) => _data[key] = value;
    }

    // ------------------------------------------------------------------------
    // --- Tests ---
    // ------------------------------------------------------------------------

    /// <summary>
    /// 1.1.1 Defaults: Liefert Defaultwerte, wenn noch nichts gespeichert ist.
    /// </summary>
    [Fact]
    public void Defaults_WhenNothingStored_ShouldReturnDefaults()
    {
        var sut = new ConfigService(new InMemoryStore());

        Assert.Equal(string.Empty, sut.LastVaultName);
        Assert.False(sut.ShowOnlyMine);
        Assert.Equal(string.Empty, sut.Theme);
        Assert.NotNull(sut.Vaults);
        Assert.Empty(sut.Vaults);
    }

    /// <summary>
    /// 1.1.2 Roundtrip: Properties werden korrekt persistiert und wieder geladen.
    /// </summary>
    [Fact]
    public void Roundtrip_WhenSettingValues_ShouldReadBackSameValues()
    {
        var store = new InMemoryStore();
        _ = new ConfigService(store)
        {
            LastVaultName = "VaultX",
            ShowOnlyMine = true,
            Theme = "Modern.Dark",
            Vaults = new Dictionary<string, string>
            {
                ["VaultX"] = "salt-base64-1",
                ["VaultY"] = "salt-base64-2"
            }
        };

        // Neuer Service auf gleichem Store simuliert App-Neustart
        var sut2 = new ConfigService(store);

        Assert.Equal("VaultX", sut2.LastVaultName);
        Assert.True(sut2.ShowOnlyMine);
        Assert.Equal("Modern.Dark", sut2.Theme);

        Assert.Equal(2, sut2.Vaults.Count);
        Assert.Equal("salt-base64-1", sut2.Vaults["VaultX"]);
        Assert.Equal("salt-base64-2", sut2.Vaults["VaultY"]);
    }
}