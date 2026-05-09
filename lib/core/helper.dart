import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' show parse;
import 'package:image/image.dart' as img;
import 'package:famkey/core/service_locator.dart';
import '../services/session_service.dart';

/// Sammlung von Hilfsfunktionen für die UI.

/// Lädt das Favicon einer Website über den Google-Dienst und gibt es als Base64-String zurück.
///
/// ## CORS (Cross-Origin Resource Sharing)
/// Browser blockieren direkte Anfragen an fremde Domains, sofern der Zielserver keinen `Access-Control-Allow-Origin`-Header setzt.
/// Google setzen diesen Header nicht. Für die Web-Appliance wird daher der eigene Sync-Server als Proxy verwendet:
/// Er ruft das Favicon serverseitig ab und leitet es mit korrektem CORS-Header zurück an den Client.
/// Auf nativen Plattformen entfällt dieser Umweg (kein CORS auf nativem Code).
// Future<String?> downloadFavicon(String url) async {
//   final domain = Uri.parse(url.startsWith('http') ? url : 'https://$url').host;
//   if (domain.isEmpty) return null;
//
//   String faviconUrl;
//   if (kIsWeb) {
//     // Sync-Server als CORS-Proxy verwenden.
//     final sessionService = getIt<SessionService>();
//     final host = sessionService.settings?.host ?? 'https://famkey.de'; // ist bereits normalisiert (ohne Slash am Ende)
//     faviconUrl = '$host/favicons.php?domain=$domain';
//   } else {
//     // Nativ: direkt ohne Proxy
//     faviconUrl = 'https://www.google.com/s2/favicons?domain=$domain&sz=64';
//   }
//
//   final dio = Dio();
//
//   try {
//     final response = await dio.get<List<int>>(faviconUrl, options: Options(responseType: ResponseType.bytes));
//     if (response.data != null && response.data!.isNotEmpty) {
//       return base64.encode(response.data!);
//     }
//   } catch (_) {}
//
//   return null;
// }

Future<String?> downloadFavicon(String url) async {
  final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
  final domain = uri.host;
  if (domain.isEmpty) return null;

  if (kIsWeb) { // Web-Appliance
    // CORS-Proxy verwenden, um auf den Google-Service zuzugreifen (Browser blockiert direkte Cross-Origin-Anfragen).
    final sessionService = getIt<SessionService>();
    final host = sessionService.settings?.host ?? 'https://famkey.de'; // ist bereits normalisiert (ohne Slash am Ende)
    return await _getFavicon('$host/favicons.php?domain=$domain');
  }

  // Nativ (Android oder Windows):
  // 1. Versuch: Google-Service (schnell und oft erfolgreich)
  var icon = await _getFavicon('https://www.google.com/s2/favicons?domain=$domain&sz=64');

  // 2. Versuch, falls Google die Webseite nicht gecrawlt hat: URL des Favicons aus der HTML-Seite parsen
  icon ??= await _getFaviconFromHtml(uri);

  // 3. Letzter Versuch: Standardpfad /favicon.ico
  //icon ??= await _getFavicon('${uri.scheme}://$domain/favicon.ico');

  return icon;
}

/// Lädt das Favicon einer Website und gibt es als Base64-String zurück.
Future<String?> _getFavicon(String url) async {
  final dio = Dio();
  try {
    final response = await dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
    if (response.data != null && response.data!.isNotEmpty) {
      return base64.encode(response.data!);
    }
  } catch (_) {}
  return null;
}

/// Versucht die HTML-Seite zu laden und nach <link rel="icon"> zu suchen.
Future<String?> _getFaviconFromHtml(Uri originalUri) async {
  final dio = Dio();
  try {
    // Kurzes Timeout, damit die UI nicht zu lange blockiert, falls die Seite langsam ist
    final response = await dio.get<String>(
      originalUri.toString(),
      options: Options(responseType: ResponseType.plain),
    ).timeout(const Duration(seconds: 3));

    if (response.data == null) return null;
    final document = parse(response.data);

    // Suche nach verschiedenen Link-Tags.
    // Der Selektor findet rel="icon", rel="shortcut icon", rel="apple-touch-icon" etc.
    final linkElements = document.querySelectorAll('link[rel*="icon"]');

    for (var element in linkElements) {
      String? href = element.attributes['href'];
      if (href == null || href.isEmpty) continue;

      // Relative Pfade auflösen (z.B. "/favicon.png" -> "https://domain.de/favicon.png")
      final absoluteHref = Uri.parse(href).isAbsolute ? href : originalUri.resolve(href).toString();

      // Download versuchen
      debugPrint('favicon: $absoluteHref');
      final icon = await _getFavicon(absoluteHref);

      // Nur zurückgeben, wenn wir wirklich ein Icon gefunden haben!
      // Wenn icon null ist, geht die Schleife zum nächsten Element weiter.
      if (icon != null) return icon;
    }
  } catch (e) {
    debugPrint('HTML-Parsing fehlgeschlagen: $e');
  }
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