import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:privault/viewmodels/settings_view_model.dart';

/// Der [SettingsScreen] ermöglicht die Konfiguration der App und des aktuellen Tresors.
///
/// Hier werden sowohl sicherheitsrelevante als auch optische Einstellungen verwaltet:
/// * **Identität:** Ändern des Master-Passworts und Verwaltung des Tresornamens.
/// * **Synchronisation:** Konfiguration der Server-Verbindung (URL & API-Token).
/// * **Sicherheit:** Verwaltung von vertrauenswürdigen Kontakten ("Freunde") und Biometrie-Optionen.
/// * **Generator:** Standardwerte für den integrierten Passwort-Generator festlegen.
/// * **System:** Schneller Zugriff auf Android-Systemeinstellungen für Autofill und App-Infos.
class SettingsScreen extends StatefulWidget {
  /// Konstruktor
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ------------------------------------------------------------------------
  // --- Verwendete Dienste ---
  // ------------------------------------------------------------------------

  final TextEditingController _vaultNameController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _specialCharsController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  // ------------------------------------------------------------------------
  // --- Interne Variablen ---
  // ------------------------------------------------------------------------

  late SettingsViewModel _viewModel;

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert den Screen und lädt die Daten, sobald der erste Frame gerendert wurde.
  @override
  void initState() {
    super.initState();

    _viewModel = context.read<SettingsViewModel>();
    _viewModel.addListener(_onViewModelChanged);
    _viewModel.init();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _viewModel.load();
      _vaultNameController.text = _viewModel.vaultName;
      _userNameController.text = _viewModel.userName;
      _hostController.text = _viewModel.host;
      _tokenController.text = _viewModel.apiToken;
      _specialCharsController.text = _viewModel.pwSpecialCharSet;
      _lengthController.text = _viewModel.pwLength.toString();
      _categoryController.text = _viewModel.categoryPlaceholder;
    });
  }

  /// Entfernt den Listener und gibt alle Ressourcen frei.
  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _vaultNameController.dispose();
    _userNameController.dispose();
    _hostController.dispose();
    _tokenController.dispose();
    _specialCharsController.dispose();
    _lengthController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  /// Wird getriggert, wenn das ViewModel notifyListeners() aufruft.
  /// Hier kann u.a. der Text vom TextEditingController aktualisiert werden.
  ///
  /// Aktualisiert insbesondere das Feld für Sonderzeichen, falls dieses extern
  /// (via Buttons) geändert wurde.
  void _onViewModelChanged() {
    if (!mounted) return;
    // Nur das Sonderzeichen-Feld aktualisieren, wenn es vom VM abweicht
    if (_specialCharsController.text != _viewModel.pwSpecialCharSet) {
      _specialCharsController.text = _viewModel.pwSpecialCharSet;
    }
  }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  /// Baut die zentrale Benutzeroberfläche der Einstellungsseite auf.
  ///
  /// Diese Methode definiert das gesamte Layout des Screens. Sie enthält:
  /// * Eine **AppBar** mit einer Speicher-Schaltfläche, die bei Klick Änderungen wie
  ///   Tresor-Umbenennungen (nach Passwort-Verifizierung) und allgemeine Einstellungen übernimmt.
  /// * Einen **Body**, der alle Konfigurationsabschnitte (Identifikation, Synchronisation,
  ///   Freunde, Passwort-Generator, Anmeldeoptionen, Design und System) in einer
  ///   scrollbaren Ansicht zusammenfasst.
  /// * Einen **Lade-Indikator**, der über den Screen gelegt wird, wenn das ViewModel
  ///   gerade eine asynchrone Operation (z. B. Speichern oder Verbindungstest) ausführt.
  @override
  Widget build(BuildContext context) {
    // Dies triggert die build-Methode jedes Mal, wenn das ViewModel notifyListeners() aufruft.
    final viewModel = context.watch<SettingsViewModel>();

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
                  enabled: !viewModel.isRegistered,
                  decoration: const InputDecoration(
                    labelText: 'Tresorname',
                    prefixIcon: Icon(Icons.shield_outlined),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => viewModel.vaultName = value,
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
                            viewModel.vaultStoragePath,
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
                      value: viewModel.useBiometric,
                      onChanged: (val) => viewModel.useBiometric = val,
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
                  enabled: !viewModel.isRegistered,
                  decoration: const InputDecoration(
                    labelText: 'Benutzername',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => viewModel.userName = value,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _hostController,
                  decoration: const InputDecoration(
                    labelText: 'Host URL',
                    prefixIcon: Icon(Icons.cloud_outlined),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => viewModel.host = value,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tokenController,
                  obscureText: viewModel.isTokenHidden,
                  decoration: InputDecoration(
                    labelText: 'API Token',
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(viewModel.isTokenHidden ? Icons.visibility : Icons.visibility_off),
                      tooltip: viewModel.isTokenHidden ? 'Anzeigen' : 'Verbergen',
                      onPressed: viewModel.toggleTokenVisibility,
                    ),
                  ),
                  onChanged: (value) => viewModel.apiToken = value,
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
                  controller: _lengthController,
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
                            final val = int.tryParse(_lengthController.text) ?? 0;
                            if (val > 1) {
                              final newVal = val - 1;
                              _lengthController.text = newVal.toString();
                              viewModel.pwLength = newVal;
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            final val = int.tryParse(_lengthController.text) ?? 0;
                            final newVal = val + 1;
                            _lengthController.text = newVal.toString();
                            viewModel.pwLength = newVal;
                          },
                        ),
                      ],
                    ),
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val);
                    if (parsed != null) viewModel.pwLength = parsed;
                  },
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _specialCharsController,
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
                          onPressed: () => viewModel.setSpecialChars('Standard'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.all_inclusive),
                          tooltip: 'Alle',
                          onPressed: () => viewModel.setSpecialChars('All'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle),
                          tooltip: 'Keine',
                          onPressed: () => viewModel.setSpecialChars('None'),
                        ),
                      ],
                    ),
                  ),
                  onChanged: (value) => viewModel.pwSpecialCharSet = value,
                ),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Lesbarkeit optimieren (I, l, O, 0 ausschließen)'),
                    Switch(
                      value: viewModel.pwAvoidIlO0,
                      onChanged: (val) => viewModel.pwAvoidIlO0 = val,
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
                if (viewModel.friends.isEmpty)
                  Text('Dieser Tresor wird nicht geteilt.', style: TextStyle(fontStyle: FontStyle.italic))
                // const Padding(
                //   padding: EdgeInsets.all(8),
                //   child: Text(
                //     'Keine weiteren Personen.',
                //     style: TextStyle(fontStyle: FontStyle.italic),
                //   ),
                // )
                else
                  Column(
                    children: viewModel.friends
                        .map(
                          (friend) => Card(
                            key: ValueKey('friend_${friend.uuid}'),
                            child: ListTile(
                              title: Text(friend.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    viewModel.getFingerprint(friend.publicKey),
                                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                                  ),
                                  if (friend.id != null && viewModel.needsRekeying(friend.id!))
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
                                      onChanged: (_) => viewModel.toggleVerification(friend),
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
                  selected: {viewModel.themeMode},
                  onSelectionChanged: (val) => viewModel.themeMode = val.first,
                ),

                const SizedBox(height: 32),

                TextField(
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Name für leere Kategorie',
                    prefixIcon: Icon(Icons.label_outlined),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => viewModel.categoryPlaceholder = value,
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
                  viewModel.openBiometricSettings,
                ),

                _buildSystemButton(
                  Icons.text_fields_outlined,
                  'Autofill',
                  'Hilfeseite für das automatische Ausfüllen öffnen',
                  viewModel.openAutofillSettings,
                ),

                _buildSystemButton(
                  Icons.info_outline,
                  'App-Info',
                  'Systemdetails dieser App anzeigen',
                  viewModel.openAppSettings,
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
    if (_viewModel.isBusy) return;

    if (_viewModel.isDirty) {
      final confirmed = await _showConfirmDialog(
        'Eintrag speichern',
        'Möchtest du die Änderungen speichern?',
        ok: 'Ja, speichern',
        cancel: 'Nein, verwerfen',
      );
      if (confirmed == true) {
        _handleSave();
        return;
      }
    }

    if (mounted) Navigator.pop(context);
  }

  /// Testet, ob Host-URL und API-Token korrekt sind
  Future<void> _handleSave() async {
    if (_viewModel.isBusy) return;

    try {
      // Tresor umbenennen
      if (_viewModel.isVaultRenamed) {
        String? errorText;
        while (true) {
          final password = await _showPasswordDialog(
            'Tresor umbenennen',
            'Bitte bestätige dein Master-Passwort, um den Tresor umzubenennen.',
            errorText: errorText,
          );
          if (password == null) return;
          final result = await _viewModel.renameVault(password);
          if (!context.mounted) return;

          if (result == RenameVaultResult.success) {
            _showSnack('Tresor erfolgreich umbenannt.', success: true);
            break;
          } else if (result == RenameVaultResult.wrongPassword) {
            errorText = _viewModel.errorMessage;
            continue;
          } else {
            _showSnack(_viewModel.errorMessage ?? 'Unerwarteter Fehler');
            break;
          }
        }
      }

      // Einstellungen speichern
      final success = await _viewModel.save();
      if (!context.mounted) return;
      if (!success) {
        _showSnack(_viewModel.errorMessage ?? 'Unerwarteter Fehler');
        return;
      }
      _showSnack('Einstellungen gespeichert.', success: true);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e, st) {
      _showException(e, stackTrace: st);
    }
  }

  /// Fragt ein neues und das bisherige Passwort ab und ändert es schließlich.
  Future<void> _handlePasswordChange() async {
    if (_viewModel.isBusy) return;

    try {
      // Neues Passwort abfragen
      final newPassword = await _showPasswordDialog(
        'Passwort ändern',
        'Bitte gib dein NEUES Master-Passwort ein.',
      );
      if (newPassword == null) return;

      String? errorText;
      while (true) {
        // Bisheriges Passwort abfragen
        final currentPassword = await _showPasswordDialog(
          'Passwort-Änderung autorisieren',
          'Bitte gib jetzt dein AKTUELLES Master-Passwort ein.',
          errorText: errorText,
        );
        if (currentPassword == null) return;

        // Trivial-Check: Die Passwörter dürfen nicht identisch sein
        if (currentPassword == newPassword) {
          _showSnack("Neues und altes Master-Passwort sind identisch");
          return;
        }

        // Passwort ändern
        final result = await _viewModel.changeMasterPassword(
          newPassword,
          currentPassword,
        );
        if (!context.mounted) return;

        // Ergebnis auswerten
        if (result == ChangePasswordResult.success) {
          _showSnack('Passwort erfolgreich geändert.', success: true);
          break;
        } else if (result == ChangePasswordResult.wrongPassword) {
          errorText = _viewModel.errorMessage;
          continue;
        } else {
          _showSnack(_viewModel.errorMessage ?? 'Unerwarteter Fehler');
          break;
        }
      }
    } catch (e, st) {
      _showException(e, stackTrace: st);
    }
  }

  /// Testet, ob Host-URL und API-Token korrekt sind
  Future<void> _handleTestConnection() async {
    if (_viewModel.isBusy) return;

    final ok = await _viewModel.testConnection();
    if (!context.mounted) return;
    if (ok) {
      _showSnack('Verbindung erfolgreich.', success: true);
    } else {
      _showSnack('Verbindung fehlgeschlagen.');
    }
  }

  /// Öffnet den Freund-Such-Dialog und verarbeitet das Ergebnis.
  /// Bei Fehlern wie "nicht gefunden" bleibt der Dialog offen,
  /// andere Fehler werden per SnackBar gemeldet.
  Future<void> _handleAddFriend() async {
    if (_viewModel.isBusy) return;

    try {
      String? errorText;
      while (true) {
        final name = await _showAddFriendDialog(errorText: errorText);
        if (name == null) return;

        final result = await _viewModel.addFriend(name);
        if (!mounted) return;

        if (result == AddFriendResult.success) {
          _showSnack(
            '"$name" wurde hinzugefügt. Bitte verifiziere zur Sicherheit den Fingerprint.',
            success: true,
          );
          break;
        } else if (result == AddFriendResult.notFound || result == AddFriendResult.alreadyAdded) {
          // im Dialog anzeigen, NICHT SnackBar
          errorText = _viewModel.errorMessage;
          continue;
        } else {
          _showSnack(_viewModel.errorMessage ?? 'Unerwarteter Fehler');
          break;
        }
      }
    } catch (e, st) {
      _showException(e, stackTrace: st);
    }
  }

  /// Fragt nach Bestätigung und löscht dann den Freund aus der Liste.
  Future<void> _handleDeleteFriend(dynamic user) async {
    if (_viewModel.isBusy) return;

    final confirmed = await _showConfirmDialog(
      'Person entfernen',
      'Möchtest du die Person aus deiner Liste löschen?\n'
          'Das Teilen von Einträgen mit dieser Person ist dann nicht mehr möglich.',
      ok: 'Ja, löschen',
    );
    if (confirmed == true && mounted) {
      _viewModel.deleteFriend(user);
    }
  }

  /// Zeigt eine Sicherheitsabfrage an, bevor der lokale Tresor gelöscht wird.
  Future<void> _handleDeleteTresor() async {
    if (_viewModel.isBusy) return;

    final confirmed = await _showConfirmDialog(
      'Tresor lokal löschen',
      'Bist du sicher? Alle lokalen Daten dieses Tresors werden unwiderruflich entfernt.',
      ok: 'Ja, löschen',
    );
    if (confirmed == true && mounted) {
      _viewModel.deleteVault();
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  // ------------------------------------------------------------------------
  // --- Dialoge ---
  // ------------------------------------------------------------------------

  /// Öffnet einen Dialog zur Suche nach anderen Personen.
  Future<String?> _showAddFriendDialog({String? errorText}) async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Person suchen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Name der Person',
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    Navigator.pop(dialogContext, val.trim());
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(dialogContext, name);
                }
              },
              child: const Text('Suchen'),
            ),
          ],
        ),
      ),
    );
  }

  /// Öffnet einen modalen Dialog für eine Ja/Nein-Frage.
  Future<bool?> _showConfirmDialog(String title, String message, {String? ok, String? cancel}) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            child: Text(cancel ?? 'Abbrechen'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: Text(ok ?? 'OK'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
  }

  /// Öffnet einen modalen Dialog zur Passwortabfrage.
  ///
  /// Wird benötigt, um sensible Aktionen wie das Umbenennen des Tresors
  /// oder das Ändern des Passworts zu autorisieren.
  ///
  /// Wenn `errorText` gesetzt ist, wird das Textfeld rot + Fehlertext angezeigt.
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
                    onPressed: () => setDialogState(() => obscureText = !obscureText),
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
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: const Text('Abbrechen'),
            ),
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

  // ------------------------------------------------------------------------
  // --- Sonstige interne Methoden ---
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
    debugPrint("❌ SettingsScreen: $ex");
    if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
    _showSnack("Ein unerwarteter Fehler ist aufgetreten.");
  }
}
