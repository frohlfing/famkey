import 'package:flutter/foundation.dart';

class BaseViewModel extends ChangeNotifier {
  bool _isBusy = false;
  String? _errorMessage;

  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  void setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  void setError(String? value) {
    _errorMessage = value;
    notifyListeners();
  }

  /// Hilfsmethode, um Fehler zurückzusetzen, bevor eine neue Operation startet
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
