import 'package:privault/core/service_locator.dart';
import 'package:privault/services/system_settings_service/system_settings_service.dart';
import 'package:privault/services/session_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Implementierung von [SystemSettingsService] für eine WebAssembly (WASM).
class SystemSettingsServiceWeb implements SystemSettingsService {

  @override
  bool get canOpenAppSettings => false;

  @override
  bool get canOpenBiometricSettings => false;

  @override
  bool get canOpenAutofillSettings => false;

  @override
  Future<void> openAppSettings() async {
    // // Fallback
    // final sessionService = getIt<SessionService>();
    // final host = sessionService.settings?.host ?? 'https://privault.frank-rohlfing.de'; // ist bereits normalisiert (ohne Slash am Ende)
    // final url = Uri.parse(host);
    // if (await canLaunchUrl(url)) {
    //   await launchUrl(url, mode: LaunchMode.externalApplication);
    // }
  }

  /// No-Op - Biometrie ist unter Web nicht möglich.
  @override
  Future<void> openBiometricSettings() async {}

  /// No-Op - Autofill ist unter Web nicht möglich.
  @override
  Future<void> openAutofillSettings() async {}
}

/// Erzeugt eine [SystemSettingsService]-Instanz (Web).
SystemSettingsService createSystemSettingsService() => SystemSettingsServiceWeb();