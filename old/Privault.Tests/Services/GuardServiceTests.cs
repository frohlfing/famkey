using Moq;
using Privault.Core.Models.Entities;
using Privault.Core.Services;
using Privault.Core.Services.Contracts;

namespace Privault.Tests.Services;

/// <summary>
/// Tests für den <see cref="GuardService"/>.
/// </summary>
public class GuardServiceTests
{
    // ------------------------------------------------------------------------
    // --- Setup ---
    // ------------------------------------------------------------------------

    private sealed class Fixture
    {
        public Mock<ICryptoService> Crypto { get; } = new();
        public Mock<IDatabaseService> Db { get; } = new();
        public Mock<ISessionService> Session { get; } = new();
        public Mock<IUiService> Ui { get; } = new();

        public GuardService CreateService() => new(
            Crypto.Object,
            Db.Object,
            Session.Object,
            Ui.Object
        );
    }

    private static SettingsEntity CreateSettings(string saltBase64, string encryptedPrivateKey) => new()
    {
        Salt = saltBase64,
        EncryptedPrivateKey = encryptedPrivateKey
    };

    // ------------------------------------------------------------------------
    // --- Tests ---
    // ------------------------------------------------------------------------

    /// <summary>
    /// 1.1.1 ExecuteCriticalOperationAsync: Abbruch bei leerem Passwort -> false und keine DB-Aktionen.
    /// </summary>
    [Fact]
    public async Task ExecuteCriticalOperationAsync_WhenPasswordIsEmpty_ShouldReturnFalse_AndNotTouchDatabase()
    {
        // Arrange
        var f = new Fixture();
        var sut = f.CreateService();

        f.Ui.Setup(u => u.PromptAsync("T", "M", "Ausführen", "Abbrechen"))
            .ReturnsAsync("   ");

        // Act
        var ok = await sut.ExecuteCriticalOperationAsync("T", "M", _ => Task.CompletedTask);

        // Assert
        Assert.False(ok);
        f.Db.Verify(d => d.CreateBackup(), Times.Never);
        f.Db.Verify(d => d.RemoveBackup(), Times.Never);
        f.Db.Verify(d => d.RestoreBackup(), Times.Never);
        f.Crypto.Verify(c => c.DeriveKeyAsync(It.IsAny<string>(), It.IsAny<byte[]>()), Times.Never);
    }

