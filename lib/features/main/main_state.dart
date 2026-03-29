import 'package:privault/core/app_error.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/main/adopt_identity/user_identity.dart';
import 'package:privault/features/main/sync_statistics.dart';

/// Ein Enum für den Status von Aktionen
enum MainActionStatus {
  initial, // Der Ausgangszustand
  progress, // Aktion läuft
  loaded, // Liste wurde erfolgreich geladen
  synced, // Sync wurde erfolgreich beendet
  adopted, // Benutzeridentität wurde erfolgreich adoptiert
  failure, // Aktion mit Fehler beendet
  syncAskForAdoption, // Frage, ob die auf dem Server gespeicherte Identität adoptiert werden soll.
  syncAskForRekeying, // Schlüssel des Freundes ist ungültig
}

class MainState {

  /// Der Name des Tresors.
  final String vaultName;

  /// Der Suchbegriff.
  final String searchQuery;

  /// Gibt an, ob nur die eigenen Einträge angezeigt werden.
  final bool onlyMyEntries;

  /// Anzuzeigende Einträge gruppiert nach Kategorien
  final Map<String, List<EntryEntity>> groupedEntries;

  /// Speichert die Namen der Kategorien, die aktuell in der UI eingeklappt sind.
  final Set<String> collapsedCategories;

  /// Benutzeridentität, die adoptiert werden muss.
  final UserIdentity adoptionUserIdentity;

  /// Die Sync-Statistik.
  final SyncStatistics syncStatistics;

  /// Der Status der letzten Aktion.
  final MainActionStatus status;

  /// Der Fehler der letzten Operation.
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob der Benutzer ein Feld verändert hat.
  bool get isBusy => status == MainActionStatus.progress;

  /// Konstruktor
  const MainState({
    this.vaultName = '',
    this.searchQuery = '',
    this.onlyMyEntries = false,
    this.groupedEntries = const {},
    this.collapsedCategories = const {},
    this.adoptionUserIdentity = const UserIdentity(),
    this.syncStatistics = const SyncStatistics(),
    this.status = MainActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  MainState copyWith({
    String? vaultName,
    String? searchQuery,
    bool? onlyMyEntries,
    Map<String, List<EntryEntity>>? groupedEntries,
    Set<String>? collapsedCategories,
    UserIdentity? adoptionUserIdentity,
    SyncStatistics? syncStatistics,
    MainActionStatus? status,
    AppError? error,
  }) {

    return MainState(
      groupedEntries: groupedEntries ?? this.groupedEntries,
      collapsedCategories: collapsedCategories ?? this.collapsedCategories,
      vaultName: vaultName ?? this.vaultName,
      searchQuery: searchQuery ?? this.searchQuery,
      onlyMyEntries: onlyMyEntries ?? this.onlyMyEntries,
      adoptionUserIdentity: adoptionUserIdentity ?? this.adoptionUserIdentity,
      syncStatistics: syncStatistics ?? this.syncStatistics,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
