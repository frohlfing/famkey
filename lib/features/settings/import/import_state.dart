import 'package:privault/core/app_error.dart';
import 'package:privault/features/settings/import/import_form_data.dart';
import 'package:privault/features/settings/import/import_statistics.dart';

/// Ein Enum für den Status von Aktionen
enum ImportActionStatus {
  initial, // Der Ausgangszustand (der Benutzer wählt eine Datei aus)
  parse, // Datei wird geparst
  import, // Einträge werden importiert
  success, // Importprozess wurde erfolgreich abgeschlossen
  failure, // Aktion mit Fehler beendet
}

class ImportState {

  /// Die Formulardaten.
  final ImportFormData formData;

  /// Die ursprünglichen Formulardaten (für den Dirty-Check).
  final ImportFormData originalFormData;

  /// Die Sync-Statistik nach erfolgreicher Durchführung.
  final ImportStatistics? statistics;

  /// Der Status der letzten Aktion.
  final ImportActionStatus status;

  /// Der Fehler der letzten Aktion.
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy =>
    status == ImportActionStatus.parse ||
    status == ImportActionStatus.import;

  /// Gibt an, ob der Benutzer ein Feld verändert hat.
  bool get isDirty => formData != originalFormData;

  /// Konstruktor
  const ImportState({
    this.formData = const ImportFormData(),
    this.originalFormData = const ImportFormData(),
    this.statistics = const ImportStatistics(),
    this.status = ImportActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  ImportState copyWith({
    ImportFormData? formData,
    ImportFormData? originalFormData,
    ImportStatistics? statistics,
    ImportActionStatus? status,
    AppError? error,
  }) {
    return ImportState(
      formData: formData ?? this.formData,
      originalFormData: originalFormData ?? this.originalFormData,
      statistics: statistics ?? this.statistics,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
