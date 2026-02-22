using Moq;
using Privault.Core.Models.Entities;
using Privault.Core.Services.Contracts;
using Privault.Core.ViewModels;
using System.Text;

namespace Privault.Tests.ViewModels;

/// <summary>
/// Tests für das <see cref="DetailViewModel"/>.
/// </summary>
public class DetailViewModelTests
{
    // ------------------------------------------------------------------------
    // --- Setup ---
    // ------------------------------------------------------------------------

    private readonly Mock<ICryptoService> _cryptoMock = new();
    private readonly Mock<IDatabaseService> _dbMock = new();
    private readonly Mock<IPasswordService> _pwMock = new();
    private readonly Mock<ISessionService> _sessionMock = new();
    private readonly Mock<IThumbnailService> _thumbMock = new();
    private readonly Mock<IUiService> _uiMock = new();

    private DetailViewModel CreateViewModel()
    {
        return new DetailViewModel(
            _cryptoMock.Object,
            _dbMock.Object,
            _pwMock.Object,
            _sessionMock.Object,
            _thumbMock.Object,
            _uiMock.Object);
    }

    // ------------------------------------------------------------------------
    // --- Tests ---
    // ------------------------------------------------------------------------

    // --- 1. Laden und Entschlüsseln ---

    /// <summary>
    /// 1.1.1 LoadEntry: Bestehender Eintrag muss entschlüsselt und in der UI angezeigt werden.
    /// </summary>
    [Fact]
    public async Task LoadEntry_ShouldDecryptPayload()
    {
        // Arrange
        var vm = CreateViewModel();
        var entryId = 42;
        var myId = 1;
        var entryKey = new byte[32];
        
        // Korrektur zu Fehler 1: Explizite Array-Initialisierung statt [...]
        var entry = new EntryEntity 
        { 
            Id = entryId, 
            CreatorId = myId, 
            EncryptedData = "123" 
        };
        var perm = new PermissionEntity { EntryId = entryId, UserId = myId, AccessLevel = 3, EncryptedKey = "abc" };
        var payloadJson = "{\"Title\":\"Geheim\",\"Password\":\"Pass123\"}";

        _sessionMock.Setup(s => s.User).Returns(new UserEntity { Id = myId });
        _sessionMock.Setup(s => s.PrivateKey).Returns([9, 8, 7]);
        _dbMock.Setup(d => d.GetEntryAsync(entryId)).ReturnsAsync(entry);
        _dbMock.Setup(d => d.GetPermissionByEntryIdAndUserIdAsync(entryId, myId)).ReturnsAsync(perm);
        
        // Korrektur zu Fehler 2: Zweiter Parameter muss byte[] sein (It.IsAny<byte[]>)
        _cryptoMock.Setup(c => c.DecryptRsa(It.IsAny<string>(), It.IsAny<byte[]>())).Returns(entryKey);
        _cryptoMock.Setup(c => c.Decrypt(entry.EncryptedData, entryKey)).Returns(Encoding.UTF8.GetBytes(payloadJson));

        // Act
        var query = new Dictionary<string, object> { { "id", entryId.ToString() } };
        vm.InitializeCommand.Execute(query);
        
        await Task.Delay(50); 

        // Assert
        Assert.Equal("Geheim", vm.Title);
        Assert.Equal("Pass123", vm.Password);
        Assert.True(vm.HasFullAccess);
    }

    // --- 2. Speichern ---

    /// <summary>
    /// 2.1.1 Save: Ein neuer Eintrag muss verschlüsselt und in der DB gespeichert werden.
    /// </summary>
    [Fact]
    public async Task Save_NewEntry_ShouldEncryptAndInvokeDb()
    {
        // Arrange
        var vm = CreateViewModel();
        vm.Title = "Neu";
        vm.Password = "Safe";
    
        // Wir müssen sicherstellen, dass der Session-User eine ID und einen Public Key hat
        _sessionMock.Setup(s => s.User).Returns(new UserEntity { Id = 1, PublicKey = "pub" });

        // Act 
        await vm.SaveCommand.ExecuteAsync(null);

        // Assert
        // 1. Prüfen, ob verschlüsselt wurde
        _cryptoMock.Verify(c => c.Encrypt(It.IsAny<byte[]>(), It.IsAny<byte[]>()), Times.AtLeastOnce);

        // 2. Verifizieren der NEUEN Transaktions-Methode
        _dbMock.Verify(d => d.SaveEntryWithPermissionsAsync(It.IsAny<EntryEntity>(), It.IsAny<int>(),It.IsAny<string>(),3), Times.Once);
    
        // Optional: Sicherstellen, dass die ALTE Methode NICHT mehr gerufen wird
        _dbMock.Verify(d => d.SaveEntryAsync(It.IsAny<EntryEntity>()), Times.Never);
    }

    // --- 3. Passwort-Generator ---

    /// <summary>
    /// 3.1.1 GeneratePassword: Muss den PasswordService aufrufen und die UI aktualisieren.
    /// </summary>
    [Fact]
    public void GeneratePassword_ShouldCallService()
    {
        // Arrange
        var vm = CreateViewModel();
        _pwMock.Setup(p => p.GeneratePassword(It.IsAny<int>(), It.IsAny<bool>(), It.IsAny<string>()))
               .Returns("Generated123!");

        // Act
        vm.GeneratePasswordCommand.Execute(null);

        // Assert
        Assert.Equal("Generated123!", vm.Password);
    }
}