using Privault.Core.Services.Contracts;

namespace Privault.Core.Services;

/// <inheritdoc cref="IGuardService" />
public class GuardService : IGuardService
{
    // ------------------------------------------------------------------------
    // --- Felder ---
    // ------------------------------------------------------------------------

    private readonly ICryptoService _cryptoService;
    private readonly IDatabaseService _databaseService;
    private readonly ISessionService _sessionService;
    private readonly IUiService _uiService;

    // ------------------------------------------------------------------------
    // --- Konstruktor ---
    // ------------------------------------------------------------------------

    /// <summary>
    /// Initialisiert eine neue Instanz des <see cref="GuardService"/>.
    /// </summary>
    /// <param name="cryptoService">Dienst für die Passwort-Validierung und Key-Ableitung.</param>
    /// <param name="databaseService">Dienst für Backup- und Restore-Operationen.</param>
    /// <param name="sessionService">Dienst für den Zugriff auf Sitzungseinstellungen und Logout.</param>
    /// <param name="uiService">Dienst für die UI-Interaktionen</param>
    /// <exception cref="ArgumentNullException">Wird geworfen, wenn ein Dienst null ist.</exception>
    public GuardService(
        ICryptoService cryptoService,
        IDatabaseService databaseService,
        ISessionService sessionService,
        IUiService uiService)
    {
        _cryptoService = cryptoService ?? throw new ArgumentNullException(nameof(cryptoService));
        _databaseService = databaseService ?? throw new ArgumentNullException(nameof(databaseService));
        _sessionService = sessionService ?? throw new ArgumentNullException(nameof(sessionService));
        _uiService = uiService ?? throw new ArgumentNullException(nameof(uiService));
    }

    // ------------------------------------------------------------------------
    // --- Öffentliche Methoden ---
    // ------------------------------------------------------------------------

    /// <inheritdoc />
    public async Task<bool> ExecuteCriticalOperationAsync(
        string title,
        string message,
        Func<byte[], Task> operation,
        bool forceLogout = false,
        string? overrideSalt = null,
        string? overrideValidationKey = null)
    {
        // 1. Passwort Bestätigung
        var pw = await _uiService.PromptAsync(title, message);
        if (string.IsNullOrWhiteSpace(pw)) return false;

        // 2. Key ableiten & Validieren
        var saltString = overrideSalt ?? _sessionService.Settings?.Salt;
        if (string.IsNullOrEmpty(saltString)) throw new Exception("Kein Salt vorhanden.");
        var salt = Convert.FromBase64String(saltString);

        var masterKey = await _cryptoService.DeriveKeyAsync(pw, salt);

        // Test-Entschlüsselung, um Passwort zu prüfen
        var validationKey = overrideValidationKey ?? _sessionService.Settings?.EncryptedPrivateKey;
        if (string.IsNullOrEmpty(validationKey)) throw new Exception("Kein privater RSA-Schlüssel vorhanden.");

        try
        {
            _cryptoService.Decrypt(validationKey, masterKey);
        }
        catch
        {
            await _uiService.ErrorAsync("Falsches Passwort");
            return false;
        }
        
        // Warum statt Datei-Backup nicht einfach eine Transaktion verwenden?
        // Eine Transaction reicht hier nicht, weil sie diese Operationen nicht absichern kann:
        // - Umbenennen des Tresors (sobald die Verbindung schließt, endet die Transaktion)
        // - Umverschlüsseln des Tresors (mit `PRAGMA rekey`)

        // 3. Backup erstellen
        _databaseService.CreateBackup();

        try
        {
            // 4. Die eigentliche Logik ausführen
            await operation(masterKey);

            // 5. Erfolg: Backup weg
            _databaseService.RemoveBackup();

            if (forceLogout)
            {
                _sessionService.ClearSession();
                await _uiService.NavigateAsync("/login");
            }

            return true;
        }
        catch (Exception ex)
        {
            // 6. Fehler: Restore!
            _databaseService.RestoreBackup();
            await _uiService.ErrorAsync(ex.Message);
            return false;
        }
    }
}