import 'package:privault/core/app_error.dart';
import 'package:privault/features/settings/log_config/log_config_form_data.dart';

/// Status-Enum für die Aktionen im LogConfigDialog
enum LogConfigStatus {
  initial,
  progress,
  loaded,
  saved,
  failure,
}

/// Zustand des Log-Datei-Dialogs.
class LogConfigState {

  /// Die Formulardaten (editierbar durch den Benutzer).
  final LogConfigFormData formData;

  /// Die ursprünglichen Formulardaten beim Laden (für den Dirty-Check).
  final LogConfigFormData originalFormData;

  /// Aktueller Status der letzten Aktion.
  final LogConfigStatus status;

  /// Fehlermeldung (falls status == failure).
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy => status == LogConfigStatus.progress;

  /// Gibt an, ob der Benutzer Log-Einstellungen verändert hat.
  /// (content wird absichtlich nicht verglichen – es ist kein editierbares Feld)
  bool get isDirty =>
      formData.minLevel != originalFormData.minLevel ||
          formData.maxDays != originalFormData.maxDays;

  /// Konstruktor
  const LogConfigState({
    this.formData = const LogConfigFormData(),
    this.originalFormData = const LogConfigFormData(),
    this.status = LogConfigStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  LogConfigState copyWith({
    LogConfigFormData? formData,
    LogConfigFormData? originalFormData,
    LogConfigStatus? status,
    AppError? error,
  }) {
    return LogConfigState(
      formData: formData ?? this.formData,
      originalFormData: originalFormData ?? this.originalFormData,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}