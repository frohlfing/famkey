import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/features/settings/settings_notifier.dart';
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

      // Textfelder synchronisieren
      final state = ref.read(settingsProvider);
      _vaultNameController.text = state.vaultName;
      _userNameController.text = state.userName;
      _hostController.text = state.host;
      _apiTokenController.text = state.apiToken;
      _pwSpecialCharsController.text = state.pwSpecialChars;
      _pwLengthController.text = state.pwLength.toString();
      _categoryPlaceholderController.text = state.categoryPlaceholder;
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

  // todo testen, ob erforderlich
  // /// Aktualisiert insbesondere das Feld für Sonderzeichen, falls dieses extern
  // /// (via Buttons) geändert wurde.
  // void _onViewModelChanged() {
  //   if (!mounted) return;
  //   // Nur das Sonderzeichen-Feld aktualisieren, wenn es vom VM abweicht
  //   if (_pwSpecialCharsController.text != _viewModel.pwSpecialChars) {
  //     _pwSpecialCharsController.text = _viewModel.pwSpecialChars;
  //   }
  // }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  /// Rendert die Seite (getriggert durch Änderungen im State)
  @override
  Widget build(BuildContext context) {
    // Notifier und State holen
    final notifier = ref.read(settingsProvider.notifier);
    final state = ref.watch(settingsProvider);

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
            actions: [
              IconButton(
                icon: const Icon(Icons.check),
                tooltip: 'Speichern',
                onPressed: _handleSave,
              ),
            ],
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
                TextField(
                  controller: _vaultNameController,
                  enabled: !state.isRegistered,
                  decoration: const InputDecoration(
                    labelText: 'Tresorname',
                    prefixIcon: Icon(Icons.shield_outlined),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: notifier.setVaultName,
                ),
                const SizedBox(height: 12),
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
                          Text(
                            notifier.getVaultStoragePath(),
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
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
                    Switch(
                      value: state.useBiometric,
                      onChanged: notifier.setUseBiometric,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade800,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _handlePasswordChange,
                  icon: const Icon(Icons.password_outlined),
                  label: const Text('Master-Passwort ändern'),
                ),
                const SizedBox(height: 32),

                // ------------------------------------------------------------------------
                // --- Sync-Server ---
                // ------------------------------------------------------------------------
                _buildSectionTitle('Sync-Server'),
                TextField(
                  controller: _userNameController,
                  enabled: !state.isRegistered,
                  decoration: const InputDecoration(
                    labelText: 'Benutzername',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: notifier.setUserName,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _hostController,
                  decoration: const InputDecoration(
                    labelText: 'Host URL',
                    prefixIcon: Icon(Icons.cloud_outlined),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: notifier.setHost,
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _apiTokenController,
                  label: 'API-Token',
                  prefixIcon: Icons.vpn_key_outlined,
                  onChanged: notifier.setApiToken,
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _handleTestConnection,
                  icon: const Icon(Icons.swap_calls_outlined),
                  label: const Text('Verbindung testen'),
                ),
                const SizedBox(height: 32),

                // ------------------------------------------------------------------------
                // --- Passwort-Generator ---
                // ------------------------------------------------------------------------
                _buildSectionTitle('Passwort-Generator'),

                TextField(
                  controller: _pwLengthController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Länge',
                    prefixIcon: const Icon(Icons.onetwothree_outlined),
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
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _pwSpecialCharsController,
                  decoration: InputDecoration(
                    labelText: 'Sonderzeichen',
                    prefixIcon: Icon(Icons.emoji_symbols_outlined),
                    border: OutlineInputBorder(),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.star),
                          tooltip: 'Standard',
                          onPressed: () => notifier.setSpecialChars('Standard'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.all_inclusive),
                          tooltip: 'Alle',
                          onPressed: () => notifier.setSpecialChars('All'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle),
                          tooltip: 'Keine',
                          onPressed: () => notifier.setSpecialChars('None'),
                        ),
                      ],
                    ),
                  ),
                  onChanged: notifier.setPwSpecialChars,
                ),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Lesbarkeit optimieren (I, l, O, 0 ausschließen)'),
                    Switch(
                      value: state.pwAvoidIlO0,
                      onChanged: notifier.setPwAvoidIlO0,
                    ),
                  ],
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
                if (state.friends.isEmpty)
                  Text('Dieser Tresor wird nicht geteilt.', style: TextStyle(fontStyle: FontStyle.italic))
                else
                  Column(
                    children: state.friends
                        .map(
                          (friend) => Card(
                            key: ValueKey('friend_${friend.uuid}'),
                            child: ListTile(
                              title: Text(friend.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notifier.getFingerprint(friend.publicKey),
                                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                                  ),
                                  if (notifier.needsRekeying(friend.id))
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
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 32),

                // ------------------------------------------------------------------------
                // --- Design ---
                // ------------------------------------------------------------------------
                _buildSectionTitle('Design'),

                //const SizedBox(height: 16),
                SegmentedButton<ThemeMode>(
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
                  selected: {state.themeMode},
                  onSelectionChanged: (val) => notifier.setThemeMode(val.first),
                ),

                const SizedBox(height: 32),

                TextField(
                  controller: _categoryPlaceholderController,
                  decoration: const InputDecoration(
                    labelText: 'Name für leere Kategorie',
                    prefixIcon: Icon(Icons.label_outlined),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: notifier.setCategoryPlaceholder,
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

                const SizedBox(height: 64),

                Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    onPressed: _handleDeleteTresor,
                    icon: const Icon(Icons.delete_outlined),
                    label: const Text('Tresor lokal löschen'),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
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
    // Busy-Check
    if (ref.read(settingsProvider).isBusy) return;

    final notifier = ref.read(settingsProvider.notifier);
    if (notifier.isDirty()) {
      final confirmed = await ConfirmDialog.show(
        context,
        title: 'Eintrag speichern',
        text: 'Möchtest du die Änderungen speichern?',
        ok: 'Ja, speichern',
        cancel: 'Nein, verwerfen',
      );
      if (confirmed == true) {
        _handleSave();
        return;
      }
    }

    // Zur vorherigen Seite navigieren
    if (mounted) Navigator.of(context).pop();
  }

  // Speichert den Eintrag und springt dann zur Hauptseite.
  Future<void> _handleSave() async {
    // Busy-Check
    if (ref.read(settingsProvider).isBusy) return;

    // Tresor umbenennen, wenn ein anderer Name eingegeben wurde
    final notifier = ref.read(settingsProvider.notifier);
    if (notifier.isVaultRenamed()) {
      final success = await _handleRenameVault();
      if (!success || !mounted) return;
    }

    // Einstellungen speichern
    final success = await notifier.save();
    if (!mounted) return;

    // Aktuellen State holen
    final state = ref.read(settingsProvider);

    // Fehlerfall
    if (!success) {
      if (state.error.field == null) {
        Snack.show(context, state.error.text);
      }
      return;
    }

    // Erfolgsfall
    // Zurück zur Hauptseite navigieren
    Snack.show(context, 'Einstellungen gespeichert.', success: true);
    if (mounted) Navigator.of(context).pop();

  }

  /// Benennt den Tresor um.
  Future<bool> _handleRenameVault() async {
    // Busy-Check
    if (ref.read(settingsProvider).isBusy) return false;

    String? errorText;
    while (true) {

      // Passwort abfragen
      final password = await PasswordDialog.show(
        context,
        title: 'Tresor umbenennen',
        text: 'Bitte bestätige dein Master-Passwort, um den Tresor umzubenennen.',
        errorText: errorText,
      );
      if (password == null || !mounted) return false;

      // Tresor umbenennen
      final notifier = ref.read(settingsProvider.notifier);
      final success = await notifier.renameVault(password);
      if (!mounted) return false;

      // Aktuellen State holen
      final state = ref.read(settingsProvider);

      // Fehlerfall
      if (!success) {
        if (state.error.code == ErrorCode.wrongPassword) {
          errorText = state.error.text;
          continue; // Passwort falsch -> Passwortabfrage wiederholen
        }
        if (state.error.field == null) {
          Snack.show(context, state.error.text);
        }
        return false; // irgendein anderer Fehler -> Abbruch
      }

      // Erfolgsfall
      Snack.show(context, 'Tresor erfolgreich umbenannt.', success: true);
      return true;
    }
  }

  /// Fragt ein neues und das bisherige Passwort ab und ändert es schließlich.
  Future<void> _handlePasswordChange() async {
    // Busy-Check
    if (ref.read(settingsProvider).isBusy) return;

    // Neues Passwort abfragen
    final newPassword = await PasswordDialog.show(
      context,
      title: 'Passwort ändern',
      text: 'Bitte gib dein NEUES Master-Passwort ein.',
    );
    if (newPassword == null || !mounted) return;

    String? errorText;
    while (true) {

      // Bisheriges Passwort abfragen
      final currentPassword = await PasswordDialog.show(
        context,
        title: 'Passwort-Änderung autorisieren',
        text: 'Bitte gib jetzt dein AKTUELLES Master-Passwort ein.',
        errorText: errorText,
      );
      if (currentPassword == null || !mounted) return;

      // Validierung: Die Passwörter dürfen nicht identisch sein
      if (currentPassword == newPassword) {
        Snack.show(context, "Neues und altes Master-Passwort sind identisch");
        return;
      }

      // Passwort ändern
      final notifier = ref.read(settingsProvider.notifier);
      final success = await notifier.changeMasterPassword(newPassword, currentPassword);
      if (!mounted) return;

      // Aktuellen State holen
      final state = ref.read(settingsProvider);

      // Fehlerfall
      if (!success) {
        if (state.error.code == ErrorCode.wrongPassword) {
          errorText = state.error.text;
          continue; // Passwort falsch -> Passwortabfrage wiederholen
        }
        if (state.error.field == null) {
          Snack.show(context, state.error.text);
        }
        return; // irgendein anderer Fehler -> Abbruch
      }

      // Erfolgsfall
      Snack.show(context, 'Passwort erfolgreich geändert.', success: true);
      return;
    }
  }

  /// Testet, ob Host-URL und API-Token korrekt sind
  Future<void> _handleTestConnection() async {
    // Busy-Check
    if (ref.read(settingsProvider).isBusy) return;

    // Verbindung testen
    final notifier = ref.read(settingsProvider.notifier);
    final success = await notifier.testConnection();
    if (!mounted) return;

    // Aktuellen State holen
    final state = ref.read(settingsProvider);

    // Fehlerfall
    if (!success) {
      Snack.show(context, state.error.text);
      return;
    }

    // Erfolgsfall
    Snack.show(context, 'Verbindung erfolgreich.', success: true);
  }

  /// Öffnet den Freund-Such-Dialog und verarbeitet das Ergebnis.
  /// Bei Fehlern wie "nicht gefunden" bleibt der Dialog offen,
  /// andere Fehler werden per SnackBar gemeldet.
  Future<void> _handleAddFriend() async {
    // Busy-Check
    if (ref.read(settingsProvider).isBusy) return;
    
    String? errorText;
    while (true) {
      // Name des Freundes abfragen
      final name = await FriendSearchDialog.show(context, errorText: errorText);
      if (name == null || !mounted) return;

      // Freund hinzufügen
      final notifier = ref.read(settingsProvider.notifier);
      final success = await notifier.addFriend(name);
      if (!mounted) return;

      // Aktuellen State holen
      final state = ref.read(settingsProvider);

      // Fehlerfall
      if (!success) {
        if (state.error.code == ErrorCode.userNotFound || state.error.code == ErrorCode.userAlreadyAdded) {
          errorText = state.error.text;
          continue; // im Dialog anzeigen, NICHT SnackBar
        }
        if (state.error.field == null) {
          Snack.show(context, state.error.text);
        }
        return; // irgendein anderer Fehler -> Abbruch
      }

      // Erfolgsfall
      Snack.show(context, '"$name" wurde hinzugefügt. Bitte verifiziere zur Sicherheit den Fingerprint.', success: true);
      return;
    }
  }

  /// Fragt nach Bestätigung und löscht dann den Freund aus der Liste.
  Future<void> _handleDeleteFriend(dynamic user) async {
    // Busy-Check
    if (ref.read(settingsProvider).isBusy) return;

    // Löschen bestätigen lassen
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Person entfernen',
      text: 'Möchtest du die Person aus deiner Liste löschen?\n'
          'Das Teilen von Einträgen mit dieser Person ist dann nicht mehr möglich.',
      ok: 'Ja, löschen',
    );
    if (confirmed != true || !mounted) return;

    // Freund löschen
    final notifier = ref.read(settingsProvider.notifier);
    final success = await notifier.deleteFriend(user);
    if (!mounted) return;

    // Aktuellen State holen
    final state = ref.read(settingsProvider);

    // Fehlerfall
    if (!success) {
      if (state.error.field == null) {
        Snack.show(context, state.error.text);
      }
      return; // irgendein anderer Fehler -> Abbruch
    }

    // Erfolgsfall
    return; // ohne Meldung weiter machen
  }

  /// Zeigt eine Sicherheitsabfrage an, bevor der lokale Tresor gelöscht wird.
  Future<void> _handleDeleteTresor() async {
    // Busy-Check
    if (ref.read(settingsProvider).isBusy) return;

    // Löschen bestätigen lassen
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Tresor lokal löschen',
      text: 'Bist du sicher? Alle lokalen Daten dieses Tresors werden unwiderruflich entfernt.',
      ok: 'Ja, löschen',
    );
    if (confirmed != true || !mounted) return;

    // Tresor löschen
    final notifier = ref.read(settingsProvider.notifier);
    final success = await notifier.deleteVault();
    if (!mounted) return;

    // Aktuellen State holen
    final state = ref.read(settingsProvider);

    // Fehlerfall
    if (!success) {
      if (state.error.field == null) {
        Snack.show(context, state.error.text);
      }
      return; // irgendein anderer Fehler -> Abbruch
    }

    // Erfolgsfall
    // Loginseite öffnen (und Navigations‑Stack zurücksetzen)
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }
}
