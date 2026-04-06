import 'package:privault/core/app_error.dart';
import 'package:privault/features/main/import/import_form_data.dart';

/// Ein Enum für den Status von Aktionen
enum ImportActionStatus {
  initial, // Der Ausgangszustand (der Benutzer wählt eine Datei aus)
  progress, // Aktion läuft
  success, // Importprozess wurde erfolgreich abgeschlossen
  failure, // Aktion mit Fehler beendet
}

class ImportState {

  /// Die Formulardaten.
  final ImportFormData formData;

  /// Die ursprünglichen Formulardaten (für den Dirty-Check).
  final ImportFormData originalFormData; // todo wird nicht benötigt

  /// Gesamtzahl für die Fortschrittsanzeige.
  final int totalCount; // todo umbenennen in total

  // /// Aktueller Wert der Fortschrittsanzeige.
  // final int currentCount;

  /// Die Anzahl der Einträge, die tatsächlich importiert wurden.
  final int addedCount; // todo umbenennen in added

  /// Die Anzahl der Einträge, die aufgrund von Duplikaten übersprungen wurden.
  final int skippedCount; // todo umbenennen in skipped

  /// Wird gesetzt, wenn der Benutzer den Import abbrechen möchte.
  final bool isAborting;

  /// Der Status der letzten Aktion.
  final ImportActionStatus status;

  /// Der Fehler der letzten Aktion.
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy =>
    status == ImportActionStatus.progress;

  /// Gibt an, ob der Benutzer ein Feld verändert hat.
  bool get isDirty => formData != originalFormData; // todo wird nicht benötigt

  /// Aktueller Wert für die Fortschrittsanzeige.
  int get currentCount => addedCount + skippedCount; // todo umbenennen in progress

  /// Konstruktor
  const ImportState({
    this.formData = const ImportFormData(),
    this.originalFormData = const ImportFormData(),
    this.totalCount = 0,
    this.addedCount = 0,
    this.skippedCount = 0,
    this.isAborting = false,
    this.status = ImportActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  ImportState copyWith({
    ImportFormData? formData,
    ImportFormData? originalFormData,
    int? totalCount,
    int? currentCount,
    int? addedCount,
    int? skippedCount,
    bool? isAborting,
    ImportActionStatus? status,
    AppError? error,
  }) {
    return ImportState(
      formData: formData ?? this.formData,
      originalFormData: originalFormData ?? this.originalFormData,
      totalCount: totalCount ?? this.totalCount,
      addedCount: addedCount ?? this.addedCount,
      skippedCount: skippedCount ?? this.skippedCount,
      isAborting: isAborting ?? this.isAborting,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
