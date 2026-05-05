import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famkey/core/app_error.dart';
import 'package:famkey/core/logger.dart';
import 'package:famkey/core/service_locator.dart';
import 'package:famkey/database/database.dart';
import 'package:famkey/features/main/main_state.dart';
import 'package:famkey/models/payloads/index_payload.dart';
import 'package:famkey/services/auto_lock_service.dart';
import 'package:famkey/services/clipboard_service.dart';
import 'package:famkey/services/config_service.dart';
import 'package:famkey/services/crypto_service.dart';
import 'package:famkey/services/database_service.dart';
import 'package:famkey/services/session_service.dart';

/// Kombiniert einen Datenbank-Eintrag mit seinen entschlüsselten Anzeigedaten.
typedef EntryWithIndex = ({EntryEntity entry, IndexPayload index});

final mainProvider = NotifierProvider<MainNotifier, MainState>(() {
  return MainNotifier();
});

class MainNotifier extends Notifier<MainState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

  late final AutoLockService _autoLockService;
  late final ClipboardService _clipboardService;
  late final ConfigService _configService;
  late final CryptoService _cryptoService;
  late final DatabaseService _databaseService;
  late final SessionService _sessionService;

  // ------------------------------------------------------------------------
  // --- Interne Variablen (nicht reaktiv, nicht UI‑relevant) ---
  // ------------------------------------------------------------------------

  /// Liste der Einträge
  List<EntryWithIndex> _allEntries = [];

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert einen Notifier.
  ///
  /// Die Verwendung von `Ref.watch` oder `Ref.listen` innerhalb dieser Methode ist unbedenklich.
  /// Ändert sich eine Abhängigkeit dieses Notifiers (bei Verwendung von `Ref.watch`), wird der Build-Prozess erneut ausgeführt. Der Notifier selbst wird jedoch nicht neu erstellt. Seine Instanz bleibt zwischen den Build-Ausführungen erhalten.
  @override
  MainState build() {
    // Dienste aus getIt holen
    _autoLockService = getIt();
    _clipboardService = getIt();
    _configService = getIt();
    _cryptoService = getIt();
    _databaseService = getIt();
    _sessionService = getIt();

    // Initialer State
    return const MainState();
  }

  /// Lädt die Daten für die Anzeige.
  Future<void> load() async {
    if (state.isBusy) return;

    // UI-State zurücksetzen
    state = const MainState(status: MainActionStatus.progress, error: AppError.none());

    try {

      // Daten abfragen
      final entries = await _databaseService.getEntries();
      final indexKey = _sessionService.indexKey!;

      _allEntries = await Future.wait(entries.map((entry) async {
        try {
          final decrypted = await _cryptoService.decrypt(entry.encryptedIndex, indexKey);
          final index = IndexPayload.fromJson(json.decode(utf8.decode(decrypted)));
          return (entry: entry, index: index);
        } catch (_) {
          // Fehlertoleranz: leerer Index falls encryptedIndex fehlt oder korrupt ist
          return (entry: entry, index: const IndexPayload(category: '', title: '', url: '', notes: '', favicon: ''));
        }
      }));

      final hasFriends = await _databaseService.hasFriends();

      // UI-State aktualisieren
      final grouped = _groupEntries(onlyMyEntries: _configService.showOnlyMine);
      final collapsed = _configService.allCategoriesCollapsed ? grouped.keys.toSet() : const <String>{};
      state = state.copyWith(
        groupedEntries: grouped,
        collapsedCategories: collapsed,
        vaultName: _sessionService.vaultName,
        hasFriends: hasFriends,
        onlyMyEntries: _configService.showOnlyMine,
        status: MainActionStatus.loaded,
      );

    } catch (e, st) {
      log.fatal("Fehler beim Laden: $e", stack: st);
      state = state.copyWith(status: MainActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  /// Meldet den Benutzer ab und bereinigt die Sitzungsdaten im RAM.
  void logout() {
    _allEntries = [];

    // Timeout-Services stoppen
    _autoLockService.stop();
    _clipboardService.cancelAndClear();

    // Datenbankverbindung kappen
    _databaseService.close();

    // Schlüssel aus dem RAM löschen
    _sessionService.clearSession();

    // State zurücksetzen
    state = const MainState();
  }

  // ------------------------------------------------------------------------
  // --- Setter für den UI-State (synchron) ---
  // ------------------------------------------------------------------------

  /// Setter für Suchbegriff
  void setSearchQuery(String value) {
    state = state.copyWith(
      searchQuery: value,
      groupedEntries: _groupEntries(searchQuery: value, onlyMyEntries: state.onlyMyEntries),
    );
  }

  /// Setter für "Nur-Meine"-Filter
  void setOnlyMyEntries(bool value) {
    _configService.showOnlyMine = value;
    state = state.copyWith(
      onlyMyEntries: value,
      groupedEntries: _groupEntries(searchQuery: state.searchQuery, onlyMyEntries: value),
    );
  }

  /// Gruppiert die gefilterten Einträge nach Kategorien für die Darstellung in der UI.
  Map<String, List<EntryWithIndex>> _groupEntries({String searchQuery = '', bool onlyMyEntries = false}) {
    final Map<String, List<EntryWithIndex>> groups = {};
    final placeholder = _sessionService.settings?.categoryPlaceholder ?? 'Allgemein';
    final q = searchQuery.toLowerCase();

    // Filter anwenden
    final filtered = _allEntries.where((e) {
      final idx = e.index;
      final matchesSearch = q.isEmpty ||
          idx.title.toLowerCase().contains(q) ||
          idx.url.toLowerCase().contains(q) ||
          idx.notes.toLowerCase().contains(q) ||
          e.entry.uuid.contains(q);
      if (!onlyMyEntries) return matchesSearch;
      return matchesSearch && e.entry.creatorId == _sessionService.user?.id;
    });

    // Gruppieren
    for (final e in filtered) {
      final category = e.index.category.isEmpty ? placeholder : e.index.category;
      groups.putIfAbsent(category, () => []).add(e);
    }

    return groups;
  }

  /// Klappt eine Kategorie auf/zu.
  void toggleCategory(String category) {
    final collapsed = Set<String>.from(state.collapsedCategories);
    if (collapsed.contains(category)) {
      collapsed.remove(category);
    } else {
      collapsed.add(category);
    }
    state = state.copyWith(collapsedCategories: collapsed);
  }

  /// Klappt alle Kategorien auf oder zu (Toggle).
  void toggleAllCategories() {
    final allCollapsed = state.allCategoriesCollapsed;
    final collapsed = allCollapsed ? const <String>{} : state.groupedEntries.keys.toSet();
    _configService.allCategoriesCollapsed = !allCollapsed;
    state = state.copyWith(collapsedCategories: collapsed);
  }
}
