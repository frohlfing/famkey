using Moq;
using Privault.Core.Models.Entities;
using Privault.Core.Services.Contracts;
using Privault.Core.ViewModels;

namespace Privault.Tests.ViewModels;

/// <summary>
/// Tests für das <see cref="MainViewModel"/>.
/// </summary>
public class MainViewModelTests
{
    // ------------------------------------------------------------------------
    // --- Setup ---
    // ------------------------------------------------------------------------

    private readonly Mock<IDatabaseService> _dbMock = new();
    private readonly Mock<ISessionService> _sessionMock = new();
    private readonly Mock<IConfigService> _configMock = new();

    private MainViewModel CreateViewModel()
    {
        return new MainViewModel(
            Mock.Of<ICacheService>(),
            _configMock.Object,
            _dbMock.Object,
            _sessionMock.Object,
            Mock.Of<ISyncService>(),
            Mock.Of<IUiService>());
    }

    // ------------------------------------------------------------------------
    // --- Tests ---
    // ------------------------------------------------------------------------

    // --- 1. Datenladung und Gruppierung ---

    /// <summary>
    /// 1.1.1 ReloadData: Einträge müssen nach Kategorien gruppiert werden.
    /// </summary>
    [Fact]
    public async Task ReloadDataInternal_ShouldGroupByCategory()
    {
        // Arrange
        var vm = CreateViewModel();
        var entries = new List<EntryEntity>
        {
            new() { Title = "A", Category = "Arbeit" },
            new() { Title = "B", Category = "Privat" },
            new() { Title = "C", Category = "Arbeit" }
        };
        _dbMock.Setup(d => d.GetEntriesAsync()).ReturnsAsync(entries);
        _dbMock.Setup(d => d.GetUsersAsync()).ReturnsAsync(new List<UserEntity>());

        // Act
        await vm.ReloadDataCommand.ExecuteAsync(null);

        // Assert
        Assert.Equal(2, vm.GroupedEntries.Count); // Zwei Gruppen: Arbeit und Privat
        var workGroup = vm.GroupedEntries.FirstOrDefault(g => g.Name == "Arbeit");
        Assert.NotNull(workGroup);
        Assert.Equal(2, workGroup.Count);
    }

    // --- 2. Filter-Logik ---

    /// <summary>
    /// 2.1.1 SearchText: Die Liste muss bei Texteingabe gefiltert werden.
    /// </summary>
    [Fact]
    public async Task SearchText_ShouldFilterEntries()
    {
        // Arrange
        var vm = CreateViewModel();
        var entries = new List<EntryEntity>
        {
            new() { Title = "Google", Category = "Web" },
            new() { Title = "Bank", Category = "Finance" }
        };
        _dbMock.Setup(d => d.GetEntriesAsync()).ReturnsAsync(entries);
        _dbMock.Setup(d => d.GetUsersAsync()).ReturnsAsync(new List<UserEntity>());
        await vm.ReloadDataCommand.ExecuteAsync(null);

        // Act
        vm.SearchText = "goog";

        // Assert
        var totalVisible = vm.GroupedEntries.Sum(g => g.Count);
        Assert.Equal(1, totalVisible);
        Assert.Equal("Google", vm.GroupedEntries[0][0].Title);
    }

    /// <summary>
    /// 2.2.1 ShowOnlyMine: Wenn aktiv, dürfen nur eigene Einträge angezeigt werden.
    /// </summary>
    [Fact]
    public async Task ShowOnlyMine_ShouldFilterByCreator()
    {
        // Arrange
        var vm = CreateViewModel();
        var myId = 1;
        _sessionMock.Setup(s => s.User).Returns(new UserEntity { Id = myId });
        
        var entries = new List<EntryEntity>
        {
            new() { Title = "Mein Eintrag", CreatorId = myId },
            new() { Title = "Fremder Eintrag", CreatorId = 99 }
        };
        _dbMock.Setup(d => d.GetEntriesAsync()).ReturnsAsync(entries);
        _dbMock.Setup(d => d.GetUsersAsync()).ReturnsAsync(new List<UserEntity>());
        await vm.ReloadDataCommand.ExecuteAsync(null);

        // Act
        vm.ShowOnlyMine = true;

        // Assert
        var totalVisible = vm.GroupedEntries.Sum(g => g.Count);
        Assert.Equal(1, totalVisible);
        Assert.Equal("Mein Eintrag", vm.GroupedEntries[0][0].Title);
    }
    
    // --- 3. Sitzungsverwaltung ---

    /// <summary>
    /// 3.1.1 Logout: Beim Abmelden müssen DB geschlossen und Cache geleert werden.
    /// </summary>
    [Fact]
    public async Task Logout_ShouldCleanupAllResources()
    {
        // Arrange
        var cacheMock = new Mock<ICacheService>();
        var dbMock = new Mock<IDatabaseService>();
        var sessionMock = new Mock<ISessionService>();
        var uiMock = new Mock<IUiService>();
    
        var vm = new MainViewModel(
            cacheMock.Object, Mock.Of<IConfigService>(), 
            dbMock.Object, sessionMock.Object, Mock.Of<ISyncService>(), uiMock.Object);

        // Act
        await vm.LogoutCommand.ExecuteAsync(null);

        // Assert
        dbMock.Verify(d => d.CloseConnectionAsync(), Times.Once);
        sessionMock.Verify(s => s.ClearSession(), Times.Once);
        cacheMock.Verify(c => c.ClearCacheAsync(), Times.Once);
        uiMock.Verify(u => u.NavigateAsync("/login", null), Times.Once);
    }
}