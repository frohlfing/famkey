using Moq;
using Privault.Core.Models.Entities;
using Privault.Core.Services.Contracts;
using Privault.Core.ViewModels;

namespace Privault.Tests.ViewModels;

/// <summary>
/// Tests für das <see cref="LoginViewModel"/>.
/// </summary>
public class LoginViewModelTests
{
    // ------------------------------------------------------------------------
    // --- Setup ---
    // ------------------------------------------------------------------------

    private readonly Mock<IBiometricService> _bioMock = new();
    private readonly Mock<IConfigService> _configMock = new();
    private readonly Mock<ICryptoService> _cryptoMock = new();
    private readonly Mock<IDatabaseService> _databaseMock = new();
    private readonly Mock<ISessionService> _sessionMock = new();
    private readonly Mock<IUiService> _uiMock = new();
        
    private LoginViewModel CreateViewModel()
    {
        return new LoginViewModel(
            _bioMock.Object,
            _configMock.Object,
            _cryptoMock.Object,
            _databaseMock.Object,
            _sessionMock.Object,
            _uiMock.Object);
    }

    // ------------------------------------------------------------------------
    // --- Tests ---
    // ------------------------------------------------------------------------

    // --- 1. Validierung und UI-Logik ---

    /// <summary>
    /// 1.1.1 OnVaultNameChanged: Ungültige Zeichen im Tresornamen müssen ersetzt werden.
    /// </summary>
    [Fact]
    public void OnVaultNameChanged_ShouldSanitizeInvalidCharacters()
    {
        var vm = CreateViewModel();
        vm.VaultName = "Mein/Tresor?"; // '/' und '?' sind oft ungültig
        Assert.Equal("Mein_Tresor_", vm.VaultName);
    }

    /// <summary>
    /// 1.2.1 CanLogin: Login-Befehl darf nur bei vollständig ausgefüllten Feldern ausführbar sein.
    /// </summary>
    [Fact]
    public void CanLogin_WhenFieldsEmpty_ShouldReturnFalse()
    {
        var vm = CreateViewModel();
        vm.VaultName = "";
        vm.Password = "";
        Assert.False(vm.LoginCommand.CanExecute(null));
        
        vm.VaultName = "Test";
        vm.Password = "Pass";
        Assert.True(vm.LoginCommand.CanExecute(null));
    }

    // --- 2. Login-Prozess ---

    /// <summary>
    /// 2.1.1 LoginAsync: Wenn der Tresor existiert, muss versucht werden, ihn zu öffnen.
    /// </summary>
    [Fact]
    public async Task LoginAsync_WithExistingVault_ShouldOpenDatabase()
    {
        // Arrange
        var vm = CreateViewModel();
        vm.VaultName = "Safe";
        vm.Password = "Secret";
        vm.IsExists = true;
        
        var saltBase64 = Convert.ToBase64String(new byte[16]);
        _configMock.Setup(c => c.Vaults).Returns(new Dictionary<string, string> { { "Safe", saltBase64 } });
        _cryptoMock.Setup(c => c.DeriveKeyAsync(It.IsAny<string>(), It.IsAny<byte[]>())).ReturnsAsync(new byte[32]);
        
        _databaseMock.Setup(d => d.GetUserAsync(1)).ReturnsAsync(new UserEntity { Id = 1 });
        _databaseMock.Setup(d => d.GetSettingsAsync()).ReturnsAsync(new SettingsEntity { EncryptedPrivateKey = "key" });

        // Act
        await vm.LoginCommand.ExecuteAsync(null);

        // Assert
        _databaseMock.Verify(d => d.InitializeAsync("Safe", It.IsAny<byte[]>()), Times.Once);
        _uiMock.Verify(u => u.NavigateAsync("/main", null), Times.Once);
    }

    /// <summary>
    /// 2.2.1 LoginAsync: Falsches Passwort führt zu einer Fehlermeldung.
    /// </summary>
    [Fact]
    public async Task LoginAsync_WithWrongPassword_ShouldSetErrorMessage()
    {
        // Arrange
        var vm = CreateViewModel();
        vm.VaultName = "Safe";
        vm.Password = "Wrong";
        vm.IsExists = true;
        
        _configMock.Setup(c => c.Vaults).Returns(new Dictionary<string, string> { { "Safe", "salt" } });
        _databaseMock.Setup(d => d.InitializeAsync(It.IsAny<string>(), It.IsAny<byte[]>()))
            .ThrowsAsync(new Exception("file is not a database"));

        // Act
        await vm.LoginCommand.ExecuteAsync(null); 

        // Assert
        _uiMock.Verify(u => u.ErrorAsync("Falsches Master-Passwort."), Times.Once);
    }
    
    /// <summary>
    /// 2.3.1 LoginAsync: Wenn der Tresor nicht existiert, wird nach Bestätigung ein neuer Tresor angelegt.
    /// </summary>
    [Fact]
    public async Task LoginAsync_WithNonExistingVault_ShouldCreateVault()
    {
        // Arrange
        var vm = CreateViewModel();
        vm.VaultName = "NewVault";
        vm.Password = "NewPassword";

        // Tresor existiert nicht, Vaults-Property für Get/Set mocken
        _configMock.SetupProperty(c => c.Vaults, new Dictionary<string, string>());

        // User bestätigt die Erstellung
        _uiMock.Setup(u => u.ConfirmAsync(
                "Tresor anlegen",
                $"Der Tresor '{vm.VaultName}' existiert auf diesem Gerät noch nicht.\nMöchtest du ihn anlegen?",
                "Ja, anlegen",
                "Nein, abbrechen"))
            .ReturnsAsync(true);

        var salt = new byte[16];
        var masterKey = new byte[32];
        var privateKey = new byte[32];
        _cryptoMock.Setup(c => c.GenerateSalt()).Returns(salt);
        _cryptoMock.Setup(c => c.DeriveKeyAsync(vm.Password, salt)).ReturnsAsync(masterKey);
        _cryptoMock.Setup(c => c.GenerateRsaKeyPair()).Returns(("public", privateKey));
        _cryptoMock.Setup(c => c.Encrypt(privateKey, masterKey)).Returns("encrypted");
        
        // Properties für Session und Config mocken, um Werte zu speichern und zu prüfen
        _sessionMock.SetupAllProperties();
        _configMock.SetupProperty(c => c.LastVaultName);

        // Act
        await vm.LoginCommand.ExecuteAsync(null);

        // Assert
        _uiMock.Verify(u => u.ConfirmAsync(
            "Tresor anlegen",
            $"Der Tresor '{vm.VaultName}' existiert auf diesem Gerät noch nicht.\nMöchtest du ihn anlegen?",
            "Ja, anlegen",
            "Nein, abbrechen"), Times.Once);
        _databaseMock.Verify(d => d.InitializeAsync(vm.VaultName, masterKey), Times.Once);
        _databaseMock.Verify(d => d.SaveUserAsync(It.IsAny<UserEntity>()), Times.Once);
        _databaseMock.Verify(d => d.SaveSettingsAsync(It.IsAny<SettingsEntity>()), Times.Once);
        Assert.Contains(vm.VaultName, _configMock.Object.Vaults.Keys);
        Assert.Equal(vm.VaultName, _configMock.Object.LastVaultName);
        Assert.NotNull(_sessionMock.Object.User);
        _cryptoMock.Verify(c => c.WipeKey(masterKey), Times.Once);
        _uiMock.Verify(u => u.NavigateAsync("/main", null), Times.Once);
    }
}