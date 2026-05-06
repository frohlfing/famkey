import 'dart:async';
import 'package:famkey/core/navigator_key.dart';
import 'package:famkey/services/clipboard_service.dart';
import 'package:famkey/services/database_service.dart';
import 'package:famkey/services/session_service.dart';

/// Sperrt den Tresor automatisch nach konfigurierbarer Inaktivitätsdauer.
///
/// Der Timer wird bei jeder Benutzeraktion (Pointer, Tastatur) zurückgesetzt.
/// Läuft er ab, werden Session und Datenbankverbindung getrennt und die
/// App navigiert zur Login-Seite.
class AutolockService {

  final SessionService _sessionService;
  final DatabaseService _databaseService;
  final ClipboardService _clipboardService;

  Timer? _timer;
  int? _minutes;

  AutolockService(this._sessionService, this._databaseService, this._clipboardService);

  /// Aktiviert oder deaktiviert den Timer.
  /// [minutes] == null deaktiviert die Auto-Sperre.
  void configure(int? minutes) {
    _minutes = minutes;
    _resetTimer();
  }

  /// Setzt den Timer zurück. Wird bei jeder Benutzeraktion aufgerufen.
  void resetTimer() {
    if (_minutes == null) return;
    _resetTimer();
  }

  /// Stoppt den Timer (z. B. bei manuellem Logout).
  void stop() {
    _timer?.cancel();
    _timer = null;
    _minutes = null;
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = null;
    if (_minutes == null) return;
    _timer = Timer(Duration(minutes: _minutes!), _lock);
  }

  void _lock() {
    _timer = null;
    _databaseService.close();
    _sessionService.clearSession();
    _clipboardService.cancelAndClear();
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
  }
}
