import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/features/main/export/export_dialog.dart';
import 'package:privault/features/main/main_notifier.dart';
import 'package:privault/features/main/main_state.dart';
import 'package:privault/features/main/import/import_dialog.dart';
import 'package:privault/features/main/sync/sync_dialog.dart';
import 'package:privault/widgets/snack.dart';

/// Der [MainPage] ist die zentrale Übersicht deines Tresors.
///
/// Er listet alle gespeicherten Einträge auf, gruppiert nach Kategorien.
/// Von hier aus kannst du:
/// * Deine Einträge nach Titeln durchsuchen und filtern.
/// * Kategorien ein- und ausklappen, um die Übersicht zu behalten.
/// * Den Synchronisationsvorgang mit dem Server manuell anstoßen.
/// * Neue Einträge erstellen oder zu den Details bestehender Einträge navigieren.
/// * Über das Menü auf Einstellungen zugreifen oder dich abmelden.
class MainPage extends ConsumerStatefulWidget {
  /// Konstruktor
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {

  // ------------------------------------------------------------------------
  // --- TextEditingController ---
  // ------------------------------------------------------------------------

  final _searchController = TextEditingController();

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert die Seite und lädt die Daten, sobald der erste Frame gerendert wurde.
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(mainProvider.notifier);
      notifier.load();
    });
  }

  // /// Gibt Ressourcen frei.
  // @override
  // void dispose() {
  // }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  /// Rendert die Seite (getriggert durch Änderungen im State)
  @override
  Widget build(BuildContext context) {
    // Notifier holen
    final notifier = ref.read(mainProvider.notifier);

    // Listener für Status-Änderungen
    ref.listen(mainProvider.select((s) => s.status), (previous, next) {
      final state = ref.read(mainProvider);

      switch (next) {

        case MainActionStatus.failure:
          if (state.error.field == null) { // Nur allgemeine Fehler anzeigen
            Snack.show(context, state.error.text);
          }
          break;

        default:
          break;
      }
    });

    // Gezielte Watches für maximale Performance
    final isBusy = ref.watch(mainProvider.select((s) => s.isBusy));
    final hasFriends = ref.watch(mainProvider.select((s) => s.hasFriends));
    final groupedEntries = ref.watch(mainProvider.select((s) => s.groupedEntries));

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Consumer(
              builder: (ctx, ref, _) {
                final vaultName = ref.watch(mainProvider.select((state) => state.vaultName));
                return Text(vaultName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold));
              },
            ),
            //title: Text(vaultName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
            leading: PopupMenuButton<String>(
              onSelected: isBusy ? null : (value) async {
                switch (value) {
                  case 'sync':
                    _showSyncDialog();
                    break;
                  case 'import':
                    _showImportDialog();
                    break;
                  case 'export':
                    _showExportDialog();
                    break;
                  case 'report':
                    _showReportPage();
                    break;
                  case 'settings':
                    _showSettingsPage();
                    break;
                  case 'logout':
                    _handleLogout();
                    break;
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'sync',
                  child: ListTile(
                    leading: Icon(Icons.cloud_sync_outlined),
                    title: Text('Synchronisieren'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                    leading: Icon(Icons.file_download_outlined),
                    title: Text('Importieren'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                    leading: Icon(Icons.file_upload_outlined),
                    title: Text('Exportieren'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'report',
                  child: ListTile(
                    leading: Icon(Icons.security_outlined),
                    title: Text('Sicherheitsbericht'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: ListTile(
                    leading: Icon(Icons.settings_outlined),
                    title: Text('Einstellungen'),
                  ),
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
                onPressed: isBusy ? null : _handleAddEntry,
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
                    Consumer(
                      builder: (ctx, ref, _) {
                        final searchQuery = ref.watch(mainProvider.select((s) => s.searchQuery));
                        return TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Suchen...',
                            prefixIcon: const Icon(Icons.search),
                            // Das X-Icon zum Löschen:
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      notifier.setSearchQuery('');
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            filled: true,
                            fillColor: Theme.of(ctx).cardColor,
                          ),
                          onChanged: notifier.setSearchQuery,
                        );
                      },
                    ),
                    if (hasFriends) ...[
                      const SizedBox(height: 8),
                      Consumer(
                        builder: (ctx, ref, _) {
                          // Dieser Consumer lauscht NUR auf onlyMyEntries.
                          final onlyMyEntries = ref.watch(mainProvider.select((s) => s.onlyMyEntries));
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Nur meine Einträge anzeigen', style: TextStyle(fontSize: 13)),
                              Switch(
                                  value: onlyMyEntries,
                                  onChanged: notifier.setOnlyMyEntries,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),

              Expanded(
                child: groupedEntries.isEmpty && !isBusy
                    ? const Center(child: Text('Keine Einträge gefunden.'))
                    : ListView.builder(
                        itemCount: groupedEntries.length,
                        itemBuilder: (ctx, index) {
                          final category = groupedEntries.keys.elementAt(index);
                          final items = groupedEntries[category]!;

                          return Consumer(
                            builder: (ctx, ref, _) {
                              final isCollapsed = ref.watch(mainProvider.select((s) => s.collapsedCategories.contains(category)));
                              return Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4, bottom: 2, left: 16, right: 16), // Hier den Abstand anpassen
                                    child: Material(
                                      color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                      child: ListTile(
                                        title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        trailing: Icon(isCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up),
                                        dense: true,
                                        onTap: () => notifier.toggleCategory(category),
                                      ),
                                    ),
                                  ),
                                  if (!isCollapsed) ...items.map((entry) => _buildEntryCard(ctx, entry)),
                                ],
                              );
                            },
                          );
                        },
                      ),
              ),

              // --- Abstand zum unteren Rand ---
              const SizedBox(height: 48),
            ],
          ),
        ),

        if (isBusy)
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
  Widget _buildEntryCard(BuildContext context, EntryWithIndex entry) {
    return Padding(
      padding: const EdgeInsets.only(top: 0, bottom: 0, left: 24, right: 24),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: buildFavicon(entry.index.favicon),
          title: Text(
            entry.index.title.isNotEmpty ? entry.index.title : 'Unbenannter Eintrag',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            entry.index.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
  Widget buildFavicon(String base64) {
    // if (base64.isEmpty) {
    //   return const Icon(Icons.lock_outlined, color: Colors.blueGrey);
    // }
    // try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(base64Decode(base64), width: 32, height: 32, errorBuilder: (ctx, err, stack) => const Icon(Icons.lock_outlined)),
      );
    // } catch (_) {
    //   return const Icon(Icons.lock_outlined);
    // }
  }

  // ------------------------------------------------------------------------
  // --- Handler ---
  // ------------------------------------------------------------------------

  /// Öffnet den Dialog zum Synchronisieren.
  Future<void> _showSyncDialog() async {
    final ok = await SyncDialog.show(context);
    if (mounted && ok == true) {
      final notifier = ref.read(mainProvider.notifier);
      notifier.load();
    }
  }

  /// Öffnet den Dialog zum Importieren einer Datei.
  Future<void> _showImportDialog() async {
    final ok = await ImportDialog.show(context);
    if (mounted && ok == true) {
      final notifier = ref.read(mainProvider.notifier);
      notifier.load();
    }
  }
  /// Öffnet den Dialog zum Exportieren des Tresors.
  Future<void> _showExportDialog() async {
    await ExportDialog.show(context);
  }

   /// Öffnet den Sicherheitsbericht.
   Future<void> _showReportPage() async {
     await Navigator.of(context).pushNamed('/report');
   }

  /// Öffnet die Einstellungen.
  Future<void> _showSettingsPage() async {
    // Öffnet die Einstellungen und wartet, bis die Seite wieder geschlossen wird.
    final hasChanged = await Navigator.of(context).pushNamed('/settings');
    // Wenn der Einstellungen geändert wurden, die Liste neu laden.
    if (mounted && hasChanged == true) {
      final notifier = ref.read(mainProvider.notifier);
      notifier.load();
    }
  }

  /// Meldet den Benutzer ab und springt zur Anmeldeseite.
  Future<void> _handleLogout() async {
    final notifier = ref.read(mainProvider.notifier);
    notifier.logout();
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  /// Öffnet die Editierseite.
  Future<void> _handleAddEntry() async {
    // Öffnet die Editierseite und wartet, bis die Seite wieder geschlossen wird.
    final hasChanged = await Navigator.of(context).pushNamed('/edit');

    // Wenn der Eintrag geändert wurde, die Liste neu laden.
    if (mounted && hasChanged == true) {
      final notifier = ref.read(mainProvider.notifier);
      notifier.load();
    }
  }

  /// Öffnet die Detailansicht.
  Future<void> _handleViewEntry(EntryWithIndex entry) async {
    // Öffnet die Editierseite und wartet, bis die Seite wieder geschlossen wird.
    final hasChanged = await Navigator.of(context).pushNamed('/detail', arguments: entry.entry.id);

    // Wenn der Eintrag geändert wurde, die Liste neu laden.
    if (hasChanged == true && mounted) {
      final notifier = ref.read(mainProvider.notifier);
      notifier.load();
    }
  }
}
