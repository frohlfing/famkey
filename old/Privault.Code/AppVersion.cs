using System.Reflection;

namespace Privault.Core;

/// <summary>
/// Stellt Versionsinformationen der Anwendung bereit.
/// </summary>
/// <remarks>
/// Diese Klasse ermöglicht den Zugriff auf die Versionsnummer der Anwendung (Major, Minor, Patch)
/// sowie auf die minimal erforderliche Server-Version. Die Versionsinformationen werden aus den
/// Assembly-Metadaten extrahiert und lazy-initialisiert.
/// </remarks>
public static class AppVersion
{
    // ------------------------------------------------------------------------
    // --- Eigenschaften ---
    // ------------------------------------------------------------------------

    /// <summary>
    /// Major-Version der App.
    /// </summary>
    /// <remarks>
    /// Wird nach einem Redesign oder bei einem Migrations-Bruch erhöht.
    /// </remarks>
    public static int Major => Version.Value.Major;

    /// <summary>
    /// Minor-Version der App.
    /// </summary>
    /// <remarks>
    /// Wird nach Änderung der Funktionalität erhöht. Wird auf 0 zurückgesetzt, wenn MAJOR erhöht wird.
    /// </remarks>
    public static int Minor => Version.Value.Minor;

    /// <summary>
    /// Patch-Version der App.
    /// </summary>
    /// <remarks>
    /// Wird nach einer Fehlerbehebung (Bugfix) erhöht. Wird auf 0 zurückgesetzt, wenn MAJOR oder MINOR erhöht wird.
    /// </remarks>
    public static int Patch => Version.Value.Build >= 0 ? Version.Value.Build : 0;

    /// <summary>
    /// Minimal erforderliche Server-Minor-Version.
    /// </summary>
    public static int RequiredServerMinor => RequiredServerMinorAttribute.Value;
    
    // ------------------------------------------------------------------------
    // --- Private Eigenschaften ---
    // ------------------------------------------------------------------------

    /// <summary>
    /// Ermöglicht den Zugriff auf die Assembly, die die Kernanwendungslogik enthält.
    /// </summary>
    /// <remarks>
    /// Diese Eigenschaft verweist auf die Assembly, in der die Klasse <c>AppVersion</c> definiert ist.
    /// Sie wird verwendet, um Metadaten auf Assembly-Ebene zu extrahieren, wie z.B. Versionsinformationen und benutzerdefinierte Attribute.
    /// </remarks>
    private static Assembly CoreAssembly => typeof(AppVersion).Assembly;
    
    /// <summary>
    /// Liest die System-Version aus den Assembly-Metadaten und bereinigt sie.
    /// </summary>
    /// <remarks>
    /// Lazy-initialisierte Versionsinformation der Anwendung, extrahiert aus dem <see cref="AssemblyInformationalVersionAttribute"/>.
    /// </remarks>
    private static readonly Lazy<Version> Version = new(() =>
    {
        var info = CoreAssembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion ?? "0.0.0";

        // SemVer: "1.2.3-rc.1+meta" -> "1.2.3"
        var clean = info.Split('-', '+')[0];
        
        // Robust: kein Throw bei kaputter Version, sondern Fallback
        return System.Version.TryParse(clean, out var parsed) ? parsed : new Version(0, 0, 0);
    });
    
    /// <summary>
    /// Liest die minimal erforderliche Server-Minor-Version aus den Assembly-Metadaten.
    /// </summary>
    /// <remarks>
    /// Lazy-initialisierter Wert, der aus dem <see cref="AssemblyMetadataAttribute"/> mit dem Schlüssel "RequiredServerMinor" extrahiert wird.
    /// </remarks>
    private static readonly Lazy<int> RequiredServerMinorAttribute = new(() =>
    {
        var attribute = CoreAssembly.GetCustomAttributes<AssemblyMetadataAttribute>()
            .FirstOrDefault(a => a.Key == "RequiredServerMinor");
        var value = attribute?.Value;
        return value != null && int.TryParse(value, out var parsed) ? parsed : 0;
    });
}