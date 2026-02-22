import 'package:privault/core/base_view_model.dart';
import 'package:privault/models/entities/entry_entity.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/sync_service.dart';
import 'package:privault/services/session_service.dart';

class MainViewModel extends BaseViewModel {
  final DatabaseService _databaseService;
  final SyncService _syncService;
  final SessionService _sessionService;

  List<EntryEntity> _allEntries = [];
  String _searchQuery = '';
  bool _onlyMyEntries = false;
  
  // Speichert, welche Kategorien eingeklappt sind
  final Set<String> _collapsedCategories = {};

  MainViewModel(this._databaseService, this._syncService, this._sessionService);

  String get vaultName => _sessionService.vaultName;
  bool get onlyMyEntries => _onlyMyEntries;
  String get searchQuery => _searchQuery;

  set onlyMyEntries(bool value) {
    _onlyMyEntries = value;
    notifyListeners();
  }

  set searchQuery(String value) {
    _searchQuery = value.toLowerCase();
    notifyListeners();
  }

  // Filtert die Einträge basierend auf Suche und "Nur meine"
  List<EntryEntity> get filteredEntries {
    return _allEntries.where((entry) {
      final matchesSearch = entry.title.toLowerCase().contains(_searchQuery) ||
          entry.url.toLowerCase().contains(_searchQuery);
      
      final matchesUser = !_onlyMyEntries || entry.creatorId == _sessionService.user?.id;
      
      return matchesSearch && matchesUser;
    }).toList();
  }

  // Gruppiert die gefilterten Einträge nach Kategorien
  Map<String, List<EntryEntity>> get groupedEntries {
    final Map<String, List<EntryEntity>> groups = {};
    final placeholder = _sessionService.settings?['category_placeholder'] ?? 'Allgemein';

    for (var entry in filteredEntries) {
      final category = entry.category.isEmpty ? placeholder : entry.category;
      if (!groups.containsKey(category)) {
        groups[category] = [];
      }
      groups[category]!.add(entry);
    }
    return groups;
  }

  bool isCategoryCollapsed(String category) => _collapsedCategories.contains(category);

  void toggleCategory(String category) {
    if (_collapsedCategories.contains(category)) {
      _collapsedCategories.remove(category);
    } else {
      _collapsedCategories.add(category);
    }
    notifyListeners();
  }

  Future<void> loadEntries() async {
    setBusy(true);
    try {
      _allEntries = await _databaseService.getAllEntries();
      notifyListeners();
    } catch (e) {
      setError("Fehler beim Laden: $e");
    } finally {
      setBusy(false);
    }
  }

  Future<SyncStatistics?> sync() async {
    setBusy(true);
    clearError();
    try {
      final stats = await _syncService.sync();
      await loadEntries();
      return stats;
    } catch (e) {
      setError("Sync fehlgeschlagen: $e");
      return null;
    } finally {
      setBusy(false);
    }
  }

  void logout() {
    _sessionService.clearSession();
  }
}
