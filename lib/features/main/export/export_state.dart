import 'dart:typed_data';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/app_file.dart';

/// Ein Enum für den Status von Aktionen
enum ExportActionStatus {
  initial,  // Ausgangszustand
  loading,  // Datei wird geladen
  loaded,   // Datei wurde erfolgreich geladen
  progress, // Aktion läuft (Download oder Drucken)
  success,  // Aktion erfolgreich abgeschlossen
  failure,  // Aktion mit Fehler beendet
}

class ExportState {

  /// Die Markdown-Datei für die Vorschau und zum drucken.
  final AppFile mdFile;

  /// Inhalt der Markdown-Datei
  final Uint8List? mdBytes;

  /// Der Status der letzten Aktion.
  final ExportActionStatus status;

  /// Der Fehler der letzten Aktion.
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy => status == ExportActionStatus.progress;

  /// Konstruktor
  const ExportState({
    this.mdFile = const AppFile.none(),
    this.mdBytes,
    this.status = ExportActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  ExportState copyWith({
    AppFile? mdFile,
    String? text,
    Uint8List? mdBytes,
    ExportActionStatus? status,
    AppError? error,
  }) {
    return ExportState(
      mdFile: mdFile ?? this.mdFile,
      mdBytes: mdFile == AppFile.none() ? null : mdBytes ?? this.mdBytes,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
