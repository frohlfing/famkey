using Privault.Core.ViewModels;

namespace Privault.Tests.ViewModels;

/// <summary>
/// Tests für das <see cref="MainGroupViewModel"/>.
/// </summary>
public class MainGroupViewModelTests
{
    // ------------------------------------------------------------------------
    // --- Setup ---
    // ------------------------------------------------------------------------

    /// <summary>
    /// Erstellt eine Liste mit Test-Einträgen.
    /// </summary>
    private List<MainEntryViewModel> CreateTestEntries(int count)
    {
        var list = new List<MainEntryViewModel>();
        for (int i = 0; i < count; i++)
        {
            list.Add(new MainEntryViewModel { Title = $"Eintrag {i}" });
        }
        return list;
    }

    // ------------------------------------------------------------------------
    // --- Tests ---
    // ------------------------------------------------------------------------

    // --- 1. Konstruktor und Initialisierung ---

    /// <summary>
    /// 1.1.1 Initialisierung: Wenn IsExpanded true ist, müssen alle Einträge in der Collection sein.
    /// </summary>
    [Fact]
    public void Constructor_WhenExpanded_ShouldContainAllEntries()
    {
        // Arrange
        var entries = CreateTestEntries(3);

        // Act
        var vm = new MainGroupViewModel("Soziale Medien", entries, true, "Allgemein");

        // Assert
        Assert.Equal(3, vm.Count); // Collection-Inhalt
        Assert.Equal(3, vm.TotalCount); // Eigenschaft TotalCount
        Assert.True(vm.IsExpanded);
    }

    /// <summary>
    /// 1.1.2 Initialisierung: Wenn IsExpanded false ist, muss die Collection leer sein, aber TotalCount stimmen.
    /// </summary>
    [Fact]
    public void Constructor_WhenCollapsed_ShouldBeEmptyButKeepTotalCount()
    {
        // Arrange
        var entries = CreateTestEntries(5);

        // Act
        var vm = new MainGroupViewModel("Banking", entries, false, "Allgemein");

        // Assert
        Assert.Empty(vm); // Die Liste für die UI ist leer (eingeklappt)
        Assert.Equal(5, vm.TotalCount); // Die Metadaten wissen aber noch von den 5 Einträgen
        Assert.False(vm.IsExpanded);
    }

    /// <summary>
    /// 1.2.1 Namenslogik: Wenn kein Name übergeben wird, muss der Fallback-Name verwendet werden.
    /// </summary>
    [Theory]
    [InlineData("", "Standard")]
    [InlineData("  ", "Standard")]
    [InlineData("Kategorie A", "Kategorie A")]
    public void Constructor_NameLogic_ShouldHandleFallbackCorrectly(string inputName, string expectedResult)
    {
        // Act
        var vm = new MainGroupViewModel(inputName, new List<MainEntryViewModel>(), true, "Standard");

        // Assert
        Assert.Equal(expectedResult, vm.Name);
    }

    // --- 2. Visueller Zustand ---

    /// <summary>
    /// 2.1.1 StateIcon: Muss das korrekte Symbol für den Erweiterungszustand liefern.
    /// </summary>
    [Fact]
    public void StateIcon_ShouldReflectExpandedState()
    {
        // Act & Assert (Erweitert)
        var expandedVm = new MainGroupViewModel("Test", new List<MainEntryViewModel>(), true, "Default");
        Assert.Equal("▼", expandedVm.StateIcon);

        // Act & Assert (Eingeklappt)
        var collapsedVm = new MainGroupViewModel("Test", new List<MainEntryViewModel>(), false, "Default");
        Assert.Equal("▶", collapsedVm.StateIcon);
    }
}