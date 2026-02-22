namespace Privault.Core.Services.Contracts;

/// <summary>
/// Erzeugt Thumbnails für (Bild-)Dateien. 
/// </summary>
/// <remarks>
/// Die Implementierung ist plattformabhängig (MAUI/Web).
/// </remarks>
public interface IThumbnailService
{
    /// <summary>
    /// Erzeugt ein verkleinertes Vorschaubild (Thumbnail) aus den übergebenen Bilddaten.
    /// </summary>
    /// <param name="fileName">Dateiname.</param>
    /// <param name="content">Die unverschlüsselten Original-Bilddaten.</param>
    /// <param name="width">Breite des Thumbnails in Pixel.</param>
    /// <param name="height">Höhe des Thumbnails in Pixel.</param>
    /// <returns>Das verkleinerte Bild als Byte-Array (JPEG) oder null bei Fehlern.</returns>
    string? TryCreateThumbnailBase64(string fileName, byte[] content, int width, int height);
}