import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:privault/viewmodels/settings_view_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _vaultNameController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _specialCharsController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = context.read<SettingsViewModel>();
      await vm.loadSettings();
      _vaultNameController.text = vm.vaultName;
      _userNameController.text = vm.userName;
      _hostController.text = vm.host;
      _tokenController.text = vm.apiToken;
      _specialCharsController.text = vm.pwSpecialCharSet;
      _categoryController.text = vm.categoryPlaceholder;
    });
  }

  @override
  void dispose() {
    _vaultNameController.dispose();
    _userNameController.dispose();
    _hostController.dispose();
    _tokenController.dispose();
    _specialCharsController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _showAddFriendDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Person suchen'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Name der Person'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              context.read<SettingsViewModel>().addFriend(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Suchen'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tresor lokal löschen'),
        content: const Text(
          'Bist du sicher? Alle lokalen Daten dieses Tresors werden unwiderruflich von diesem Gerät entfernt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              await context.read<SettingsViewModel>().deleteVault();
              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SettingsViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
        actions: [
          Tooltip(
            message: 'Speichern',
            child: IconButton(
              icon: const Icon(Icons.check),
              onPressed: viewModel.isBusy
                  ? null
                  : () async {
                      final success = await viewModel.save();
                      if (success && context.mounted) Navigator.pop(context);
                    },
            ),
          ),
        ],
      ),
      body: viewModel.isBusy
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sektion: Identifikation
                  _buildSectionTitle('Identifikation'),
                  TextField(
                    controller: _vaultNameController,
                    enabled: !viewModel.isRegistered,
                    decoration: const InputDecoration(
                      labelText: 'Tresor-Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.shield_outlined),
                    ),
                    onChanged: (value) => viewModel.vaultName = value,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _userNameController,
                    enabled: !viewModel.isRegistered,
                    decoration: const InputDecoration(
                      labelText: 'Benutzer-Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    onChanged: (value) => viewModel.userName = value,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Diese Funktion wird in einer zukünftigen Version implementiert (TODO).',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.password),
                      label: const Text('Master-Passwort ändern'),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Sektion: Anmeldeoptionen
                  _buildSectionTitle('Anmeldeoptionen'),
                  SwitchListTile(
                    title: const Text('Biometrie verwenden'),
                    subtitle: const Text(
                      'Erlaubt das Entsperren des Tresors via Fingerabdruck oder Gesichtserkennung.',
                    ),
                    value: viewModel.useBiometric,
                    onChanged: (val) => viewModel.useBiometric = val,
                  ),
                  const SizedBox(height: 8),

                  // Sektion: Synchronisation
                  _buildSectionTitle('Synchronisation'),
                  TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: 'Host URL',
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
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          viewModel.isTokenHidden
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: viewModel.toggleTokenVisibility,
                      ),
                    ),
                    onChanged: (value) => viewModel.apiToken = value,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final ok = await viewModel.testConnection();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Verbindung erfolgreich!'
                                  : 'Verbindung fehlgeschlagen.',
                            ),
                            backgroundColor: ok ? Colors.green : Colors.red,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.swap_calls),
                    label: const Text('Verbindung testen'),
                  ),
                  const SizedBox(height: 32),

                  // Sektion: Freunde
                  _buildSectionHeaderWithAction(
                    'Freunde',
                    Icons.person_add,
                    'Person suchen',
                    _showAddFriendDialog,
                  ),
                  if (viewModel.friends.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Keine weiteren Personen im Tresor.',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    )
                  else
                    ...viewModel.friends.map(
                      (f) => Card(
                        child: ListTile(
                          title: Text(f.name),
                          subtitle: Text(
                            f.fingerprint,
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                          trailing: Switch(
                            value: f.isVerified,
                            onChanged: (_) => viewModel.toggleVerification(f),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),

                  // Sektion: Passwort-Generator
                  _buildSectionTitle('Passwort-Generator'),
                  const Text(
                    'Länge',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: viewModel.pwLength.toDouble(),
                          min: 8,
                          max: 64,
                          divisions: 56,
                          label: viewModel.pwLength.toString(),
                          onChanged: (val) => viewModel.pwLength = val.toInt(),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          viewModel.pwLength.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _specialCharsController,
                          decoration: const InputDecoration(
                            labelText: 'Sonderzeichen',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) =>
                              viewModel.pwSpecialCharSet = value,
                        ),
                      ),
                      Tooltip(
                        message: 'Standard',
                        child: IconButton(
                          icon: const Icon(Icons.star_outline),
                          onPressed: () {
                            viewModel.setSpecialChars('Standard');
                            _specialCharsController.text =
                                viewModel.pwSpecialCharSet;
                          },
                        ),
                      ),
                      Tooltip(
                        message: 'Alle',
                        child: IconButton(
                          icon: const Icon(Icons.all_inclusive),
                          onPressed: () {
                            viewModel.setSpecialChars('All');
                            _specialCharsController.text =
                                viewModel.pwSpecialCharSet;
                          },
                        ),
                      ),
                      Tooltip(
                        message: 'Keine',
                        child: IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            viewModel.setSpecialChars('None');
                            _specialCharsController.text = '';
                          },
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    title: const Text('Lesbarkeit optimieren'),
                    subtitle: const Text(
                      'Vermeidet verwechselbare Zeichen wie I, l, O, 0',
                    ),
                    value: viewModel.pwAvoidIlO0,
                    onChanged: (val) => viewModel.pwAvoidIlO0 = val,
                  ),
                  const SizedBox(height: 32),

                  // Sektion: Design
                  _buildSectionTitle('Erscheinungsbild'),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Hell'),
                        icon: Icon(Icons.light_mode),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dunkel'),
                        icon: Icon(Icons.dark_mode),
                      ),
                    ],
                    selected: {viewModel.themeMode},
                    onSelectionChanged: (val) =>
                        viewModel.themeMode = val.first,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Name für leere Kategorie',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => viewModel.categoryPlaceholder = value,
                  ),
                  const SizedBox(height: 32),

                  // Sektion: Systemeinstellungen
                  _buildSectionTitle('Systemeinstellungen'),
                  _buildSystemButton(
                    Icons.fingerprint,
                    'Biometrie',
                    'Systemeinstellungen für Biometrie öffnen',
                    viewModel.openBiometricSettings,
                  ),
                  _buildSystemButton(
                    Icons.text_fields,
                    'Autofill',
                    'Android-Einstellungen für das automatische Ausfüllen öffnen',
                    viewModel.openAutofillSettings,
                  ),
                  _buildSystemButton(
                    Icons.info_outline,
                    'App-Info',
                    'Systemdetails dieser App anzeigen (Version, Speicher)',
                    viewModel.openAppSettings,
                  ),
                  const SizedBox(height: 64),

                  // Sektion: Gefahrenzone
                  Center(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade900,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      onPressed: _showDeleteConfirm,
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Tresor lokal löschen'),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  Widget _buildSectionHeaderWithAction(
    String title,
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSectionTitle(title),
        Tooltip(
          message: tooltip,
          child: IconButton(icon: Icon(icon), onPressed: onPressed),
        ),
      ],
    );
  }

  Widget _buildSystemButton(
    IconData icon,
    String label,
    String help,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: Text(
              help,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
