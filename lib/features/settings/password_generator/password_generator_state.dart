import 'package:privault/core/app_error.dart';
import 'package:privault/features/settings/password_generator/password_generator_form_data.dart';

/// Ein Enum für den Status von Aktionen
enum PasswordGeneratorActionStatus {
  initial, // Der Ausgangszustand
  progress, // Aktion läuft
  loaded, // Einstellungen wurden erfolgreich geladen
  saved, // Änderungen wurden erfolgreich gespeichert
  failure, // Aktion mit Fehler beendet
}

class PasswordGeneratorState {

  /// Die Formulardaten.
  final PasswordGeneratorFormData formData;

  /// Der ursprünglichen Formulardaten (für den Dirty-Check).
  final PasswordGeneratorFormData originalFormData;

  /// Der Status der letzten Aktion.
  final PasswordGeneratorActionStatus status;

  /// Der Fehler der letzten Aktion.
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy =>
      status == PasswordGeneratorActionStatus.progress;

  /// Gibt an, ob der Benutzer ein Feld verändert hat.
  bool get isDirty => formData != originalFormData;

  /// Konstruktor
  const PasswordGeneratorState({
    this.formData = const PasswordGeneratorFormData(),
    this.originalFormData = const PasswordGeneratorFormData(),
    this.status = PasswordGeneratorActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  PasswordGeneratorState copyWith({
    PasswordGeneratorFormData? formData,
    PasswordGeneratorFormData? originalFormData,
    PasswordGeneratorActionStatus? status,
    AppError? error,
  }) {
    return PasswordGeneratorState(
      formData: formData ?? this.formData,
      originalFormData: originalFormData ?? this.originalFormData,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
