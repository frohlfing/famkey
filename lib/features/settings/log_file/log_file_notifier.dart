import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famkey/core/app_error.dart';
import 'package:famkey/core/app_file.dart';
import 'package:famkey/core/logger.dart';
import 'package:famkey/features/settings/log_file/log_file_state.dart';
import 'package:famkey/services/config_service.dart';

final logFileProvider = NotifierProvider<LogFileNotifier, LogFileState>(() {
  return LogFileNotifier();
});

/// Notifier für den Log-Datei-Dialog.
///
/// Lädt den Inhalt der Logdatei und ermöglicht das Anpassen
/// von [LogLevel] und [maxDays] in der [ConfigService]-Konfiguration.
class LogFileNotifier extends Notifier<LogFileState> {

  // ------------------------------------------------------------------------
  // --- Initialisierung ---
  // ------------------------------------------------------------------------

  @override
  LogFileState build() {
    return const LogFileState();
  }

  // ------------------------------------------------------------------------
  // --- Öffentliche Methoden ---
  // ------------------------------------------------------------------------

  /// Lädt Logdatei-Inhalt
  Future<void> load() async {
    if (state.isBusy) return;
    state = const LogFileState().copyWith(status: LogFileStatus.progress);

    try {
      final path = Logger().logPath;
      if (path == null) throw Exception('Logdatei wurde nicht initialisiert');
      final file = AppFile(path);
      final exists = await file.exists();
      //final content = exists ? (await file.readAsLines()).join('\n') : '';
      final content = exists ? await file.readAsString() : '';

      state = state.copyWith(
        content: content,
        status: LogFileStatus.loaded,
      );

    } catch (e, st) {
      log.error('Fehler beim Laden der Logdatei: $e', context: {'stack': st.toString()});
      state = state.copyWith(
        status: LogFileStatus.failure,
        error: AppError(ErrorCode.unknown, text: 'Logdatei konnte nicht gelesen werden.'),
      );
    }
  }

  /// Löscht die Einträge aus der Logdatei.
  Future<void> clearFile() async {
    if (state.isBusy) return;
    state = const LogFileState().copyWith(status: LogFileStatus.progress);

    try {
      final path = Logger().logPath;
      if (path == null) throw Exception('Logdatei wurde nicht initialisiert');
      final file = AppFile(path);
      final exists = await file.exists();
      if (exists) await file.writeAsString('');

      state = state.copyWith(
        content: '',
        status: LogFileStatus.loaded,
      );

    } catch (e, st) {
      log.error('Fehler beim Laden der Logdatei: $e', context: {'stack': st.toString()});
      state = state.copyWith(
        status: LogFileStatus.failure,
        error: AppError(ErrorCode.unknown, text: 'Logdatei konnte nicht gelesen werden.'),
      );
    }
  }
}