using System.Text.Json;
using Privault.Core.Services.Contracts;

namespace Privault.Core.Services;

/// <inheritdoc cref="IConfigService" />
public class ConfigService : IConfigService
{
    // ------------------------------------------------------------------------
    // --- Felder ---
    // ------------------------------------------------------------------------
    
    private const string KeyLastVaultName = "last_vault_name";
    private const string KeyShowOnlyMine = "show_only_mine";
    private const string KeyTheme = "theme";
    private const string KeyVaults = "vaults";
    private readonly IKeyValueStore _store;

    // ------------------------------------------------------------------------
    // --- Konstruktor ---
    // ------------------------------------------------------------------------
    
    /// <summary>
    /// Initialisiert eine neue Instanz des <see cref="ConfigService"/>.
    /// </summary>
    /// <param name="store">Key/Value-Store.</param>
    /// <exception cref="ArgumentNullException">Wird geworfen, wenn <c>store</c> null ist.</exception>
    public ConfigService(IKeyValueStore store)
    {
        _store = store ?? throw new ArgumentNullException(nameof(store));
    }

    // ------------------------------------------------------------------------
    // --- Eigenschaften ---
    // ------------------------------------------------------------------------

    /// <inheritdoc />
    public string LastVaultName
    {
        get => _store.GetString(KeyLastVaultName, string.Empty);
        set => _store.SetString(KeyLastVaultName, value);
    }

    /// <inheritdoc />
    public bool ShowOnlyMine
    {
        get => _store.GetBool(KeyShowOnlyMine, false);
        set => _store.SetBool(KeyShowOnlyMine, value);
    }

    /// <inheritdoc />
    public string Theme
    {
        get => _store.GetString(KeyTheme, string.Empty);
        set => _store.SetString(KeyTheme, value);
    }

    /// <inheritdoc />
    public Dictionary<string, string> Vaults
    {
        get => JsonSerializer.Deserialize<Dictionary<string, string>>(_store.GetString(KeyVaults, "{}")) ?? new Dictionary<string, string>();
        set => _store.SetString(KeyVaults, JsonSerializer.Serialize(value));
    }
}