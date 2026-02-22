using Privault.Core.Services.Contracts;
using SkiaSharp;

namespace Privault.Services;

/// <summary>
/// MAUI-Implementierung für Thumbnail-Erzeugung über SkiaSharp.
/// </summary>
public sealed class MauiThumbnailService : IThumbnailService
{
    // ------------------------------------------------------------------------
    // --- Öffentliche Methoden ---
    // ------------------------------------------------------------------------
    
    /// <inheritdoc />
    public string? TryCreateThumbnailBase64(string fileName, byte[] content, int width, int height)
    {
        if (content.Length == 0) 
            return null;
        
        if (string.IsNullOrWhiteSpace(fileName)) 
            return null;

        var fnLower = fileName.ToLowerInvariant();
        var isImage =
            fnLower.EndsWith(".png") ||
            fnLower.EndsWith(".jpg") ||
            fnLower.EndsWith(".jpeg") ||
            fnLower.EndsWith(".gif") ||
            fnLower.EndsWith(".bmp") ||
            fnLower.EndsWith(".webp");

        if (!isImage) 
            return null;

        try
        {
            // 1) Decode
            using var src = SKBitmap.Decode(content);
            if (src == null || src.Width <= 0 || src.Height <= 0)
                return null;

            // 2) Aspect-Fit berechnen
            var scale = Math.Min((double)width / src.Width, (double)height / src.Height);
            var newW = Math.Max(1, (int)Math.Round(src.Width * scale));
            var newH = Math.Max(1, (int)Math.Round(src.Height * scale));

            // 3) Resize
            //using var resized = src.Resize(new SKImageInfo(newW, newH), new SKSamplingOptions(SKCubicResampler.Mitchell)); // SKFilterQuality.High
            using var resized = src.Resize(
                new SKImageInfo(newW, newH),
                new SKSamplingOptions(SKFilterMode.Linear, SKMipmapMode.Linear)); // SKFilterQuality.Medium
            if (resized == null)
                return null;

            // 4) Encode
            using var img = SKImage.FromBitmap(resized);
            using var encoded = img.Encode(SKEncodedImageFormat.Jpeg, 80); // oder Png
            return Convert.ToBase64String(encoded.ToArray());
        }
        catch
        {
            // Stiller Catch-Block für robuste Bildverarbeitung bei korrupten Dateien.
            return null;
        }
    }
}