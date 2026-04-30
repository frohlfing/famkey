import 'package:app_settings/app_settings.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:famkey/core/env.dart';
import 'package:famkey/services/system_settings_service/system_settings_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Implementierung von [SystemSettingsService] für die Windows-Platform.
class SystemSettingsServiceWindows implements SystemSettingsService {

  @override
  bool get canOpenAppSettings => true;

  @override
  bool get canOpenBiometricSettings => true;

  @override
  bool get canOpenAutofillSettings => false;

  @override
  Future<void> openAppSettings() async {
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
  }

  @override
  Future<void> openBiometricSettings() async {
    final uri = Uri.parse('ms-settings:signinoptions');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// No-Op - Autofill ist unter Windows nicht möglich.
  @override
  Future<void> openAutofillSettings() async {}

}

/// Implementierung von [SystemSettingsService] für die Mobile-Platform (Android, iOS und andere mobile/posix Systeme).
class SystemSettingsServiceMobile implements SystemSettingsService {

  @override
  bool get canOpenAppSettings => env.isAndroid;

  @override
  bool get canOpenBiometricSettings => true;

  @override
  bool get canOpenAutofillSettings => env.isAndroid;

  @override
  Future<void> openAppSettings() async {
    final opened = await ph.openAppSettings();
    if (!opened) {
      throw 'Konnte die App-Einstellungen nicht öffnen.';
    }
  }

  @override
  Future<void> openBiometricSettings() async {
    await AppSettings.openAppSettings(type: AppSettingsType.security);
  }

  @override
  Future<void> openAutofillSettings() async {
    if (env.isAndroid) {
      final channel = MethodChannel('de.frohlfing.famkey/autofill');
      await channel.invokeMethod('openAutofillSettings');
    }
  }
}

/// Erzeugt eine [SystemSettingsService]-Instanz (Desktop- oder Mobile).
SystemSettingsService createSystemSettingsService()
  => env.isWindows
      ? SystemSettingsServiceWindows()
      : SystemSettingsServiceMobile();