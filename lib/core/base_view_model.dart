import 'package:flutter/foundation.dart';

/// Basisklasse für ViewModels.
class BaseViewModel extends ChangeNotifier {
    bool _isBusy = false;
    String? _errorMessage;
    bool get isBusy => _isBusy;
    String? get errorMessage => _errorMessage;

    /// Hilfsmethode, um den Busy-Status zu setzen
    void setBusy(bool value) {
        _isBusy = value;
        notifyListeners();
    }

    /// Hilfsmethode, um Fehler zu setzen
    void setError(String? value) {
        if (value != null) {
            // Stacktrace für Debugging-Zwecke ausgeben
            debugPrint('❌ [VM-ERROR] $value');
            debugPrintStack();
        }
        _errorMessage = value;
        notifyListeners();
    }

    /// Hilfsmethode, um Fehler zurückzusetzen, bevor eine neue Operation startet
    void clearError() {
        _errorMessage = null;
        notifyListeners();
    }
}
