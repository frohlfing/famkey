import 'package:privault/core/env.dart';
import 'package:url_launcher/url_launcher.dart';

// todo

/// Implementierung für die Autofill-Unterstützung.
class AutofillService {

  // Future<void> registerAutofill();
  // Future<void> unregisterAutofill();

  /// Prüft, ob das aktuelle Gerät Autofill unterstützt.
  Future<bool> isAvailable() async {
    throw UnimplementedError();
  }

  /// Öffnet die plattformspezifischen Systemeinstellungen für Autofill.
  Future<void> openSystemSettings() async {
    if (env.isWindows) {
      await launchUrl(Uri.parse('https://support.microsoft.com/de-de/windows/ausf%C3%BCllen-von-formularen-mit-microsoft-autofill-64eb7382-777e-400a-8671-8884976c666e'), mode: LaunchMode.externalApplication);
    } else if (env.isAndroid) {
      await launchUrl(Uri.parse('intent:#Intent;action=android.settings.REQUEST_SET_AUTOFILL_SERVICE;end'));
    } else if (env.isApple) {
      await launchUrl(Uri.parse('App-Prefs:root=PASSWORDS'));
    }
  }
}