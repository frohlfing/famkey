namespace Privault.Core.Models.Results;

/// <summary>
/// Repräsentiert eine vom Nutzer ausgewählte Datei inklusive deren Inhaltsdaten.
/// Wird als Transferobjekt zwischen dem UI-Service und der Business-Logik verwendet.
/// </summary>
public sealed class PickedFileResult
{
    /// <summary>
    /// Der ursprüngliche Name der Datei (z. B. "dokument.pdf").
    /// </summary>
    public required string Filename { get; init; }

    /// <summary>
    /// Der MIME-Typ der Datei (z. B. "application/pdf"), sofern vom System erkannt.
    /// </summary>
    public string Mime { get; init; } = string.Empty;

    /// <summary>
    /// Der binäre Inhalt der Datei.
    /// </summary>
    /// <remarks>
    /// Achtung: Bei sehr großen Dateien sollte dieses Modell mit Bedacht verwendet werden, 
    /// um den Arbeitsspeicher nicht zu überlasten.
    /// </remarks>
    public required byte[] Content { get; init; }
}