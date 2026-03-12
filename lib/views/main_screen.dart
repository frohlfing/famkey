import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:privault/core/app_error.dart';
import 'package:provider/provider.dart';
import 'package:privault/viewmodels/main_view_model.dart';
import 'package:privault/widgets/password_dialog.dart';
import 'package:privault/widgets/snack.dart';
import 'package:privault/widgets/text_dialog.dart';

/// Der [MainScreen] ist die zentrale Übersicht deines Tresors.
///
/// Er listet alle gespeicherten Einträge auf, gruppiert nach Kategorien.
/// Von hier aus kannst du:
/// * Deine Einträge nach Titeln durchsuchen und filtern.
/// * Kategorien ein- und ausklappen, um die Übersicht zu behalten.
/// * Den Synchronisationsvorgang mit dem Server manuell anstoßen.
/// * Neue Einträge erstellen oder zu den Details bestehender Einträge navigieren.
/// * Über das Menü auf Einstellungen zugreifen oder dich abmelden.
class MainScreen extends StatefulWidget {
  /// Konstruktor
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // ------------------------------------------------------------------------
  // --- Interne Variablen ---
  // ------------------------------------------------------------------------

  late MainViewModel _viewModel;
  final _searchController = TextEditingController();

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert den Screen und lädt die Daten, sobald der erste Frame gerendert wurde.
  @override
  void initState() {
    super.initState();

    _viewModel = context.read<MainViewModel>();
    //_viewModel.addListener(_onViewModelChanged);
    _viewModel.init();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.load();
    });
  }

  // /// Entfernt den Listener und gibt alle Ressourcen frei.
  // @override
  // void dispose() {
  //   _viewModel.removeListener(_onViewModelChanged);
  // }

  // /// Wird getriggert, wenn das ViewModel notifyListeners() aufruft.
  // /// Hier kann u.a. der Text vom TextEditingController aktualisiert werden.
  // void _onViewModelChanged() {
  // }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  /// Baut die zentrale Hauptansicht der App auf.
  ///
  /// Hier werden die AppBar mit den Menüoptionen, das Suchfeld zur schnellen
  /// Filterung deiner Passwörter und die nach Kategorien gruppierte Liste
  /// der Einträge zusammengeführt.
  @override
  Widget build(BuildContext context) {
    // Dies triggert die build-Methode jedes Mal, wenn das ViewModel notifyListeners() aufruft.
    final viewModel = context.watch<MainViewModel>();

    final grouped = viewModel.groupedEntries;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(
              viewModel.vaultName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,

            leading: PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'sync':
                    _handleSync();
                    break;
                  case 'settings':
                    _handleSettings();
                    break;
                  case 'logout':
                    _handleLogout();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'sync',
                  child: ListTile(leading: Icon(Icons.cloud_sync_outlined), title: Text('Synchronisieren')),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: ListTile(leading: Icon(Icons.settings_outlined), title: Text('Einstellungen')),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                    leading: Icon(Icons.logout_outlined, color: Colors.red),
                    title: Text('Abmelden', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
              tooltip: 'Menü anzeigen',
            ),

            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Neuer Eintrag',
                onPressed: _handleAddEntry,
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                color: Theme.of(context).appBarTheme.backgroundColor,
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Suchen...',
                        prefixIcon: const Icon(Icons.search),
                        // Das X-Icon zum Löschen:
                        suffixIcon: viewModel.searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  viewModel.searchQuery = '';
                                },
                              )
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                      ),
                      onChanged: (val) => viewModel.searchQuery = val,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Nur meine Einträge anzeigen', style: TextStyle(fontSize: 13)),
                        Switch(value: viewModel.onlyMyEntries, onChanged: (val) => viewModel.onlyMyEntries = val),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: grouped.isEmpty && !viewModel.isBusy
                    ? const Center(child: Text('Keine Einträge gefunden.'))
                    : ListView.builder(
                        itemCount: grouped.length,
                        itemBuilder: (context, index) {
                          final category = grouped.keys.elementAt(index);
                          final items = grouped[category]!;
                          final isCollapsed = viewModel.isCategoryCollapsed(category);

                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 4, bottom: 2, left: 16, right: 16), // Hier den Abstand anpassen
                                child: Material(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                  child: ListTile(
                                    title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    trailing: Icon(isCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up),
                                    dense: true,
                                    onTap: () => viewModel.toggleCategory(category),
                                  ),
                                ),
                              ),
                              if (!isCollapsed) ...items.map((entry) => _buildEntryCard(context, viewModel, entry)),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),

        if (viewModel.isBusy)
          Container(
            color: Colors.black.withValues(alpha: 0.1),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  // ------------------------------------------------------------------------
  // --- Widgets ---
  // ------------------------------------------------------------------------

  /// Erstellt eine kompakte Karte (Card) für einen einzelnen Tresor-Eintrag.
  ///
  /// Zeigt das Favicon, den Titel und die URL an. Ein Tippen auf die Karte
  /// navigiert dich direkt zur Detailansicht des jeweiligen Eintrags.
  Widget _buildEntryCard(BuildContext context, MainViewModel viewModel, dynamic entry) {
    return Padding(
      padding: const EdgeInsets.only(top: 0, bottom: 0, left: 24, right: 24),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: _buildFavicon(entry.favicon),
          title: Text(entry.title.isNotEmpty ? entry.title : 'Unbenannter Eintrag', style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(entry.url, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => _handleViewEntry(entry),
        ),
      ),
    );
  }

  /// Hilfsfunktion zum Rendern des Webseiten-Icons (Favicon).
  ///
  /// Versucht das in der Datenbank hinterlegte Base64-Bild anzuzeigen.
  /// Falls kein Bild vorhanden ist oder die Daten beschädigt sind, wird
  /// ein dezentes Standard-Icon als Platzhalter genutzt.
  Widget _buildFavicon(String base64) {
    if (base64.isEmpty) return const Icon(Icons.lock_outlined, color: Colors.blueGrey);
    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(
          base64Decode(base64),
          width: 32,
          height: 32,
          errorBuilder: (ctx, err, stack) => const Icon(Icons.lock_outlined),
        ),
      );
    } catch (_) {
      return const Icon(Icons.lock_outlined);
    }
  }

  // ------------------------------------------------------------------------
  // --- Handler ---
  // ------------------------------------------------------------------------

  /// Koordiniert den Synchronisationsvorgang mit dem Server.
  Future<void> _handleSync() async {
    if (_viewModel.isBusy) return;
    try {
      // Sync starten
      final result = await _viewModel.sync();
      if (!mounted) return;
      if (!result.isSuccess) {
        if (result.errorCode == ErrorCode.syncSaltMismatch) {
          // Das Salt auf dem Server stimmt nicht mit dem Lokalen Salt überein -> Identitätsübernahme (Adoption) starten
          _handleSaltMismatch();
          return;
        }
        if (result.errorCode == ErrorCode.syncEmptyEntryKey) {
          TextDialog.show(
            context,
            title: 'Sicherheitsstopp',
            text: "Der Fingerprint eines Freundes hat sich geändert.\n"
                "Bitte verifiziere diesen in den Einstellungen, und starte danach die Synchronisation erneut.",
          );
          return;
        }
        Snack.show(context, result.errorMessage!);
      }
      final stats = _viewModel.stats;
      TextDialog.show(
          context,
          title: 'Info',
          text: 'Synchronisation erfolgreich abgeschlossen.\n\n$stats'
      );
    } catch (e, st) {
      if (mounted) Snack.showException(context, e, stackTrace: st, label: 'MainScreen');
    }
  }

  /// Adoptiert die auf dem Server gespeicherte Identität
  Future<void> _handleSaltMismatch() async {
    final userResponse = _viewModel.userResponse!;
    try {
      String? errorText;
      final message = userResponse.userUuid == _viewModel.myUuid
          ? "Du hast das Master-Passwort auf einem anderen Gerät geändert. Bitte gib es zur Synchronisation ein." //
          : "Dieser Tresor wird bereits auf einem anderen Gerät verwendet. Bitte gib das Master-Passwort ein, um die Identität zu übernehmen.";
      while (true) {
        // Master-Passwort abfragen
        final password = await PasswordDialog.show(
            context,
            title: 'Account verknüpfen',
            text: message,
            errorText: errorText
        );
        if (password == null) return;

        // Die auf dem Server gespeicherte Identität übernehmen
        final result = await _viewModel.adoptIdentity(userResponse, password);
        if (!mounted) return;
        if (!result.isSuccess) {
          if (result.errorCode == ErrorCode.wrongPassword) {
            // im Dialog anzeigen, NICHT SnackBar
            errorText = result.errorMessage;
            continue;
          }
          Snack.show(context, result.errorMessage!);
          break;
        }
        Snack.show(context, 'Account erfolgreich verknüpft.', success: true);
        _handleSync(); // Sync erneut starten
        break;
      }
    } catch (e, st) {
      if (mounted) Snack.showException(context, e, stackTrace: st, label: 'MainScreen');
    }
  }

  /// Navigiert zu den Einstellungen
  Future<void> _handleSettings() async {
    if (_viewModel.isBusy) return;
    Navigator.of(context).pushNamed('/settings');
  }

  /// Beendet die Session und navigiert zur Login-Seite.
  Future<void> _handleLogout() async {
    if (_viewModel.isBusy) return;
    _viewModel.logout();
    if (mounted) Navigator.of(context).pushReplacementNamed('/');
  }

  // 1) Aufrufkette für Eintrag hinzufügen: main -> edit -> details -> main
  // 2) Aufrufkette für Eintrag bearbeiten: main -> details -> edit -> details -> main
  // 3) Aufrufkette für Eintrag löschen: main -> details -> edit -> main

  /// Beendet die Session und navigiert zur Login-Seite.
  Future<void> _handleAddEntry() async {
    if (_viewModel.isBusy) return;
    final hasChanged = await Navigator.of(context).pushNamed('/edit');
    if (hasChanged == true && mounted) {
      _viewModel.load();
    }
  }

  /// Öffnet die Detailansicht.
  Future<void> _handleViewEntry(dynamic entry) async {
    if (_viewModel.isBusy) return;
    final hasChanged = await Navigator.of(context).pushNamed('/detail', arguments: entry.id);
    if (hasChanged == true && mounted) {
      _viewModel.load();
    }
  }
}
