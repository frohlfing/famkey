import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:privault/core/env.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/services/session_service.dart';
import 'package:url_launcher/url_launcher.dart';

// todo für Web testen - vermutlich besser, per Conditional Import und Factory-Pattern zu lösen

class DeviceService {
  /// Öffnet die App-Info-Seite in den Systemeinstellungen.
  ///
  /// Für Web ist die Funktion nicht verfügbar.
  Future<void> openAppSettings() async {

    if (env.isWindows) {
      // Unter Windows gibt es keinen direkten Weg in die Detail-Ansicht einer fremden MSIX/EXE via URI.
      // Der Standardweg öffnet "ms-settings:appsfeatures-app".
      // Man kann versuchen, direkt auf die Windows-App-Einstellungen für *diese* App zu zielen.
      final packageInfo = await PackageInfo.fromPlatform();
      final pfn = packageInfo.packageName;
      final uri = Uri.parse('ms-settings:appsfeatures-app?PFN=$pfn');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Fallback: Die allgemeine Liste der installierten Apps
        await launchUrl(Uri.parse('ms-settings:appsfeatures'));
      }

    } else if (env.isAndroid) {
      final opened = await ph.openAppSettings();
      if (!opened) {
        throw 'Konnte die Android App-Einstellungen nicht öffnen.';
      }
    }

    else if (env.isApple) {
      await ph.openAppSettings();
    }

    else { // Web
      // Fallback
      final sessionService = getIt<SessionService>();
      final host = sessionService.settings?.host ?? 'https://privault.frank-rohlfing.de'; // ist bereits normalisiert (ohne Slash am Ende)
      final url = Uri.parse(host);
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    }

  }
}