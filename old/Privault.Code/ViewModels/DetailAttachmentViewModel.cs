using CommunityToolkit.Mvvm.ComponentModel;
using Privault.Core.Models.Entities;

// ReSharper disable UnusedAutoPropertyAccessor.Global

namespace Privault.Core.ViewModels;

/// <summary>
/// Das <see cref="DetailAttachmentViewModel"/> repräsentiert einen einzelnen Dateianhang eines Tresoreintrags.
/// Es bereitet Metadaten wie Dateigröße und MIME-Typ für die UI auf und verwaltet die Logik für Vorschaubilder oder Icons.
/// </summary>
public class DetailAttachmentViewModel : ObservableObject
{
    // ------------------------------------------------------------------------
    // --- Eigenschaften ---
    // ------------------------------------------------------------------------

    /// <summary>
    /// Die zugrundeliegende Anhang-Entität.
    /// Muss im Objekt-Initialisierer gesetzt werden (<c>new DetailAttachmentViewModel {Attachment = a})</c>).
    /// </summary>
    public AttachmentEntity Attachment { get; init; } = null!;

    // --- Entschlüsselte Metadaten ---
    
    // Da sie in der Liste nur angezeigt werden, reichen einfache { get; init; }.

    /// <summary>
    /// Der ursprüngliche Dateiname (z.B. "dokument.pdf").
    /// </summary>
    public string Filename { get; init; } = string.Empty;
    
    /// <summary>
    /// Der Internet Media Type (MIME) der Datei (z.B. "application/pdf").
    /// </summary>
    public string Mime { get; init; } = string.Empty;
    
    /// <summary>
    /// Die Dateigröße in Bytes.
    /// </summary>
    public long Size { get; init; }
    
    /// <summary>
    /// Optionales Vorschaubild als Base64-String (typischerweise bei Bildern).
    /// </summary>
    public string? ThumbnailBase64 { get; init; }
    
    /// <summary>
    /// Zeitpunkt der Erstellung oder des letzten Uploads.
    /// </summary>
    public DateTime Timestamp { get; init; }

    // --- Berechnete Eigenschaften für die View ---
    
    /// <summary>
    /// UI-neutraler Datei-Typ für ein Icon.
    /// </summary>
    public string IconType => GetIconType();

    /// <summary>
    /// Gibt an, ob ein Thumbnail vorhanden ist.
    /// </summary>
    public bool HasThumbnail => !string.IsNullOrWhiteSpace(ThumbnailBase64);

    /// <summary>
    /// Liefert eine Unterzeile für die Liste (z.B. "image/jpeg • 1.24 MB").
    /// </summary>
    public string Subtitle => $"• {Mime} \n• {FormatSize(Size)}";

    // ------------------------------------------------------------------------
    // --- Private Methoden ---
    // ------------------------------------------------------------------------
    
    /// <summary>
    /// Formatiert eine Byte-Anzahl in eine menschenlesbare Zeichenfolge mit Einheit.
    /// </summary>
    /// <param name="bytes">Die Größe in Bytes.</param>
    /// <returns>Formatiert als "X.XX KB", "X.XX MB", etc.</returns>
    private static string FormatSize(long bytes)
    {
        const int scale = 1024;
        string[] orders = [ "B", "KB", "MB", "GB" ];
        double max = bytes;
        int order = 0;
        while (max >= scale && order < orders.Length - 1)
        {
            order++;
            max = max / scale;
        }
        //return string.Format(System.Globalization.CultureInfo.InvariantCulture, "{0:0.##} {1}", max, orders[order]);
        return $"{max:0.##} {orders[order]}";
    }
    
    /// <summary>
    /// Ermittelt den Datei-Typ basierend auf Dateiendung oder MIME-Typ.
    /// <para>
    /// Folgende Typen sind definiert: <c>image</c>, <c>pdf</c>, <c>word</c>, <c>slides</c>, <c>excel</c>, <c>vcar</c>,
    /// <c>audio</c>, <c>video</c>, <c>archive</c>, <c>text</c> und als Fallback <c>generic</c>
    /// </para>
    /// </summary>
    /// <returns>Der Datei-Typ.</returns>
    private string GetIconType()
    {
        var file = Filename.ToLowerInvariant();
        if (file.EndsWith(".png") || file.EndsWith(".jpg") || file.EndsWith(".jpeg") || file.EndsWith(".gif") || file.EndsWith(".bmp") || file.EndsWith(".webp")) return "image";
        if (file.EndsWith(".pdf")) return "pdf";
        if (file.EndsWith(".doc") || file.EndsWith(".docx")) return "word";
        if (file.EndsWith(".ppt") || file.EndsWith(".pptx")) return "slides";
        if (file.EndsWith(".xls") || file.EndsWith(".xlsx") || file.EndsWith(".csv")) return "excel";
        if (file.EndsWith(".vcf")) return "vcard";
        if (file.EndsWith(".mp3") || file.EndsWith(".wav") || file.EndsWith(".flac") || file.EndsWith(".aac") || file.EndsWith(".ogg")) return "audio";
        if (file.EndsWith(".mp4") || file.EndsWith(".avi") || file.EndsWith(".mov") || file.EndsWith(".mkv") || file.EndsWith(".webm")) return "video";
        if (file.EndsWith(".zip") || file.EndsWith(".rar") || file.EndsWith(".tar") || file.EndsWith(".7z")) return "archive";
        if (file.EndsWith(".txt") || file.EndsWith(".md")) return "text";

        var mime = Mime.ToLowerInvariant();
        if (mime.StartsWith("image/")) return "image";
        if (mime.Contains("pdf")) return "pdf";
        if (mime.Contains("word") || mime.Contains("msword") || mime.Contains("doc")) return "word";
        if (mime.Contains("presentation") || mime.Contains("powerpoint") || mime.Contains("ppt")) return "slides";
        if (mime.Contains("excel") || mime.Contains("sheet") || mime.Contains("xls")) return "excel";
        if (mime.Contains("vcard") || mime.Contains("contact")) return "vcard";
        if (mime.Contains("audio")) return "audio";
        if (mime.Contains("video")) return "video";
        if (mime.Contains("zip") || mime.Contains("rar") || mime.Contains("7z") || mime.Contains("tar")) return "archive";
        if (mime.Contains("text")) return "text";
        return "generic";
    }
}