import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:famkey/core/app_file.dart';
import 'package:famkey/core/env.dart';

/// Globale Zugriffsvariable (Kurzform für Logger())
final log = Logger();

enum LogLevel {
  debug,
  info,
  warn,
  error,
  fatal;

  /// Priorität
  int get priority {
    // @formatter:off
    switch (this) {
      case LogLevel.debug: return 0;
      case LogLevel.info: return 1;
      case LogLevel.warn: return 2;
      case LogLevel.error: return 3;
      case LogLevel.fatal: return 4;
    }
    // @formatter:on
  }

  /// Enum aus String
  static LogLevel fromName(String name) {
    return LogLevel.values.firstWhere((lvl) => lvl.name == name, orElse: () => LogLevel.info);
  }

  /// Enum aus int
  static LogLevel fromPriority(int value) {
    return LogLevel.values.firstWhere((lvl) => lvl.priority == value, orElse: () => LogLevel.info);
  }
}

/// Diese Klasse schreibt Nachrichten in eine Logdatei.
/// - Schreibt Log-Einträge in eine Datei.
/// - Behält die letzten X Tage im Log.
/// - Gibt im Debug-Modus zusätzlich in die Konsole aus.
/// - Thread-Safe
class Logger {
  /// Singleton-Instanz
  static final Logger _instance = Logger._internal();
  factory Logger() => _instance;
  Logger._internal(); /// privater benannter Konstruktor

  /// Logdatei
  late final AppFile _logFile;
  bool _initialized = false;

  /// Minimaler Log-Level, der geschrieben wird
  /// Default: INFO
  LogLevel _level = LogLevel.info;

  /// Maximale Anzahl an Tagen, die in der Log-Datei aufbewahrt wird
  /// Default: 7 Tage.
  int _days = 7;

  /// Maximale Dateigröße in Bytes, ab der ältere Einträge abgeschnitten werden.
  /// Default: 512 KB.
  int _size = 512 * 1024;

  /// Initialisierung
  /// Wird einmalig in `main()` aufgerufen (nach `env.init();`).
  Future<void> init({required LogLevel level, required int days, required int size}) async {
    if (_initialized) return;
    _initialized = true;
    configure(level: level, days: days, size: size);
    final path = p.join(env.storagePath, 'FamKey.log');
    _logFile = AppFile(path);
    await _cleanupOldEntries();
  }

  /// Setzt Konfigurationsparameter
  void configure({LogLevel? level, int? days, int? size}) {
    if (level != null) _level = level;
    if (days != null) _days = days;
    if (size != null) _size = size;
  }

  /// Absoluter Pfad zur Logdatei.
  /// Gibt [null] zurück, solange [init] noch nicht aufgerufen wurde.
  String? get logPath => _initialized ? _logFile.path : null;

  // ------------------------------------------------------------------------
  // Öffentliche Methoden
  // ------------------------------------------------------------------------

  /// Loggt eine Debug-Message.
  Future<void> debug(String message, {Map<String, dynamic>? context}) => _write(LogLevel.debug, message, context);

  /// Loggt eine Information.
  Future<void> info(String message, {Map<String, dynamic>? context}) => _write(LogLevel.info, message, context);

  /// Loggt eine Warnung.
  Future<void> warn(String message, {Map<String, dynamic>? context}) => _write(LogLevel.warn, message, context);

  /// Loggt einen Fehler.
  Future<void> error(String message, {Map<String, dynamic>? context}) => _write(LogLevel.error, message, context);

  /// Loggt einen unbehandelten/unerwarteten Fehler.
  Future<void> fatal(String message, {Map<String, dynamic>? context, StackTrace? stack}) => _write(LogLevel.fatal, message, context, stack: stack);

  // ------------------------------------------------------------------------
  // Private Methoden
  // ------------------------------------------------------------------------

