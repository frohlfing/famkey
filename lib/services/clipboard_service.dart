import 'dart:async';
import 'package:flutter/services.dart';
import 'package:privault/services/config_service.dart';

/// Kapselt alle Zwischenablage-Operationen und leert die Ablage nach konfigurierbarer Zeit.
class ClipboardService {

  final ConfigService _configService;
  Timer? _timer;

  ClipboardService(this._configService);

  /// Kopiert [text] in die Zwischenablage und startet den Clear-Timer.
  void copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _timer?.cancel();
    final seconds = _configService.clipboardClearSeconds;
    if (seconds != null) {
      _timer = Timer(Duration(seconds: seconds), _clear);
    }
  }

  /// Bricht den laufenden Timer ab und leert die Zwischenablage sofort.
  ///
  /// Wird durch Benutzeraktionen aufgerufen (Logout, manuelle Sperre), daher
  /// auf Web in der Regel erlaubt.
  void cancelAndClear() {
    _timer?.cancel();
    _timer = null;
    Clipboard.setData(const ClipboardData(text: '')).catchError((_) {});
  }

  void _clear() {
    _timer = null;
    // Auf Web schlägt das Leeren ohne Benutzeraktivierung lautlos fehl (Browser-Sicherheitsmodell).
    Clipboard.setData(const ClipboardData(text: '')).catchError((_) {});
  }
}
