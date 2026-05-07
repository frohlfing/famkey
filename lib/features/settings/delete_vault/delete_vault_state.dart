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

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy => status == DeleteVaultActionStatus.progress;

  /// Konstruktor
  const DeleteVaultState({
    this.isRegistered = false,
    this.status = DeleteVaultActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  DeleteVaultState copyWith({
    bool? isRegistered,
    DeleteVaultActionStatus? status,
    AppError? error,
  }) {
    return DeleteVaultState(
      isRegistered: isRegistered ?? this.isRegistered,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
