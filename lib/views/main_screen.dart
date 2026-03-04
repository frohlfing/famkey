import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:privault/models/exceptions/empty_entry_key_exception.dart';
import 'package:provider/provider.dart';
import 'package:privault/viewmodels/main_view_model.dart';
import '../models/exceptions/salt_mismatch_exception.dart';

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

    /// Initialisiert den Screen und stößt das Laden der Tresor-Einträge
    /// über das ViewModel an, sobald die View bereit ist.
    @override
    void initState() {
        super.initState();

        _viewModel = context.read<MainViewModel>();

        WidgetsBinding.instance.addPostFrameCallback((_) {
                _viewModel.loadEntries();
            }
        );
    }

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
        // Das watch sorgt dafür, dass Flutter den gesamten Screen neu zeichnet, sobald das MainViewModel eine Änderung meldet.
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
                                        _handleSync(context, viewModel);
                                        break;
                                    case 'settings':
                                        Navigator.pushNamed(context, '/settings');
                                        break;
                                    case 'logout':
                                        viewModel.logout();
                                        Navigator.pushReplacementNamed(context, '/');
                                        break;
                                }
                            },
                            itemBuilder: (context) => [
                                const PopupMenuItem(
                                    value: 'sync',
                                    child: ListTile(leading: Icon(Icons.sync), title: Text('Synchronisieren')),
                                ),
                                const PopupMenuItem(
                                    value: 'settings',
                                    child: ListTile(leading: Icon(Icons.settings), title: Text('Einstellungen')),
                                ),
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                    value: 'logout',
                                    child: ListTile(
                                        leading: Icon(Icons.logout, color: Colors.red),
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
                                onPressed: () async {
                                    // Wenn wir von hier aus einen neuen Eintrag erstellen,
                                    // warten wir auf das Resultat (true beim pushReplacement im EditScreen).
                                    final result = await Navigator.pushNamed(context, '/edit');
                                    if (result == true) {
                                        viewModel.loadEntries();
                                    }
                                },
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
                                                suffixIcon: viewModel.searchQuery.isNotEmpty ? IconButton(
                                                        icon: const Icon(Icons.clear),
                                                        onPressed: () {
                                                            _searchController.clear();
                                                            viewModel.searchQuery = '';
                                                        },
                                                    ) : null,
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

                if (viewModel.isBusy) Container(
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
                    onTap: () async {
                        // Wenn wir aus dem DetailScreen zurückkommen (der ggf. Daten geändert hat),
                        // laden wir die Liste neu.
                        await Navigator.pushNamed(context, '/detail', arguments: entry.id);
                        viewModel.loadEntries();
                    },
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
        if (base64.isEmpty) return const Icon(Icons.vpn_key_outlined, color: Colors.blueGrey);
        try {
            return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(
                    base64Decode(base64),
                    width: 32,
                    height: 32,
                    errorBuilder: (ctx, err, stack) => const Icon(Icons.vpn_key_outlined),
                ),
            );
        }
        catch (_) {
            return const Icon(Icons.vpn_key_outlined);
        }
    }

    // ------------------------------------------------------------------------
    // --- Interne Methoden ---
    // ------------------------------------------------------------------------

    /// Zeigt eine farbige Statusmeldung (SnackBar) am unteren Bildschirmrand an.
    /// Nutzt Grün für Erfolgsmeldungen und Rot für Fehlerhinweise.
    void _showSnack(String message, {bool success = false}) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            SnackBar(
                content: Text(message),
                backgroundColor: success ? Colors.green.shade800 : Colors.red.shade800,
            ),
        );
    }

    /// Protokolliert eine Exception in der SnackBar an.
    void _showException(dynamic ex, {StackTrace? stackTrace}) {
        if (!mounted) return;
        debugPrint("❌ MainScreen: $ex");
        if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
        _showSnack("Ein unerwarteter Fehler ist aufgetreten.");
    }

    /// Öffnet einen modalen Dialog zur Passwortabfrage.
    ///
    /// Diese Funktion wird innerhalb des Sync-Prozesses benötigt, um 
    /// kritische Identitätsänderungen zu autorisieren.
    ///
    /// Wenn `errorText` gesetzt ist, wird das Textfeld rot + Fehlertext angezeigt.
    // todo ist identisch mit settings_screen._showPasswordDialog -> als widget auslagern
    Future<String?> _showPasswordDialog(String title, String message, {String? errorText}) async {
        final controller = TextEditingController();
        bool obscureText = true; // Passwort ausgeblendet

        return showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => StatefulBuilder(
                builder: (context, setDialogState) => AlertDialog(
                    title: Text(title),
                    content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text(message),
                            const SizedBox(height: 16),
                            TextField(
                                controller: controller,
                                obscureText: obscureText,
                                autofocus: true,
                                decoration: InputDecoration(
                                    labelText: 'Master-Passwort',
                                    border: const OutlineInputBorder(),
                                    errorText: errorText,
                                    suffixIcon: IconButton(
                                        icon: Icon(obscureText ? Icons.visibility : Icons.visibility_off),
                                        onPressed: () => setDialogState(() => obscureText = !obscureText)
                                    ),
                                ),
                                onSubmitted: (_) {
                                    if (controller.text.isNotEmpty) {
                                        Navigator.pop(dialogContext, controller.text);
                                    }
                                },
                            ),
                        ],
                    ),
                    actions: [
                        TextButton(onPressed: () => Navigator.pop(dialogContext, null), child: const Text('Abbrechen')),
                        ElevatedButton(
                            onPressed: () {
                                if (controller.text.isNotEmpty) {
                                    Navigator.pop(dialogContext, controller.text);
                                }
                            },
                            child: const Text('OK'),
                        ),
                    ],
                ),
            ),
        );
    }

    /// Koordiniert den Synchronisationsvorgang mit dem Server.
    ///
    /// Diese Methode verarbeitet nicht nur den Standard-Sync, sondern kümmert sich
    /// auch um komplexe Fälle wie den [SaltMismatchException]. 
    /// Wenn du beispielsweise dein Master-Passwort auf einem anderen Gerät geändert hast,
    /// führt dich diese Funktion durch den Prozess der Identitätsübernahme (Identity Adoption),
    /// damit deine lokalen Daten wieder mit dem Server harmonieren.
    Future<void> _handleSync(BuildContext context, MainViewModel viewModel) async {
        // if (await _viewModel.hasUnverifiedFriend()) {
        //     if (!context.mounted) return;
        //     showDialog(
        //         context: context,
        //         builder: (dialogContext) => AlertDialog(
        //             title: const Text('Verifizierung der Freunde erforderlich'),
        //             content: const Text('Für die Synchronisation müssen deine Freunde verifiziert sein. Gehe hierzu in den Einstellungen und überprüfe die Fingerprints.'),
        //             actions: [
        //                 TextButton(
        //                   onPressed: () => Navigator.pop(dialogContext),
        //                   child: const Text('OK'),
        //               ),
        //             ],
        //         ),
        //     );
        //     return;
        // }

        try {
            // Sync starten
            final stats = await viewModel.sync();
            if (!context.mounted) return;
            // Sync-Statistik anzeigen
            showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                    title: const Text('Info'),
                    content: Text('Synchronisation erfolgreich abgeschlossen.\n\n$stats'),
                    actions: [
                        TextButton(
                            onPressed: () {
                                if (!dialogContext.mounted) return;
                                Navigator.pop(dialogContext);
                            },
                            child: const Text('OK'),
                        ),
                    ],
                ),
            );
        }
        on SaltMismatchException catch (sme) {
            // Das Salt auf dem Server stimmt nicht mit dem Lokalen Salt überein -> Identitätsübernahme (Adoption) starten
            if (!context.mounted) return;
            final userResponse = sme.userResponse;
            try {
                String? errorText;
                final message = userResponse.userUuid == viewModel.myUuid
                    ? "Du hast das Master-Passwort auf einem anderen Gerät geändert. Bitte gib es zur Synchronisation ein."
                    : "Dieser Tresor wird bereits auf einem anderen Gerät verwendet. Bitte gib das Master-Passwort ein, um die Identität zu übernehmen.";
                while (true) {
                    // Master-Passwort abfragen
                    final password = await _showPasswordDialog('Account verknüpfen', message, errorText: errorText);
                    if (password == null) return;

                    // Die auf dem Server gespeicherte Identität übernehmen
                    final result = await viewModel.adoptIdentity(userResponse, password);
                    if (!context.mounted) return;

                    if (result == AdoptIdentityResult.success) {
                        _showSnack('Account erfolgreich verknüpft.', success: true);
                        _handleSync(context, viewModel); // Sync erneut starten
                        break;
                    }
                    else if (result == AdoptIdentityResult.wrongPassword) {
                        // im Dialog anzeigen, NICHT SnackBar
                        errorText = viewModel.errorMessage;
                        continue;
                    }
                    else {
                        _showSnack(viewModel.errorMessage ?? 'Unerwarteter Fehler');
                        break;
                    }
                }
            }
            catch (e, st) {
                _showException(e, stackTrace: st);
            }
        }
        on EmptyEntryKeyException catch (_) {
            const message = "Der Fingerprint eines Freundes hat sich geändert. Bitte verifiziere diesen in den Einstellungen, und starte danach die Synchronisation erneut.";
            if (await _viewModel.hasUnverifiedFriend()) {
                if (!context.mounted) return;
                showDialog(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                        title: const Text('Sicherheitsstopp'),
                        content: const Text(message),
                        actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('OK'),
                            ),
                        ],
                    ),
                );
            }
        }
        catch (e, st) {
            _showException(e, stackTrace: st);
        }
    }
}
