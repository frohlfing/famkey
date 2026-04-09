import 'dart:convert';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Sammlung von Hilfsfunktionen für die UI.

/// Ermittelt den MIME-Typ basierend auf der Dateiendung.
String getMimeType(String filename) {
  // @formatter:off
  final ext = filename.split('.').last.toLowerCase();
  switch (ext) {
    case 'jpg': return 'image/jpeg';
    case 'jpeg': return 'image/jpeg';
    case 'png': return 'image/png';
    case 'gif': return 'image/gif';
    case 'bmp': return 'image/bmp';
    case 'webp': return 'image/webp';
    case 'pdf': return 'application/pdf';
    case 'doc': return 'application/msword';
    case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'ppt': return 'application/vnd.ms-powerpoint';
    case 'pptx': return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    case 'xls': return 'application/vnd.ms-excel';
    case 'xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'csv': return 'text/csv';
    case 'vcf': return 'text/vcard';
    case 'mp3': return 'audio/mpeg';
    case 'wav': return 'audio/wav';
    case 'flac': return 'audio/flac';
    case 'aac': return 'audio/aac';
    case 'ogg': return 'audio/ogg';
    case 'mp4': return 'video/mp4';
    case 'avi': return 'video/x-msvideo';
    case 'mov': return 'video/quicktime';
    case 'mkv': return 'video/x-matroska';
    case 'webm': return 'video/webm';
    case 'zip': return 'application/zip';
    case 'rar': return 'application/vnd.rar';
    case 'tar': return 'application/x-tar';
    case '7z': return 'application/x-7z-compressed';
    case 'txt': return 'text/plain';
    case 'md': return 'text/markdown';
    default: return 'application/octet-stream';
  }
  // @formatter:on
}

/// Ermittelt den Datei-Typ basierend auf der Dateiendung oder des MIME-Typs.
String getIconType(String filename, String mimeType) {
  final file = filename.toLowerCase();
  if (file.endsWith(".png") || file.endsWith(".jpg") || file.endsWith(".jpeg") || file.endsWith(".gif") || file.endsWith(".bmp") || file.endsWith(".webp")) return "image";
  if (file.endsWith(".pdf")) return "pdf";
  if (file.endsWith(".doc") || file.endsWith(".docx")) return "word";
  if (file.endsWith(".ppt") || file.endsWith(".pptx")) return "slides";
  if (file.endsWith(".xls") || file.endsWith(".xlsx") || file.endsWith(".csv")) return "excel";
  if (file.endsWith(".vcf")) return "vcard";
  if (file.endsWith(".mp3") || file.endsWith(".wav") || file.endsWith(".flac") || file.endsWith(".aac") || file.endsWith(".ogg")) return "audio";
  if (file.endsWith(".mp4") || file.endsWith(".avi") || file.endsWith(".mov") || file.endsWith(".mkv") || file.endsWith(".webm")) return "video";
  if (file.endsWith(".zip") || file.endsWith(".rar") || file.endsWith(".tar") || file.endsWith(".7z")) return "archive";
  if (file.endsWith(".txt") || file.endsWith(".md")) return "text";

  final mime = mimeType.toLowerCase();
  if (mime.startsWith("image/")) return "image";
  if (mime.contains("pdf")) return "pdf";
  if (mime.contains("word") || mime.contains("msword") || mime.contains("doc")) return "word";
  if (mime.contains("presentation") || mime.contains("powerpoint") || mime.contains("ppt")) return "slides";
  if (mime.contains("excel") || mime.contains("sheet") || mime.contains("xls")) return "excel";
  if (mime.contains("vcard") || mime.contains("contact")) return "vcard";
  if (mime.contains("audio")) return "audio";
  if (mime.contains("video")) return "video";
  if (mime.contains("zip") || mime.contains("rar") || mime.contains("7z") || mime.contains("tar")) return "archive";
  if (mime.contains("text")) return "text";

  return "generic";
}