    /// <summary>
    /// 1.1.2 ExecuteCriticalOperationAsync: Fehlendes Salt -> Exception.
    /// </summary>
    [Fact]
    public async Task ExecuteCriticalOperationAsync_WhenSaltIsMissing_ShouldThrow()
    {
        // Arrange
        var f = new Fixture();
        var sut = f.CreateService();

        f.Ui.Setup(u => u.PromptAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
            .ReturnsAsync("pw");

        f.Session.SetupGet(s => s.Settings).Returns(new SettingsEntity { Salt =  string.Empty, EncryptedPrivateKey = "enc" });

        // Act + Assert
        await Assert.ThrowsAsync<Exception>(() =>
            sut.ExecuteCriticalOperationAsync("T", "M", _ => Task.CompletedTask));
    }

    /// <summary>
    /// 1.1.3 ExecuteCriticalOperationAsync: Falsches Passwort (Decrypt wirft) -> Alert + false, kein Backup.
    /// </summary>
    [Fact]
    public async Task ExecuteCriticalOperationAsync_WhenPasswordIsWrong_ShouldAlertAndReturnFalse()
    {
        // Arrange
        var f = new Fixture();
        var sut = f.CreateService();

        var salt = Convert.ToBase64String(new byte[16]);
        f.Session.SetupGet(s => s.Settings).Returns(CreateSettings(salt, "encPrivKey"));

        f.Ui.Setup(u => u.PromptAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
            .ReturnsAsync("pw");

        var derived = new byte[] { 1, 2, 3, 4 };
        f.Crypto.Setup(c => c.DeriveKeyAsync("pw", It.IsAny<byte[]>()))
            .ReturnsAsync(derived);

        f.Crypto.Setup(c => c.Decrypt("encPrivKey", derived))
            .Throws(new Exception("bad key"));

        // Act
        var ok = await sut.ExecuteCriticalOperationAsync("T", "M", _ => Task.CompletedTask);

        // Assert
        Assert.False(ok);
        f.Ui.Verify(u => u.ErrorAsync("Falsches Passwort"), Times.Once);
        f.Db.Verify(d => d.CreateBackup(), Times.Never);
    }

    /// <summary>
    /// 1.1.4 ExecuteCriticalOperationAsync: Erfolg -> Backup, Operation, RemoveBackup, true.
    /// </summary>
    [Fact]
    public async Task ExecuteCriticalOperationAsync_WhenOperationSucceeds_ShouldRemoveBackupAndReturnTrue()
    {
        // Arrange
        var f = new Fixture();
        var sut = f.CreateService();

        var salt = Convert.ToBase64String(new byte[16]);
        f.Session.SetupGet(s => s.Settings).Returns(CreateSettings(salt, "encPrivKey"));

        f.Ui.Setup(u => u.PromptAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
            .ReturnsAsync("pw");

        var derived = "\t\t\t\t"u8.ToArray();
        f.Crypto.Setup(c => c.DeriveKeyAsync("pw", It.IsAny<byte[]>()))
            .ReturnsAsync(derived);

        f.Crypto.Setup(c => c.Decrypt("encPrivKey", derived))
            .Returns([7, 7]); // “Validierung” erfolgreich

        byte[]? keySeenByOperation = null;

        // Act
        var ok = await sut.ExecuteCriticalOperationAsync("T", "M", key =>
        {
            keySeenByOperation = key;
            return Task.CompletedTask;
        });

        // Assert
        Assert.True(ok);
        Assert.NotNull(keySeenByOperation);
        Assert.True(keySeenByOperation!.SequenceEqual(derived));

        f.Db.Verify(d => d.CreateBackup(), Times.Once);
        f.Db.Verify(d => d.RemoveBackup(), Times.Once);
        f.Db.Verify(d => d.RestoreBackup(), Times.Never);
        f.Ui.Verify(u => u.AlertAsync(It.IsAny<string>(), It.IsAny<string>()), Times.Never);
    }

    /// <summary>
    /// 1.1.5 ExecuteCriticalOperationAsync: Exception in Operation -> RestoreBackup + Alert + false.
    /// </summary>
    [Fact]
    public async Task ExecuteCriticalOperationAsync_WhenOperationThrows_ShouldRestoreBackupAndReturnFalse()
    {
        // Arrange
        var f = new Fixture();
        var sut = f.CreateService();

        var salt = Convert.ToBase64String(new byte[16]);
        f.Session.SetupGet(s => s.Settings).Returns(CreateSettings(salt, "encPrivKey"));

        f.Ui.Setup(u => u.PromptAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
            .ReturnsAsync("pw");

        var derived = new byte[] { 1, 2, 3, 4 };
        f.Crypto.Setup(c => c.DeriveKeyAsync("pw", It.IsAny<byte[]>()))
            .ReturnsAsync(derived);

        f.Crypto.Setup(c => c.Decrypt("encPrivKey", derived))
            .Returns([0xAA]);

        // Act
        var ok = await sut.ExecuteCriticalOperationAsync("T", "M", _ =>
            throw new InvalidOperationException("boom"));

        // Assert
        Assert.False(ok);
        f.Db.Verify(d => d.CreateBackup(), Times.Once);
        f.Db.Verify(d => d.RestoreBackup(), Times.Once);
        f.Db.Verify(d => d.RemoveBackup(), Times.Never);
        f.Ui.Verify(u => u.ErrorAsync("boom"), Times.Once);
    }

    /// <summary>
    /// 1.1.6 ExecuteCriticalOperationAsync: forceLogout -> ClearSession + Navigation nach Erfolg.
    /// </summary>
    [Fact]
    public async Task ExecuteCriticalOperationAsync_WhenForceLogout_ShouldClearSessionAndNavigate()
    {
        // Arrange
        var f = new Fixture();
        var sut = f.CreateService();

        var salt = Convert.ToBase64String(new byte[16]);
        f.Session.SetupGet(s => s.Settings).Returns(CreateSettings(salt, "encPrivKey"));

        f.Ui.Setup(u => u.PromptAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
            .ReturnsAsync("pw");

        var derived = new byte[] { 5, 5, 5, 5 };
        f.Crypto.Setup(c => c.DeriveKeyAsync("pw", It.IsAny<byte[]>()))
            .ReturnsAsync(derived);

        f.Crypto.Setup(c => c.Decrypt("encPrivKey", derived))
            .Returns([0xBB]);

        // Act
        var ok = await sut.ExecuteCriticalOperationAsync("T", "M", _ => Task.CompletedTask, forceLogout: true);

        // Assert
        Assert.True(ok);
        f.Session.Verify(s => s.ClearSession(), Times.Once);
        f.Ui.Verify(u => u.NavigateAsync("/login", null), Times.Once);
    }
}