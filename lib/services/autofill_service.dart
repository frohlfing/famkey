import 'package:famkey/core/env.dart';
import 'package:famkey/services/autofill_service/autofill_service_android.dart';
import 'package:famkey/services/autofill_service/autofill_service_noop.dart';

/// Android-spezifischer Service für das Autofill-Framework.
///
/// # Was ist Autofill?
///
/// Autofill bedeutet, dass FamKey Benutzername und Passwort automatisch in
/// Anmeldeformulare anderer Apps einträgt – ohne dass der Nutzer kopieren/einfügen muss.
/// Android übernimmt die Vermittlung: Das Betriebssystem ruft FamKey aktiv auf,
/// wenn der Nutzer ein Formular antippt. FamKey ist als Autofill-Provider registriert.
///
/// Für Windows existiert ein separater [AutotypeService]
/// (`lib/services/autotype_service.dart`), der Zugangsdaten per simulierten
/// Tastatureingaben (Win32 SendInput) in beliebige Fenster tippt.
///
/// Die Implementierung liegt in [AutofillServiceAndroid]
/// in `autofill_service/autofill_service_android.dart`.
/// Auf anderen Plattformen wird [AutofillServiceNoop] verwendet (`isSupported == false`).
abstract class AutofillService {

  factory AutofillService() => env.isAndroid ? AutofillServiceAndroid() : AutofillServiceNoop();

  /// Gibt an, ob Autofill auf dieser Plattform verfügbar ist.
  bool get isSupported;

  /// Domain des aktiven Autofill-Requests (z.B. "paypal.com").
  /// Null solange kein Request aktiv ist.
  String? get pendingDomain;

  /// True, wenn ein Android-Autofill-Request auf Bearbeitung wartet.
  bool get hasAutofillRequest;

  /// Initialisiert den MethodChannel und richtet die Request-Callbacks ein.
  Future<void> init();

  /// Schließt den Autofill-Vorgang ab und befüllt die Felder der anfragenden App.
  Future<void> complete(String username, String password);

  /// Bricht den Autofill-Vorgang ab.
  Future<void> cancel();

  /// Gibt an, ob FamKey als aktiver Autofill-Anbieter im Android-System eingestellt ist.
  Future<bool> isAutofillEnabled();

  /// Öffnet die Android-Systemeinstellungen zur Auswahl des Autofill-Anbieters.
  Future<void> openSystemSettings();
}
