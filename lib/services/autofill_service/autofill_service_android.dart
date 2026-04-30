import 'package:flutter/services.dart';
import 'package:famkey/core/logger.dart';
import 'package:famkey/core/navigator_key.dart';
import 'package:famkey/core/service_locator.dart';
import 'package:famkey/services/autofill_service.dart';
import 'package:famkey/services/session_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Android-Implementierung des Autofill-Service.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// GROSSES BILD: Was passiert, wenn ein Nutzer ein Login-Formular antippt?
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Das Android-Betriebssystem hat ein eingebautes "Autofill-Framework". Jede App
/// kann sich als "Autofill-Provider" registrieren. FamKey tut das, damit Android
/// FamKey fragt, wenn der Nutzer ein Formular ausfüllen möchte.
///
/// Der Ablauf hat viele Schritte und ist über mehrere Dateien verteilt:
///
/// ```
///   Chrome (andere App)     Android-System          FamKey (diese Datei + Kotlin)
///   ──────────────────      ──────────────          ──────────────────────────────
///
///   Nutzer tippt ins
///   Login-Formular
///         │
///         ▼
///   Android erkennt          FamKeyAutofillService.onFillRequest()
///   Formularfelder    ──►    (Kotlin, android/.../FamKeyAutofillService.kt)
///                             • Welche Felder gibt es? (Benutzername, Passwort)
///                             • Welche Domain ist das? (z.B. "paypal.com")
///                             • "FamKey"-Eintrag als Vorschlag erstellen
///                             • PendingIntent auf AutofillAuthActivity
///                                  │
///         ◄──────────────────────── Zeigt "FamKey"-Bubble im Dropdown
///
///   Nutzer tippt auf
///   FamKey-Bubble   ──►    AutofillAuthActivity.onCreate()
///                             (Kotlin, android/.../AutofillAuthActivity.kt)
///                             • Callbacks in AutofillResultRelay registrieren
///                             • MainActivity mit FLAG_ACTIVITY_NEW_TASK starten
///                                  │
///         ◄──────────── FamKey kommt in den Vordergrund
///
///                             MainActivity.onNewIntent() oder onCreate()
///                             (Kotlin, android/.../MainActivity.kt)
///                             • Ruft Flutter via MethodChannel auf
///                                  │
///                                  ▼
///                    ┌─────────────────────────────────────┐
///                    │  Flutter (Dart) – diese Datei       │
///                    │                                     │
///                    │  init() hat zwei Jobs:              │
///                    │  a) beim Start: getAutofillRequest  │
///                    │  b) im Betrieb: onAutofillRequest   │
///                    │                                     │
///                    │  _pendingDomain wird gesetzt        │
///                    │  Navigation zu /autofill-picker     │
///                    └─────────────────────────────────────┘
///                                  │
///                                  ▼
///                    AutofillPickerPage (Flutter UI)
///                    (lib/features/autofill/autofill_picker_page.dart)
///                    • Einträge laden und nach Domain filtern
///                    • Nutzer wählt einen Eintrag aus
///                                  │
///                                  ▼
///                    complete(username, password)
///                    • MethodChannel → Kotlin completeAutofill
///                    • AutofillResultRelay.deliver() → AutofillAuthActivity
///                    • AutofillAuthActivity: Dataset bauen, setResult(OK)
///                    • AutofillAuthActivity: finish()
///
///         ◄──────────────────────────────── Android befüllt Formular in Chrome
///
///   Formular ist befüllt ✓
/// ```
///
/// ═══════════════════════════════════════════════════════════════════════════
/// DIE DREI START-SZENARIEN
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Je nachdem, ob FamKey schon läuft oder nicht, gibt es drei Szenarien:
///
/// **Szenario A – Cold-Start (FamKey war nicht gestartet):**
///   1. Android startet FamKey komplett neu
///   2. `init()` ruft `getAutofillRequest` ab → `_pendingDomain` wird gesetzt
///   3. Nutzer sieht den Login-Screen
///   4. Nach dem Login prüft die Login-Seite `hasAutofillRequest` und navigiert zu
///      `/autofill-picker` (statt zu `/main`)
///
/// **Szenario B – Warm-Start, eingeloggt (FamKey lief im Hintergrund):**
///   1. Android bringt FamKey in den Vordergrund
///   2. Kotlin ruft `onAutofillRequest` via MethodChannel auf
///   3. Der Handler hier setzt `_pendingDomain` und navigiert sofort zu `/autofill-picker`
///
/// **Szenario C – Warm-Start, nicht eingeloggt (FamKey lief, aber gesperrt):**
///   1. Android bringt FamKey in den Vordergrund
///   2. Kotlin ruft `onAutofillRequest` auf
///   3. Der Handler setzt nur `_pendingDomain`, navigiert aber NICHT (weil kein Login)
///   4. Nutzer loggt sich ein → Login-Seite prüft `hasAutofillRequest` → `/autofill-picker`
///
/// ═══════════════════════════════════════════════════════════════════════════
/// WAS IST EIN METHODCHANNEL?
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Flutter (Dart) und der Android-Unterbau (Kotlin) laufen in getrennten
/// Laufzeitumgebungen. Sie können nicht direkt auf die Objekte des anderen zugreifen.
/// Ein MethodChannel ist eine benannte Brücke zwischen den beiden Welten:
///
///   Dart  ──( "completeAutofill" + args )──►  Kotlin
///   Dart  ◄─( result )──────────────────────  Kotlin
///
/// Der Channel hat einen Namen ("de.frohlfing.famkey/autofill"), an dem sich
/// beide Seiten erkennen. Der Aufruf ist asynchron (`await`), weil er die Grenze
/// zwischen zwei Threads überquert.
class AutofillServiceAndroid implements AutofillService {
  /// Bidirektionaler MethodChannel zum Kotlin-`FamKeyAutofillService`.
  ///
  /// Dieser Name muss auf beiden Seiten exakt gleich sein:
  /// - Dart: hier in dieser Datei
  /// - Kotlin: in `MainActivity.kt` (Konstante `channel`)
  ///
  /// Dart → Kotlin: `getAutofillRequest`, `completeAutofill`, `cancelAutofill`, `isAutofillEnabled`.
  /// Kotlin → Dart: `onAutofillRequest`.
  static const _channel = MethodChannel('de.frohlfing.famkey/autofill');

