using Privault.Core.ViewModels;

namespace Privault.Tests.ViewModels;

/// <summary>
/// Tests für das <see cref="DetailAttachmentViewModel"/>.
/// </summary>
public class DetailAttachmentViewModelTests
{
    /// <summary>
    /// 1.1.1 SizeFormatting: Die Dateigröße muss korrekt formatiert werden.
    /// </summary>
    [Fact]
    public void SizeFormatting_ShouldBeCorrect()
    {
        var vm = new DetailAttachmentViewModel { Size = 1024 * 1024 + 524288 }; // 1.5 MB
        Assert.Equal("1.5 MB", vm.Subtitle.Split('•')[1].Trim().Replace(",", "."));
    }

    /// <summary>
    /// 1.2.1 IconKey: Der Icon-Key muss basierend auf der Dateiendung korrekt ermittelt werden.
    /// </summary>
    [Theory]
    [InlineData("test.pdf", "pdf")]
    [InlineData("bild.jpg", "image")]
    [InlineData("tabelle.xlsx", "excel")]
    [InlineData("unbekannt.xyz", "generic")]
    public void IconKey_ShouldMatchExtension(string filename, string expectedKey)
    {
        var vm = new DetailAttachmentViewModel { Filename = filename };
        Assert.Equal(expectedKey, vm.IconType);
    }
}