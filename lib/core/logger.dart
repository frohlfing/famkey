import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

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
/// - Ist Thread-Safe
class Logger {
  /// Singleton-Instanz
  static final Logger _instance = Logger._internal();

  factory Logger() => _instance;

  Logger._internal();

  /// Logdatei
  late final File _logFile;
  bool _initialized = false;

  /// Minimaler Log-Level, der geschrieben wird
  LogLevel minLevel = LogLevel.info;

  /// Maximale Anzahl an Tagen, die in der Log-Datei aufbewahrt wird
  int maxDays = 7;

  /// Initialisierung (wird einmalig beim App-Start aufgerufen)
  Future<void> init({required LogLevel minLevel, required int maxDays}) async {
    if (_initialized) return;
    _initialized = true;
    configure(minLevel: minLevel, maxDays: maxDays);
    final dir = await getApplicationSupportDirectory();
    _logFile = File('${dir.path}/privault.log');
    await _cleanupOldEntries();
  }

  /// Setzt Konfigurationsparameter
  void configure({LogLevel? minLevel, int? maxDays}) {
    if (minLevel != null) this.minLevel = minLevel;
    if (maxDays != null) this.maxDays = maxDays;
  }

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
    if (level.priority < minLevel.priority) return;

    // Bei Unit-Tests nicht schreiben
    bool isTestEnvironment = Platform.environment.containsKey('FLUTTER_TEST');
    if (isTestEnvironment) return;

    // Zeile generieren
    final timestamp = DateTime.now().toIso8601String();
    var line = '[$timestamp] $level: $message';
    if (context != null && context.isNotEmpty) {
      line += ' ${context.toString()}';
    }

    // Im Debug-Mode zusätzlich in die Konsole ausgeben
    if (kDebugMode) {
      debugPrint('❌ $line');
      if (stack != null) {
        debugPrintStack(stackTrace: stack, maxFrames: 5);
      }
    }

    // Datei schreiben
    await _logFile.writeAsString('\n$line\n', mode: FileMode.append);
    if (stack != null) {
      final readable = _getReadableStackTrace(stack, maxFrames: 5);
      await _logFile.writeAsString('$readable\n', mode: FileMode.append);
    }
  }

  // ------------------------------------------------------------------------
  // Log-Rotation
  // ------------------------------------------------------------------------

  /// Löscht Einträge, die älter als X Tage sind
  Future<void> _cleanupOldEntries() async {
    if (!await _logFile.exists()) return;

    final lines = await _logFile.readAsLines();
    final cutoff = DateTime.now().subtract(Duration(days: maxDays));

    final filtered = lines.where((line) {
      if (!line.startsWith('[')) return true;
      final end = line.indexOf(']');
      if (end < 0) return true;

      final ts = DateTime.tryParse(line.substring(1, end));
      return ts == null || ts.isAfter(cutoff);
    }).toList();

    await _logFile.writeAsString(filtered.join('\n'));
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
