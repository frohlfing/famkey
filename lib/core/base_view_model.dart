import 'package:flutter/foundation.dart';

/// Basisklasse für ViewModels.
class BaseViewModel extends ChangeNotifier {
    bool _isBusy = false;
    String? _errorMessage;
    bool get isBusy => _isBusy;
    String? get errorMessage => _errorMessage;

    /// Setzt den Busy-Status und benachrichtigt die View
    void setBusy(bool value) {
        _isBusy = value;
        notifyListeners();
    }

    /// Setzt den Fehlertext und benachrichtigt die View
    void notifyError(String value) {
        _errorMessage = value;
        notifyListeners();
    }

    /// Setzt "Unerwarteter Fehler" als Fehlertext und benachrichtigt die View
    void notifyUnexpectedError() {
      _errorMessage = "Unerwarteter Fehler";
      notifyListeners();
    }

    /// Setzt den Fehlertext zurück und benachrichtigt die View
    void clearError({bool notify = true}) {
      _errorMessage = null;
      if (notify) notifyListeners();
    }

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
