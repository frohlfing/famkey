import 'dart:typed_data';
import 'package:famkey/core/app_error.dart';
import 'package:famkey/core/app_file.dart';

/// Ein Enum für den Status von Aktionen
enum PreviewActionStatus {
  initial,  // Ausgangszustand
  loading,  // Datei wird geladen
  loaded,   // Datei wurde erfolgreich geladen
  progress, // Aktion läuft (Download oder Drucken)
  success,  // Aktion erfolgreich abgeschlossen
  failure,  // Aktion mit Fehler beendet
}

class PreviewState {

  /// Die Date.
  final AppFile file;

  /// Inhalt der Datei
  final Uint8List? bytes;

  /// Der Status der letzten Aktion.
  final PreviewActionStatus status;

  /// Der Fehler der letzten Aktion.
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy => status == PreviewActionStatus.progress;

  /// Konstruktor
  const PreviewState({
    this.file = const AppFile.none(),
    this.bytes,
    this.status = PreviewActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  PreviewState copyWith({
    AppFile? file,
    String? text,
    Uint8List? bytes,
    PreviewActionStatus? status,
    AppError? error,
  }) {
    return PreviewState(
      file: file ?? this.file,
      bytes: file == AppFile.none() ? null : bytes ?? this.bytes,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
