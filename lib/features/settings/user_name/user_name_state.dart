import 'package:privault/core/app_error.dart';

/// Ein Enum für den Status von Aktionen
enum UserNameActionStatus {
  initial, // Der Ausgangszustand
  progress, // Aktion läuft
  loaded, // Einstellungen wurden erfolgreich geladen
  saved, // Änderungen wurden erfolgreich gespeichert
  failure, // Aktion mit Fehler beendet
}

class UserNameState {

  /// Die Formulardaten.
  final String userName;

  /// Die ursprünglichen Formulardaten (für den Dirty-Check).
  final String originalUserName;

  /// Der Status der letzten Aktion.
  final UserNameActionStatus status;

  /// Der Fehler der letzten Aktion.
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy =>
    status == UserNameActionStatus.progress;

  /// Gibt an, ob der Benutzer ein Feld verändert hat.
  bool get isDirty => userName != originalUserName;

  /// Konstruktor
  const UserNameState({
    this.userName = '',
    this.originalUserName = '',
    this.status = UserNameActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  UserNameState copyWith({
    String? userName,
    String? originalUserName,
    UserNameActionStatus? status,
    AppError? error,
  }) {
    return UserNameState(
      userName: userName ?? this.userName,
      originalUserName: originalUserName ?? this.originalUserName,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
