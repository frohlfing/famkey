import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:privault/viewmodels/edit_view_model.dart';

class EditScreen extends StatefulWidget {
  final int? entryId;

  const EditScreen({super.key, this.entryId});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  late EditViewModel _viewModel; // Referenz speichern

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<EditViewModel>(); // Sicher in initState holen

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _viewModel.initialize(widget.entryId);

      _categoryController.text = _viewModel.category;
      _titleController.text = _viewModel.title;
      _usernameController.text = _viewModel.username;
      _passwordController.text = _viewModel.password;
      _urlController.text = _viewModel.url;
      _notesController.text = _viewModel.notes;

      _viewModel.addListener(_onViewModelChanged);
    });
  }

  void _onViewModelChanged() {
    if (!mounted) return;
    if (_passwordController.text != _viewModel.password) {
      _passwordController.text = _viewModel.password;
    }
    if (_categoryController.text != _viewModel.category) {
      _categoryController.text = _viewModel.category;
    }
    setState(() {}); // UI Refresh für dynamischen Titel
  }

  @override
  void dispose() {
    // Sicherer Zugriff ohne Context
    _viewModel.removeListener(_onViewModelChanged);
    _categoryController.dispose();
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Color _getStrengthColor(int score) {
    switch (score) {
      case 0:
        return const Color(0xFFCBD5E1);
      case 1:
        return const Color(0xFFDC2626);
      case 2:
        return const Color(0xFFF59E0B);
      case 3:
        return const Color(0xFF84CC16);
      case 4:
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFFCBD5E1);
    }
  }

  String _getStrengthText(int score) {
    switch (score) {
      case 0:
        return "";
      case 1:
        return "Sehr schwach";
      case 2:
        return "Schwach";
      case 3:
        return "Gut";
      case 4:
        return "Stark";
      default:
        return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<EditViewModel>();

    final displayTitle = viewModel.title.isEmpty ? (viewModel.isEditMode ? 'Eintrag bearbeiten' : 'Neuer Eintrag') : viewModel.title;

    return Scaffold(
      appBar: AppBar(
        title: Text(displayTitle),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Speichern',
            icon: const Icon(Icons.check),
            onPressed: viewModel.isBusy
                ? null
                : () async {
                    final savedId = await viewModel.save();
                    if (savedId != null && context.mounted) {
                      if (viewModel.isEditMode) {
                        // Zurück zum DetailScreen (dieser aktualisiert sich durch das Resultat)
                        Navigator.pop(context, true);
                      } else {
                        // Bei Neuanlage: Direkt zum neuen DetailScreen navigieren und EditScreen vom Stack entfernen.
                        // 'result: true' signalisiert dem MainScreen (der im Stack darunter liegt), dass er refreshen soll.
                        Navigator.pushReplacementNamed(context, '/detail', arguments: savedId, result: true);
                      }
                    }
                  },
          ),
        ],
      ),
      body: viewModel.isBusy
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _categoryController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Kategorie',
                      border: const OutlineInputBorder(),
                      suffixIcon: viewModel.existingCategories.isNotEmpty
                          ? PopupMenuButton<String>(
                              icon: const Icon(Icons.filter_list),
                              onSelected: (val) {
                                viewModel.category = val;
                                _categoryController.text = val;
                              },
                              itemBuilder: (context) =>
                                  viewModel.existingCategories.map((c) => PopupMenuItem(value: c, child: Text(c))).toList(),
                            )
                          : null,
                    ),
                    onChanged: (value) => viewModel.category = value,
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Titel', border: OutlineInputBorder()),
                    onChanged: (value) => viewModel.title = value,
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Benutzername', border: OutlineInputBorder()),
                    onChanged: (value) => viewModel.username = value,
                  ),
                  const SizedBox(height: 16),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _passwordController,
                        obscureText: viewModel.isPasswordHidden,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Passwort',
                          border: const OutlineInputBorder(),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                tooltip: 'Passwort generieren',
                                onPressed: viewModel.generatePassword,
                              ),
                              IconButton(
                                icon: Icon(viewModel.isPasswordHidden ? Icons.visibility : Icons.visibility_off),
                                tooltip: viewModel.isPasswordHidden ? 'Passwort anzeigen' : 'Passwort verbergen',
                                onPressed: viewModel.togglePasswordVisibility,
                              ),
                            ],
                          ),
                        ),
                        onChanged: (value) => viewModel.password = value,
                      ),
                      const SizedBox(height: 6),
                      if (viewModel.password.isNotEmpty)
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: (viewModel.passwordStrength + 1) / 5,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(_getStrengthColor(viewModel.passwordStrength)),
                                  minHeight: 4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _getStrengthText(viewModel.passwordStrength),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getStrengthColor(viewModel.passwordStrength),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _urlController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'URL', border: OutlineInputBorder()),
                    onChanged: (value) => viewModel.url = value,
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _notesController,
                    minLines: 3,
                    maxLines: null,
                    decoration: const InputDecoration(labelText: 'Notizen', border: OutlineInputBorder()),
                    onChanged: (value) => viewModel.notes = value,
                  ),

                  const SizedBox(height: 32),

                  if (viewModel.isEditMode)
                    ElevatedButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Eintrag löschen'),
                            content: const Text('Soll dieser Eintrag wirklich gelöscht werden?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Löschen', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && context.mounted) {
                          final navigator = Navigator.of(context);
                          final success = await viewModel.deleteEntry();
                          if (success && mounted) {
                            // Direkt zurück zur Hauptseite springen (Pop bis zur Route vor Details)
                            navigator.popUntil((route) => route.settings.name == '/main');
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Eintrag löschen'),
                    ),

                  if (viewModel.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        viewModel.errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
