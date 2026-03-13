import 'package:privault/core/app_error.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/main/sync_statistics.dart';
import 'package:privault/models/dtos/user_response.dart';

class MainState {
  /// Gibt an, ob ein Ladesymbol angezeigt wird
  final bool isBusy;

  /// Liste der Einträge
  final List<EntryEntity> allEntries;

  /// Suchbegriff
  final String searchQuery;

  /// Gibt an, ob nur die eigenen Einträge angezeigt werden
  final bool onlyMyEntries;

  /// Speichert die Namen der Kategorien, die aktuell in der UI eingeklappt sind.
  final Set<String> collapsedCategories;

  /// Sync-Statistik
  final SyncStatistics? lastSyncStats;

  /// Antwort des Servers mit der neuen Benutzer-Identität, die adoptiert werden muss
  final UserResponse? userResponse;

  /// Fehler der letzten Operation
  final FormError? error;

  /// Konstruktor
  const MainState({
    this.isBusy = false,
    this.allEntries = const [],
    this.searchQuery = '',
    this.onlyMyEntries = false,
    this.collapsedCategories = const {},
    this.lastSyncStats,
    this.userResponse,
    this.error,
  });

  /// Status aktualisieren (immutable)
  MainState copyWith({
    bool? isBusy,
    List<EntryEntity>? allEntries,
    String? searchQuery,
    bool? onlyMyEntries,
    Set<String>? collapsedCategories,
    SyncStatistics? lastSyncStats,
    UserResponse? userResponse,
    FormError? error,
  }) {
    return MainState(
      isBusy: isBusy ?? this.isBusy,
      allEntries: allEntries ?? this.allEntries,
      searchQuery: searchQuery ?? this.searchQuery,
      onlyMyEntries: onlyMyEntries ?? this.onlyMyEntries,
      collapsedCategories: collapsedCategories ?? this.collapsedCategories,
      lastSyncStats: lastSyncStats ?? this.lastSyncStats,
      userResponse: userResponse ?? this.userResponse,
      error: error ?? this.error,
    );
  }
}
