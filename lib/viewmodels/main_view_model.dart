import 'package:flutter/material.dart';
import 'package:privault/core/base_view_model.dart';
import 'package:privault/models/entities/entry_entity.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';
import 'package:privault/services/sync_service.dart';
import 'package:privault/services/crypto_service.dart';

class MainViewModel extends BaseViewModel {
  // ------------------------------------------------------------------------
  // --- Felder ---
  // ------------------------------------------------------------------------

  final DatabaseService _databaseService;
  final SessionService _sessionService;
  final SyncService _syncService;
  final CryptoService _cryptoService;

  List<EntryEntity> _allEntries = [];
  Map<String, List<EntryEntity>> _groupedEntries = {};
  final Set<String> _collapsedCategories = {};

  String _searchQuery = '';
  bool _onlyMyEntries = false;

  // ------------------------------------------------------------------------
  // --- Konstruktor ---
  // ------------------------------------------------------------------------

  MainViewModel(this._databaseService, this._sessionService, this._syncService, this._cryptoService);

  // ------------------------------------------------------------------------
  // --- Eigenschaften ---
  // ------------------------------------------------------------------------

  String get vaultName => _sessionService.vaultName;

  Map<String, List<EntryEntity>> get groupedEntries => _groupedEntries;

  String get searchQuery => _searchQuery;

  set searchQuery(String value) {
    _searchQuery = value;
    _applyFilters();
  }

  bool get onlyMyEntries => _onlyMyEntries;

  set onlyMyEntries(bool value) {
    _onlyMyEntries = value;
    _applyFilters();
  }

  // ------------------------------------------------------------------------
  // --- Befehle ---
  // ------------------------------------------------------------------------

  /// Lädt alle Einträge aus der Datenbank und wendet Filter an.
  Future<void> loadEntries() async {
    setBusy(true);
    try {
      _allEntries = await _databaseService.getAllEntries();
      _applyFilters();
    } catch (e) {
      setError("Fehler beim Laden der Einträge: $e");
    } finally {
      setBusy(false);
    }
  }

  /// Startet den Synchronisationsprozess mit dem konfigurierten Server.
  /// (Gibt Exceptions wie SaltMismatchException bewusst weiter an die UI).
  Future<SyncStatistics?> sync() async {
    if (isBusy) return null;
    setBusy(true);
    clearError();
    try {
      final host = _sessionService.settings?['host'] ?? '';
      if (host.isEmpty) {
        throw Exception("Bitte konfiguriere erst den Sync-Server in den Einstellungen.");
      }

      // SyncService aufrufen
      final stats = await _syncService.sync();

      // Nach erfolgreichem Sync die lokale Liste neu laden
      await loadEntries();
      return stats;
    } catch (e) {
      debugPrint("Fehler beim Synchronisieren: $e");
      rethrow;
    }
    finally {
      setBusy(false);
    }
  }

  /// Die Logik für die Adoption ohne Dialog (wird nach Passworteingabe in der UI aufgerufen).
  Future<void> adoptIdentity(dynamic remoteUser, dynamic remoteMasterKey) async {
    await _syncService.adoptRemoteIdentity(remoteUser, remoteMasterKey);
  }

  // Getter für Services, damit UI-Dialoge diese verwenden können.
  CryptoService get cryptoService => _cryptoService;
  SessionService get sessionService => _sessionService;
  DatabaseService get databaseService => _databaseService;

  /// Beendet die Sitzung.
  void logout() {
    _sessionService.clearSession();
  }

  bool isCategoryCollapsed(String category) {
    return _collapsedCategories.contains(category);
  }

  void toggleCategory(String category) {
    if (_collapsedCategories.contains(category)) {
      _collapsedCategories.remove(category);
    } else {
      _collapsedCategories.add(category);
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------------
  // --- Private Methoden ---
  // ------------------------------------------------------------------------

  void _applyFilters() {
    var filtered = _allEntries;

    // Nur meine Einträge? (Ersteller bin ich)
    if (_onlyMyEntries) {
      filtered = filtered.where((e) => e.creatorId == 1).toList();
    }

    // Suchtext?
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((e) {
        return e.title.toLowerCase().contains(q) ||
               e.url.toLowerCase().contains(q) ||
               e.category.toLowerCase().contains(q);
      }).toList();
    }

    // Gruppieren
    final Map<String, List<EntryEntity>> grouped = {};
    for (var entry in filtered) {
      final cat = entry.category.isEmpty ? "Allgemein" : entry.category;
      if (!grouped.containsKey(cat)) {
        grouped[cat] = [];
      }
      grouped[cat]!.add(entry);
    }

    // Sortieren (erst Kategorien, dann Einträge nach Titel)
    final sortedKeys = grouped.keys.toList()..sort();
    final Map<String, List<EntryEntity>> sortedGrouped = {};
    for (var key in sortedKeys) {
      final list = grouped[key]!;
      list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      sortedGrouped[key] = list;
    }

    _groupedEntries = sortedGrouped;
    notifyListeners();
  }
}
