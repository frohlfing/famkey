import 'dart:typed_data';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/app_file.dart';
import 'package:privault/features/main/export/export_form_data.dart';

/// Ein Enum für den Status von Aktionen
enum ExportActionStatus {
  initial,  // Ausgangszustand
  loading,  // Die Daten werden geladen und die Exportdatei generiert.
  loaded,   // Ladevorgang abgeschlossen. Die Markdowndatei kann gedruckt und die Exportdatei gespeichert werden.
  aborted,  // Der Ladevorgang wurde abgebrochen. Der Dialog wird geschlossen.
  progress, // Druck- oder Speichervorgang läuft.
  success,  // Speichervorgang erfolgreich abgeschlossen. Der Dialog kann geschlossen werden.
  failure,  // Aktion mit Fehler beendet
}

class ExportState {

  /// Formulardaten (Verschlüsselungsverfahren, Passwort).
  final ExportFormData formData;

  /// Die Markdown-Datei für die Vorschau und zum Drucken.
  final AppFile mdFile;

  /// Inhalt der Markdown-Datei.
  final Uint8List? mdBytes;

  /// Gesamtzahl für die Fortschrittsanzeige.
  final int total;

  /// Bereits verarbeitete Einträge für die Fortschrittsanzeige.
  final int processed;

  /// true, wenn der Benutzer den laufenden Vorgang abbrechen möchte.
  final bool isAborting;

  /// Der Status der letzten Aktion.
  final ExportActionStatus status;

  /// Der Fehler der letzten Aktion.
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy => status == ExportActionStatus.progress ||
                     status == ExportActionStatus.loading;

  /// Konstruktor
  const ExportState({
    this.formData = const ExportFormData(),
    this.mdFile = const AppFile.none(),
    this.mdBytes,
    this.total = 0,
    this.processed = 0,
    this.isAborting = false,
    this.status = ExportActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  ExportState copyWith({
    ExportFormData? formData,
    AppFile? mdFile,
    Uint8List? mdBytes,
    int? total,
    int? processed,
    bool? isAborting,
    ExportActionStatus? status,
    AppError? error,
  }) {
    return ExportState(
      formData: formData ?? this.formData,
      mdFile: mdFile ?? this.mdFile,
      mdBytes: mdFile == const AppFile.none() ? null : mdBytes ?? this.mdBytes,
      total: total ?? this.total,
      processed: processed ?? this.processed,
      isAborting: isAborting ?? this.isAborting,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}