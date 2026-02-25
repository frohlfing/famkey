import 'package:flutter/material.dart';
import 'package:privault/core/base_view_model.dart';
import 'package:privault/models/entities/entry_entity.dart';
import 'package:privault/models/exceptions/salt_mismatch_exception.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/sync_service.dart';
import 'package:privault/services/session_service.dart';

/// Das [MainViewModel] steuert die Hauptansicht der Anwendung.
/// Es verwaltet die Anzeige, Filterung und Gruppierung aller Tresoreinträge und orchestriert die Synchronisation.
///
/// **Kernfunktionalitäten:**
/// * Effizientes Laden von Eintrags-Metadaten ohne vollständige Entschlüsselung.
/// * Echtzeit-Filterung nach Text (Titel, URL, Notizen) und Urheberschaft.
/// * Kategoriebasierte Gruppierung inklusive Verwaltung des Aufklapp-Zustands.
/// * Integration des [SyncService] für den Datenabgleich mit dem Server.
/// * Sicherer Logout-Prozess mit Bereinigung der Sitzungsdaten.
class MainViewModel extends BaseViewModel {
  // ------------------------------------------------------------------------
  // --- Felder ---
  // ------------------------------------------------------------------------

  final DatabaseService _databaseService;
  final SyncService _syncService;
  final SessionService _sessionService;

  List<EntryEntity> _allEntries = [];
  String _searchQuery = '';
  bool _onlyMyEntries = false;

  /// Speichert die Namen der Kategorien, die aktuell in der UI eingeklappt sind.
  final Set<String> _collapsedCategories = {};

  // ------------------------------------------------------------------------
  // --- Konstruktor ---
  // ------------------------------------------------------------------------

  MainViewModel(this._databaseService, this._syncService, this._sessionService);

  // ------------------------------------------------------------------------
  // --- Eigenschaften ---
  // ------------------------------------------------------------------------

  /// Der Name des aktuell geöffneten Tresors.
  String get vaultName => _sessionService.vaultName;

  /// Filter-Schalter: Falls `true`, werden nur vom aktuellen Benutzer erstellte Einträge angezeigt.
  bool get onlyMyEntries => _onlyMyEntries;

  /// Der aktuelle Suchtext für die Filterung der Liste.
  String get searchQuery => _searchQuery;

  set onlyMyEntries(bool value) {
    if (_onlyMyEntries == value) return;
    _onlyMyEntries = value;
    notifyListeners();
  }

  set searchQuery(String value) {
    final lower = value.toLowerCase();
    if (_searchQuery == lower) return;
    _searchQuery = lower;
    notifyListeners();
  }

  /// Liefert die Liste der Einträge unter Berücksichtigung von Suche und Benutzer-Filter.
  List<EntryEntity> get filteredEntries {
    return _allEntries.where((entry) {
      // Suche über Titel, URL und Notizen (wie in MAUI)
      final matchesSearch =
          entry.title.toLowerCase().contains(_searchQuery) ||
          entry.url.toLowerCase().contains(_searchQuery) ||
          entry.notes.toLowerCase().contains(_searchQuery);

      final matchesUser = !_onlyMyEntries || entry.creatorId == _sessionService.user?.id;

      return matchesSearch && matchesUser;
    }).toList();
  }

  /// Gruppiert die gefilterten Einträge nach Kategorien für die Darstellung in der UI.
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

  /// Prüft, ob eine Kategorie aktuell eingeklappt ist.
  bool isCategoryCollapsed(String category) => _collapsedCategories.contains(category);

  // ------------------------------------------------------------------------
  // --- Befehle ---
  // ------------------------------------------------------------------------

  /// Schaltet den Erweiterungszustand (aufgeklappt/zugeklappt) einer Kategorie um.
  void toggleCategory(String category) {
    if (_collapsedCategories.contains(category)) {
      _collapsedCategories.remove(category);
    } else {
      _collapsedCategories.add(category);
    }
    notifyListeners();
  }

  /// Lädt die Metadaten aller Einträge aus der lokalen Datenbank.
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

  /// Startet den Synchronisationsprozess mit dem konfigurierten Server.
  /// Behandelt Spezialfälle wie Passwortänderungen auf anderen Geräten (Adoption).
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
        // Bei Salt-Konflikt: Passwort-Prompt zur Identitätsübernahme (Adoption)
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
            final statsAfterAdopt = await _syncService.sync(); // Erneuter Versuch nach Adoption
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Sync fehlgeschlagen: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4), // Fehler etwas länger anzeigen
          ),
        );
      }
      return null;
    } finally {
      setBusy(false);
    }
  }

  /// Meldet den Benutzer ab und bereinigt die Sitzungsdaten im RAM.
  void logout() {
    _databaseService.close(); // Datenbankverbindung kappen (wie in MAUI)
    _sessionService.clearSession(); // Schlüssel aus dem RAM löschen
    _allEntries.clear();
  }

  // ------------------------------------------------------------------------
  // --- Private Methoden ---
  // ------------------------------------------------------------------------

  /// Hilfsdialog zur Abfrage des Master-Passworts während des Sync-Vorgangs.
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
                TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Abbrechen')),
                FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Bestätigen')),
              ],
            );
          },
        );
      },
    );
  }
}
