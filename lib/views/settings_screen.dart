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
  final TextEditingController _pathController = TextEditingController();
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _specialCharsController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  late SettingsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<SettingsViewModel>();
    _viewModel.addListener(_onViewModelChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _viewModel.loadSettings();
      _vaultNameController.text = _viewModel.vaultName;
      _userNameController.text = _viewModel.userName;
      _pathController.text = _viewModel.vaultStoragePath;
      _hostController.text = _viewModel.host;
      _tokenController.text = _viewModel.apiToken;
      _specialCharsController.text = _viewModel.pwSpecialCharSet;
      _lengthController.text = _viewModel.pwLength.toString();
      _categoryController.text = _viewModel.categoryPlaceholder;
    });
  }

  void _onViewModelChanged() {
    if (!mounted) return;
    if (_specialCharsController.text != _viewModel.pwSpecialCharSet) {
      _specialCharsController.text = _viewModel.pwSpecialCharSet;
    }
    setState(() {});
  }

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

  void _showAddFriendDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Person suchen'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Name der Person')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () {
              _viewModel.addFriend(controller.text);
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
        content: const Text('Bist du sicher? Alle lokalen Daten dieses Tresors werden unwiderruflich entfernt.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () async {
              await _viewModel.deleteVault();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
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

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Einstellungen'),
            centerTitle: true,
            actions: [
              Tooltip(
                message: 'Speichern',
                child: IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: viewModel.isBusy ? null : () async {
                    final success = await viewModel.save();
                    if (success && mounted) Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 32),

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
                    suffixIcon: IconButton(
                      icon: Icon(viewModel.isTokenHidden ? Icons.visibility : Icons.visibility_off),
                      onPressed: viewModel.toggleTokenVisibility,
                    ),
                  ),
                  onChanged: (value) => viewModel.apiToken = value,
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final ok = await viewModel.testConnection();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok ? 'Verbindung erfolgreich!' : 'Verbindung fehlgeschlagen.'),
                          backgroundColor: ok ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.swap_calls),
                  label: const Text('Verbindung testen'),
                ),
                const SizedBox(height: 32),

                _buildSectionHeaderWithAction('Freunde', Icons.person_add, 'Person suchen', _showAddFriendDialog),
                if (viewModel.friends.isEmpty)
                  const Padding(padding: EdgeInsets.all(16), child: Text('Keine weiteren Personen.', style: TextStyle(fontStyle: FontStyle.italic)))
                else
                  Column(
                    children: viewModel.friends.map((f) => Card(
                      key: ValueKey('friend_${f.user.uuid}'),
                      child: ListTile(
                        title: Text(f.name),
                        subtitle: Text(f.fingerprint, style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                        trailing: Switch(value: f.isVerified, onChanged: (_) => viewModel.toggleVerification(f)),
                      ),
                    )).toList(),
                  ),
                const SizedBox(height: 32),

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
                        decoration: const InputDecoration(labelText: 'Sonderzeichen', border: OutlineInputBorder()),
                        onChanged: (value) => viewModel.pwSpecialCharSet = value,
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.star_outline), onPressed: () => viewModel.setSpecialChars('Standard')),
                    IconButton(icon: const Icon(Icons.all_inclusive), onPressed: () => viewModel.setSpecialChars('All')),
                    IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => viewModel.setSpecialChars('None')),
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

                _buildSectionTitle('Anmeldeoptionen'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Biometrie verwenden', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Erlaubt das Entsperren des Tresors via Fingerabdruck.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Switch(value: viewModel.useBiometric, onChanged: (val) => viewModel.useBiometric = val),
                  ],
                ),
                const SizedBox(height: 32),

                _buildSectionTitle('Design'),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto)),
                    ButtonSegment(value: ThemeMode.light, label: Text('Hell'), icon: Icon(Icons.light_mode)),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dunkel'), icon: Icon(Icons.dark_mode)),
                  ],
                  selected: {viewModel.themeMode},
                  onSelectionChanged: (val) => viewModel.themeMode = val.first,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _categoryController,
                  decoration: const InputDecoration(labelText: 'Name für leere Kategorie', border: OutlineInputBorder()),
                  onChanged: (value) => viewModel.categoryPlaceholder = value,
                ),
                const SizedBox(height: 64),

                Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
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
        
        if (viewModel.isBusy)
          Container(
            color: Colors.black.withValues(alpha: 0.05),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
    );
  }

  Widget _buildSectionHeaderWithAction(String title, IconData icon, String tooltip, VoidCallback onPressed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSectionTitle(title),
        Tooltip(message: tooltip, child: IconButton(icon: Icon(icon), onPressed: onPressed)),
      ],
    );
  }

  Widget _buildSystemButton(IconData icon, String label, String help, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label)),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: Text(help, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
