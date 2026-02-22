class AttachmentMetaPayload {
  final String filename;
  final String mime;
  final int size;
  final String? thumbnail; // Base64 thumbnail
  final DateTime timestamp;

  AttachmentMetaPayload({
    required this.filename,
    required this.mime,
    required this.size,
    this.thumbnail,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'mime': mime,
      'size': size,
      'thumbnail': thumbnail,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AttachmentMetaPayload.fromJson(Map<String, dynamic> json) {
    return AttachmentMetaPayload(
      filename: json['filename'] as String,
      mime: json['mime'] as String,
      size: json['size'] as int,
      thumbnail: json['thumbnail'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String).toUtc(),
    );
  }
}
