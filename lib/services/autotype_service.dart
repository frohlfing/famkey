import 'package:famkey/core/env.dart';
import 'package:famkey/services/autotype_service/autotype_service_noop.dart';
import 'package:famkey/services/autotype_service/autotype_service_windows.dart';

/// Windows-spezifischer Service für Auto-Type.
///
/// Simuliert Tastatureingaben, um Zugangsdaten in beliebige Windows-Fenster
/// einzutragen (Win32 SendInput-API via MethodChannel).
///
/// Für Android existiert ein separater [AutofillService]
/// (`lib/services/autofill_service.dart`), der das Android-Autofill-Framework nutzt.
///
/// Die Implementierung liegt in [AutotypeServiceWindows]
/// in `autotype_service/autotype_service_windows.dart`.
/// Auf anderen Plattformen wird [AutotypeServiceNoop] verwendet (`isSupported == false`).
abstract class AutotypeService {

  factory AutotypeService() => env.isWindows ? AutotypeServiceWindows() : AutotypeServiceNoop();

  /// Gibt an, ob Auto-Type auf dieser Plattform verfügbar ist.
  bool get isSupported;

  /// Initialisiert den MethodChannel-Handler und registriert den globalen Hotkey.
  Future<void> init();

  /// Deregistriert den Hotkey vorübergehend, damit der Hotkey-Konfiguration-Dialog
  /// die Tastenkombination als normales Key-Event empfangen kann.
  Future<void> unregisterHotkey();

  /// Registriert den Hotkey nach dem Schließen des Konfiguration-Dialogs neu.
  Future<void> reregisterHotkey();

  /// Gibt den Titel des zuletzt aktiven Nicht-FamKey-Fensters zurück.
  Future<String> getLastWindowTitle();

  /// Tippt [username] und [password] per Win32-SendInput in das Zielfenster.
  /// Gibt false zurück, wenn kein gültiges Zielfenster verfügbar ist.
  Future<bool> typeCredentials(String username, String password);
}
