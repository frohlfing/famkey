using Moq;
using Privault.Core.Models.Entities;
using Privault.Core.Services;
using Privault.Core.Services.Contracts;

namespace Privault.Tests.Services;

/// <summary>
/// Tests für den <see cref="SessionService"/>.
/// </summary>
public class SessionServiceTests
{
    // ------------------------------------------------------------------------
    // --- Setup ---
    // ------------------------------------------------------------------------
    
    /// <summary>
    /// Erstellt eine Instanz des SessionService mit einem gemockten CryptoService.
    /// </summary>
    private (SessionService service, Mock<ICryptoService> cryptoMock) CreateService()
    {
        var cryptoMock = new Mock<ICryptoService>();
        var service = new SessionService(cryptoMock.Object);
        return (service, cryptoMock);
    }

    // ------------------------------------------------------------------------
    // --- Tests ---
    // ------------------------------------------------------------------------

    // --- 1. Eigenschaften ---

    /// <summary>
    /// 1.1.1 IsLoggedIn: Ist true, wenn der User angemeldet ist.
    /// </summary>
    [Fact]
    public void IsLoggedIn_WhenUserAndKeyAreSet_ShouldReturnTrue()
    {
        var (service, _) = CreateService();
        service.User = new UserEntity { Name = "Frank" };
        service.PrivateKey = [1, 2, 3];
        Assert.True(service.IsLoggedIn);
    }
    
    /// <summary>
    /// 1.1.2 IsLoggedIn: Ist false, wenn kein User gesetzt ist.
    /// </summary>
    [Fact]
    public void IsLoggedIn_WhenUserMissing_ShouldReturnFalse()
    {
        var (service, _) = CreateService();
        service.PrivateKey = [1, 2, 3];
        service.User = null;
        Assert.False(service.IsLoggedIn);
    }

    /// <summary>
    /// 1.1.3 IsLoggedIn: Ist false, wenn der PrivateKey leer ist.
    /// </summary>
    [Fact]
    public void IsLoggedIn_WhenKeyEmpty_ShouldReturnFalse()
    {
        var (service, _) = CreateService();
        service.User = new UserEntity { Name = "Frank" };
        service.PrivateKey = [];
        Assert.False(service.IsLoggedIn);
    }
    
    // --- 2. Methoden ---
    
    /// <summary>
    /// 2.1.1 ClearSession: Sensible Daten werden beim Logout physisch aus dem RAM gelöscht.
    /// </summary>
    [Fact]
    public void ClearSession_ShouldInvokeWipeKeyOnPrivateKey()
    {
        var (service, cryptoMock) = CreateService();
        var secret = new byte[] { 0xAA, 0xBB, 0xCC };
        service.PrivateKey = secret;
        service.ClearSession();
        cryptoMock.Verify(c => c.WipeKey(secret), Times.Once);
        Assert.Null(service.PrivateKey);
    }
    
    /// <summary>
    /// 2.1.2 ClearSession: Sitzung wird vollständig Zurückgesetzt.
    /// </summary>
    [Fact]
    public void ClearSession_WhenCalled_ShouldNullifyAllProperties()
    {
        var (service, _) = CreateService();
        service.User = new UserEntity { Name = "Frank" };
        service.PrivateKey = [1, 2, 3];
        service.VaultName = "MyVault";
        service.ClearSession();
        Assert.Null(service.User);
        Assert.Null(service.PrivateKey);
        Assert.Equal(string.Empty, service.VaultName);
        Assert.False(service.IsLoggedIn);
    }
}