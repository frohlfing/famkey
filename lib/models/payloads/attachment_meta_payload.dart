/// Repräsentiert die verschlüsselten Metadaten eines Dateianhangs.
/// Dieses Objekt wird als JSON serialisiert und anschließend mittels AES-256-GCM verschlüsselt
/// in der Spalte `encryptedMeta` der `AttachmentEntity` gespeichert.
class AttachmentMetaPayload {
  /// Der ursprüngliche Dateiname (z. B. "Urlaubsfoto.jpg").
  final String filename;

  /// Der Internet Media Type der Datei (z. B. "image/jpeg").
  final String mime;

  /// Die Größe der unverschlüsselten Datei in Bytes.
  final int size;

  /// Der binäre Dateninhalt eines verkleinerten Vorschaubildes als Base64-String (null, wenn die Datei kein Bild ist).
  final String? thumbnail;

  /// Zeitstempel der Datei (UTC).
  final DateTime timestamp;

  /// Konstruktor
  AttachmentMetaPayload({
    required this.filename,
    required this.mime,
    required this.size,
    this.thumbnail, // null, wenn die Datei kein Bild ist
    required this.timestamp
  });

  /// Erstellt eine [AttachmentMetaPayload] aus einer JSON-Map.
  factory AttachmentMetaPayload.fromJson(Map<String, dynamic> json) {
    return AttachmentMetaPayload(
      filename: json['filename'] as String,
      mime: json['mime'] as String,
      size: json['size'] as int,
      thumbnail: json['thumbnail'] as String?,
      timestamp: DateTime.tryParse(json['timestamp'] ?? '')?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true), // Fallback: 1970‑01‑01 00:00:00 UTC
    );
  }

  /// Konvertiert eine [AttachmentMetaPayload] in eine Map für die JSON-Serialisierung.
  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'mime': mime,
      'size': size,
      'thumbnail': thumbnail,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
