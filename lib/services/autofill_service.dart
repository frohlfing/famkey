import 'package:flutter/services.dart';
import 'package:privault/core/env.dart';
import 'package:privault/core/navigator_key.dart';
import 'package:url_launcher/url_launcher.dart';

/// Verwaltet die plattformspezifische Autofill-Unterstützung.
///
/// **Android:** PriVault registriert sich als Android-Autofill-Provider. Das OS
/// ruft den nativen [PriVaultAutofillService] auf, wenn ein Login-Formular in
/// einer fremden App erkannt wird. Dieser Service kommuniziert über einen
/// MethodChannel mit Flutter, um passende Credentials abzufragen und die Felder
/// zu befüllen. Der Nutzer aktiviert PriVault als Provider einmalig in den
/// Android-Systemeinstellungen (Einstellungen → Passwörter → Autofill-Dienst).
///
/// **Windows:** Kein natives Autofill-Framework. Zwei Ansätze:
/// - Auto-Type: Der Nutzer klickt in PriVault auf "Einfügen". Die App wechselt
///   den Fokus auf das Ziel-Fenster und simuliert Tastaturanschläge via Win32-API.
/// - Browser-Extension (geplant V2): Eine Chrome/Edge-Extension kommuniziert
///   über Native Messaging mit PriVault und befüllt Felder automatisch.
///
/// **Web:** Kein systemeigenes Autofill möglich, da PriVault selbst im Browser
/// läuft. Autofill erfordert dieselbe Browser-Extension wie Windows (V2).
class AutofillService {
  static const _channel = MethodChannel('de.frohlfing.privault/autofill');

  /// Die Domain, für die gerade ein Autofill-Request vorliegt, z.B. "paypal.com".
  /// Ist null, wenn kein Autofill-Request aktiv ist.
  String? _pendingDomain;

  String? get pendingDomain => _pendingDomain;

  bool get hasAutofillRequest => _pendingDomain != null;

  /// Initialisiert den MethodChannel-Handler.
  ///
  /// Muss einmalig nach dem Starten der Flutter-Engine aufgerufen werden.
  /// Auf Nicht-Android-Plattformen ist diese Methode ein No-op.
  Future<void> init() async {
    if (!env.isAndroid) return;

    // Prüfen, ob die Activity für Autofill geöffnet wurde
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('getAutofillRequest');
      if (result != null) {
        _pendingDomain = result['domain'] as String?;
      }
    } catch (_) {}

    // Handler für eingehende Autofill-Requests (App war bereits offen)
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onAutofillRequest') {
        final args = call.arguments as Map<Object?, Object?>;
        _pendingDomain = args['domain'] as String?;
        if (_pendingDomain != null) {
          navigatorKey.currentState?.pushNamed('/autofill-picker');
        }
      }
    });
  }

  /// Schließt den Autofill-Vorgang ab und befüllt die Felder in der anfragenden App.
  Future<void> complete(String username, String password) async {
    if (env.isAndroid) {
      await _channel.invokeMethod<void>('completeAutofill', {
        'username': username,
        'password': password,
      });
    }
    _pendingDomain = null;
  }

  /// Bricht den Autofill-Vorgang ab.
  Future<void> cancel() async {
    if (env.isAndroid) {
      await _channel.invokeMethod<void>('cancelAutofill');
    }
    _pendingDomain = null;
  }

  /// Gibt an, ob Autofill auf diesem Gerät unterstützt wird.
  bool get isAvailable => env.isAndroid;

  /// Gibt an, ob PriVault aktuell als aktiver Autofill-Anbieter im System eingestellt ist.
  ///
  /// Gibt auf Nicht-Android-Plattformen immer false zurück.
  Future<bool> isAutofillEnabled() async {
    if (!env.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isAutofillEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Öffnet die plattformspezifischen Systemeinstellungen für den Autofill-Dienst.
  Future<void> openSystemSettings() async {
    if (env.isAndroid) {
      await launchUrl(Uri.parse('intent:#Intent;action=android.settings.REQUEST_SET_AUTOFILL_SERVICE;end'));
    } else if (env.isWindows) {
      await launchUrl(
        Uri.parse('https://support.microsoft.com/de-de/windows/ausf%C3%BCllen-von-formularen-mit-microsoft-autofill-64eb7382-777e-400a-8671-8884976c666e'),
        mode: LaunchMode.externalApplication,
      );
    } else if (env.isApple) {
      await launchUrl(Uri.parse('App-Prefs:root=PASSWORDS'));
    }
  }
}
