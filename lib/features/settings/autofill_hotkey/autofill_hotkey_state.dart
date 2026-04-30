import 'package:famkey/core/app_error.dart';

/// Ein Enum für den Status von Aktionen
enum AutofillHotkeyStatus {
  initial, // Der Ausgangszustand
  progress, // Aktion läuft
  loaded, // Einstellungen wurden erfolgreich geladen
  saved, // Änderungen wurden erfolgreich gespeichert
  failure, // Aktion mit Fehler beendet
}

class AutofillHotkeyState {

  /// Die Formulardaten.
  final String hotkey;

  /// Die ursprünglichen Formulardaten (für den Dirty-Check).
  final String originalHotkey;

  /// Der Status der letzten Aktion.
  final AutofillHotkeyStatus status;

  /// Der Fehler der letzten Aktion.
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy =>
    status == AutofillHotkeyStatus.progress;

  /// Gibt an, ob der Benutzer ein Feld verändert hat.
  bool get isDirty => hotkey != originalHotkey;

  /// Konstruktor
  const AutofillHotkeyState({
    this.hotkey = '',
    this.originalHotkey = '',
    this.status = AutofillHotkeyStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  AutofillHotkeyState copyWith({
    String? hotkey,
    String? originalHotkey,
    AutofillHotkeyStatus? status,
    AppError? error,
  }) {
    return AutofillHotkeyState(
      hotkey: hotkey ?? this.hotkey,
      originalHotkey: originalHotkey ?? this.originalHotkey,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
