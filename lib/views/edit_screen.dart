import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:privault/viewmodels/edit_view_model.dart';

/// Der [EditScreen] stellt das Formular zum Erstellen oder Bearbeiten eines Tresor-Eintrags bereit.
///
/// Die Ansicht validiert Eingaben in Echtzeit und bietet folgende Hilfsmittel:
/// * Zuweisung zu neuen oder bereits existierenden Kategorien.
/// * Integrierter Passwort-Generator für hochsichere Zufallspasswörter.
/// * Visuelle Anzeige der Passwortstärke während der Eingabe.
/// * Möglichkeit, bestehende Einträge endgültig aus dem Tresor zu löschen.
class EditScreen extends StatefulWidget {
  final int? entryId;

  /// Konstruktor
  const EditScreen({super.key, this.entryId});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  // ------------------------------------------------------------------------
  // --- Verwendete Dienste ---
  // ------------------------------------------------------------------------

  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // ------------------------------------------------------------------------
  // --- Interne Variablen ---
  // ------------------------------------------------------------------------

  late EditViewModel _viewModel;

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert den Screen und lädt die Daten, sobald der erste Frame gerendert wurde.
  @override
  void initState() {
    super.initState();

    _viewModel = context.read<EditViewModel>();
    _viewModel.addListener(_onViewModelChanged);
    _viewModel.init();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _viewModel.load(widget.entryId);
      _categoryController.text = _viewModel.category;
      _titleController.text = _viewModel.title;
      _usernameController.text = _viewModel.username;
      _passwordController.text = _viewModel.password;
      _urlController.text = _viewModel.url;
      _notesController.text = _viewModel.notes;
    });
  }

  /// Entfernt den Listener und gibt alle Ressourcen frei.
  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _categoryController.dispose();
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Wird aufgerufen, wenn das ViewModel signalisiert, dass sich Daten geändert haben.
  ///
  /// Diese Methode stellt sicher, dass die Textfelder (insbesondere für Passwort und
  /// Kategorie) aktualisiert werden, wenn diese Werte durch Logik im ViewModel (z.B.
  /// den Generator) geändert werden.
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

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  /// Baut die Eingabemaske zum Erstellen oder Bearbeiten eines Eintrags auf.
  ///
  /// Der Screen bietet:
  /// * Eine **AppBar** mit dynamischem Titel und einer Speichern-Schaltfläche.
  /// * Eingabefelder für Kategorie (mit Auswahl bereits existierender), Titel, Benutzername, Passwort, URL und Notizen.
  /// * Einen integrierten **Passwort-Generator** und eine **Stärke-Anzeige**.
  /// * Eine Schaltfläche zum **Löschen** des Eintrags (nur im Bearbeitungsmodus).
  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<EditViewModel>();

    final displayTitle = viewModel.title.isEmpty ? (viewModel.isEditMode ? 'Eintrag bearbeiten' : 'Neuer Eintrag') : viewModel.title;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(displayTitle),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
              tooltip: "Zurück",
            ),
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
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ------------------------------------------------------------------------
                // Formular
                // ------------------------------------------------------------------------
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
                            itemBuilder: (context) => viewModel.existingCategories.map((c) => PopupMenuItem(value: c, child: Text(c))).toList(),
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
                      backgroundColor: Colors.red.shade800,
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
  // --- Interne Methoden ---
  // ------------------------------------------------------------------------

  /// Bestimmt die Farbe der Stärke-Anzeige basierend auf der Bewertung des Passworts.
  ///
  /// Die Skala reicht von dezentem Grau (keine Eingabe) über Rot (sehr schwach)
  /// bis hin zu sattem Grün (stark).
  Color _getStrengthColor(int score) {
    // @formatter:off
    switch (score) {
      case 0: return const Color(0xFFCBD5E1);
      case 1: return const Color(0xFFDC2626);
      case 2: return const Color(0xFFF59E0B);
      case 3: return const Color(0xFF84CC16);
      case 4: return const Color(0xFF16A34A);
      default: return const Color(0xFFCBD5E1);
    }
    // @formatter:on
  }

  /// Liefert den passenden Beschreibungstext für die visuelle Passwort-Stärke-Anzeige.
  String _getStrengthText(int score) {
    // @formatter:off
    switch (score) {
      case 0: return "";
      case 1: return "Sehr schwach";
      case 2: return "Schwach";
      case 3: return "Gut";
      case 4: return "Stark";
      default: return "";
    }
    // @formatter:on
  }
}