  /// Domain des aktiven Autofill-Requests (z.B. "paypal.com").
  ///
  /// Gesetzt von `init()` beim App-Start (Szenario A) oder vom Channel-Handler (Szenario B/C).
  /// Nach `complete()` oder `cancel()` wieder null – signalisiert "kein offener Request".
  String? _pendingDomain;

  @override
  String? get pendingDomain => _pendingDomain;

  @override
  bool get hasAutofillRequest => _pendingDomain != null;

  /// Initialisiert den MethodChannel und behandelt beide Einstiegsszenarien.
  ///
  /// Diese Methode wird einmalig beim App-Start in `main.dart` aufgerufen,
  /// nachdem Flutter vollständig initialisiert ist.
  ///
  /// **Szenario A (Cold-Start):** `getAutofillRequest` fragt Kotlin, ob die App
  /// über einen Autofill-Intent gestartet wurde. Wenn ja, liefert Kotlin die Domain.
  /// In diesem Fall ist FamKey noch nicht gestartet gewesen – Android hat es für
  /// den Nutzer gestartet.
  ///
  /// **Szenario B/C (Warm-Start):** `onAutofillRequest` ist ein Kotlin→Dart-Callback,
  /// der ausgelöst wird, wenn FamKey schon lief und Android es reaktiviert.
  @override
  Future<void> init() async {
    // ─────────────────────────────────────────────────────────────────────────
    // Szenario A: FamKey wurde über einen Autofill-Intent kalt gestartet.
    // Kotlin hat beim Start der MainActivity die Domain aus dem Intent-Extra gelesen
    // und wartet, bis Flutter sie über diesen MethodChannel-Aufruf abholt.
    // ─────────────────────────────────────────────────────────────────────────
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('getAutofillRequest');
      if (result != null) {
        _pendingDomain = result['domain'] as String?;
        log.debug('Autofill-Request beim Start');
      }
    } catch (_) {}

