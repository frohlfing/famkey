import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/features/settings/settings_notifier.dart';
import 'package:privault/features/settings/settings_state.dart';
import 'package:privault/widgets/confirm_dialog.dart';
import 'package:privault/widgets/friend_search_dialog.dart';
import 'package:privault/widgets/password_dialog.dart';
import 'package:privault/widgets/password_field.dart';
import 'package:privault/widgets/snack.dart';

/// Der [SettingsPage] ermöglicht die Konfiguration der App und des aktuellen Tresors.
///
/// Hier werden sowohl sicherheitsrelevante als auch optische Einstellungen verwaltet:
/// * **Identität:** Ändern des Master-Passworts und Verwaltung des Tresornamens.
/// * **Synchronisation:** Konfiguration der Server-Verbindung (URL & API-Token).
/// * **Sicherheit:** Verwaltung von vertrauenswürdigen Kontakten ("Freunde") und Biometrie-Optionen.
/// * **Generator:** Standardwerte für den integrierten Passwort-Generator festlegen.
/// * **System:** Schneller Zugriff auf Android-Systemeinstellungen für Autofill und App-Infos.
class SettingsPage extends ConsumerStatefulWidget {
  /// Konstruktor
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {

  // ------------------------------------------------------------------------
  // --- TextEditingController ---
  // ------------------------------------------------------------------------

  final _vaultNameController = TextEditingController();
  final _userNameController = TextEditingController();
  final _hostController = TextEditingController();
  final _apiTokenController = TextEditingController();
  final _pwSpecialCharsController = TextEditingController();
  final _pwLengthController = TextEditingController();
  final _categoryPlaceholderController = TextEditingController();

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert den Screen und lädt die Daten, sobald der erste Frame gerendert wurde.
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Daten laden
      final notifier = ref.read(settingsProvider.notifier);
      await notifier.load();
    });
  }

  /// Gibt Ressourcen frei.
  @override
  void dispose() {
    _vaultNameController.dispose();
    _userNameController.dispose();
    _hostController.dispose();
    _apiTokenController.dispose();
    _pwSpecialCharsController.dispose();
    _pwLengthController.dispose();
    _categoryPlaceholderController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  /// Rendert die Seite (getriggert durch Änderungen im State)
  @override
  Widget build(BuildContext context) {

    // todo Listener anpassen
    // Listener für Side-Effects (Navigation, SnackBars)
    // Er wird nur einmal ausgelöst, wenn sich der Status ändert, und verursacht keine Rebuilds.
    ref.listen(settingsProvider.select((s) => s.status), (previous, next) {
      final state = ref.read(settingsProvider);

      switch (next) {
        case SettingsActionStatus.saved:
          Snack.show(context, 'Gespeichert!', success: true);
          Navigator.of(context).pop(true); // Zurück zur Hauptseite
          break;

        case SettingsActionStatus.deleted:
          Snack.show(context, 'Tresor gelöscht!', success: true);
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false); // Loginseite öffnen (und Navigations‑Stack zurücksetzen)
          break;

        case SettingsActionStatus.testSuccessful:
          Snack.show(context, 'Verbindung erfolgreich.', success: true);
          break;

        case SettingsActionStatus.testFailed:
          Snack.show(context, state.error.text);
          break;

        case SettingsActionStatus.changingVaultName:
          _handleRenameVault();
          break;

        case SettingsActionStatus.changingPassword:
          _handleChangePassword();
          break;

        case SettingsActionStatus.friendAdded:
          Snack.show(context, 'Freund wurde hinzugefügt. Bitte verifiziere zur Sicherheit den Fingerprint.', success: true);
          break;

        case SettingsActionStatus.friendDeleted:
          Snack.show(context, 'Freund gelöscht', success: true);
          break;

        case SettingsActionStatus.failure:
          if (state.error.field == null) { // Nur allgemeine Fehler anzeigen
            Snack.show(context, state.error.text);
          }
          break;

        default:
          break;
      }
    });

    // Listener, der die Controller nur bei Initialladung oder Generierung füllt
    ref.listen(settingsProvider, (previous, next) {
      if (previous == next) return;
      final formData = next.formData;
      if (_vaultNameController.text != formData.vaultName) _vaultNameController.text = formData.vaultName;
      if (_userNameController.text != formData.userName) _userNameController.text = formData.userName;
      if (_hostController.text != formData.host) _hostController.text = formData.host;
      if (_apiTokenController.text != formData.apiToken) _apiTokenController.text = formData.apiToken;
      if (_pwSpecialCharsController.text != formData.pwSpecialChars) _pwSpecialCharsController.text = formData.pwSpecialChars;
      if (_pwLengthController.text != formData.pwLength.toString()) _pwLengthController.text = formData.pwLength.toString();
      if (_categoryPlaceholderController.text != formData.categoryPlaceholder) _categoryPlaceholderController.text = formData.categoryPlaceholder;
    });

    // Gezielte Watches für maximale Performance
    final isBusy = ref.watch(settingsProvider.select((s) => s.isBusy));
    final isRegistered = ref.watch(settingsProvider.select((state) => state.isRegistered));

    // Notifier holen
    final notifier = ref.read(settingsProvider.notifier);

    // todo Consumer einbauen (Skeleton hab ich bereits an den entsprechenden Stellen eingefügt)
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Einstellungen'),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _handleCancel,
              tooltip: "Zurück",
            ),
            // actions: [
            //   IconButton(
            //     icon: const Icon(Icons.check),
            //     tooltip: 'Speichern',
            //     onPressed: notifier.save,
            //   ),
            // ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // Button linksbündig
              children: [

                // ------------------------------------------------------------------------
                // --- Tresor ---
                // ------------------------------------------------------------------------
                _buildSectionTitle('Tresor'),

                // --- Tresorname ---
                //_buildText('Tresorname', (state) => state.formData.vaultName, icon: Icons.shield_outlined),
                //const SizedBox(height: 16),
                Consumer(
                  builder: (context, ref, _) {
                    final errorText = ref.watch(settingsProvider.select((state) => state.error.field == 'vaultName' ? state.error.text : null));
                    return TextField(
                      controller: _vaultNameController,
                      textInputAction: TextInputAction.next,
                      enabled: !isRegistered,
                      decoration: InputDecoration(
                        labelText: 'Tresorname',
                        prefixIcon: Icon(Icons.shield_outlined),
                        errorText: errorText,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: notifier.setVaultName,
                    );
                  },
                ),
                const SizedBox(height: 8),

                // --- Button für Tresor-Umbenennung ---
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade800,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isBusy || isRegistered ? null : _handleRenameVault,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Tresor umbenennen'),
                ),
                const SizedBox(height: 16),

                // --- Speicherort ---
                Row(
                  children: [
                    const Icon(Icons.folder_open_outlined, size: 20, color: Colors.blueGrey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Speicherort der Tresore',
                            style: TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                          ),
                          Consumer(
                            builder: (context, ref, _) {
                              final vaultStoragePath = ref.watch(settingsProvider.select((state) => state.vaultStoragePath));
                              return Text(
                                vaultStoragePath,
                                style: const TextStyle(fontSize: 14, color: Colors.grey),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // ------------------------------------------------------------------------
                // --- Login ---
                // ------------------------------------------------------------------------
                _buildSectionTitle('Login'),

                // --- Button für Passwortänderung ---
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade800,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isBusy ? null : _handleChangePassword,
                  icon: const Icon(Icons.password_outlined),
                  label: const Text('Master-Passwort ändern'),
                ),
                const SizedBox(height: 16),

                // --- Biometrie ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Biometrie verwenden',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Erlaubt das Entsperren des Tresors via Fingerabdruck oder Gesichtserkennung.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final useBiometric = ref.watch(settingsProvider.select((state) => state.formData.useBiometric));
                        return Switch(
                          value: useBiometric,
                          onChanged: isBusy ? null : notifier.setUseBiometric,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // ------------------------------------------------------------------------
                // --- Sync-Server ---
                // ------------------------------------------------------------------------
                _buildSectionTitle('Sync-Server'),

                // --- Benutzername ---
                //_buildText('Benutzername', (state) => state.formData.userName, icon: Icons.person_outline),
                //const SizedBox(height: 16),

                Consumer(
                  builder: (context, ref, _) {
                    final errorText = ref.watch(settingsProvider.select((state) => state.error.field == 'userName' ? state.error.text : null));
                    return TextField(
                      controller: _userNameController,
                      textInputAction: TextInputAction.next,
                      enabled: !isRegistered,
                      decoration: InputDecoration(
                        labelText: 'Benutzername',
                        prefixIcon: Icon(Icons.person_outline),
                        errorText: errorText,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: notifier.setUserName,
                    );
                  },
                ),
                const SizedBox(height: 8),

                // --- Button für Namensänderung ---
                ElevatedButton.icon(
                  onPressed: isBusy || isRegistered ? null : notifier.saveUsername,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Benutzername speichern'),
                ),
                const SizedBox(height: 32),

                // --- Host ---
                //_buildText('Server-URL', (state) => state.formData.host, icon: Icons.cloud_outlined),
                //const SizedBox(height: 16),
                Consumer(
                  builder: (context, ref, _) {
                    final errorText = ref.watch(settingsProvider.select((state) => state.error.field == 'host' ? state.error.text : null));
                    return TextField(
                      controller: _hostController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Server-URL',
                        prefixIcon: Icon(Icons.cloud_outlined),
                        errorText: errorText,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: notifier.setHost,
                    );
                  },
                ),
                const SizedBox(height: 16),

                // --- API-Token ---
                Consumer(
                  builder: (context, ref, _) {
                    final errorText = ref.watch(settingsProvider.select((state) => state.error.field == 'apiToken' ? state.error.text : null));
                    return PasswordField(
                      controller: _apiTokenController,
                      textInputAction: TextInputAction.next,
                      label: 'API-Token',
                      prefixIcon: Icons.vpn_key_outlined,
                      errorText: errorText,
                      onChanged: notifier.setApiToken,
                    );
                  },
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                // --- Button für Verbindungtest ---
                ElevatedButton.icon(
                  onPressed: isBusy ? null : notifier.testConnection,
                  icon: const Icon(Icons.swap_calls_outlined),
                  label: const Text('Verbindung testen'),
                ),
                const SizedBox(width: 16),

                // --- Button für Änderung der Verbindungsparameter ---
                ElevatedButton.icon(
                  onPressed: isBusy ? null : notifier.saveSyncServer,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Speichern'),
                ),
                ]),
                const SizedBox(height: 32),

                // ------------------------------------------------------------------------
                // --- Passwort-Generator ---
                // ------------------------------------------------------------------------
                _buildSectionTitle('Passwort-Generator'),

                // --- Länge ---
                Consumer(
                  builder: (context, ref, _) {
                    final errorText = ref.watch(settingsProvider.select((state) => state.error.field == 'title' ? state.error.text : null));
                    return TextField(
                      controller: _pwLengthController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Länge',
                        prefixIcon: const Icon(Icons.onetwothree_outlined),
                        errorText: errorText,
                        border: const OutlineInputBorder(),
                        // Minus- und Plus-Button für die Länge
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () {
                                final val = int.tryParse(_pwLengthController.text) ?? 0;
                                if (val > 1) {
                                  final newVal = val - 1;
                                  _pwLengthController.text = newVal.toString();
                                  notifier.setPwLength(newVal);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                final val = int.tryParse(_pwLengthController.text) ?? 0;
                                final newVal = val + 1;
                                _pwLengthController.text = newVal.toString();
                                notifier.setPwLength(newVal);
                              },
                            ),
                          ],
                        ),
                      ),
                      onChanged: (val) {
                        final parsed = int.tryParse(val);
                        if (parsed != null) notifier.setPwLength(parsed);
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),

                // --- Sonderzeichen ---
                Consumer(
                  builder: (context, ref, _) {
                    final errorText = ref.watch(settingsProvider.select((state) => state.error.field == 'title' ? state.error.text : null));
                    return TextField(
                      controller: _pwSpecialCharsController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Sonderzeichen',
                        prefixIcon: Icon(Icons.emoji_symbols_outlined),
                        errorText: errorText,
                        border: OutlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.star),
                              tooltip: 'Standard',
                              onPressed: notifier.setDefaultPwSpecialChars,
                            ),
                            IconButton(
                              icon: const Icon(Icons.all_inclusive),
                              tooltip: 'Alle',
                              onPressed: notifier.setAllPwSpecialChars,
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle),
                              tooltip: 'Keine',
                              onPressed: notifier.setNonePwSpecialChars,
                            ),
                          ],
                        ),
                      ),
                      onChanged: notifier.setPwSpecialChars,
                    );
                  },
                ),
                const SizedBox(height: 8),

                // --- Lesbarkeit optimieren ---
                Consumer(
                  builder: (context, ref, _) {
                    final pwAvoidIlO0 = ref.watch(settingsProvider.select((state) => state.formData.pwAvoidIlO0));
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Lesbarkeit optimieren (I, l, O, 0 ausschließen)'),
                        Switch(
                          value: pwAvoidIlO0,
                          onChanged: notifier.setPwAvoidIlO0,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),

                // --- Button für Änderung der Passwort-Generator-Einstellungen ---
                ElevatedButton.icon(
                  onPressed: isBusy ? null : notifier.savePasswortGeneratorSettings,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Speichern'),
                ),
                const SizedBox(height: 32),

                // ------------------------------------------------------------------------
                // --- Freunde ---
                // ------------------------------------------------------------------------
                _buildSectionHeaderWithAction(
                  'Freunde',
                  Icons.person_add,
                  'Person suchen',
                  _handleAddFriend,
                ),

                // --- Liste ---
                Consumer(builder: (context, ref, _) {
                  final friends = ref.watch(settingsProvider.select((s) => s.friends));
                  final fingerprints = ref.watch(settingsProvider.select((s) => s.fingerprints));
                  final friendNeedsRekeying = ref.watch(settingsProvider.select((s) => s.friendNeedsRekeying));
                  if (friends.isEmpty) {
                    return Text('Dieser Tresor wird nicht geteilt.', style: TextStyle(fontStyle: FontStyle.italic));
                  }
                  return Column(
                    children: friends.map((friend) => Card(
                      key: ValueKey('friend_${friend.uuid}'),
                      child: ListTile(
                        title: Text(friend.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fingerprints[friend.id] ?? '',
                              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                            ),
                            if (friendNeedsRekeying[friend.id] ?? false)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'Fingerprint hat sich geändert!',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Verifiziert',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Transform.scale(
                              scale: 0.75,
                              child: Switch(
                                value: friend.isVerified,
                                onChanged: (_) => notifier.toggleVerification(friend),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              tooltip: 'Löschen',
                              onPressed: () => _handleDeleteFriend(friend),
                            ),
                          ],
                        ),
                      ),
                    )).toList(),
                  );
                }),
                const SizedBox(height: 32),

                // ------------------------------------------------------------------------
                // --- Design ---
                // ------------------------------------------------------------------------
                _buildSectionTitle('Design'),

                // --- Theme ---
                Consumer(
                  builder: (context, ref, _) {
                    final themeMode = ref.watch(settingsProvider.select((state) => state.themeMode));
                    return SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                          icon: Icon(Icons.brightness_auto_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Hell'),
                          icon: Icon(Icons.light_mode_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dunkel'),
                          icon: Icon(Icons.dark_mode_outlined),
                        ),
                      ],
                      selected: {themeMode},
                      onSelectionChanged: (val) => notifier.setThemeMode(val.first),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // --- Platzhalter für Kategorie ---
                Consumer(
                  builder: (context, ref, _) {
                    final errorText = ref.watch(settingsProvider.select((state) => state.error.field == 'title' ? state.error.text : null));
                    return TextField(
                      controller: _categoryPlaceholderController,
                      decoration: InputDecoration(
                        labelText: 'Name für leere Kategorie',
                        prefixIcon: Icon(Icons.label_outlined),
                        errorText: errorText,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: notifier.setCategoryPlaceholder,
                    );
                  },
                ),
                const SizedBox(height: 32),

                // ------------------------------------------------------------------------
                // --- Systemeinstellungen ---
                // ------------------------------------------------------------------------
                _buildSectionTitle('Systemeinstellungen'),

                _buildSystemButton(
                  Icons.fingerprint_outlined,
                  'Biometrie',
                  'Systemeinstellungen für Biometrie öffnen',
                  notifier.openBiometricSettings,
                ),

                _buildSystemButton(
                  Icons.text_fields_outlined,
                  'Autofill',
                  'Hilfeseite für das automatische Ausfüllen öffnen',
                  notifier.openAutofillSettings,
                ),

                _buildSystemButton(
                  Icons.info_outline,
                  'App-Info',
                  'Systemdetails dieser App anzeigen',
                  notifier.openAppSettings,
                ),

                const SizedBox(height: 32),

                // ------------------------------------------------------------------------
                // --- Footer ---
                // ------------------------------------------------------------------------

                // --- Button für Löschen ---
                Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    onPressed: _handleDeleteVault,
                    icon: const Icon(Icons.delete_outlined),
                    label: const Text('Tresor lokal löschen'),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
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

  // /// Gibt den Wert aus mit einem Titel und einem Icon.
  // Widget _buildText(String title, String Function(SettingsState) selector, {IconData? icon}) {
  //   return Row(
  //     children: [
  //       Icon(icon, size: 20, color: Colors.blueGrey),
  //       const SizedBox(width: 12),
  //       Expanded(
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Text(
  //               title,
  //               style: TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold),
  //             ),
  //             Consumer(
  //               builder: (context, ref, _) {
  //                 final value = ref.watch(settingsProvider.select(selector));
  //                 return Text(
  //                   value,
  //                   style: const TextStyle(fontSize: 14, color: Colors.grey),
  //                 );
  //               },
  //             ),
  //           ],
  //         ),
  //       ),
  //     ],
  //   );
  // }

  /// Erstellt eine einheitliche, fettgedruckte Überschrift für die verschiedenen
  /// Einstellungsbereiche (z. B. "Identifikation" oder "Synchronisation").
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey),
      ),
    );
  }

  /// Erstellt eine Sektion-Überschrift, die zusätzlich einen Aktion-Button
  /// auf der rechten Seite enthält (z. B. zum Hinzufügen von Freunden).
  Widget _buildSectionHeaderWithAction(String title, IconData icon, String tooltip, VoidCallback onPressed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSectionTitle(title),
        Padding(
          padding: EdgeInsets.only(top: 0, bottom: 0, left: 0, right: 28),
          child: IconButton(icon: Icon(icon), tooltip: tooltip, onPressed: onPressed),
        ),
      ],
    );
  }

  /// Erstellt eine einheitliche Schaltfläche inklusive Icon und Hilfetext für Systemeinstellungen.
  Widget _buildSystemButton(IconData icon, String label, String help, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: ElevatedButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label)),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: Text(help, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------------
  // --- Handler ---
  // ------------------------------------------------------------------------

  // Speichert erst die Änderungen, wenn gewünscht und springt dann zurück.
  Future<void> _handleCancel() async {
    // final state = ref.read(settingsProvider);
    // if (state.isDirty) {
    //   final confirmed = await ConfirmDialog.show(
    //     context,
    //     title: 'Eintrag speichern',
    //     text: 'Möchtest du die Änderungen speichern?',
    //     ok: 'Ja, speichern',
    //     cancel: 'Nein, verwerfen',
    //   );
    //   if (mounted && confirmed == true) {
    //     final notifier = ref.read(settingsProvider.notifier);
    //     notifier.save(); // Statt Cancel die Save-Action ausführen
    //     return;
    //   }
    // }
    if (mounted) Navigator.of(context).pop(); // Zur vorherigen Seite navigieren
  }

  /// Benennt den Tresor um.
  Future<void> _handleRenameVault() async {
    // String? vaultName = state.formData.vaultName;
    //
    // // Neuer Name des Tresors abfragen
    // if (vaultName == state.originalFormData.vaultName || state.error.field == 'vaultName') {
    //   vaultName = await InputDialog.show(
    //     context,
    //     title: 'Tresor umbenennen',
    //     text: 'Wie soll der Tresor heißen?',
    //     label: 'Neuer Tresorname',
    //     value: vaultName,
    //     errorText: state.error.field == 'vaultName' ? state.error.text : null,
    //   );
    //   if (!mounted || vaultName == null) return;
    // }

    final state = ref.read(settingsProvider);
    final password = await PasswordDialog.show(
      context,
      title: 'Tresor umbenennen',
      text: 'Bitte bestätige dein Master-Passwort, um den Tresor umzubenennen.',
      errorText: state.error.code == ErrorCode.wrongPassword ? state.error.text : null,
    );
    if (mounted && password != null) {
      final notifier = ref.read(settingsProvider.notifier);
      notifier.renameVault(password);
    }
  }

  /// Zeigt eine Sicherheitsabfrage an, bevor der lokale Tresor gelöscht wird.
  Future<void> _handleDeleteVault() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Tresor lokal löschen',
      text: 'Bist du sicher? Alle lokalen Daten dieses Tresors werden unwiderruflich entfernt.',
      ok: 'Ja, löschen',
    );
    if (mounted && confirmed == true) {
      final notifier = ref.read(settingsProvider.notifier);
      notifier.deleteVault();
    }
  }

  /// Ändert das Master-Passwort.
  Future<void> _handleChangePassword() async {
    final state = ref.read(settingsProvider);
    String? newPassword = state.newPassword;

    // Neues Passwort abfragen
    if (newPassword.isEmpty || state.error.field == 'newVPassword') {
      newPassword = await PasswordDialog.show(
        context,
        title: 'Passwort ändern',
        text: 'Bitte gib dein NEUES Master-Passwort ein.',
        errorText: state.error.field == 'newPassword' ? state.error.text : null,
      );
      if (!mounted || newPassword == null) return;
    }

    // Bisheriges Passwort abfragen
    final password = await PasswordDialog.show(
      context,
      title: 'Passwort ändern',
      text: 'Bitte gib jetzt dein AKTUELLES Master-Passwort ein.',
      errorText: state.error.code == ErrorCode.wrongPassword ? state.error.text : null,
    );
    if (!mounted || password == null) return;

    final notifier = ref.read(settingsProvider.notifier);
    notifier.changeMasterPassword(newPassword, password);
  }

  // /// Ändert den Benutzername.
  // Future<void> _handleChangeUsername() async {
  //   final state = ref.read(settingsProvider);
  //   final name = await InputDialog.show(
  //     context,
  //     title: 'Benutzername ändern',
  //     text: 'Bitte gib dein neuen Benutzername ein.',
  //     value: state.formData.userName,
  //     errorText: state.error.field == 'userName' ? state.error.text : null,
  //   );
  //   if (mounted && name != null) {
  //     final notifier = ref.read(settingsProvider.notifier);
  //     notifier.saveUsername(name);
  //   }
  // }

  /// Fügt einen Freund zu Liste hinzu.
  Future<void> _handleAddFriend() async {
    final state = ref.read(settingsProvider);
    final name = await FriendSearchDialog.show(
      context,
      errorText: state.error.code == ErrorCode.wrongPassword ? state.error.text : null,
    );
    if (mounted && name != null) {
      final notifier = ref.read(settingsProvider.notifier);
      notifier.addFriend(name);
      return;
    }
  }

  /// Fragt nach Bestätigung und löscht dann den Freund aus der Liste.
  Future<void> _handleDeleteFriend(dynamic user) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Person entfernen',
      text: 'Möchtest du die Person aus deiner Liste löschen?\n'
          'Das Teilen von Einträgen mit dieser Person ist dann nicht mehr möglich.',
      ok: 'Ja, löschen',
    );
    if (mounted && confirmed == true) {
      final notifier = ref.read(settingsProvider.notifier);
      notifier.deleteFriend(user);
    }
  }
}
