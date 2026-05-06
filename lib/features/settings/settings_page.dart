import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famkey/core/env.dart';
import 'package:famkey/features/settings/autotype_hotkey/autotype_hotkey_dialog.dart';
import 'package:famkey/features/settings/category_placeholder/category_placeholder_dialog.dart';
import 'package:famkey/features/settings/log_config/log_config_dialog.dart';
import 'package:famkey/features/settings/autolock_dialog/autolock_dialog.dart';
import 'package:famkey/features/settings/clipboard_clear/clipboard_clear_dialog.dart';
import 'package:famkey/features/settings/log_file/log_file_dialog.dart';
import 'package:famkey/features/settings/master_password/master_password_dialog.dart';
import 'package:famkey/features/settings/new_friend/new_friend_dialog.dart';
import 'package:famkey/features/settings/password_generator/password_generator_dialog.dart';
import 'package:famkey/features/settings/settings_notifier.dart';
import 'package:famkey/features/settings/settings_state.dart';
import 'package:famkey/features/settings/sync_server/sync_server_dialog.dart';
import 'package:famkey/features/settings/user_name/user_name_dialog.dart';
import 'package:famkey/features/settings/vault_name/vault_name_dialog.dart';
import 'package:famkey/widgets/confirm_dialog.dart';
import 'package:famkey/widgets/snack.dart';

