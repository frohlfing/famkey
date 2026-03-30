import 'package:privault/core/app_error.dart';

/// Ein Enum für den Status von Aktionen
enum AdoptIdentityActionStatus {
  initial, // Der Ausgangszustand
  progress, // Aktion läuft
  loaded, // Einstellungen wurden erfolgreich geladen
  saved, // Änderungen wurden erfolgreich gespeichert
  failure, // Aktion mit Fehler beendet
}

class AdoptIdentityState {

  /// Wenn `true`: Zweitgerät soll zum ersten mal synchronisiert werden.
  /// Wenn `false`: Ein anderes Gerät hat das Master-Passwort geändert.
  final bool isOnboarding;

  /// Das aktuelle Master-Passwort.
  final String password;

  // Wird nicht benötigt, denn initial ist das Passwortfeld immer leer.
  //final MasterPasswordFormData originalPassword;

  /// Der Status der letzten Aktion.
  final AdoptIdentityActionStatus status;

  /// Der Fehler der letzten Aktion.
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy =>
    status == AdoptIdentityActionStatus.progress;

  /// Gibt an, ob der Benutzer ein Feld verändert hat.
  // todo wird vermutlich nicht benötigt
  bool get isDirty => password.isNotEmpty;

  /// Konstruktor
  const AdoptIdentityState({
    this.isOnboarding = false,
    this.password = '',
    this.status = AdoptIdentityActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  AdoptIdentityState copyWith({
    bool? isOnboarding,
    String? password,
    AdoptIdentityActionStatus? status,
    AppError? error,
  }) {
    return AdoptIdentityState(
      isOnboarding: isOnboarding ?? this.isOnboarding,
      password: password ?? this.password,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
