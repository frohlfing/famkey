import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:privault/core/service_locator.dart';
import '../services/session_service.dart';

/// Sammlung von Hilfsfunktionen für die UI.

/// Lädt das Favicon einer Website über den Google-Dienst und gibt es als Base64-String zurück.
///
/// ## CORS (Cross-Origin Resource Sharing)
/// Browser blockieren direkte Anfragen an fremde Domains, sofern der Zielserver keinen `Access-Control-Allow-Origin`-Header setzt.
/// Google setzen diesen Header nicht. Für die Web-Appliance wird daher der eigene Sync-Server als Proxy verwendet:
/// Er ruft das Favicon serverseitig ab und leitet es mit korrektem CORS-Header zurück an den Client.
/// Auf nativen Plattformen entfällt dieser Umweg (kein CORS auf nativem Code).
Future<String?> downloadFavicon(String url) async {
  final domain = Uri.parse(url.startsWith('http') ? url : 'https://$url').host;
  if (domain.isEmpty) return null;

  String faviconUrl;
  if (kIsWeb) {
    // Sync-Server als CORS-Proxy verwenden.
    final sessionService = getIt<SessionService>();
    final host = sessionService.settings?.host ?? ''; // enthält die API-URL (z.B. "https://privault.test/api")
    final apiUrl = host.endsWith('/') ? host.substring(0, host.length - 1) : host; // Slash am Ende entfernen, falls vorhanden
    final baseUrl = apiUrl.endsWith('/api') ? apiUrl.substring(0, apiUrl.length - 4) : 'https://privault.frank-rohlfing.de'; // "/api"-Suffix entfernen.
    faviconUrl = '$baseUrl/favicons.php?domain=$domain';
  } else {
    // Nativ: direkt ohne Proxy
    faviconUrl = 'https://www.google.com/s2/favicons?domain=$domain&sz=64';
  }

  final dio = Dio();

  try {
    final response = await dio.get<List<int>>(faviconUrl, options: Options(responseType: ResponseType.bytes));
    if (response.data != null && response.data!.isNotEmpty) {
      return base64.encode(response.data!);
    }
  } catch (_) {}

  return null;
}

/// Formatiert Byte-Größen in lesbare Einheiten (KB, MB, GB).
String formatSize(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  double size = bytes.toDouble();
  int unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    unit++;
    size /= 1024;
  }
  return '${size.toStringAsFixed(2)} ${units[unit]}';
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

/// Bereinigt einen Dateinamen von illegalen Zeichen.
/// Ersetzt Zeichen wie < > : " / \ | ? * und Steuerzeichen durch einen Unterstrich.
String sanitizeFilename(String input, {String replacement = '_'}) {
  // Liste der illegalen Zeichen:
  // / \ : * ? " < > |  sowie Steuerzeichen (ASCII 0-31)
  final illegalChars = RegExp(r'[<>:"/\\|?*\x00-\x1F]');
  String sanitized = input.replaceAll(illegalChars, replacement).trim();
  if (sanitized.length > 255) {
    sanitized = sanitized.substring(0, 255);
  }
  return sanitized;
}