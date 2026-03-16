import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/features/main/main_notifier.dart';
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
    // Notifier und State holen
    final notifier = ref.read(mainProvider.notifier);
    final state = ref.watch(mainProvider);

    // Einträge nach Kategorien gruppieren
    final grouped = notifier.getEntriesGroupedByCategory();

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(notifier.getVaultName(), overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                        suffixIcon: state.searchQuery.isNotEmpty
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
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Nur meine Einträge anzeigen', style: TextStyle(fontSize: 13)),
                        Switch(value: state.onlyMyEntries, onChanged: notifier.setOnlyMyEntries),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: grouped.isEmpty && !state.isBusy
                    ? const Center(child: Text('Keine Einträge gefunden.'))
                    : ListView.builder(
                        itemCount: grouped.length,
                        itemBuilder: (context, index) {
                          final category = grouped.keys.elementAt(index);
                          final items = grouped[category]!;
                          final isCollapsed = state.collapsedCategories.contains(category);

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
                      ),
              ),
            ],
          ),
        ),

        if (state.isBusy)
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
          leading: _buildFavicon(entry.favicon),
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

  // todo in den Notifier!
  /// Hilfsfunktion zum Rendern des Webseiten-Icons (Favicon).
  ///
  /// Versucht das in der Datenbank hinterlegte Base64-Bild anzuzeigen.
  /// Falls kein Bild vorhanden ist oder die Daten beschädigt sind, wird
  /// ein dezentes Standard-Icon als Platzhalter genutzt.
  Widget _buildFavicon(String base64) {
    if (base64.isEmpty) {
      return const Icon(Icons.lock_outlined, color: Colors.blueGrey);
    }
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
    // Busy-Check
    if (ref.read(mainProvider).isBusy) return;

    // Sync durchführen
    final notifier = ref.read(mainProvider.notifier);
    final success  = await notifier.sync();
    if (!mounted) return;

    // Aktuellen State holen
    final state = ref.read(mainProvider);

    // Fehlerfall
    if (!success) {
      switch (state.error.code) {
        case ErrorCode.syncSaltMismatch:
          // Das Salt auf dem Server stimmt nicht mit dem Lokalen Salt überein -> Identitätsübernahme (Adoption) starten
          _handleSaltMismatch();
          break;

        case ErrorCode.syncEmptyEntryKey:
          TextDialog.show(
            context,
            title: 'Sicherheitsstopp',
            text: "Der Fingerprint eines Freundes hat sich geändert.\n"
              "Bitte verifiziere diesen in den Einstellungen, und starte danach die Synchronisation erneut.",
          );
          break;

        default:
          if (state.error.field == null) {
            Snack.show(context, state.error.text);
          }
      }
      return;
    }

    // Erfolgsfall
    final stats = ref.read(mainProvider).lastSyncStats;
    TextDialog.show(context, title: 'Info', text: 'Synchronisation erfolgreich abgeschlossen.\n\n$stats');
  }

  /// Adoptiert die auf dem Server gespeicherte Identität
  Future<void> _handleSaltMismatch() async {
    // Busy-Check
    if (ref.read(mainProvider).isBusy) return;

    // Passenden Text für die Passwortfrage
    final notifier = ref.read(mainProvider.notifier);
    final message = notifier.isOnboarding()
        ? "Dieser Tresor wird bereits auf einem anderen Gerät verwendet. Bitte gib das Master-Passwort ein, um die Identität zu übernehmen." // UUIDs stimmen nicht
        : "Du hast das Master-Passwort auf einem anderen Gerät geändert. Bitte gib es zur Synchronisation ein.";

    // Passwort abfragen (solange, bis es korrekt ist oder der Benutzer abbricht) und Identität übernehmen
    String? errorText;
    while (true) {
      // Master-Passwort abfragen
      final password = await PasswordDialog.show(
          context,
          title: 'Account verknüpfen',
          text: message,
          errorText: errorText,
      );
      if (password == null) return;

      // Die auf dem Server gespeicherte Identität übernehmen
      final success = await notifier.adoptIdentity(password);
      if (!mounted) return;

      // Aktuellen State holen
      final state = ref.read(mainProvider);

      // Fehlerfall
      if (!success) {
        if (state.error.code == ErrorCode.wrongPassword) {
          // im Dialog anzeigen, NICHT SnackBar
          errorText = state.error.text;
          continue;
        }
        Snack.show(context, state.error.text);
        break;
      }

      // Erfolgsfall
      Snack.show(context, 'Account erfolgreich verknüpft.', success: true);
      _handleSync(); // Sync erneut starten
      break;
    }
  }

  /// Navigiert zu den Einstellungen
  Future<void> _handleSettings() async {
    // Busy-Check
    if (ref.read(mainProvider).isBusy) return;

    // Einstellungen öffnen
    Navigator.of(context).pushNamed('/settings');
  }

  /// Beendet die Session und navigiert zur Login-Seite.
  Future<void> _handleLogout() async {
    // Busy-Check
    if (ref.read(mainProvider).isBusy) return;

    // Logout durchführen
    final notifier = ref.read(mainProvider.notifier);
    notifier.logout();
    //if (!mounted) return;

    // Loginseite öffnen (und Navigations‑Stack zurücksetzen)
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  /// Öffnet die Editierseite.
  Future<void> _handleAddEntry() async {
    // Busy-Check
    if (ref.read(mainProvider).isBusy) return;

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
    // Busy-Check
    if (ref.read(mainProvider).isBusy) return;

    // Öffnet die Editierseite und wartet, bis die Seite wieder geschlossen wird.
    final hasChanged = await Navigator.of(context).pushNamed('/detail', arguments: entry.id);

    // Wenn der Eintrag geändert wurde, die Liste neu laden.
    if (hasChanged == true && mounted) {
      final notifier = ref.read(mainProvider.notifier);
      notifier.load();
    }
  }
}
