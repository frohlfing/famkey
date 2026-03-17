import 'package:flutter/material.dart';

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
