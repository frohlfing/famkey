using System.Diagnostics.CodeAnalysis;
using Moq;
using Privault.Core.Models.Entities;
using Privault.Core.Models.DTOs;
using Privault.Core.Services.Contracts;
using Privault.Core.ViewModels;

namespace Privault.Tests.ViewModels;

/// <summary>
/// Tests für das <see cref="SettingsViewModel"/>.
/// </summary>
public class SettingsViewModelTests
{
    // ------------------------------------------------------------------------
    // --- Setup ---
    // ------------------------------------------------------------------------

    private readonly Mock<IBiometricService> _bioMock = new();
    private readonly Mock<IConfigService> _configMock = new();
    private readonly Mock<ICryptoService> _cryptoMock = new();
    private readonly Mock<IDatabaseService> _dbMock = new();
    private readonly Mock<IGuardService> _guardMock = new();
    private readonly Mock<ISessionService> _sessionMock = new();
    private readonly Mock<IUiService> _uiMock = new();
    private readonly Mock<IWebService> _webMock = new();

    /// <summary>
    /// Hilfsmethode zum Erstellen des ViewModels.
    /// Erlaubt optional die Übergabe von vordefinierten Einstellungen für den DB-Mock.
    /// </summary>
    private SettingsViewModel CreateViewModel(SettingsEntity? settingsFromDb = null)
    {
        // Mock-Verhalten für Properties aktivieren
        _sessionMock.SetupAllProperties();
        
        // Grundlegende Session-Daten
        var session = _sessionMock.Object;
        session.User = new UserEntity { Id = 1, Name = "User", Uuid = "my-uuid" };
        session.VaultName = "OldVault";
        session.Settings = new SettingsEntity { Salt = "salt" };
        session.PrivateKey = new byte[32];

        // Config-Mock initialisieren (verhindert NullReferenceException in Maps)
        _configMock.Setup(c => c.Vaults).Returns(new Dictionary<string, string>());
        _configMock.Setup(c => c.Theme).Returns("Modern.Light");

        // DB-Mock: Wenn keine Settings übergeben wurden, eine leere Standard-Instanz liefern.
        _dbMock.Setup(d => d.GetSettingsAsync()).ReturnsAsync(settingsFromDb ?? new SettingsEntity());
        _dbMock.Setup(d => d.GetUsersAsync()).ReturnsAsync(new List<UserEntity>());

        _uiMock.Setup(u => u.GetThemeKinds()).Returns(new List<string> { "Modern", "Classic" });
        _uiMock.Setup(u => u.GetThemeModes()).Returns(new List<string> { "System", "Light", "Dark" });
        
        var vm = new SettingsViewModel(
            _bioMock.Object,
            _configMock.Object, 
            _cryptoMock.Object, 
            _dbMock.Object,
            _guardMock.Object, 
            _uiMock.Object, 
            _sessionMock.Object, 
            _webMock.Object);
        
        // vm.ThemeKind = "Modern";
        // vm.ThemeMode = "Light";
        vm.InitializeCommand.Execute(null);
        return vm;
    }

    // ------------------------------------------------------------------------
    // --- Tests ---
    // ------------------------------------------------------------------------

    // --- 1. Initialisierung ---

    /// <summary>
    /// 1.1.1 LoadSettings: Werte müssen korrekt aus der DB geladen werden.
    /// </summary>
    [Fact]
    public async Task LoadSettings_ShouldFillProperties()
    {
        // Arrange
        var expectedHost = "https://my.api";
        var settingsFromDb = new SettingsEntity { Host = expectedHost, PwLength = 32 };

        // Act: Wir übergeben die gewünschten Settings direkt an die Hilfsmethode
        var vm = CreateViewModel(settingsFromDb);
        
        // Da LoadSettingsAsync im Konstruktor via fire-and-forget läuft,
        // warten wir, bis die Eigenschaft 'Host' den erwarteten Wert annimmt.
        int retry = 0;
        while (vm.Host != expectedHost && retry < 20)
        {
            await Task.Delay(50);
            retry++;
        }

        // Assert
        Assert.Equal(expectedHost, vm.Host);
        Assert.Equal(32, vm.PwLength);
    }

    // --- 2. Freundesverwaltung ---

    /// <summary>
    /// 2.1.1 AddFriend: Erfolgreiche Suche und Speicherung.
    /// </summary>
    [Fact]
    public async Task AddFriend_WhenFoundOnWeb_ShouldSaveToDb()
    {
        // Arrange
        var vm = CreateViewModel();
        _uiMock.Setup(u => u.PromptAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
               .ReturnsAsync("Alice");
        
        _webMock.Setup(w => w.FindUserAsync(It.IsAny<string>(), "Alice"))
            .ReturnsAsync(new UserResponse { UserUuid = "uuid-123", PublicKey = "pub-key" });

        // Act
        await vm.AddFriendCommand.ExecuteAsync(null);

        // Assert
        _dbMock.Verify(d => d.SaveUserAsync(It.Is<UserEntity>(u => u.Name == "Alice")), Times.Once);
    }

    // --- 3. Tresor-Operationen ---

    /// <summary>
    /// 3.1.1 Save: Namensänderung triggert korrekte Service-Aufrufe.
    /// </summary>
    [Fact]
    public async Task Save_WhenVaultNameChanged_ShouldRenameDatabase()
    {
        // Arrange
        var vm = CreateViewModel();
        
        // Kurz warten, damit die Initialisierung aus dem Konstruktor durch ist
        await Task.Delay(100); 
        
        vm.VaultName = "NewVaultName";
        _dbMock.Setup(d => d.DatabaseExists("NewVaultName")).Returns(false);

        _guardMock.Setup(g => g.ExecuteCriticalOperationAsync(
                It.IsAny<string>(), It.IsAny<string>(), It.IsAny<Func<byte[], Task>>(), 
                It.IsAny<bool>(), It.IsAny<string>(), It.IsAny<string>()))
            .Returns<string, string, Func<byte[], Task>, bool, string, string>([SuppressMessage("ReSharper", "UnusedParameter.Local")] async (t, m, action, l, s, k) => 
            {
                await action(new byte[32]);
                return true;
            });

        // Act
        await vm.SaveCommand.ExecuteAsync(null);

        // Assert
        _dbMock.Verify(d => d.RenameDatabase("OldVault", "NewVaultName"), Times.Once);
        _configMock.VerifySet(c => c.LastVaultName = "NewVaultName", Times.Once);
    }

    /// <summary>
    /// 3.2.1 Cancel: Dirty-Check soll bei Änderungen Speichern-Dialog anzeigen.
    /// </summary>
    [Fact]
    public async Task Cancel_WhenDirty_ShouldPromptForSave()
    {
        // Arrange
        var vm = CreateViewModel();
        await Task.Delay(100); // Initialisierung abwarten
        
        // Act: Wert ändern (Dirty machen)
        vm.Host = "https://changed.api";
        
        await vm.CancelCommand.ExecuteAsync(null);

        // Assert: ConfirmAsync muss aufgerufen worden sein
        _uiMock.Verify(u => u.ConfirmAsync(
            It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()), 
            Times.Once);
    }
}