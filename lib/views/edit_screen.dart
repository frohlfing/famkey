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

  /// Wird getriggert, wenn das ViewModel notifyListeners() aufruft.
  /// Hier kann u.a. der Text vom TextEditingController aktualisiert werden.
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
    // Dies triggert die build-Methode jedes Mal, wenn das ViewModel notifyListeners() aufruft.
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
              onPressed: _handleCancel,
              tooltip: "Zurück",
            ),
            actions: [
              IconButton(
                tooltip: 'Speichern',
                icon: const Icon(Icons.check),
                onPressed: _handleSave,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              //crossAxisAlignment: CrossAxisAlignment.start, // Button linksbündig
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
                  decoration: InputDecoration(
                    labelText: 'Titel',
                    border: OutlineInputBorder(),
                    errorText: viewModel.getFieldError('title'),
                  ),
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
                              icon: const Icon(Icons.casino),
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
                    onPressed: _handleDeleteEntry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    icon: const Icon(Icons.delete_outlined),
                    label: const Text('Eintrag löschen'),
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
      if (confirmed == true && mounted) {
        _handleSave();
        return;
      }
    }

    if (mounted) Navigator.of(context).pop();
  }

  // Speichert den Eintrag und  springt dann zur Detailansicht.
  Future<void> _handleSave() async {
    if (_viewModel.isBusy) return;

    final modified = _viewModel.isDirty;
    final savedId = await _viewModel.save();

    // Falls ein allgemeiner Fehler im VM gesetzt wurde (z.B. Server-Fehler)
    if (_viewModel.errorMessage != null && mounted) {
      _showSnack(_viewModel.errorMessage!);
      //_viewModel.clearError(); // Wichtig, damit er nicht doppelt triggert
      return;
    }

    if (savedId != null && mounted) {
      if (_viewModel.isEditMode) {
        // Diese Seite wurde von der Detailansicht aufgerufen.
        // Wir navigieren einfach wieder zurück.
        Navigator.of(context).pop(modified);
      } else {
        // Diese Seite wurde von der Hauptseite aufgerufen.
        // Wir ersetzen im Navigations-Stack diese Seite mit der Detailansicht.
        Navigator.of(context).pushReplacementNamed('/detail', arguments: savedId, result: modified);
      }
    }
  }

  /// Speichert die Änderungen, wenn gewünscht und springt dann zurück zur Detailansicht.
  Future<void> _handleDeleteEntry() async {
    if (_viewModel.isBusy) return;

    final confirmed = await _showConfirmDialog(
      'Eintrag löschen',
      'Soll dieser Eintrag wirklich gelöscht werden?',
      ok: 'Ja, löschen',
    );

    if (confirmed == true && mounted) {
      final success = await _viewModel.deleteEntry();
      if (success && mounted) {
        // Das Löschen ist nur im Editiermodus möglich, d.h., diese Seite wurde von der Detailansicht aufgerufen.
        // Wir navigieren zurück zur Detailansicht und weiter zurück zur Hauptansicht.
        Navigator.of(context)..pop()..pop(true);
      }
    }
  }

  // ------------------------------------------------------------------------
  // --- Dialoge ---
  // ------------------------------------------------------------------------

  /// Öffnet einen modalen Dialog für eine Ja/Nein-Frage.
  Future<bool?> _showConfirmDialog(String title, String message, {String? ok, String? cancel, bool autofocus = true}) async {
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
            autofocus: autofocus,
            child: Text(ok ?? 'OK'),
            onPressed: () => Navigator.of(ctx).pop(true),
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
