import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/main/main_state.dart';
import 'package:privault/models/payloads/index_payload.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';

/// Kombiniert einen Datenbank-Eintrag mit seinen entschlüsselten Anzeigedaten.
typedef EntryWithIndex = ({EntryEntity entry, IndexPayload index});

final mainProvider = NotifierProvider<MainNotifier, MainState>(
  MainNotifier.new,
);

// todo wenn es das selbe ist, diese Syntax nehmen (auch bei LoginNotifier)
//final mainProvider = NotifierProvider<MainNotifier, MainState>(() {
//  return MainNotifier();
//});

class MainNotifier extends Notifier<MainState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

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

      // UI-State aktualisieren
      state = state.copyWith(
        groupedEntries: _groupEntries(),
        vaultName: _sessionService.vaultName,
        status: MainActionStatus.loaded,
      );

    } catch (e, st) {
      Logger().fatal("Fehler beim Laden: $e", stack: st);
      state = state.copyWith(status: MainActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  /// Meldet den Benutzer ab und bereinigt die Sitzungsdaten im RAM.
  void logout() {
    _allEntries = [];

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
      groupedEntries: _groupEntries(searchQuery: value),
    );
  }

  /// Setter für "Nur-Meine"-Filter
  void setOnlyMyEntries(bool value) {
    state = state.copyWith(
      onlyMyEntries: value,
      groupedEntries: _groupEntries(onlyMyEntries: value),
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
          idx.title.toLowerCase().contains(q) || // todo Werte im index bereits in kleinbuchstaben umwandeln
          idx.url.toLowerCase().contains(q) ||
          idx.notes.toLowerCase().contains(q) ||
          e.entry.uuid.contains(q);
      final matchesUser = !onlyMyEntries || e.entry.creatorId == _sessionService.user?.id;
      return matchesSearch && matchesUser;
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
}
