using Privault.Core.Models.Entities;

namespace Privault.Core.Models.Payloads;

/// <summary>
/// Repräsentiert die verschlüsselten Metadaten eines Dateianhangs (<see cref="AttachmentEntity"/>).
/// </summary>
public class AttachmentMetaPayload
{
    /// <summary>
    /// Der ursprüngliche Dateiname (z. B. "Urlaubsfoto.jpg").
    /// </summary>
    public string Filename { get; init; } = string.Empty;
    
    /// <summary>
    /// Der Internet Media Type der Datei (z. B. "image/jpeg").
    /// </summary>
    public string Mime { get; init; } = "application/octet-stream";
    
    /// <summary>
    /// Die Größe der unverschlüsselten Datei in Bytes.
    /// </summary>
    public long Size { get; init; }
    
    /// <summary>
    /// Der binäre Dateninhalt eines verkleinerten Vorschaubildes als Base64-String.
    /// </summary>
    public string Thumbnail { get; init; } = string.Empty;
    
    private readonly DateTime _timestamp = DateTime.SpecifyKind(new DateTime(1970, 1, 1), DateTimeKind.Utc);

    /// <summary>
    /// Zeitstempel der Datei (UTC).
    /// </summary>
    public DateTime Timestamp
    {
        get => _timestamp;
        init => _timestamp = value.Kind == DateTimeKind.Unspecified ? DateTime.SpecifyKind(value, DateTimeKind.Utc) : value.ToUniversalTime();
    }
}