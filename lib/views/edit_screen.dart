import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:privault/viewmodels/edit_view_model.dart';
import 'package:privault/widgets/confirm_dialog.dart';
import 'package:privault/widgets/password_field.dart';
import 'package:privault/widgets/password_strength_bar.dart';
import 'package:privault/widgets/snack.dart';


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
                    prefixIcon: Icon(Icons.label_outlined),
                    errorText: viewModel.getFieldError('category'),
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
                    prefixIcon: Icon(Icons.title_outlined),
                    errorText: viewModel.getFieldError('title'),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => viewModel.title = value,
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Benutzername',
                    prefixIcon: Icon(Icons.person_outline),
                    errorText: viewModel.getFieldError('username'),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => viewModel.username = value,
                ),
                const SizedBox(height: 16),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PasswordField(
                      controller: _passwordController,
                      label: 'Passwort',
                      prefixIcon: Icons.key_outlined,
                      errorText: viewModel.getFieldError('password'),
                      suffixActions: [
                        IconButton(
                          icon: const Icon(Icons.casino),
                          tooltip: 'Passwort generieren',
                          onPressed: viewModel.generatePassword,
                        ),
                      ],
                      onChanged: (val) => viewModel.password = val,
                    ),
                    const SizedBox(height: 6),
                    if (viewModel.password.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: PasswordStrengthBar(score: viewModel.passwordStrength),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _urlController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'URL',
                    prefixIcon: Icon(Icons.public_outlined),
                    errorText: viewModel.getFieldError('url'),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => viewModel.url = value,
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: null,
                  decoration: InputDecoration(
                    labelText: 'Notizen',
                    prefixIcon: Icon(Icons.article_outlined),
                    errorText: viewModel.getFieldError('notes'),
                    border: OutlineInputBorder(),
                  ),
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
      final confirmed = await ConfirmDialog.show(
        context,
        title: 'Eintrag speichern',
        text: 'Möchtest du die Änderungen speichern?',
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
    final result = await _viewModel.save();
    if (!mounted) return;

    // Hier bleiben, falls das Ergebnis einen Fehler enthält
    if (!result.isSuccess) {
      if (result.field == null) Snack.show(context, result.errorMessage!);
      return;
    }

    if (!_viewModel.isEditMode) {
      // Diese Seite wurde von der Hauptseite aufgerufen.
      // Wir ersetzen im Navigations-Stack diese Seite mit der Detailansicht.
      final savedId = result.data!;
      Navigator.of(context).pushReplacementNamed('/detail', arguments: savedId, result: modified);
      return;
    }

    // Diese Seite wurde von der Detailansicht aufgerufen.
    // Wir navigieren einfach wieder zurück.
    Navigator.of(context).pop(modified);
  }

  /// Speichert die Änderungen, wenn gewünscht und springt dann zurück zur Detailansicht.
  Future<void> _handleDeleteEntry() async {
    if (_viewModel.isBusy) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Eintrag löschen',
      text: 'Soll dieser Eintrag wirklich gelöscht werden?',
      ok: 'Ja, löschen',
    );
    if (confirmed != true || !mounted) return;

    final result = await _viewModel.deleteEntry();
    if (!mounted) return;

    if (!result.isSuccess) {
      if (result.field == null) Snack.show(context, result.errorMessage!);
      return;
    }

    // Das Löschen ist nur im Editiermodus möglich, d.h., diese Seite wurde von der Detailansicht aufgerufen.
    // Wir navigieren zurück zur Detailansicht und weiter zurück zur Hauptansicht.
    Navigator.of(context)..pop()..pop(true);
  }
}
