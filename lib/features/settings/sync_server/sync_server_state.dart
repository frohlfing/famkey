import 'package:famkey/core/app_error.dart';
import 'package:famkey/features/settings/sync_server/sync_server_form_data.dart';

/// Ein Enum für den Status von Aktionen
enum SyncServerActionStatus {
  initial, // Der Ausgangszustand
  progress, // Aktion läuft
  loaded, // Einstellungen wurden erfolgreich geladen
  saved, // Änderungen wurden erfolgreich gespeichert
  testSuccessful, // Test erfolgreich beendet
  failure, // Aktion mit Fehler beendet
}

class SyncServerState {

  /// Die Formulardaten.
  final SyncServerFormData formData;

  /// Die ursprünglichen Formulardaten (für den Dirty-Check).
  final SyncServerFormData originalFormData;

  /// Der Status der letzten Aktion.
  final SyncServerActionStatus status;

  /// Der Fehler der letzten Aktion.
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy =>
    status == SyncServerActionStatus.progress;

  /// Gibt an, ob der Benutzer ein Feld verändert hat.
  bool get isDirty => formData != originalFormData;

  /// Konstruktor
  const SyncServerState({
    this.formData = const SyncServerFormData(),
    this.originalFormData = const SyncServerFormData(),
    this.status = SyncServerActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  SyncServerState copyWith({
    SyncServerFormData? formData,
    SyncServerFormData? originalFormData,
    SyncServerActionStatus? status,
    AppError? error,
  }) {
    return SyncServerState(
      formData: formData ?? this.formData,
      originalFormData: originalFormData ?? this.originalFormData,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
