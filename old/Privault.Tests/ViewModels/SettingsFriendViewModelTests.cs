using Moq;
using Privault.Core.Models.Entities;
using Privault.Core.Services.Contracts;
using Privault.Core.ViewModels;

namespace Privault.Tests.ViewModels;

/// <summary>
/// Tests für das <see cref="SettingsFriendViewModel"/>.
/// </summary>
public class SettingsFriendViewModelTests
{
    /// <summary>
    /// 1.1.1 Fingerprint: Der Fingerprint muss über den CryptoService berechnet werden.
    /// </summary>
    [Fact]
    public void Fingerprint_ShouldCallCryptoService()
    {
        // Arrange
        var cryptoMock = new Mock<ICryptoService>();
        cryptoMock.Setup(c => c.Fingerprint("KEY-DATA")).Returns("SHA-ABC-123");
        
        var vm = new SettingsFriendViewModel(cryptoMock.Object, Mock.Of<IDatabaseService>())
        {
            User = new UserEntity { PublicKey = "KEY-DATA" }
        };

        // Act
        var result = vm.Fingerprint;

        // Assert
        Assert.Equal("SHA-ABC-123", result);
        cryptoMock.Verify(c => c.Fingerprint("KEY-DATA"), Times.Once);
    }
}