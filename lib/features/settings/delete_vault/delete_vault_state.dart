import 'package:famkey/core/app_error.dart';

/// Ein Enum für den Status von Aktionen
enum DeleteVaultActionStatus {
  initial, // Der Ausgangszustand (noch nicht geladen)
  progress, // Aktion läuft (Laden oder Löschen)
  loaded, // Bereit für Benutzereingabe
  saved, // Server-Eintrag wurde entfernt (lokale Daten bleiben erhalten)
  deleted, // Tresor wurde lokal gelöscht
  failure, // Aktion mit Fehler beendet
}

class DeleteVaultState {

  /// Gibt an, ob der Tresor bereits synchronisiert wurde (bestimmt die angezeigten Optionen).
  final bool isRegistered;

  /// Der Status der letzten Aktion.
  final DeleteVaultActionStatus status;

  /// Der Fehler der letzten Aktion.
  final AppError error;

  /// Ob der Tresor auf dem Server gelöscht werden soll.
  final bool deleteServer;

  /// Ob der Tresor auf diesem Gerät gelöscht werden soll.
  final bool deleteLocal;

  /// Das eingegebene Master-Passwort zur Bestätigung.
  final String password;

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy => status == DeleteVaultActionStatus.progress;

  /// Gibt an, ob die Löschaktion ausgeführt werden kann.
  bool get canConfirm => (deleteServer || deleteLocal) && password.isNotEmpty;

  /// Konstruktor
  const DeleteVaultState({
    this.isRegistered = false,
    this.status = DeleteVaultActionStatus.initial,
    this.error = const AppError.none(),
    this.deleteServer = false,
    this.deleteLocal = false,
    this.password = '',
  });

  /// Status aktualisieren (immutable)
  DeleteVaultState copyWith({
    bool? isRegistered,
    DeleteVaultActionStatus? status,
    AppError? error,
    bool? deleteServer,
    bool? deleteLocal,
    String? password,
  }) {
    return DeleteVaultState(
      isRegistered: isRegistered ?? this.isRegistered,
      status: status ?? this.status,
      error: error ?? this.error,
      deleteServer: deleteServer ?? this.deleteServer,
      deleteLocal: deleteLocal ?? this.deleteLocal,
      password: password ?? this.password,
    );
  }
}
