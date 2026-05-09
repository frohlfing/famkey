import 'package:famkey/core/app_error.dart';
import 'package:famkey/features/main/main_notifier.dart';

/// Ein Enum für den Status von Aktionen
enum MainActionStatus {
  initial, // Ausgangszustand
  progress, // Aktion läuft
  loaded, // Liste wurde erfolgreich geladen
  failure, // Aktion mit Fehler beendet
}

class MainState {

  /// Der Name des Tresors.
  final String vaultName;

  /// Der Suchbegriff.
  final String searchQuery;

  /// Gibt an, ob der Nutzer Freunde in der Liste hat.
  final bool hasFriends;

  /// Gibt an, ob nur die eigenen Einträge angezeigt werden (nur relevant, wenn es Freunde gibt).
  final bool onlyMyEntries;

  /// Anzuzeigende Einträge gruppiert nach Kategorien
  final Map<String, List<EntryWithIndex>> groupedEntries;

  /// Speichert die Namen der Kategorien, die aktuell in der UI eingeklappt sind.
  final Set<String> collapsedCategories;

  /// Sortierte Liste aller vorhandenen Kategorienamen (ungefiltert) – für die Vorschlagsliste im Edit-Dialog.
  final List<String> allCategories;

  /// Der Status der letzten Aktion.
  final MainActionStatus status;

  /// Der Fehler der letzten Operation.
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob der Benutzer ein Feld verändert hat.
  bool get isBusy => status == MainActionStatus.progress;

  /// Gibt an, ob alle Kategorien eingeklappt sind.
  bool get allCategoriesCollapsed => groupedEntries.isNotEmpty && collapsedCategories.containsAll(groupedEntries.keys);

  /// Konstruktor
  const MainState({
    this.vaultName = '',
    this.searchQuery = '',
    this.hasFriends = false,
    this.onlyMyEntries = false,
    this.groupedEntries = const {},
    this.collapsedCategories = const {},
    this.allCategories = const [],
    this.status = MainActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  MainState copyWith({
    String? vaultName,
    String? searchQuery,
    bool? hasFriends,
    bool? onlyMyEntries,
    Map<String, List<EntryWithIndex>>? groupedEntries,
    Set<String>? collapsedCategories,
    List<String>? allCategories,
    MainActionStatus? status,
    AppError? error,
  }) {
    return MainState(
      vaultName: vaultName ?? this.vaultName,
      searchQuery: searchQuery ?? this.searchQuery,
      hasFriends: hasFriends ?? this.hasFriends,
      onlyMyEntries: onlyMyEntries ?? this.onlyMyEntries,
      groupedEntries: groupedEntries ?? this.groupedEntries,
      collapsedCategories: collapsedCategories ?? this.collapsedCategories,
      allCategories: allCategories ?? this.allCategories,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}