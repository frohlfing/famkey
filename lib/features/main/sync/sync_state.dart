import 'package:privault/core/app_error.dart';
import 'package:privault/features/main/sync/adopt_identity/user_identity.dart';
import 'package:privault/features/main/sync/sync_statistics.dart';

/// Ein Enum für den Status von Aktionen
enum SyncStatus {
  initial, // Ausgangszustand
  progress, // Aktion läuft
  success, // Sync-Prozess wurde erfolgreich abgeschlossen
  failure, // Aktion mit Fehler beendet
  askForAdoption, // Frage, ob die auf dem Server gespeicherte Identität adoptiert werden soll.
  askForRekeying, // Schlüssel des Freundes ist ungültig
}

class SyncState {

  /// Benutzeridentität, die adoptiert werden muss.
  final UserIdentity adoptionUserIdentity;

  /// Die Sync-Statistik nach erfolgreicher Durchführung.
  final SyncStatistics? syncStatistics;

  /// Der Status der letzten Aktion.
  final SyncStatus status;

  /// Der Fehler der letzten Operation.
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob der Benutzer ein Feld verändert hat.
  bool get isBusy => status == SyncStatus.progress;

  /// Konstruktor
  const SyncState({
    this.syncStatistics = const SyncStatistics(),
    this.adoptionUserIdentity = const UserIdentity(),
    this.status = SyncStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  SyncState copyWith({
    SyncStatistics? syncStatistics,
    UserIdentity? adoptionUserIdentity,
    SyncStatus? status,
    AppError? error,
  }) {
    return SyncState(
      syncStatistics: syncStatistics ?? this.syncStatistics,
      adoptionUserIdentity: adoptionUserIdentity ?? this.adoptionUserIdentity,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}