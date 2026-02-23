import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:privault/core/base_view_model.dart';
import 'package:privault/models/entities/entry_entity.dart';
import 'package:privault/models/exceptions/salt_mismatch_exception.dart';
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

  Future<SyncStatistics?> sync(BuildContext context) async {
    setBusy(true);
    clearError();
    try {
      final stats = await _syncService.sync();
      await loadEntries();
      return stats;
    } on SaltMismatchException catch (e, stackTrace) {
      debugPrint("SaltMismatchException: $e\n$stackTrace");
      if (context.mounted) {
        final password = await _showPasswordDialog(
          context,
          'Account verknüpfen',
          e.userResponse.userUuid == _sessionService.user?.uuid
              ? 'Du hast das Master-Passwort auf einem anderen Gerät geändert. Bitte gib es zur Synchronisation ein:'
              : 'Dieser Tresor wird bereits auf einem anderen Gerät verwendet. Bitte gib das Master-Passwort ein, um die Identität zu übernehmen:',
        );
        if (password != null && password.isNotEmpty) {
          try {
            await _syncService.adoptRemoteIdentity(password, e.userResponse);
            final statsAfterAdopt = await _syncService.sync(); // Retry nach Adoption
            await loadEntries();
            return statsAfterAdopt;
          } catch (adoptEx, adoptStack) {
            debugPrint("Identitätsübernahme fehlgeschlagen: $adoptEx\n$adoptStack");
            setError("Identitätsübernahme fehlgeschlagen. Falsches Passwort?");
          }
        }
      }
      return null;
    } catch (e, stackTrace) {
      debugPrint("Sync fehlgeschlagen: $e\n$stackTrace");
      setError("Sync fehlgeschlagen: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Sync fehlgeschlagen: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4), // Fehler etwas länger anzeigen
        ));
      }
      return null;
    } finally {
      setBusy(false);
    }
  }

  void logout() {
    _sessionService.clearSession();
  }

  Future<String?> _showPasswordDialog(BuildContext context, String title, String message) {
    final controller = TextEditingController();
    bool isObscure = true;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    obscureText: isObscure,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Master-Passwort',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(isObscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => isObscure = !isObscure),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(controller.text),
                  child: const Text('Bestätigen'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