    // ─────────────────────────────────────────────────────────────────────────
    // Szenario B/C: FamKey lief bereits. Android hat MainActivity via
    // onNewIntent() benachrichtigt, die dann diesen Callback auslöst.
    //
    // Der Handler prüft, ob der Nutzer eingeloggt ist, bevor er navigiert:
    //   - Eingeloggt (Szenario B): sofort zu /autofill-picker navigieren
    //   - Nicht eingeloggt (Szenario C): nur _pendingDomain setzen; die Login-Seite
    //     navigiert nach erfolgreichem Login selbst zu /autofill-picker, weil sie
    //     hasAutofillRequest prüft (login_page.dart).
    // ─────────────────────────────────────────────────────────────────────────
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onAutofillRequest') {
        final args = call.arguments as Map<Object?, Object?>;
        _pendingDomain = args['domain'] as String?;
        log.debug('Autofill-Request (App lief)');
        if (_pendingDomain != null) {
          // Nur navigieren wenn bereits eingeloggt – sonst übernimmt der Login-Handler
          // die Navigation nach erfolgreichem Login (hasAutofillRequest → /autofill-picker).
          final isLoggedIn = getIt<SessionService>().user != null;
          if (isLoggedIn) {
            navigatorKey.currentState?.pushNamed('/autofill-picker');
          }
        }
      }
    });
  }

  /// Schließt den Autofill-Vorgang erfolgreich ab und befüllt die Formularfelder.
  ///
  /// Was hier passiert:
  /// 1. `_channel.invokeMethod('completeAutofill', ...)` schickt Benutzername und
  ///    Passwort über den MethodChannel an Kotlin.
  /// 2. Kotlin ruft `AutofillResultRelay.deliver()` auf.
  /// 3. Das Relay leitet die Daten an `AutofillAuthActivity` weiter.
  /// 4. `AutofillAuthActivity` baut ein `Dataset` (Container mit den Feldwerten)
  ///    und gibt es mit `setResult(RESULT_OK)` an Android zurück.
  /// 5. Android befüllt die Felder in Chrome (oder einer anderen App).
  /// 6. FamKey geht mit `moveTaskToBack` in den Hintergrund (Session bleibt erhalten).
  ///
  /// Erst NACHDEM Kotlin `result.success(null)` aufruft, kehrt `await invokeMethod`
  /// hier zurück – d.h. das Formular ist zu diesem Zeitpunkt bereits befüllt.
  @override
  Future<void> complete(String username, String password) async {
    log.debug('Autofill abschließen');
    await _channel.invokeMethod<void>('completeAutofill', {
      'username': username,
      'password': password,
    });
    _pendingDomain = null;
  }

  /// Bricht den Autofill-Vorgang ab (Nutzer hat den X-Button gedrückt).
  ///
  /// Was hier passiert:
  /// 1. Kotlin ruft `AutofillResultRelay.cancel()` auf.
  /// 2. Das Relay benachrichtigt `AutofillAuthActivity`.
  /// 3. `AutofillAuthActivity` ruft `setResult(RESULT_CANCELED)` auf und schließt sich.
  /// 4. Das Android-Autofill-Framework erhält das Cancel – Chrome zeigt keinen Fehler.
  /// 5. FamKey geht mit `moveTaskToBack` in den Hintergrund.
  @override
  Future<void> cancel() async {
    log.debug('Autofill abgebrochen');
    await _channel.invokeMethod<void>('cancelAutofill');
    _pendingDomain = null;
  }

  /// Fragt Android, ob FamKey als Autofill-Provider ausgewählt ist.
  ///
  /// Der Nutzer muss in den Android-Einstellungen unter "Passwörter & Autofill"
  /// FamKey als Anbieter einstellen. Diese Methode gibt true zurück, wenn das
  /// bereits geschehen ist. Wird in den FamKey-Einstellungen angezeigt.
  @override
  Future<bool> isAutofillEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isAutofillEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  // Die folgenden Methoden sind Windows-spezifisch und werden auf Android nicht benötigt.
  // Sie existieren hier nur, weil AutofillService als gemeinsames Interface alle Methoden
  // enthält und diese Implementierung den Vertrag erfüllen muss.

  @override
  Future<void> unregisterHotkey() async {}

  @override
  Future<void> reregisterHotkey() async {}

  @override
  Future<String> getLastWindowTitle() async => '';

  @override
  Future<bool> typeCredentials(String username, String password) async => false;
}
