import 'package:famkey/core/app_error.dart';

/// Ein Enum für den Status von Aktionen
enum AutotypeHotkeyStatus {
  initial, // Der Ausgangszustand
  progress, // Aktion läuft
  loaded, // Einstellungen wurden erfolgreich geladen
  saved, // Änderungen wurden erfolgreich gespeichert
  failure, // Aktion mit Fehler beendet
}

class AutotypeHotkeyState {

  /// Die Formulardaten.
  final String hotkey;

  /// Die ursprünglichen Formulardaten (für den Dirty-Check).
  final String originalHotkey;

  /// Der Status der letzten Aktion.
  final AutotypeHotkeyStatus status;

  /// Der Fehler der letzten Aktion.
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy =>
    status == AutotypeHotkeyStatus.progress;

  /// Gibt an, ob der Benutzer ein Feld verändert hat.
  bool get isDirty => hotkey != originalHotkey;

  /// Konstruktor
  const AutotypeHotkeyState({
    this.hotkey = '',
    this.originalHotkey = '',
    this.status = AutotypeHotkeyStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  AutotypeHotkeyState copyWith({
    String? hotkey,
    String? originalHotkey,
    AutotypeHotkeyStatus? status,
    AppError? error,
  }) {
    return AutotypeHotkeyState(
      hotkey: hotkey ?? this.hotkey,
      originalHotkey: originalHotkey ?? this.originalHotkey,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
