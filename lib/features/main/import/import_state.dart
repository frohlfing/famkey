import 'package:famkey/core/app_error.dart';
import 'package:famkey/features/main/import/import_form_data.dart';

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

  /// Gesamtzahl für die Fortschrittsanzeige.
  final int total;

  // /// Aktueller Wert der Fortschrittsanzeige.
  // final int currentCount;

  /// Die Anzahl der Einträge, die tatsächlich importiert wurden.
  final int added;

  /// Die Anzahl der Einträge, die aufgrund von Duplikaten übersprungen wurden.
  final int skipped;

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

  /// Aktueller Wert für die Fortschrittsanzeige.
  int get currentCount => added + skipped;

  /// Konstruktor
  const ImportState({
    this.formData = const ImportFormData(),
    this.total = 0,
    this.added = 0,
    this.skipped = 0,
    this.isAborting = false,
    this.status = ImportActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  ImportState copyWith({
    ImportFormData? formData,
    int? total,
    int? currentCount,
    int? added,
    int? skipped,
    bool? isAborting,
    ImportActionStatus? status,
    AppError? error,
  }) {
    return ImportState(
      formData: formData ?? this.formData,
      total: total ?? this.total,
      added: added ?? this.added,
      skipped: skipped ?? this.skipped,
      isAborting: isAborting ?? this.isAborting,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
