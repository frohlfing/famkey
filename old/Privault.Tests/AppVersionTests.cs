using System.Reflection;
using Privault.Core;

namespace Privault.Tests;

public class AppVersionTests
{
    // ------------------------------------------------------------------------
    // --- Test ---
    // ------------------------------------------------------------------------

    /// <summary>
    /// 1.1.1 Version: Liest die App-Version korrekt aus.
    /// </summary>
    [Fact]
    public void VersionParts_AreReadFrom_PrivaultCoreAssembly()
    {
        // Arrange
        var coreAssembly = typeof(AppVersion).Assembly;

        var info =
            coreAssembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
            ?? "0.0.0";

        // SemVer: "1.2.3-rc.1+meta" -> "1.2.3"
        var clean = info.Split('-', '+')[0];

        var expected = Version.TryParse(clean, out var parsed)
            ? parsed
            : new Version(0, 0, 0);

        var expectedPatch = expected.Build >= 0 ? expected.Build : 0;

        // Act + Assert
        Assert.Equal(expected.Major, AppVersion.Major);
        Assert.Equal(expected.Minor, AppVersion.Minor);
        Assert.Equal(expectedPatch, AppVersion.Patch);
    }

    /// <summary>
    /// 1.1.1 RequiredServerMinor: Liest die minimal erforderliche Servers-Minor-Version korrekt aus.
    /// </summary>
    [Fact]
    public void RequiredServerMinor_IsReadFrom_AssemblyMetadata()
    {
        // Arrange
        var coreAssembly = typeof(AppVersion).Assembly;

        var value = coreAssembly
            .GetCustomAttributes<AssemblyMetadataAttribute>()
            .FirstOrDefault(a => a.Key == "RequiredServerMinor")
            ?.Value;

        var expected = value is not null && int.TryParse(value, out var v) ? v : 0;

        // Act + Assert
        Assert.Equal(expected, AppVersion.RequiredServerMinor);
    }
}