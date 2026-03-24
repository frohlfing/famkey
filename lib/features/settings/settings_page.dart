import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/features/settings/password_generator_dialog.dart';
import 'package:privault/features/settings/server_dialog.dart';
import 'package:privault/features/settings/settings_notifier.dart';
import 'package:privault/features/settings/settings_state.dart';
import 'package:privault/widgets/confirm_dialog.dart';
import 'package:privault/widgets/friend_search_dialog.dart';
import 'package:privault/widgets/input_dialog.dart';
import 'package:privault/widgets/password_dialog.dart';
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
  // --- Interne Variablen ---
  // ------------------------------------------------------------------------

  /// Gibt an, ob die Einstellungen geändert wurden.
  var _hasChanged = false;

  // ------------------------------------------------------------------------
  // --- TextEditingController ---
  // ------------------------------------------------------------------------

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
    _categoryPlaceholderController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  /// Rendert die Seite (getriggert durch Änderungen im State)
  @override
  Widget build(BuildContext context) {

    // Listener für Side-Effects (Navigation, SnackBars)
    // Er wird nur einmal ausgelöst, wenn sich der Status ändert, und verursacht keine Rebuilds.
    ref.listen(settingsProvider.select((s) => s.status), (previous, next) {
      final state = ref.read(settingsProvider);

      switch (next) {
        case SettingsActionStatus.saved:
          _hasChanged = true;
          Snack.show(context, 'Gespeichert!', success: true);
          break;

        case SettingsActionStatus.deleted:
          Snack.show(context, 'Tresor gelöscht!', success: true);
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false); // Loginseite öffnen (und Navigations‑Stack zurücksetzen)
          break;

        case SettingsActionStatus.renameVaultFailed:
          _showRenameVaultDialog();
          break;

        case SettingsActionStatus.changePasswordFailed:
          _showChangePasswordDialog();
          break;

        case SettingsActionStatus.renameUserFailed:
          _showRenameUserDialog();
          break;

        case SettingsActionStatus.testSuccessful:
        case SettingsActionStatus.testFailed:
        case SettingsActionStatus.changeServerFailed:
          _showServerDialog();
          break;

        case SettingsActionStatus.friendAdded:
          Snack.show(context, 'Freund wurde hinzugefügt. Bitte verifiziere zur Sicherheit den Fingerprint.', success: true);
          break;

        case SettingsActionStatus.friendDeleted:
          Snack.show(context, 'Freund gelöscht', success: true);
          break;

        case SettingsActionStatus.changePasswordGeneratorFailed:
          _showPasswordGeneratorDialog();
          break;

        case SettingsActionStatus.changeCategoryPlaceholderFailed:
          _showCategoryPlaceholderDialog();
          break;

        case SettingsActionStatus.failure:
          Snack.show(context, state.error.text);
          break;

        default:
          break;
      }
    });

    // // Listener, der die Controller nur bei Initialladung oder Generierung füllt
    // ref.listen(settingsProvider, (previous, next) {
    //   if (previous == next) return;
    //   if (_dummyController.text != next.dummy) _dummyController.text = next.dummy;
    // });

    // Gezielte Watches für maximale Performance
    final isBusy = ref.watch(settingsProvider.select((s) => s.isBusy));

    // Notifier holen
    final notifier = ref.read(settingsProvider.notifier);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Einstellungen'),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(_hasChanged),
              tooltip: "Zurück",
            ),
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

                // --- Speicherort ---
                _buildText(
                  'Speicherort',
                  (state) => state.vaultStoragePath,
                  icon: Icons.folder_open_outlined,
                ),

                // --- Tresorname ---
                _buildText(
                  'Tresorname',
                  (state) => state.vaultName,
                  icon: Icons.shield_outlined,
                  onPressed: _showRenameVaultDialog,
                  tooltip: 'Tresor umbenennen',
                ),

                const Divider(height: 32),

                // ------------------------------------------------------------------------
                // --- Login ---
                // ------------------------------------------------------------------------

                _buildSectionTitle('Login'),

                const SizedBox(height: 16),

                // --- Button für Passwortänderung ---
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade800,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isBusy ? null : _showChangePasswordDialog,
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
                          Text('Biometrie verwenden'),
                          Text('Erlaubt das Entsperren des Tresors via Fingerabdruck oder Gesichtserkennung.', style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final useBiometric = ref.watch(settingsProvider.select((state) => state.useBiometric));
                        return Switch(
                          value: useBiometric,
                          onChanged: isBusy ? null : notifier.saveBiometricSettings,
                        );
                      },
                    ),
                  ],
                ),

                const Divider(height: 32),

                // ------------------------------------------------------------------------
                // --- Sync-Server ---
                // ------------------------------------------------------------------------

                _buildSectionTitle('Sync-Server'),

                // --- Benutzername ---
                _buildText(
                  'Benutzername',
                  (state) => state.userName,
                  icon: Icons.person_outline,
                  onPressed: _showRenameUserDialog,
                  tooltip: 'Benutzername ändern',
                ),

                // --- Host ---
                _buildText(
                  'Serveradresse',
                  (state) => state.host,
                  icon: Icons.cloud_outlined,
                  onPressed: _showServerDialog,
                  tooltip: 'Serveradresse ändern',
                ),

                const Divider(height: 32),

                // ------------------------------------------------------------------------
                // --- Freunde ---
                // ------------------------------------------------------------------------

                _buildSectionHeaderWithAction(
                  'Freunde',
                  Icons.person_add,
                  'Person suchen',
                  _showFriendSearchDialog,
                ),

                // --- Liste ---
                Consumer(builder: (context, ref, _) {
                  final host = ref.watch(settingsProvider.select((s) => s.host));
                  final friends = ref.watch(settingsProvider.select((s) => s.friends));
                  final fingerprints = ref.watch(settingsProvider.select((s) => s.fingerprints));
                  final friendNeedsRekeying = ref.watch(settingsProvider.select((s) => s.friendNeedsRekeying));
                  if (friends.isEmpty) {
                    if (host.isEmpty) {
                      return Text('Um Freunde hinzufügen zu können, muss der Sync-Server eingerichtet sein.', style: TextStyle(fontStyle: FontStyle.italic));
                    }
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
                              onPressed: () => _showDeleteFriendDialog(friend),
                            ),
                          ],
                        ),
                      ),
                    )).toList(),
                  );
                }),

                const SizedBox(height: 8),
                const Divider(height: 32),

                // ------------------------------------------------------------------------
                // --- Passwort-Generator ---
                // ------------------------------------------------------------------------

                _buildSectionTitle('Passwortgenerator'),
                const SizedBox(height: 16),

                _buildText(
                  'Länge',
                      (state) => state.pwLength.toString(),
                  icon: Icons.onetwothree_outlined,
                  onPressed: _showPasswordGeneratorDialog,
                  tooltip: 'Passwortgenerator ändern',
                ),

                _buildText(
                  'Sonderzeichen',
                      (state) => state.pwSpecialChars,
                  icon: Icons.emoji_symbols_outlined,
                ),

                _buildText(
                  'Lesbarkeit optimieren (I, l, O, 0 ausschließen)',
                      (state) => state.pwAvoidIlO0 ? 'Ja' : 'Nein',
                  icon: Icons.cloud_outlined,
                ),

                const Divider(height: 32),

                // ------------------------------------------------------------------------
                // --- Design ---
                // ------------------------------------------------------------------------

                _buildSectionTitle('Design'),
                const SizedBox(height: 16),

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
                _buildText(
                  'Name für leere Kategorie',
                  (state) => state.categoryPlaceholder,
                  icon: Icons.label_outlined,
                  onPressed: _showCategoryPlaceholderDialog,
                  tooltip: 'Name für leere Kategorie ändern',
                ),

                const Divider(height: 32),

                // ------------------------------------------------------------------------
                // --- Systemeinstellungen ---
                // ------------------------------------------------------------------------

                _buildSectionTitle('Systemeinstellungen'),
                const SizedBox(height: 16),

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
                    onPressed: _showDeleteVaultDialog,
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

  /// Erstellt eine einheitliche, fettgedruckte Überschrift für die verschiedenen
  /// Einstellungsbereiche (z. B. "Tresor" oder "Login").
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0, top: 0),
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

  /// Gibt den Wert aus mit einem Titel und einem Icon.
  Widget _buildText(String title, String Function(SettingsState) selector, {IconData? icon, void Function()? onPressed, String? tooltip}) {
    return ListTile(
      title: Text(title),
      subtitle: Consumer(
        builder: (context, ref, _) {
          final value = ref.watch(settingsProvider.select(selector));
          return Text(value);
        },
      ),
      leading: Icon(icon),
      trailing: onPressed != null ? IconButton(
        icon: const Icon(Icons.edit),
        onPressed: onPressed,
        tooltip: tooltip ?? 'Ändern',
      ) : null,
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

  /// Benennt den Tresor um.
  Future<void> _showRenameVaultDialog() async {
    final state = ref.read(settingsProvider);
    String? newVaultName = state.newVaultName;

    if (state.status != SettingsActionStatus.renameVaultFailed || state.error.field == 'vaultName') {
      newVaultName = await InputDialog.show(
        context,
        title: 'Tresor umbenennen',
        text: 'Wie soll der Tresor heißen?',
        label: 'Neuer Tresorname',
        value:  state.newVaultName,
        errorText: state.error.field == 'vaultName' ? state.error.text : null,
      );
      if (!mounted || newVaultName == null || newVaultName == state.vaultName) return;
    }

    final password = await PasswordDialog.show(
      context,
      title: 'Tresor umbenennen',
      text: 'Bitte bestätige dein Master-Passwort, um den Tresor umzubenennen.',
      errorText: state.error.code == ErrorCode.wrongPassword ? state.error.text : null,
    );
    if (!mounted || password == null) return;

    final notifier = ref.read(settingsProvider.notifier);
    notifier.renameVault(newVaultName, password);
  }

  /// Zeigt eine Sicherheitsabfrage an, bevor der lokale Tresor gelöscht wird.
  Future<void> _showDeleteVaultDialog() async {
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
  Future<void> _showChangePasswordDialog() async {
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

  /// Ändert den Benutzername.
  Future<void> _showRenameUserDialog() async {
    final state = ref.read(settingsProvider);
    final newUserName = await InputDialog.show(
      context,
      title: 'Benutzername ändern',
      text: 'Bitte gib deinen neuen Benutzernamen ein.',
      label: 'Benutzername',
      value: state.newUserName,
      errorText: state.error.field == 'userName' ? state.error.text : null,
    );
    if (mounted && newUserName != null && newUserName != state.userName) {
      final notifier = ref.read(settingsProvider.notifier);
      notifier.renameUser(newUserName);
    }
  }

  /// Ändert den Host und den API-Token.
  Future<void> _showServerDialog() async {
    final state = ref.read(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final dialogData = await ServerDialog.show(
      context,
      host: state.serverSettingsDialogData.host,
      apiToken: state.serverSettingsDialogData.apiToken,
      hostErrorText: state.error.field == 'host' ? state.error.text : null,
      apiTokenErrorText: state.error.field == 'apiToken' ? state.error.text : null,
      onTestConnectionPressed: notifier.testConnection,
      testStatus: state.status == SettingsActionStatus.testSuccessful ? TestStatus.success : (state.status == SettingsActionStatus.testFailed ? TestStatus.failure : null),
      testResult: state.status == SettingsActionStatus.testFailed && state.error.field == null ? state.error.text : null,
    );
    if (mounted && dialogData != null && dialogData != state.serverSettingsDialogData) {
      notifier.saveSyncServer(dialogData);
    }
  }

  /// Fügt einen Freund zu Liste hinzu.
  Future<void> _showFriendSearchDialog() async {
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
  Future<void> _showDeleteFriendDialog(dynamic user) async {
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

  /// Ändert die Einstellungen für das Passwort-Generator.
  Future<void> _showPasswordGeneratorDialog() async {
    final state = ref.read(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final dialogData = await PasswortGeneratorDialog.show(
      context,
      pwLength: state.passwordGeneratorDialogData.pwLength,
      pwSpecialChars: state.passwordGeneratorDialogData.pwSpecialChars,
      pwAvoidIlO0: state.passwordGeneratorDialogData.pwAvoidIlO0,
      pwLengthErrorText: state.error.field == 'pwLength' ? state.error.text : null,
      pwSpecialCharsErrorText: state.error.field == 'pwSpecialChars' ? state.error.text : null,
    );
    if (mounted && dialogData != null && dialogData != state.passwordGeneratorDialogData) {
      notifier.savePasswortGeneratorSettings(dialogData);
    }
  }

  /// Zeigt den Dialog zum Ändern des Platzhalters für eine Kategorie ohne Namen.
  Future<void> _showCategoryPlaceholderDialog() async {
    final state = ref.read(settingsProvider);
    final newCategoryPlaceholder = await InputDialog.show(
      context,
      title: 'Kategorie ohne Namen',
      text: 'Platzhalters für eine leere Kategorie.',
      value: state.newCategoryPlaceholder,
      errorText: state.error.field == 'categoryPlaceholder' ? state.error.text : null,
    );
    if (mounted && newCategoryPlaceholder != null && newCategoryPlaceholder != state.categoryPlaceholder) {
      final notifier = ref.read(settingsProvider.notifier);
      notifier.saveCategoryPlaceholder(newCategoryPlaceholder);
    }
  }
}
