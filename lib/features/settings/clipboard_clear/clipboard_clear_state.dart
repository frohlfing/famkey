import 'package:famkey/core/app_error.dart';

/// Ein Enum für den Status von Aktionen
enum ClipboardClearActionStatus {
  initial, // Der Ausgangszustand
  progress, // Aktion läuft
  loaded, // Einstellungen wurden erfolgreich geladen
  saved, // Änderungen wurden erfolgreich gespeichert
  failure, // Aktion mit Fehler beendet
}

class ClipboardClearState {

  /// Der ausgewählte Wert (0 = Nie, sonst Sekunden).
  final int selectedValue;

  /// Der Status der letzten Aktion.
  final ClipboardClearActionStatus status;

  /// Der Fehler der letzten Aktion.
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy => status == ClipboardClearActionStatus.progress;

  /// Konstruktor
  const ClipboardClearState({
    this.selectedValue = 30,
    this.status = ClipboardClearActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  ClipboardClearState copyWith({
    int? selectedValue,
    ClipboardClearActionStatus? status,
    AppError? error,
  }) {
    return ClipboardClearState(
      selectedValue: selectedValue ?? this.selectedValue,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
