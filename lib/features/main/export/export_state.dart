import 'dart:typed_data';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/app_file.dart';
import 'package:privault/features/main/export/export_form_data.dart';

/// Ein Enum für den Status von Aktionen
enum ExportActionStatus {
  initial,  // Ausgangszustand
  loading,  // Markdown wird generiert
  loaded,   // Markdown wurde generiert, Vorschau bereit
  progress, // Export läuft
  success,  // Aktion erfolgreich abgeschlossen
  failure,  // Aktion mit Fehler beendet
}

class ExportState {

  /// Die Markdown-Datei für die Vorschau und zum Drucken.
  final AppFile mdFile;

  /// Inhalt der Markdown-Datei.
  final Uint8List? mdBytes;

  /// Formulardaten (Verschlüsselung, Passwort).
  final ExportFormData formData;

  /// Der Status der letzten Aktion.
  final ExportActionStatus status;

  /// Der Fehler der letzten Aktion.
  final AppError error;

  // --- Getter ---

  bool get isBusy => status == ExportActionStatus.progress ||
                     status == ExportActionStatus.loading;

  /// Konstruktor
  const ExportState({
    this.mdFile = const AppFile.none(),
    this.mdBytes,
    this.formData = const ExportFormData(),
    this.status = ExportActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  ExportState copyWith({
    AppFile? mdFile,
    Uint8List? mdBytes,
    ExportFormData? formData,
    ExportActionStatus? status,
    AppError? error,
  }) {
    return ExportState(
      mdFile: mdFile ?? this.mdFile,
      mdBytes: mdFile == const AppFile.none() ? null : mdBytes ?? this.mdBytes,
      formData: formData ?? this.formData,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}