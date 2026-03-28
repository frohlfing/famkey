import 'package:privault/core/app_error.dart';
import 'package:privault/features/settings/master_password/master_password_form_data.dart';

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
  final MasterPasswordFormData formData;

  // Wird nicht benötigt, denn initial sind die Passwortfelder immer leer.
  //final MasterPasswordFormData originalFormData;

  /// Die berechnete Passwortstärke.
  final int passwordStrength;

  /// Der Status der letzten Aktion.
  final MasterPasswordActionStatus status;

  /// Der Fehler der letzten Aktion.
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy =>
    status == MasterPasswordActionStatus.progress;

  /// Gibt an, ob der Benutzer ein Feld verändert hat.
  // todo wird vermutlich nicht benötigt
  bool get isDirty =>
    formData.newPassword.isNotEmpty ||
    formData.password.isNotEmpty;

  /// Konstruktor
  const MasterPasswordState({
    this.formData = const MasterPasswordFormData(),
    this.passwordStrength = 0,
    this.status = MasterPasswordActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  MasterPasswordState copyWith({
    MasterPasswordFormData? formData,
    int? passwordStrength,
    MasterPasswordActionStatus? status,
    AppError? error,
  }) {
    return MasterPasswordState(
      formData: formData ?? this.formData,
      passwordStrength: passwordStrength ?? this.passwordStrength,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