/// Mappt einen Dateityp oder eine Dateiendung auf ein passendes Icon.
///
/// Dies sorgt für eine visuelle Unterscheidung zwischen verschiedenen Anhangs-Typen
/// wie Bildern, PDFs, Dokumenten oder Archiven.
IconData getIconForType(String type) {
  // @formatter:off
  switch (type) {
    case 'image': return Icons.image_outlined;
    case 'pdf':  return Icons.picture_as_pdf_outlined;
    case 'word': return Icons.description_outlined;
    case 'slides': return Icons.present_to_all_outlined;
    case 'excel': return Icons.table_chart_outlined;
    case 'vcard': return Icons.contact_page_outlined;
    case 'archive': return Icons.inventory_2_outlined;
    case 'video': return Icons.movie_outlined;
    case 'audio': return Icons.audiotrack_outlined;
    case 'text': return Icons.text_snippet_outlined;
    default: return Icons.insert_drive_file_outlined;
  }
  // @formatter:on
}

/// Lädt das Favicon einer Website über den Google-Dienst (Base64).
Future<String?> downloadFavicon(String url) async {
  try {
    final Dio dio = Dio();
    final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    final faviconUrl = 'https://www.google.com/s2/favicons?domain=${uri.host}&sz=64';
    final response = await dio.get<List<int>>(faviconUrl, options: Options(responseType: ResponseType.bytes));
    if (response.data != null) return base64.encode(response.data!);
  } catch (_) {}
  return null;
}

/// Hilfsfunktion zum Rendern des Webseiten-Icons (Favicon).
///
/// Versucht das in der Datenbank hinterlegte Base64-Bild anzuzeigen.
/// Falls kein Bild vorhanden ist oder die Daten beschädigt sind, wird
/// ein dezentes Standard-Icon als Platzhalter genutzt.
Widget buildFavicon(String base64) {
  if (base64.isEmpty) {
    return const Icon(Icons.lock_outlined, color: Colors.blueGrey);
  }
  try {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.memory(
        base64Decode(base64),
        width: 32,
        height: 32,
        errorBuilder: (ctx, err, stack) => const Icon(Icons.lock_outlined),
      ),
    );
  } catch (_) {
    return const Icon(Icons.lock_outlined);
  }
}

/// Formatiert Byte-Größen in lesbare Einheiten (KB, MB, GB).
String formatSize(int bytes) {
  const scale = 1024;
  const orders = ["B", "KB", "MB", "GB"];
  double size = bytes.toDouble();
  int order = 0;
  while (size >= scale && order < orders.length - 1) {
    order++;
    size /= scale;
  }
  return "${size.toStringAsFixed(2)} ${orders[order]}";
}

/// Erzeugt eine Thumbnail (Base64)
Future<String?> createThumbnail(Uint8List bytes) async {
  // compute lagert eine Berechnung in einen separaten Worker-Thread aus.
  // Die Worker-Funktion darf keine Instanz-Methode einer Klasse sein (static würde gehen),
  // sonst wird versucht, die gesamte Instanz in den Thread zu kopieren, was schief geht.
  return compute(_createThumbnailWorker, bytes);
}

/// Worker-Funktion zum Erzeugen einer Thumbnail (Base64).
/// Die Funktion wird innerhalb eines Threads aufgerufen.
String? _createThumbnailWorker(Uint8List bytes) {
  try {
    // 1. Image dekodieren
    final image = img.decodeImage(bytes);
    if (image == null || image.width <= 0 || image.height <= 0) return null;

    const maxWidth = 128;
    const maxHeight = 128;

    // 2. Aspect-Fit berechnen
    final scale = math.min(maxWidth / image.width, maxHeight / image.height);
    final newW = math.max(1, (image.width * scale).round());
    final newH = math.max(1, (image.height * scale).round());

    // 3. Resize auf exakte Zielgröße (verhindert Trauerränder)
    final thumbnail = img.copyResize(image, width: newW, height: newH, interpolation: img.Interpolation.linear);

    // 4. Encode mit 80% Qualität
    return base64Encode(img.encodeJpg(thumbnail, quality: 80));
  } catch (e) {
    // In statischen Methoden können wir kein logError() der Instanz rufen!
    // Wir loggen hier nur auf die Konsole oder geben null zurück.
    debugPrint('Thumbnail-Fehler: $e');
    return null;
  }
}