import 'package:famkey/core/env.dart';
import 'package:famkey/database/database.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:url_launcher/url_launcher.dart';

/// Stellt allgemeine Informationen zur App und zum laufenden System bereit.
///
/// Dieser Service bündelt drei Informationsquellen an einem zentralen Ort:
///
/// 1. **App-Versionsinformationen** – Liest `version` und `buildNumber` aus
///    `pubspec.yaml` zur Laufzeit via `package_info_plus`.
///
/// 2. **Sync-Protokollversion** – Eine Compile-Time-Konstante, die bei jeder
///    Änderung des Sync-Protokolls manuell erhöht werden muss.
///
/// 3. **App-Info-Seite** – Öffnet die plattformspezifische Systemseite mit
///    Informationen zur installierten App (Berechtigungen, Cache, Version usw.).
///    Plattformverhalten:
///    - **Windows:** Öffnet „ms-settings:appsfeatures-app" direkt zur App.
///    - **Android:** Öffnet die App-Info-Seite über `permission_handler`.
///    - **Web:** Kein Systemzugriff – [canOpenSettings] ist `false`.
class InfoService {

  // --------------------------------------------------------------------------
  // --- App-Version ---
  // --------------------------------------------------------------------------

  /// Angezeigte App-Version (aus `pubspec.yaml`, z.B. "1.0").
  Future<String> get version async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// Hauptversion der App (aus [version] extrahiert).
  /// Wird bei einem Redesign oder einem Migrations-Bruch erhöht.
  Future<int> get major async {
    final info = await PackageInfo.fromPlatform();
    final parts = info.version.split('.');
    return int.tryParse(parts[0]) ?? 0;
  }

  /// Nebenversion der App (aus [version] extrahiert).
  /// Wird bei einer Funktionsänderung erhöht und mit einer neuen Hauptversion auf 0 zurückgesetzt.
  Future<int> get minor async {
    final info = await PackageInfo.fromPlatform();
    final parts = info.version.split('.');
    return parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  }

  /// Patch der Nebenversion (aus [version] extrahiert).
  /// Wird bei einem Bugfix erhöht und mit einer neuen Nebenversion auf 0 zurückgesetzt.
  Future<int> get patch async {
    final info = await PackageInfo.fromPlatform();
    final parts = info.version.split('.');
    return parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
  }

  /// Buildnummer (aus `pubspec.yaml`, z.B. 42).
  /// Wird mit jedem Build erhöht und entspricht dem `versionCode` im Google Play Store.
  Future<int> get buildNumber async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  /// Vollständige Versionsanzeige inkl. Buildnummer (z.B. "1.0+42").
  Future<String> get fullVersion async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  // --------------------------------------------------------------------------
  // --- Sync-Protokollversion ---
  // --------------------------------------------------------------------------

  /// Versionsnummer des Sync-Protokolls zwischen App und Server.
  ///
  /// Diese Konstante muss manuell erhöht werden, sobald sich das Protokoll
  /// in einer rückwärts inkompatiblen Weise ändert (z.B. neue Pflichtfelder,
  /// geänderte Verschlüsselung, neues Handshake-Verfahren).
  ///
  /// Vor jeder Synchronisation prüft die App die Protokollkompatibilität:
  ///
  /// - `client.syncProtocolVersion < server.minSupportedSyncProtocol`
  ///   → App ist zu alt → Sync blockieren, App-Update erforderlich.
  /// - `client.syncProtocolVersion > server.currentSyncProtocol`
  ///   → Server ist zu alt → Sync blockieren, Server-Update erforderlich.
  /// - Sonst → Sync erlaubt.
  int get syncProtocolVersion => 1;

  // --------------------------------------------------------------------------
  // --- Datenbankschema ---
  // --------------------------------------------------------------------------

  /// Aktuelle Schema-Version der lokalen SQLite-Datenbank.
  /// Entspricht [AppDatabase.version] aus dem Drift-Schema.
  int get schemaVersion => AppDatabase.version;

  // --------------------------------------------------------------------------
  // --- App-Info-Seite ---
  // --------------------------------------------------------------------------

  /// Gibt an, ob die App-Info-Seite auf dieser Plattform geöffnet werden kann.
  bool get canOpenSettings => !env.isWeb;

  /// Öffnet die App-Info-Seite in den Systemeinstellungen.
  Future<void> openSystemSettings() async {
    if (env.isWeb) return;

    if (env.isWindows) {
      final packageInfo = await PackageInfo.fromPlatform();
      final pfn = packageInfo.packageName;
      final uri = Uri.parse('ms-settings:appsfeatures-app?PFN=$pfn');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Fallback: allgemeine Liste der installierten Apps
        await launchUrl(Uri.parse('ms-settings:appsfeatures'));
      }
    } else {
      final opened = await ph.openAppSettings();
      if (!opened) throw 'Konnte die App-Einstellungen nicht öffnen.';
    }
  }
}
