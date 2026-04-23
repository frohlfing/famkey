import 'package:privault/core/app_error.dart';
import 'package:privault/features/settings/vault_name/vault_name_form_data.dart';

/// Ein Enum für den Status von Aktionen
enum VaultNameActionStatus {
  initial, // Der Ausgangszustand
  progress, // Aktion läuft
  loaded, // Einstellungen wurden erfolgreich geladen
  saved, // Änderungen wurden erfolgreich gespeichert
  failure, // Aktion mit Fehler beendet
}

class VaultNameState {

  /// Die Formulardaten.
  final VaultNameFormData formData;

  /// Die ursprünglichen Formulardaten (für den Dirty-Check).
  final VaultNameFormData originalFormData;

  /// Der Status der letzten Aktion.
  final VaultNameActionStatus status;

  /// Der Fehler der letzten Aktion.
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy => status == VaultNameActionStatus.progress;

  /// Gibt an, ob der Benutzer ein Feld verändert hat.
  bool get isDirty => formData != originalFormData;

  /// Gibt an, ob der Tresor bereits mit dem Server synchronisiert wurde.
  final bool isSynced;

  /// Konstruktor
  const VaultNameState({
    this.formData = const VaultNameFormData(),
    this.originalFormData = const VaultNameFormData(),
    this.isSynced = false,
    this.status = VaultNameActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  VaultNameState copyWith({
    VaultNameFormData? formData,
    VaultNameFormData? originalFormData,
    bool? isSynced,
    VaultNameActionStatus? status,
    AppError? error,
  }) {
    return VaultNameState(
      formData: formData ?? this.formData,
      originalFormData: originalFormData ?? this.originalFormData,
      isSynced: isSynced ?? this.isSynced,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}