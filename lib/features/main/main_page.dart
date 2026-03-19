import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/helper.dart';
import 'package:privault/features/main/main_notifier.dart';
import 'package:privault/features/main/main_state.dart';
import 'package:privault/widgets/password_dialog.dart';
import 'package:privault/widgets/snack.dart';
import 'package:privault/widgets/text_dialog.dart';

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

    // Listener für Side-Effects (Navigation, SnackBars)
    // Er wird nur einmal ausgelöst, wenn sich der Status ändert, und verursacht keine Rebuilds.
    ref.listen(mainProvider.select((s) => s.status), (previous, next) {
      final state = ref.read(mainProvider);

      switch (next) {
        case MainActionStatus.synced:
          TextDialog.show(
              context,
              title: 'Info',
              text: 'Synchronisation erfolgreich abgeschlossen.\n\n${state.syncStatistics}',
          );
          break;

        case MainActionStatus.adopted:
          notifier.sync();
          break;

        case MainActionStatus.failure:
          if (state.error.field == null) { // Nur allgemeine Fehler anzeigen
            Snack.show(context, state.error.text);
          }
          break;

        case MainActionStatus.syncAskForAdoption:
          _handleAdoptionRequest(isOnboarding: false);
          break;

        case MainActionStatus.syncAskForOnboarding:
          _handleAdoptionRequest(isOnboarding: true);
          break;

        case MainActionStatus.syncAskForRekeying:
          TextDialog.show(
            context,
            title: 'Sicherheitsstopp',
            text: "Der Fingerprint eines Freundes hat sich geändert.\n"
                "Bitte verifiziere diesen in den Einstellungen, und starte danach die Synchronisation erneut.",
          );
          break;

        default:
          break;
      }
    });

    // Gezielte Watches für maximale Performance
    final isBusy = ref.watch(mainProvider.select((s) => s.isBusy));
    final vaultName = ref.watch(mainProvider.select((s) => s.vaultName));
    final groupedEntries = ref.watch(mainProvider.select((s) => s.groupedEntries));

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(vaultName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,

            leading: PopupMenuButton<String>(
              onSelected: isBusy ? null : (value) async {
                switch (value) {
                  case 'sync':
                    notifier.sync();
                    break;
                  case 'settings':
                    Navigator.of(context).pushNamed('/settings');
                    break;
                  case 'logout':
                    notifier.logout();
                    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'sync',
                  child: ListTile(
                    leading: Icon(Icons.cloud_sync_outlined),
                    title: Text('Synchronisieren'),
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
                      builder: (context, ref, _) {
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
                            fillColor: Theme.of(context).cardColor,
                          ),
                          onChanged: notifier.setSearchQuery,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Consumer(
                      builder: (context, ref, _) {
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
                ),
              ),

              Expanded(
                child: groupedEntries.isEmpty && !isBusy
                    ? const Center(child: Text('Keine Einträge gefunden.'))
                    : ListView.builder(
                        itemCount: groupedEntries.length,
                        itemBuilder: (context, index) {
                          final category = groupedEntries.keys.elementAt(index);
                          final items = groupedEntries[category]!;

                          return Consumer(
                            builder: (context, ref, _) {
                              final isCollapsed = ref.watch(mainProvider.select((s) => s.collapsedCategories.contains(category)));
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
                                        onTap: () => notifier.toggleCategory(category),
                                      ),
                                    ),
                                  ),
                                  if (!isCollapsed) ...items.map((entry) => _buildEntryCard(context, entry)),
                                ],
                              );
                            },
                          );
                        },
                      ),
              ),
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
  Widget _buildEntryCard(BuildContext context, dynamic entry) {
    return Padding(
      padding: const EdgeInsets.only(top: 0, bottom: 0, left: 24, right: 24),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: buildFavicon(entry.favicon),
          title: Text(
            entry.title.isNotEmpty ? entry.title : 'Unbenannter Eintrag',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            entry.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _handleViewEntry(entry),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------------
  // --- Handler ---
  // ------------------------------------------------------------------------

  /// Adoptiert die auf dem Server gespeicherte Identität
  Future<void> _handleAdoptionRequest({required bool isOnboarding}) async {
    final message = isOnboarding
        ? "Dieser Tresor wird bereits auf einem anderen Gerät verwendet. Bitte gib das Master-Passwort ein, um die Identität zu übernehmen." // UUIDs stimmen nicht
        : "Du hast das Master-Passwort auf einem anderen Gerät geändert. Bitte gib es zur Synchronisation ein.";
    final state = ref.read(mainProvider);
    final password = await PasswordDialog.show(
      context,
      title: 'Account verknüpfen',
      text: message,
      errorText: state.error.code == ErrorCode.wrongPassword ? state.error.text : null,
    );
    if (mounted && password != null) {
      final notifier = ref.read(mainProvider.notifier);
      notifier.adoptIdentity(password);
    }
  }

  /// Öffnet die Editierseite.
  Future<void> _handleAddEntry() async {
    // Öffnet die Editierseite und wartet, bis die Seite wieder geschlossen wird.
    final hasChanged = await Navigator.of(context).pushNamed('/edit');

    // Wenn der Eintrag geändert wurde, die Liste neu laden.
    if (hasChanged == true && mounted) {
      final notifier = ref.read(mainProvider.notifier);
      notifier.load();
    }
  }

  /// Öffnet die Detailansicht.
  Future<void> _handleViewEntry(dynamic entry) async {
    // Öffnet die Editierseite und wartet, bis die Seite wieder geschlossen wird.
    final hasChanged = await Navigator.of(context).pushNamed('/detail', arguments: entry.id);

    // Wenn der Eintrag geändert wurde, die Liste neu laden.
    if (hasChanged == true && mounted) {
      final notifier = ref.read(mainProvider.notifier);
      notifier.load();
    }
  }
}
