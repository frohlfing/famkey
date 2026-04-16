import 'dart:typed_data';
import 'renderer.dart';
import 'renderers/fallback_renderer.dart';
import 'renderers/html_renderer.dart';
import 'renderers/image_renderer.dart';
import 'renderers/markdown_renderer.dart';
import 'renderers/pdf_renderer.dart';
import 'renderers/text_renderer.dart';

/// Erstellt einen passenden [Renderer] anhand des MIME-Typs.
Renderer createRenderer(Uint8List? bytes, String mime) {
  final parts = mime.split('/');
  final type = parts.isNotEmpty ? parts.first : '';
  final subtype = parts.length > 1 ? parts.last : '';

  // @formatter:off
  switch (type) {
    // Bild
    case 'image': return ImageRenderer(bytes);

    // Text
    case 'text':
      switch (subtype) {
        case 'markdown': return MarkdownRenderer(bytes);
        case 'html': return HtmlRenderer(bytes);
        //case 'csv': return CsvRenderer(bytes);
        //case 'vcard': return VcardRenderer(bytes);
        default: return TextRenderer(bytes); // plain
      }

    // // Audio
    // case 'audio': return AudioRenderer(bytes);

    // // Video
    // case 'video': return VideoRenderer(bytes);

    case 'application':
      switch (subtype) {
        // PDF
        case 'pdf': return PdfRenderer(bytes);

        // // Word
        // case 'msword':
        // case 'vnd.openxmlformats-officedocument.wordprocessingml.document': return WordRenderer(bytes);

        // // Excel
        // case 'vnd.ms-excel':
        // case 'vnd.openxmlformats-officedocument.spreadsheetml.sheet': return ExcelRenderer(bytes);

        // // Powerpoint
        // case 'vnd.ms-powerpoint':
        // case 'application/vnd.openxmlformats-officedocument.presentationml.presentation': return PowerpointRenderer(bytes);

        // // Archiv
        // case 'zip':
        // case 'vnd.rar':
        // case 'x-tar':
        // case 'x-7z-compressed': return ArchivRenderer(bytes);

        // JSON
        // case 'json': return JsonRenderer(bytes);
      }
  }

  // Fallback
  return FallbackRenderer();
  // @formatter:on
}