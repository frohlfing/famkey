import 'package:famkey/core/app_error.dart';

/// Ein Enum für den Status von Aktionen
enum AutolockActionStatus {
  initial, // Der Ausgangszustand
  progress, // Aktion läuft
  loaded, // Einstellungen wurden erfolgreich geladen
  saved, // Änderungen wurden erfolgreich gespeichert
  failure, // Aktion mit Fehler beendet
}

class AutolockState {

  /// Der ausgewählte Wert (0 = Nie, sonst Minuten).
  final int selectedValue;

  /// Der Status der letzten Aktion.
  final AutolockActionStatus status;

  /// Der Fehler der letzten Aktion.
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy => status == AutolockActionStatus.progress;

  /// Konstruktor
  const AutolockState({
    this.selectedValue = 0,
    this.status = AutolockActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  AutolockState copyWith({
    int? selectedValue,
    AutolockActionStatus? status,
    AppError? error,
  }) {
    return AutolockState(
      selectedValue: selectedValue ?? this.selectedValue,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
