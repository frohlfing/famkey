import 'package:privault/core/app_error.dart';
import 'package:privault/features/settings/password_generator/password_generator_form_data.dart';

/// Ein Enum für den Status von Aktionen
enum MasterPasswordActionStatus {
  initial, // Der Ausgangszustand
  progress, // Aktion läuft
  loaded, // Einstellungen wurden erfolgreich geladen
  saved, // Änderungen wurden erfolgreich gespeichert
  failure, // Aktion mit Fehler beendet
}

class MasterPasswordState {

  /// Die Formulardaten.
  final PasswordGeneratorFormData formData;

  /// Der ursprünglichen Formulardaten (für den Dirty-Check).
  final PasswordGeneratorFormData originalFormData;

  /// Der Status der letzten Aktion.
  final MasterPasswordActionStatus status;

  /// Der Fehler der letzten Aktion.
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy =>
      status == MasterPasswordActionStatus.progress;

  /// Gibt an, ob der Benutzer ein Feld verändert hat.
  bool get isDirty => formData != originalFormData;

  /// Konstruktor
  const MasterPasswordState({
    this.formData = const PasswordGeneratorFormData(),
    this.originalFormData = const PasswordGeneratorFormData(),
    this.status = MasterPasswordActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  MasterPasswordState copyWith({
    PasswordGeneratorFormData? formData,
    PasswordGeneratorFormData? originalFormData,
    MasterPasswordActionStatus? status,
    AppError? error,
  }) {
    return MasterPasswordState(
      formData: formData ?? this.formData,
      originalFormData: originalFormData ?? this.originalFormData,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
