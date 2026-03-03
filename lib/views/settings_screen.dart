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
    final TextEditingController _pathController = TextEditingController();
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

    /// Initialisiert den Screen, verknüpft das ViewModel und lädt die aktuellen
    /// Einstellungen asynchron in die entsprechenden Text-Controller.
    @override
    void initState() {
        super.initState();

        _viewModel = context.read<SettingsViewModel>();
        _viewModel.addListener(_onViewModelChanged);

        WidgetsBinding.instance.addPostFrameCallback((_) async {
                await _viewModel.initialize();
                _vaultNameController.text = _viewModel.vaultName;
                _userNameController.text = _viewModel.userName;
                _pathController.text = _viewModel.vaultStoragePath;
                _hostController.text = _viewModel.host;
                _tokenController.text = _viewModel.apiToken;
                _specialCharsController.text = _viewModel.pwSpecialCharSet;
                _lengthController.text = _viewModel.pwLength.toString();
                _categoryController.text = _viewModel.categoryPlaceholder;
            }
        );
    }

    /// Gibt alle verwendeten Text-Controller frei und entfernt den Listener
    /// vom ViewModel, um Speicherlecks zu vermeiden.
    @override
    void dispose() {
        _viewModel.removeListener(_onViewModelChanged);
        _vaultNameController.dispose();
        _userNameController.dispose();
        _pathController.dispose();
        _hostController.dispose();
        _tokenController.dispose();
        _specialCharsController.dispose();
        _lengthController.dispose();
        _categoryController.dispose();
        super.dispose();
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
        final viewModel = context.watch<SettingsViewModel>();

        return Stack(
            children: [
                Scaffold(
                    appBar: AppBar(
                        title: const Text('Einstellungen'),
                        centerTitle: true,
                        actions: [
                            IconButton(
                                icon: const Icon(Icons.check),
                                tooltip: 'Speichern',
                                onPressed: viewModel.isBusy
                                    ? null
                                    : () async {
                                        try {
                                            // Tresor umbenennen
                                            if (viewModel.isVaultRenamed) {
                                                String? errorText;
                                                while (true) {
                                                    final password = await _showPasswordDialog(
                                                        'Tresor umbenennen', 
                                                        'Bitte bestätige dein Master-Passwort, um den Tresor umzubenennen.',
                                                        errorText: errorText
                                                    );
                                                    if (password == null) return;
                                                    final success = await viewModel.renameVault(password);
                                                    if (!context.mounted) return;
                                                    if (!success) {
                                                        if (viewModel.errorMessage == 'Falsches Master-Passwort') {
                                                            // im Dialog anzeigen, NICHT SnackBar
                                                            errorText = viewModel.errorMessage;
                                                            continue;
                                                        }
                                                        _showSnack(viewModel.errorMessage ?? 'Unerwarteter Fehler');
                                                        break;
                                                    }
                                                    _showSnack('Tresor erfolgreich umbenannt.', success: true);
                                                    break;
                                                }
                                            }
                                            // Einstellungen speichern
                                            final success = await viewModel.save();
                                            if (!context.mounted) return;
                                            if (!success) {
                                                _showSnack(viewModel.errorMessage ?? 'Unerwarteter Fehler');
                                                return;
                                            }
                                            _showSnack('Einstellungen gespeichert.', success: true);
                                            Navigator.pop(context);
                                        }
                                        catch (e, st) {
                                            _showException(e, stackTrace: st);
                                        }
                                    },

                            ),
                        ],
                    ),
                    body: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, // Button linksbündig
                            children: [

                                // ------------------------------------------------------------------------
                                // --- Identifikation ---
                                // ------------------------------------------------------------------------

                                _buildSectionTitle('Identifikation'),
                                TextField(
                                    controller: _vaultNameController,
                                    enabled: !viewModel.isRegistered,
                                    decoration: const InputDecoration(labelText: 'Tresor-Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.shield_outlined)),
                                    onChanged: (value) => viewModel.vaultName = value,
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                    controller: _userNameController,
                                    enabled: !viewModel.isRegistered,
                                    decoration: const InputDecoration(labelText: 'Benutzer-Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
                                    onChanged: (value) => viewModel.userName = value,
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                    controller: _pathController,
                                    readOnly: true,
                                    decoration: const InputDecoration(labelText: 'Speicherort', border: OutlineInputBorder(), prefixIcon: Icon(Icons.folder_open)),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white),
                                    onPressed: viewModel.isBusy ? null : () async {
                                            try {
                                                // Passwort ändern
                                                final newPassword = await _showPasswordDialog('Passwort ändern', 'Bitte gib dein NEUES Master-Passwort ein.');
                                                if (newPassword == null) return;
                                                String? errorText;
                                                while (true) {
                                                    final currentPassword = await _showPasswordDialog('Passwort-Änderung autorisieren', 'Bitte gib jetzt dein AKTUELLES Master-Passwort ein.', errorText: errorText);
                                                    if (currentPassword == null) return;
                                                    if (currentPassword == newPassword) {
                                                        _showSnack("Neues und altes Master-Passwort sind identisch");
                                                        return;
                                                    }
                                                    final success = await viewModel.changeMasterPassword(newPassword, currentPassword);
                                                    if (!context.mounted) return;
                                                    if (!success) {
                                                        if (viewModel.errorMessage == 'Falsches Master-Passwort') {
                                                            // im Dialog anzeigen, NICHT SnackBar
                                                            errorText = viewModel.errorMessage;
                                                            continue;
                                                        }
                                                        _showSnack(viewModel.errorMessage ?? 'Unerwarteter Fehler');
                                                        break;
                                                    }
                                                    _showSnack('Passwort erfolgreich geändert.', success: true);
                                                    break;
                                                }
                                            }
                                            catch (e, st) {
                                                _showException(e, stackTrace: st);
                                            }
                                        },
                                    icon: const Icon(Icons.password),
                                    label: const Text('Master-Passwort ändern'),
                                ),
                                const SizedBox(height: 32),

                                // ------------------------------------------------------------------------
                                // --- Synchronisation ---
                                // ------------------------------------------------------------------------

                                // Sektion: Synchronisation
                                _buildSectionTitle('Synchronisation'),
                                TextField(
                                    controller: _hostController,
                                    decoration: const InputDecoration(labelText: 'Host URL', border: OutlineInputBorder()),
                                    onChanged: (value) => viewModel.host = value,
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                    controller: _tokenController,
                                    obscureText: viewModel.isTokenHidden,
                                    decoration: InputDecoration(
                                        labelText: 'API Token',
                                        border: const OutlineInputBorder(),
                                        suffixIcon: Tooltip(
                                            message: viewModel.isTokenHidden ? 'Anzeigen' : 'Verbergen',
                                            child: IconButton(icon: Icon(viewModel.isTokenHidden ? Icons.visibility : Icons.visibility_off), onPressed: viewModel.toggleTokenVisibility),
                                        ),
                                    ),
                                    onChanged: (value) => viewModel.apiToken = value,
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                    onPressed: () async {
                                        final ok = await viewModel.testConnection();
                                        if (!context.mounted) return;
                                        if (ok) {
                                            _showSnack('Verbindung erfolgreich.', success: true);
                                        } else {
                                            _showSnack('Verbindung fehlgeschlagen.');
                                        }
                                    },
                                    icon: const Icon(Icons.swap_calls),
                                    label: const Text('Verbindung testen'),
                                ),
                                const SizedBox(height: 32),

                                // ------------------------------------------------------------------------
                                // --- Freunde ---
                                // ------------------------------------------------------------------------

                                _buildSectionHeaderWithAction('Freunde', Icons.person_add, 'Person suchen', _handleAddFriend),
                                if (viewModel.friends.isEmpty)
                                const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text('Keine weiteren Personen.', style: TextStyle(fontStyle: FontStyle.italic)),
                                )
                                else
                                Column(
                                    children: viewModel.friends
                                        .map(
                                            (f) => Card(
                                                key: ValueKey('friend_${f.uuid}'),
                                                child: ListTile(
                                                    title: Text(f.name),
                                                    subtitle: Text(viewModel.getFingerprint(f.publicKey), style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                                                    trailing: Tooltip(
                                                        message: 'Person verifiziert',
                                                        child: Switch(value: f.isVerified, onChanged: (_) => viewModel.toggleVerification(f)),
                                                    ),
                                                ),
                                            ),
                                        )
                                        .toList(),
                                ),
                                const SizedBox(height: 32),

                                // ------------------------------------------------------------------------
                                // --- Passwort-Generator ---
                                // ------------------------------------------------------------------------

                                _buildSectionTitle('Passwort-Generator'),
                                TextField(
                                    controller: _lengthController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Länge', border: OutlineInputBorder()),
                                    onChanged: (val) {
                                        final parsed = int.tryParse(val);
                                        if (parsed != null) viewModel.pwLength = parsed;
                                    },
                                ),
                                const SizedBox(height: 16),
                                Row(
                                    children: [
                                        Expanded(
                                            child: TextField(
                                                controller: _specialCharsController,
                                                decoration: const InputDecoration(
                                                    labelText: 'Sonderzeichen',
                                                    border: OutlineInputBorder()
                                                ),
                                                onChanged: (value) => viewModel.pwSpecialCharSet = value,
                                            ),
                                        ),
                                        IconButton(icon: const Icon(
                                                Icons.star_outline), 
                                            tooltip: 'Standard', 
                                            onPressed: () => viewModel.setSpecialChars('Standard')
                                        ),
                                        IconButton(icon: const Icon(
                                                Icons.all_inclusive), tooltip: 'Alle', 
                                            onPressed: () => viewModel.setSpecialChars('All')
                                        ),
                                        IconButton(icon: const Icon(
                                                Icons.remove_circle_outline), 
                                            tooltip: 'Keine', 
                                            onPressed: () => viewModel.setSpecialChars('None')
                                        ),
                                    ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                        const Text('Lesbarkeit optimieren (I, l, O, 0 ausschließen)'),
                                        Switch(value: viewModel.pwAvoidIlO0, onChanged: (val) => viewModel.pwAvoidIlO0 = val),
                                    ],
                                ),
                                const SizedBox(height: 32),

                                // ------------------------------------------------------------------------
                                // --- Anmeldeoptionen ---
                                // ------------------------------------------------------------------------

                                _buildSectionTitle('Anmeldeoptionen'),
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                        const Flexible(
                                            child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                    Text(
                                                        'Biometrie verwenden', 
                                                        style: TextStyle(
                                                            fontWeight: FontWeight.bold
                                                        )
                                                    ),
                                                    Text(
                                                        'Erlaubt das Entsperren des Tresors via Fingerabdruck oder Gesichtserkennung.', 
                                                        style: TextStyle(
                                                            fontSize: 12, 
                                                            color: Colors.grey
                                                        )
                                                    ),
                                                ],
                                            ),
                                        ),
                                        Switch(value: viewModel.useBiometric, onChanged: (val) => viewModel.useBiometric = val),
                                    ],
                                ),
                                const SizedBox(height: 32),

                                // ------------------------------------------------------------------------
                                // --- Design ---
                                // ------------------------------------------------------------------------

                                _buildSectionTitle('Design'),

                                //const SizedBox(height: 16),

                                SegmentedButton<ThemeMode>(
                                    segments: const[
                                        ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto)),
                                        ButtonSegment(value: ThemeMode.light, label: Text('Hell'), icon: Icon(Icons.light_mode)),
                                        ButtonSegment(value: ThemeMode.dark, label: Text('Dunkel'), icon: Icon(Icons.dark_mode)),
                                    ],
                                    selected: {viewModel.themeMode},
                                    onSelectionChanged: (val) => viewModel.themeMode = val.first,
                                ),

                                const SizedBox(height: 32),

                                TextField(
                                    controller: _categoryController,
                                    decoration: const InputDecoration(labelText: 'Name für leere Kategorie', border: OutlineInputBorder()),
                                    onChanged: (value) => viewModel.categoryPlaceholder = value,
                                ),
                                const SizedBox(height: 32),

                                // ------------------------------------------------------------------------
                                // --- Systemeinstellungen ---
                                // ------------------------------------------------------------------------

                                _buildSectionTitle('Systemeinstellungen'),

                                _buildSystemButton(
                                    Icons.fingerprint, 
                                    'Biometrie', 
                                    'Systemeinstellungen für Biometrie öffnen', 
                                    viewModel.openBiometricSettings
                                ),

                                _buildSystemButton(Icons.text_fields, 
                                    'Autofill', 
                                    'Hilfeseite für das automatische Ausfüllen öffnen', 
                                    viewModel.openAutofillSettings
                                ),

                                _buildSystemButton(
                                    Icons.info_outline, 
                                    'App-Info', 
                                    'Systemdetails dieser App anzeigen', 
                                    viewModel.openAppSettings
                                ),

                                const SizedBox(height: 64),

                                Center(
                                    child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red.shade800,
                                            foregroundColor: Colors.white, 
                                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                                        onPressed: _showDeleteConfirm,
                                        icon: const Icon(Icons.delete_forever),
                                        label: const Text('Tresor lokal löschen'),
                                    ),
                                ),
                                const SizedBox(height: 48),
                            ],
                        ),
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

    /// Erstellt eine einheitliche, fettgedruckte Überschrift für die verschiedenen
    /// Einstellungsbereiche (z. B. "Identifikation" oder "Synchronisation").
    Widget _buildSectionTitle(String title) {
        return Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 8),
            child: Text(
                title,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey
                ),
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
                Tooltip(
                    message: tooltip,
                    child: IconButton(
                        icon: Icon(icon),
                        onPressed: onPressed
                    ),
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
                        child: ElevatedButton.icon(
                            onPressed: onPressed,
                            icon: Icon(icon),
                            label: Text(label)
                        ),
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
      debugPrint("❌ SettingsScreen: $ex");
      if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
      _showSnack("Ein unerwarteter Fehler ist aufgetreten.");
    }

    /// Wird aufgerufen, wenn das ViewModel signalisiert, dass sich Daten geändert haben.
    /// Aktualisiert insbesondere das Feld für Sonderzeichen, falls dieses extern (via Buttons) geändert wurde.
    void _onViewModelChanged() {
        if (!mounted) return;
        // Nur das Sonderzeichen-Feld aktualisieren, wenn es vom VM abweicht
        if (_specialCharsController.text != _viewModel.pwSpecialCharSet) {
            _specialCharsController.text = _viewModel.pwSpecialCharSet;
        }
        setState(() {
            }
        );
    }

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
                                    errorText: errorText
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
                        TextButton(onPressed: () => Navigator.pop(dialogContext, null), child: const Text('Abbrechen')),
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

    /// Verarbeitet das Hinzufügen eines Freundes.
    ///
    /// Öffnet den Such-Dialog und verarbeitet das Ergebnis. Bei Fehlern wie "nicht gefunden"
    /// bleibt der Dialog offen, andere Fehler werden per SnackBar gemeldet.
    Future<void> _handleAddFriend() async {
        try {
            String? errorText;
            while (true) {
                final name = await _showAddFriendDialog(errorText: errorText);
                if (name == null) return;

                final success = await _viewModel.addFriend(name);
                if (!mounted) return;

                if (!success) {
                    if (_viewModel.errorMessage == 'Person nicht gefunden.' || 
                        _viewModel.errorMessage == 'Person bereits hinzugefügt.') {
                        // im Dialog anzeigen, NICHT SnackBar
                        errorText = _viewModel.errorMessage;
                        continue;
                    }
                    _showSnack(_viewModel.errorMessage ?? 'Unerwarteter Fehler');
                    break;
                }
                _showSnack('"$name" wurde hinzugefügt.', success: true);
                break;
            }
        }
        catch (e, st) {
            _showException(e, stackTrace: st);
        }
    }

    /// Zeigt eine Sicherheitsabfrage an, bevor der lokale Tresor und alle
    /// damit verbundenen Daten unwiderruflich vom Gerät gelöscht werden.
    void _showDeleteConfirm() {
        showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
                title: const Text('Tresor lokal löschen'),
                content: const Text('Bist du sicher? Alle lokalen Daten dieses Tresors werden unwiderruflich entfernt.'),
                actions: [
                    TextButton(
                        onPressed: () {
                            if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                            }
                        },
                        child: const Text('Abbrechen'),
                    ),
                    TextButton(
                        onPressed: () async {
                            await _viewModel.deleteVault();
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pushNamedAndRemoveUntil('/', (route) => false);
                        },
                        child: const Text('Löschen', style: TextStyle(color: Colors.red)),
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
}
