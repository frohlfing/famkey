import 'package:flutter/services.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/navigator_key.dart';
import 'package:privault/services/autofill_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Android-Implementierung des Autofill-Frameworks.
///
/// PriVault ist als Android-Autofill-Provider registriert
/// (Manifest: `android:name=".PriVaultAutofillService"`).
/// Der Kotlin-Service in `android/` kommuniziert mit dieser Dart-Klasse über den
/// MethodChannel `de.frohlfing.privault/autofill`. Die Aktivierung erfolgt einmalig
/// durch den Nutzer: Einstellungen → Passwörter → Autofill-Dienst → PriVault.
///
/// # Ablauf
///
/// 1. Nutzer fokussiert ein Login-Formular in einer fremden App (z.B. Chrome).
/// 2. Android ruft `PriVaultAutofillService.onFillRequest()` auf (Kotlin).
/// 3. Kotlin extrahiert die Domain aus der `AssistStructure` (z.B. "paypal.com").
/// 4. Je nach App-Zustand:
///
///    **a) PriVault war nicht geöffnet:**
///       Kotlin startet PriVault via `PendingIntent` mit der Domain als Intent-Extra.
///       `init()` ruft `getAutofillRequest` ab → [_pendingDomain] wird gesetzt.
///       Die App navigiert zu `/autofill-picker`.
///
///    **b) PriVault war bereits im Hintergrund:**
///       Kotlin ruft `onAutofillRequest` am Channel auf.
///       Der registrierte Handler setzt [_pendingDomain] und navigiert zu `/autofill-picker`.
///       Der registrierte Handler setzt [_pendingDomain] und navigiert zu `/autofill-picker`.
///
/// 5. `AutofillPickerPage` lädt alle Einträge und filtert nach [_pendingDomain].
/// 6. Nutzer wählt einen Eintrag → `complete()` schickt Credentials zurück an Kotlin.
/// 7. Kotlin befüllt die Felder mit einem `Dataset` in der `FillResponse`.
///
/// # Testflow: PayPal in Chrome
///
/// ```
/// Chrome (Login) → PriVaultAutofillService.onFillRequest() [Kotlin]
///   → PendingIntent → PriVault startet
///   → init(): getAutofillRequest → _pendingDomain = "paypal.com"
///   → Navigator: /autofill-picker
///   → Nutzer wählt "PayPal"-Eintrag
///   → complete("user@example.com", "geheim123")
///   → MethodChannel: completeAutofill → Kotlin → Chrome befüllt
/// ```
class AutofillServiceAndroid implements AutofillService {
  /// Bidirektionaler MethodChannel zum Kotlin-`PriVaultAutofillService`.
  ///
  /// Dart → Kotlin: `getAutofillRequest`, `completeAutofill`, `cancelAutofill`, `isAutofillEnabled`.
  /// Kotlin → Dart: `onAutofillRequest`.
  static const _channel = MethodChannel('de.frohlfing.privault/autofill');

  /// Domain des aktiven Autofill-Requests (z.B. "paypal.com").
  ///
  /// Gesetzt von `init()` beim App-Start (Szenario a) oder vom Channel-Handler (Szenario b).
  /// Nach `complete()` oder `cancel()` wieder null.
  String? _pendingDomain;

  @override
  String? get pendingDomain => _pendingDomain;

  @override
  bool get hasAutofillRequest => _pendingDomain != null;

  /// Initialisiert den MethodChannel-Handler.
  ///
  /// Prüft zunächst ob PriVault per PendingIntent mit Domain gestartet wurde
  /// (Szenario a: `getAutofillRequest`). Registriert dann den Handler für
  /// laufende App (Szenario b: `onAutofillRequest`).
  @override
  Future<void> init() async {
    // Szenario a: PriVault wurde über einen Autofill-Intent gestartet.
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('getAutofillRequest');
      if (result != null) {
        _pendingDomain = result['domain'] as String?;
        log.debug('Autofill-Request beim Start', context: {'domain': _pendingDomain});
      }
    } catch (_) {}

    // Szenario b: PriVault lief bereits, Kotlin ruft diesen Callback auf.
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onAutofillRequest') {
        final args = call.arguments as Map<Object?, Object?>;
        _pendingDomain = args['domain'] as String?;
        log.debug('Autofill-Request (App lief)', context: {'domain': _pendingDomain});
        if (_pendingDomain != null) {
          navigatorKey.currentState?.pushNamed('/autofill-picker');
        }
      }
    });
  }

  /// Schließt den Autofill-Vorgang ab und befüllt die Felder der anfragenden App.
  ///
  /// Kotlin baut einen `Dataset` in einer `FillResponse` und gibt diesen an
  /// das Android-Autofill-Framework zurück, das die Felder befüllt.
  @override
  Future<void> complete(String username, String password) async {
    log.debug('Autofill abschließen', context: {'domain': _pendingDomain, 'username': username});
    await _channel.invokeMethod<void>('completeAutofill', {
      'username': username,
      'password': password,
    });
    _pendingDomain = null;
  }

  /// Bricht den Autofill-Vorgang ab.
  ///
  /// Kotlin gibt eine leere `FillResponse` zurück, Android beendet den Vorgang sauber.
  @override
  Future<void> cancel() async {
    log.debug('Autofill abgebrochen', context: {'domain': _pendingDomain});
    await _channel.invokeMethod<void>('cancelAutofill');
    _pendingDomain = null;
  }

  /// Gibt an, ob PriVault als aktiver Autofill-Provider im System eingestellt ist.
  ///
  /// Kotlin prüft via `AutofillManager.hasEnabledAutofillServices()`.
  @override
  Future<bool> isAutofillEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isAutofillEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> unregisterHotkey() async {}

  @override
  Future<void> reregisterHotkey() async {}

  @override
  Future<String> getLastWindowTitle() async => '';

  @override
  Future<bool> typeCredentials(String username, String password) async => false;
}
