import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/app_file_factory.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/features/settings/log_file/log_file_state.dart';
import 'package:privault/services/config_service.dart';

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
      final content = await _readLogFile();
      state = state.copyWith(
        content: content,
        status: LogFileStatus.loaded,
      );

    } catch (e, st) {
      Logger().error('Fehler beim Laden der Logdatei: $e', context: {'stack': st.toString()});
      state = state.copyWith(
        status: LogFileStatus.failure,
        error: AppError(ErrorCode.unknown, text: 'Logdatei konnte nicht gelesen werden.'),
      );
    }
  }

  // ------------------------------------------------------------------------
  // --- Private Methoden ---
  // ------------------------------------------------------------------------

  /// Liest den Inhalt der Logdatei via [AppFile].
  /// Gibt einen Hinweistext zurück, wenn die Datei nicht existiert.
  Future<String> _readLogFile() async {
    final path = Logger().logPath;
    if (path == null) return '(Logdatei noch nicht initialisiert)';

    final file = createAppFile(path);
    if (!await file.exists()) return '(Keine Logeinträge vorhanden)';

    final lines = await file.readAsLines();
    return lines.join('\n');
  }
}