/// Der [SettingsPage] ermöglicht die Konfiguration der App und des aktuellen Tresors.
///
/// Hier werden sowohl sicherheitsrelevante als auch optische Einstellungen verwaltet:
/// * **Identität:** Ändern des Master-Passworts und Verwaltung des Tresornamens.
/// * **Synchronisation:** Konfiguration der Server-Verbindung (URL & API-Token).
/// * **Sicherheit:** Verwaltung von vertrauenswürdigen Kontakten ("Freunde") und Biometrie-Optionen.
/// * **Generator:** Standardwerte für den integrierten Passwortgenerator festlegen.
/// * **System:** Schneller Zugriff auf Android-Systemeinstellungen für Autofill und App-Infos.
class SettingsPage extends ConsumerStatefulWidget {
  /// Konstruktor
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> with WidgetsBindingObserver {

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
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Daten laden
      final notifier = ref.read(settingsProvider.notifier);
      await notifier.load();
    });
  }

  /// Gibt Ressourcen frei.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _categoryPlaceholderController.dispose();
    super.dispose();
  }

  /// Aktualisiert den Autofill-Status, wenn die App aus dem Hintergrund zurückkehrt
  /// (z.B. nach dem Öffnen der Systemeinstellungen).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(settingsProvider.notifier).refreshAutofillStatus();
    }
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
          //Snack.show(context, 'Gespeichert!', success: true);
          break;

        case SettingsActionStatus.deleted:
          Snack.show(context, 'Tresor gelöscht!', success: true);
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false); // Loginseite öffnen (und Navigations‑Stack zurücksetzen)
          break;

        case SettingsActionStatus.friendAdded:
          _hasChanged = true;
          Snack.show(context, 'Freund wurde hinzugefügt. Verifiziere zur Sicherheit den Fingerprint.', success: true);
          break;

        case SettingsActionStatus.friendVerified:
          _hasChanged = true;
          Snack.show(context, 'Verifizierungsstatus geändert', success: true);
          break;

        case SettingsActionStatus.friendDeleted:
          _hasChanged = true;
          Snack.show(context, 'Freund gelöscht', success: true);
          break;

        case SettingsActionStatus.failure:
          _hasChanged = true;
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
    final isAutofillSupported = ref.watch(settingsProvider.select((s) => s.isAutofillSupported));
    final isAutotypeSupported = ref.watch(settingsProvider.select((s) => s.isAutotypeSupported));
    final canOpenAppSettings = ref.watch(settingsProvider.select((s) => s.canOpenAppSettings));
    final canOpenBiometricSettings = ref.watch(settingsProvider.select((s) => s.canOpenBiometricSettings));

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
                  onPressed: _showVaultNameDialog,
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
                  onPressed: isBusy ? null : _showMasterPasswordDialog,
                  icon: const Icon(Icons.key_outlined),
                  label: const Text('Master-Passwort ändern'),
                ),

                const SizedBox(height: 16),

                // --- Biometrie ---
                Consumer(
                  builder: (ctx, ref, _) {
                    final useBiometric = ref.watch(settingsProvider.select((state) => state.useBiometric));
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          secondary: const Icon(Icons.fingerprint_outlined),
                          title: const Text('Biometrie verwenden'),
                          subtitle: const Text('Erlaubt das Entsperren des Tresors via Fingerabdruck oder Gesichtserkennung.'),
                          value: useBiometric,
                          onChanged: isBusy ? null : notifier.saveBiometricSettings,
                        ),
                        if (useBiometric && canOpenBiometricSettings) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 48, top: 12, bottom: 12),
                            child: _buildSystemButton(
                              Icons.fingerprint_outlined,
                              'Systemeinstellung für Biometrie',
                              null, //'Fingerabdruck oder Gesichtserkennung im System einrichten.',
                              notifier.openBiometricSettings,
                              width: 280,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),

                const Divider(height: 32),

                // ------------------------------------------------------------------------
                // --- Timeouts ---
                // ------------------------------------------------------------------------

                _buildSectionTitle('Timeouts'),

                // --- Auto-Sperre ---
                _buildText(
                  'Automatische Sperre',
                  (state) => state.autoLockLabel,
                  icon: Icons.lock_clock_outlined,
                  onPressed: _showAutolockDialog,
                  tooltip: 'Automatische Sperre ändern',
                ),

                // --- Zwischenablage leeren ---
                if (!env.isWeb) // der Browser erlaubt den Clipboard-Write ohne User-Gesture nicht
                  _buildText(
                    'Zwischenablage leeren',
                    (state) => state.clipboardClearLabel,
                    icon: Icons.content_paste_off_outlined,
                    onPressed: _showClipboardClearDialog,
                    tooltip: 'Zwischenablage-Timeout ändern',
                  ),

                const Divider(height: 32),

                // ------------------------------------------------------------------------
                // --- Autofill (für Android) und Autotype (für Windows) ---
                // ------------------------------------------------------------------------

                if (isAutofillSupported) ...[
                  _buildSectionTitle('Autofill'),
                  Consumer(
                    builder: (ctx, ref, _) {
                      final isAutofillEnabled = ref.watch(settingsProvider.select((s) => s.isAutofillEnabled));
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            secondary: const Icon(Icons.text_fields_outlined),
                            title: const Text('Autofill'),
                            subtitle: Text('FamKey als Autofill-Anbieter für andere Apps verwenden.'),
                            value: isAutofillEnabled,
                            onChanged: notifier.toggleAutofill,
                          ),
                        ],
                      );
                    },
                  ),
                  const Divider(height: 32),
                ],

                if (isAutotypeSupported) ...[
                  _buildSectionTitle('Autotype'),
                  Consumer(
                    builder: (ctx, ref, _) {
                      final isAutotypeEnabled = ref.watch(settingsProvider.select((s) => s.isAutotypeEnabled));
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            secondary: const Icon(Icons.text_fields_outlined),
                            title: const Text('Autotype verwenden'),
                            subtitle: Text('Benutzername und Passwort per Tastenkürzel in beliebige Fenster einfügen.'),
                            value: isAutotypeEnabled,
                            onChanged: notifier.toggleAutofill,
                          ),
                          if (isAutotypeEnabled) ...[
                            Padding(
                              padding: const EdgeInsets.only(left: 32),
                              child: Consumer(
                                builder: (ctx, ref, _) {
                                  final hotkey = ref.watch(settingsProvider.select((s) => s.autotypeHotkey));
                                  return _buildText(
                                    'Tastenkürzel',
                                    (state) => state.autotypeHotkey,
                                    icon: Icons.keyboard_outlined,
                                    onPressed: () => _showHotkeyDialog(hotkey),
                                    tooltip: 'Tastenkürzel ändern',
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 48, right: 96),
                              child: Text(
                                'Drücke das Tastenkürzel in einer beliebigen Anwendung, um FamKey im Hintergrund zu aktivieren und Benutzername und Passwort automatisch einzufügen.',
                                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: Theme.of(ctx).colorScheme.onSurfaceVariant), //TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),

                  const Divider(height: 32),
                ],

                // ------------------------------------------------------------------------
                // --- Sync-Server ---
                // ------------------------------------------------------------------------

                _buildSectionTitle('Sync-Server'),

                // --- Benutzername ---
                _buildText(
                  'Benutzername',
                  (state) => state.userName,
                  icon: Icons.person_outline,
                  onPressed: _showUserNameDialog,
                  tooltip: 'Benutzername ändern',
                ),

                // --- Host ---
                _buildText(
                  'Serveradresse',
                  (state) => state.host,
                  icon: Icons.cloud_outlined,
                  onPressed: _showSyncServerDialog,
                  tooltip: 'Serveradresse ändern',
                ),

                const Divider(height: 32),

                // ------------------------------------------------------------------------
                // --- Freunde ---
                // ------------------------------------------------------------------------

                _buildSectionHeaderWithAction(
                  'Freunde',
                  Icons.person_add,
                  'Freund hinzufügen',
                  _showFriendSearchDialog,
                ),

                // --- Liste ---
                Consumer(builder: (ctx, ref, _) {
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
                        title: Row(
                          children: [
                            Text(friend.name),
                            // Hinweis anzeigen, wenn der Freund seinen Namen geändert hat
                            if (friend.syncedName.isNotEmpty && friend.name != friend.syncedName)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Text(
                                  '(ehemals ${friend.syncedName})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Tooltip(
                              message: 'Fingerprint kopieren',
                              child: InkWell(
                                onTap: () => _handleCopyToClipboard(fingerprints[friend.id] ?? '', 'Fingerprint'),
                                child: Text(
                                  fingerprints[friend.id] ?? '',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    color: Colors.blueGrey, // Optional: Farbe ändern, damit es klickbar aussieht
                                  ),
                                ),
                              ),
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
                // --- Passwortgenerator ---
                // ------------------------------------------------------------------------

                _buildSectionTitle('Passwortgenerator'),
                // const SizedBox(height: 16),

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
                  builder: (ctx, ref, _) {
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
                const SizedBox(height: 8),

                // --- Platzhalter für Kategorie ---
                _buildText(
                  'Umbenannte Kategorie',
                  (state) => state.categoryPlaceholder,
                  icon: Icons.label_outlined,
                  onPressed: _showCategoryPlaceholderDialog,
                  tooltip: 'Platzhalter für unbenannte Kategorie ändern',
                ),

                const Divider(height: 32),

                // ------------------------------------------------------------------------
                // --- Logging ---
                // ------------------------------------------------------------------------

                _buildSectionTitle('Logging'),
                // const SizedBox(height: 16),

                _buildText(
                  'Log-Level',
                  (state) => state.logLevel.name.toUpperCase(),
                  icon: Icons.edit_notifications_outlined,
                  onPressed: _showLogConfigDialog,
                  tooltip: 'Logging konfigurieren',
                ),

                _buildText(
                  'Aufbewahrungsdauer der Logeinträge',
                  (state) => '${state.logDays == 1 ? '1 Tag' : state.logDays.toString()} Tage',
                  icon: Icons.timelapse_outlined,
                ),

                _buildText(
                  'Maximale Dateigröße',
                  (state) => '${state.logSize ~/ 1024} KB',
                  icon: Icons.insert_drive_file_outlined,
                ),

                const SizedBox(height: 8),

                _buildSystemButton(
                  Icons.article_outlined,
                  'Logdatei anzeigen',
                  '',
                  _showLogFileDialog,
                ),

                const SizedBox(height: 16),
                const Divider(height: 32),

                // ------------------------------------------------------------------------
                // --- Systemeinstellungen ---
                // ------------------------------------------------------------------------

                if (canOpenAppSettings) ...[
                  _buildSectionTitle('Systemeinstellungen'),
                  const SizedBox(height: 16),

                  _buildSystemButton(
                    Icons.info_outline,
                    'App-Info',
                    'Systemdetails dieser App anzeigen.',
                    notifier.openAppSettings,
                  ),

                  const SizedBox(height: 32),
                ],

                // ------------------------------------------------------------------------
                // --- Footer ---
                // ------------------------------------------------------------------------

                // --- Buttons für Löschen ---
                Center(
                  child: Consumer(
                    builder: (ctx, ref, _) {
                      final isRegistered = ref.watch(settingsProvider.select((s) => s.isRegistered));
                      return ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                        onPressed: () => _showDeleteVaultDialog(isRegistered),
                        icon: const Icon(Icons.delete_outlined),
                        label: const Text('Tresor löschen'),
                      );
                    },
                  ),
                ),

                // --- Abstand zum unteren Rand ---
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
        builder: (ctx, ref, _) {
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
  Widget _buildSystemButton(IconData icon, String label, String? help, VoidCallback onPressed, {double width=220}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: width,
            child: ElevatedButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label)),
          ),
          if (help != null && help.isNotEmpty)
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
  Future<void> _showVaultNameDialog() async {
    final ok = await VaultNameDialog.show(context);
    if (ok == true) {
      _hasChanged = true;
      if (mounted) {
        final notifier = ref.read(settingsProvider.notifier);
        notifier.load();
      }
    }
  }

  // todo Dialog auslagern
  /// Zeigt einen Dialog mit drei Löschvarianten.
  Future<void> _showDeleteVaultDialog(bool isRegistered) async {
    final notifier = ref.read(settingsProvider.notifier);

    if (!isRegistered) {
      // Noch nicht gesynct → nur lokales Löschen sinnvoll
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tresor löschen'),
          content: const Text('Alle lokalen Daten dieses Tresors werden unwiderruflich entfernt.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Löschen'),
            ),
          ],
        ),
      );
      if (mounted && confirmed == true) notifier.deleteVaultLocal();
      return;
    }

    // Bereits gesynct → drei Optionen
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tresor löschen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dieser Tresor wurde bereits synchronisiert. '
              'Bitte wähle, was gelöscht werden soll:',
            ),
            const SizedBox(height: 20),
            _buildDeleteOption(
              ctx,
              icon: Icons.cloud_off_outlined,
              label: 'Nur auf dem Server löschen',
              description: 'Lokale Daten bleiben erhalten. Beim nächsten Sync wird der Tresor neu registriert.',
              onPressed: () { Navigator.pop(ctx); notifier.deleteVaultServer(); },
            ),
            const SizedBox(height: 12),
            _buildDeleteOption(
              ctx,
              icon: Icons.phone_android_outlined,
              label: 'Nur auf diesem Gerät löschen',
              description: 'Die Daten auf dem Server bleiben erhalten.',
              onPressed: () { Navigator.pop(ctx); notifier.deleteVaultLocal(); },
            ),
            const SizedBox(height: 12),
            _buildDeleteOption(
              ctx,
              icon: Icons.delete_forever_outlined,
              label: 'Server und Gerät löschen',
              description: 'Alle Daten werden unwiderruflich entfernt.',
              isDestructive: true,
              onPressed: () { Navigator.pop(ctx); notifier.deleteVaultBoth(); },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
        ],
      ),
    );
  }

  /// Hilfsmethode: Baut eine einzelne Lösch-Option im Dialog.
  Widget _buildDeleteOption(BuildContext ctx, {
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onPressed,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red.shade800 : Colors.blueGrey.shade700;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 2),
                  Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ändert das Master-Passwort.
  Future<void> _showMasterPasswordDialog() async {
    final ok = await MasterPasswordDialog.show(context);
    if (ok == true) {
      _hasChanged = true;
      if (mounted) {
        final notifier = ref.read(settingsProvider.notifier);
        notifier.load();
      }
    }
  }

  /// Ändert den Benutzername.
  Future<void> _showUserNameDialog() async {
    final ok = await UserNameDialog.show(context);
    if (ok == true) {
      _hasChanged = true;
      if (mounted) {
        final notifier = ref.read(settingsProvider.notifier);
        notifier.load();
      }
    }
  }

  /// Ändert den Host und den API-Token.
  Future<void> _showSyncServerDialog() async {
    final ok = await SyncServerDialog.show(context);
    if (ok == true) {
      _hasChanged = true;
      if (mounted) {
        final notifier = ref.read(settingsProvider.notifier);
        notifier.load();
      }
    }
  }

  /// Kopiert den Text in die Zwischenablage und gibt eine SnackBar mit dem Ergebnis aus.
  /// `label` ist die Beschriftung des kopierten Textes.
  void _handleCopyToClipboard(String text, String label) {
    final notifier = ref.read(settingsProvider.notifier);
    notifier.copyToClipboard(text);
    Snack.show(context, '$label in die Zwischenablage kopiert', success: true);
  }

  /// Fügt einen Freund zu Liste hinzu.
  Future<void> _showFriendSearchDialog() async {
    final ok = await NewFriendDialog.show(context);
    if (ok == true) {
      _hasChanged = true;
      if (mounted) {
        final notifier = ref.read(settingsProvider.notifier);
        notifier.load();
      }
    }
  }

  /// Löscht nach Bestätigung den Freund aus der Liste.
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

  /// Öffnet den Dialog zum Ändern der Passwortgenerators.
  Future<void> _showPasswordGeneratorDialog() async {
    final ok = await PasswordGeneratorDialog.show(context);
    if (ok == true) {
      _hasChanged = true;
      if (mounted) {
        final notifier = ref.read(settingsProvider.notifier);
        notifier.load();
      }
    }
  }

  /// Zeigt den Dialog zum Ändern des Platzhalters für eine Kategorie ohne Namen.
  Future<void> _showCategoryPlaceholderDialog() async {
    final ok = await CategoryPlaceholderDialog.show(context);
    if (ok == true) {
      _hasChanged = true;
      if (mounted) {
        final notifier = ref.read(settingsProvider.notifier);
        notifier.load();
      }
    }
  }

  /// Öffnet den Dialog zum Anzeigen der Log-Konfiguration.
  Future<void> _showLogConfigDialog() async {
    final ok = await LogConfigDialog.show(context);
    if (ok == true) {
      _hasChanged = true;
      if (mounted) {
        final notifier = ref.read(settingsProvider.notifier);
        notifier.load();
      }
    }
  }

  /// Öffnet den Dialog zum Anzeigen der Logdatei.
  Future<void> _showLogFileDialog() async {
    await LogFileDialog.show(context);
  }

  /// Öffnet den Dialog zum Ändern der Auto-Sperre.
  Future<void> _showAutolockDialog() async {
    final ok = await AutolockDialog.show(context);
    if (ok == true) {
      _hasChanged = true;
      if (mounted) ref.read(settingsProvider.notifier).load();
    }
  }

  /// Öffnet den Dialog zum Ändern des Zwischenablage-Timeouts.
  Future<void> _showClipboardClearDialog() async {
    final ok = await ClipboardClearDialog.show(context);
    if (ok == true) {
      _hasChanged = true;
      if (mounted) ref.read(settingsProvider.notifier).load();
    }
  }

  /// Öffnet den Dialog zum Ändern des Autotype-Tastenkürzels.
  Future<void> _showHotkeyDialog(String current) async {
    final ok = await AutotypeHotkeyDialog.show(context);
    if (ok == true) {
      _hasChanged = true;
      if (mounted) {
        final notifier = ref.read(settingsProvider.notifier);
        notifier.load();
      }
    }
  }

}