  Future<void> _write(LogLevel level, String message, Map<String, dynamic>? context, {StackTrace? stack}) async {
    if (!_initialized) return;
    if (level.priority < _level.priority) return;

    // Bei Unit-Tests nicht schreiben
    if (env.isTest) return;

    // Zeile generieren
    final timestamp = DateTime.now().toUtc().toIso8601String();
    var line = '[$timestamp] $level: $message';
    if (context != null && context.isNotEmpty) {
      line += ' ${context.toString()}';
    }

    // Im Debug-Mode zusätzlich in die Konsole ausgeben
    if (kDebugMode) {
      debugPrint('🪲 $line');
      if (stack != null) {
        debugPrintStack(stackTrace: stack, maxFrames: 5);
      }
    }

    // Datei schreiben
    final buffer = StringBuffer('\n$line\n');
    if (stack != null) buffer.write('${_getReadableStackTrace(stack, maxFrames: 5)}\n');
    await _logFile.writeAsString(buffer.toString(), append: true);
  }

  // ------------------------------------------------------------------------
  // Log-Rotation
  // ------------------------------------------------------------------------

  /// Löscht Einträge, die älter als [maxDays] sind, und kürzt die Datei,
  /// wenn sie die maximale Größe [_size] überschreitet.
  ///
  /// Die kombinierte Strategie hält die Logdatei dauerhaft klein:
  /// 1. **Altersbasiert:** Zeilen mit einem Zeitstempel älter als [maxDays] werden entfernt.
  /// 2. **Größenbasiert:** Überschreitet die Datei nach Schritt 1 noch immer
  ///    [_size], werden ältere Zeilen vom Anfang abgeschnitten, bis die Datei
  ///    wieder unter dem Schwellwert liegt. Dabei werden immer nur vollständige
  ///    Log-Einträge entfernt (keine Zeilenrisse mitten in einem Eintrag).
  Future<void> _cleanupOldEntries() async {
    if (!await _logFile.exists()) return;

    var lines = await _logFile.readAsLines();

    // --- 1. Altersbasierter Cleanup ---
    final cutoff = DateTime.now().toUtc().subtract(Duration(days: _days));
    lines = lines.where((line) {
      if (!line.startsWith('[')) return true;
      final end = line.indexOf(']');
      if (end < 0) return true;
      final ts = DateTime.tryParse(line.substring(1, end));
      return ts == null || ts.isAfter(cutoff);
    }).toList();

    // --- 2. Größenbasierter Cleanup ---
    // Ungefähre Größe berechnen (1 Byte pro Zeichen + Zeilenumbruch, ausreichend für ASCII-Logs)
    var approxSize = lines.fold<int>(0, (sum, l) => sum + l.length + 1);
    if (approxSize > _size) {
      // Zeilen vom Anfang entfernen, bis die Datei klein genug ist.
      // Es wird immer an einer Eintragsgrenze (Zeile beginnt mit '[') geschnitten,
      // damit kein Eintrag halbiert wird.
      var removeUntil = 0;
      for (var i = 1; i < lines.length && approxSize > _size; i++) {
        if (lines[i].startsWith('[')) {
          approxSize -= lines
              .sublist(removeUntil, i)
              .fold<int>(0, (s, l) => s + l.length + 1);
          removeUntil = i;
        }
      }
      if (removeUntil > 0) lines = lines.sublist(removeUntil);
    }

    await _logFile.writeAsString(lines.join('\n'));
  }
}

/// Bereitet den Stacktrace auf (so wie `debugPrintStack`)
String _getReadableStackTrace(StackTrace stackTrace, {int? maxFrames}) {
  Iterable<String> lines = FlutterError.demangleStackTrace(stackTrace).toString().trimRight().split('\n');
  if (kIsWeb && lines.isNotEmpty) {
    // Remove extra call to StackTrace.current for web platform.
    lines = lines.skipWhile((String line) {
      return line.contains('StackTrace.current') || line.contains('dart-sdk/lib/_internal') || line.contains('dart:sdk_internal');
    });
  }
  if (maxFrames != null) {
    lines = lines.take(maxFrames);
  }
  return FlutterError.defaultStackFilter(lines).join('\n');
}