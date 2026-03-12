import 'package:flutter/foundation.dart';
import 'package:privault/core/command_result.dart';

import 'app_error.dart';

/// Basisklasse für alle ViewModels in der App.
///
/// Sie bietet Standard-Funktionen für:
/// * Lade-Zustände (isBusy)
/// * Allgemeine Fehlermeldungen (errorMessage)
/// * Feld-spezifische Validierungsfehler (fieldErrors)
abstract class BaseViewModel extends ChangeNotifier {

  // ------------------------------------------------------------------------
  // --- Interne Variablen ---
  // ------------------------------------------------------------------------

  bool _isBusy = false; // Gibt an, ob ein Ladesymbol angezeigt wird
  var _result = CommandResult<int>(); // Ergebnis der letzten Operation

  // ------------------------------------------------------------------------
  // --- Eigenschaften und Methoden für den Lade-Status ---
  // ------------------------------------------------------------------------

  /// Gibt an, ob ein Ladesymbol angezeigt wird
  bool get isBusy => _isBusy;

  /// Setzt den Busy-Status und benachrichtigt die UI, damit z.B. ein Ladekreis erscheint.
  void setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  // ------------------------------------------------------------------------
  // --- Methoden für die Fehlerbehandlung ---
  // ------------------------------------------------------------------------

  /// Ergebnis der letzten Operation
  CommandResult<int> get result => _result;

  /// Setzt ein positives Ergebnis
  CommandResult<int> notifySuccess([int value = 0]) {
    _result = CommandResult<int>.success(value);
    notifyListeners();
    return _result;
  }

  /// Setzt ein negatives Ergebnis
  CommandResult<int> notifyError(ErrorCode error, {String? message, String? field}) {
    _result = CommandResult.failure(error, message: message, field: field);
    notifyListeners();
    return _result;
  }

  /// Löscht den Fehler eines einzelnen Feldes (z.B. wenn der Nutzer anfängt zu tippen).
  void clearFieldError(String field) {
    if (_result.field == field) {
      _result = CommandResult<int>();
      notifyListeners();
    }
  }

  /// Löscht alle aktuellen Fehler (allgemeine und Feld-Fehler).
  /// [notify] steuert, ob die UI sofort informiert werden soll.
  void clearError({bool notify = true}) {
    _result = CommandResult<int>();
    if (notify) notifyListeners();
  }

  /// Fehlermeldung (allgemein, nicht auf ein Eingabefeld bezogen)
  String? get errorMessage => _result.errorMessage;

  /// Gibt zurück, ob aktuell irgendwo ein Fehler vorliegt.
  bool get hasError => _result.hasError;

  /// Gibt die Fehlermeldung für ein bestimmtes Feld zurück oder null.
  String? getFieldError(String field) => _result.getFieldError(field);

  // --- Logging ---

  /// Protokolliert den Fehler.
  void logError(dynamic msg, [StackTrace? stackTrace]) {
    // todo In Textdatei schreiben
    debugPrint('❌ [VM-ERROR] $msg');
    if (stackTrace != null) debugPrintStack(stackTrace: stackTrace, maxFrames: 3);
  }

  /// Protokolliert die Warnung.
  void logWarn(dynamic msg, [StackTrace? stackTrace]) {
    // todo In Textdatei schreiben
    debugPrint('⚠️ [VM-WARN] $msg');
    if (stackTrace != null) debugPrintStack(stackTrace: stackTrace, maxFrames: 3);
  }

  /// Protokolliert den Hinweis.
  void logDebug(dynamic msg, [StackTrace? stackTrace]) {
    // todo In Textdatei schreiben
    debugPrint('ℹ️ [VM-DEBUG] $msg');
    if (stackTrace != null) debugPrintStack(stackTrace: stackTrace, maxFrames: 3);
  }
}
