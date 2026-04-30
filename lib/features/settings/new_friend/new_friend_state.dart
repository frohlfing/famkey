import 'package:famkey/core/app_error.dart';

/// Ein Enum für den Status von Aktionen
enum NewFriendActionStatus {
  initial, // Der Ausgangszustand
  progress, // Aktion läuft
  loaded, // Einstellungen wurden erfolgreich geladen
  saved, // Änderungen wurden erfolgreich gespeichert
  failure, // Aktion mit Fehler beendet
}

class NewFriendState {

  /// Die Formulardaten.
  final String userName;

  // Wird nicht benötigt, denn initial ist das Suchfeld immer leer.
  //final String originalUserName;

  /// Der Status der letzten Aktion.
  final NewFriendActionStatus status;

  /// Der Fehler der letzten Aktion.
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy =>
    status == NewFriendActionStatus.progress;

  /// Gibt an, ob der Benutzer ein Feld verändert hat.
  bool get isDirty => userName.isNotEmpty;

  /// Konstruktor
  const NewFriendState({
    this.userName = '',
    this.status = NewFriendActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  NewFriendState copyWith({
    String? userName,
    NewFriendActionStatus? status,
    AppError? error,
  }) {
    return NewFriendState(
      userName: userName ?? this.userName,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
