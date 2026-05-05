import 'package:package_info_plus/package_info_plus.dart';
import 'package:famkey/core/sync_protocol.dart';
import 'package:famkey/database/database.dart';

/// Zentrale Versionierungsinformationen.
///
/// Alle Werte stammen aus ihren jeweiligen Single Sources of Truth.
class AppVersion {
  const AppVersion._(); // verhindert Instanziierung

  /// Angezeigte App-Version (aus `pubspec.yaml`, z.B. "1.0").
  static Future<String> get version async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// Hauptversion der App (aus `version` extrahiert).
  /// Wird mit einem Redesign oder bei einem Migrations-Bruch erhöht.
  static Future<int> get major async {
    final info = await PackageInfo.fromPlatform();
    final parts = info.version.split('.');
    return int.tryParse(parts[0]) ?? 0;
  }

  /// Nebenversion der App (aus `version` extrahiert).
  /// Wird mit einer Funktionsänderung erhöht und mit einer neuen Hauptversion auf 0 zurückgesetzt.
  static Future<int> get minor async {
    final info = await PackageInfo.fromPlatform();
    final parts = info.version.split('.');
    return parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  }

  /// Patch der Nebenversion (aus `version` extrahiert).
  /// Wird mit einer Fehlerbehebung (Bugfix) erhöht und mit einer neuen Nebenversion auf 0 zurückgesetzt.
  static Future<int> get patch async {
    final info = await PackageInfo.fromPlatform();
    final parts = info.version.split('.');
    return parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
  }

  /// Buildnummer (aus `pubspec.yaml`, z.B. 42).
  /// Wird (theoretisch) mit jedem Build erhöht. Sie wird niemals zurückgesetzt.
  /// Dies ist auch der `versionCode` für den Google-Store.
  static Future<int> get buildNumber async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  /// Angezeigte App-Version inkl. Buildnummer (aus `pubspec.yaml`, z.B. "1.0+42")
  static Future<String> get fullVersion async {
    final info = await PackageInfo.fromPlatform();
    return "${info.version}+${info.buildNumber}";
  }

  /// Sync-Protokollversion (aus `lib/core/sync_protocol.dart`)
  static int get syncProtocolVersion => SyncProtocol.version;

  /// Datenbankschema (aus `lib/database/database.dart`).
  static int get databaseSchemaVersion => AppDatabase.version;
}
