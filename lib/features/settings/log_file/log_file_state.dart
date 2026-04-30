import 'package:famkey/core/app_error.dart';

/// Status-Enum für die Aktionen im LogFileDialog
enum LogFileStatus {
  initial,
  progress,
  loaded,
  saved,
  failure,
}

/// Zustand des Log-Datei-Dialogs.
class LogFileState {

  /// Inhalt der Logdatei
  final String content;

  /// Aktueller Status der letzten Aktion.
  final LogFileStatus status;

  /// Fehlermeldung (falls status == failure).
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy => status == LogFileStatus.progress;

  /// Konstruktor
  const LogFileState({
    this.content = '',
    this.status = LogFileStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  LogFileState copyWith({
    String? content,
    LogFileStatus? status,
    AppError? error,
  }) {
    return LogFileState(
      content: content ?? this.content,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}