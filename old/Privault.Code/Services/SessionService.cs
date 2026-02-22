using Privault.Core.Models.Entities;
using Privault.Core.Services.Contracts;

namespace Privault.Core.Services;

/// <inheritdoc cref="ISessionService" />
public class SessionService : ISessionService
{
    // ------------------------------------------------------------------------
    // --- Felder ---
    // ------------------------------------------------------------------------
    
    private readonly ICryptoService _cryptoService;
    
    // ------------------------------------------------------------------------
    // --- Konstruktor ---
    // ------------------------------------------------------------------------
    
    /// <summary>
    /// Initialisiert eine neue Instanz des <see cref="SessionService"/>.
    /// </summary>
    /// <param name="cryptoService">Wird für das sichere Löschen von Schlüsseln benötigt.</param>
    /// <exception cref="ArgumentNullException">Wird geworfen, wenn <c>cryptoService</c> null ist.</exception>
    public SessionService(ICryptoService cryptoService)
    {
        _cryptoService = cryptoService ?? throw new ArgumentNullException(nameof(cryptoService));
    }
    
    // ------------------------------------------------------------------------
    // --- Eigenschaften ---
    // ------------------------------------------------------------------------
    
    /// <inheritdoc />
    public bool IsLoggedIn => User != null && PrivateKey is { Length: > 0 };
    
    /// <inheritdoc />
    public byte[]? PrivateKey { get; set; }
    
    /// <inheritdoc />
    public SettingsEntity? Settings { get; set; }
    
    /// <inheritdoc />
    public UserEntity? User { get; set; }

    /// <inheritdoc />
    public string VaultName { get; set; } = string.Empty;

    // ------------------------------------------------------------------------
    // --- Öffentliche Methoden ---
    // ------------------------------------------------------------------------
    
    /// <inheritdoc />
    public void ClearSession()
    {
        User = null;
        VaultName =  string.Empty;
        Settings = null;
        if (PrivateKey != null)
        {
            _cryptoService.WipeKey(PrivateKey);
            PrivateKey = null;
        }
    }
}