import 'package:privault/core/app_error.dart';
import 'package:privault/features/main/main_notifier.dart';

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

  /// Gibt an, ob nur die eigenen Einträge angezeigt werden.
  final bool onlyMyEntries;

  /// Anzuzeigende Einträge gruppiert nach Kategorien
  final Map<String, List<EntryWithIndex>> groupedEntries;

  /// Speichert die Namen der Kategorien, die aktuell in der UI eingeklappt sind.
  final Set<String> collapsedCategories;

  /// Der Status der letzten Aktion.
  final MainActionStatus status;

  /// Der Fehler der letzten Operation.
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob der Benutzer ein Feld verändert hat.
  bool get isBusy => status == MainActionStatus.progress;

  /// Sortierte Liste aller vorhandenen Kategorienamen – für die Vorschlagsliste im Edit-Dialog.
  List<String> get categories => groupedEntries.keys.toList()..sort();

  /// Konstruktor
  const MainState({
    this.vaultName = '',
    this.searchQuery = '',
    this.onlyMyEntries = false,
    this.groupedEntries = const {},
    this.collapsedCategories = const {},
    this.status = MainActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  MainState copyWith({
    String? vaultName,
    String? searchQuery,
    bool? onlyMyEntries,
    Map<String, List<EntryWithIndex>>? groupedEntries,
    Set<String>? collapsedCategories,
    MainActionStatus? status,
    AppError? error,
  }) {

    return MainState(
      groupedEntries: groupedEntries ?? this.groupedEntries,
      collapsedCategories: collapsedCategories ?? this.collapsedCategories,
      vaultName: vaultName ?? this.vaultName,
      searchQuery: searchQuery ?? this.searchQuery,
      onlyMyEntries: onlyMyEntries ?? this.onlyMyEntries,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
