import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/features/edit/edit_notifier.dart';
import 'package:privault/widgets/confirm_dialog.dart';
import 'package:privault/widgets/password_field.dart';
import 'package:privault/widgets/password_strength_bar.dart';
import 'package:privault/widgets/snack.dart';


/// Der [EditPage] stellt das Formular zum Erstellen oder Bearbeiten eines Tresor-Eintrags bereit.
///
/// Die Ansicht validiert Eingaben in Echtzeit und bietet folgende Hilfsmittel:
/// * Zuweisung zu neuen oder bereits existierenden Kategorien.
/// * Integrierter Passwort-Generator für hochsichere Zufallspasswörter.
/// * Visuelle Anzeige der Passwortstärke während der Eingabe.
/// * Möglichkeit, bestehende Einträge endgültig aus dem Tresor zu löschen.
class EditPage extends ConsumerStatefulWidget {
  /// Die ID des anzuzeigenden Eintrags
  final int? entryId;

  /// Konstruktor
  const EditPage({super.key, this.entryId});

  @override
  ConsumerState<EditPage> createState() => _EditPageState();
}

class _EditPageState extends ConsumerState<EditPage> {
  
  // ------------------------------------------------------------------------
  // --- TextEditingController ---
  // ------------------------------------------------------------------------

  final _categoryController = TextEditingController();
  final _titleController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _urlController = TextEditingController();
  final _notesController = TextEditingController();

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert den Screen und lädt die Daten, sobald der erste Frame gerendert wurde.
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Daten laden
      final notifier = ref.read(editProvider.notifier);
      await notifier.load(widget.entryId);

      // Textfelder synchronisieren
      final state = ref.read(editProvider);
      _categoryController.text = state.category;
      _titleController.text = state.title;
      _usernameController.text = state.username;
      _passwordController.text = state.password;
      _urlController.text = state.url;
      _notesController.text = state.notes;
    });
  }

  /// Gibt Ressourcen frei.
  @override
  void dispose() {
    _categoryController.dispose();
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // todo Diese Logik ist noch von der Portierung von setState() zu Riverpod übrig. Kann das raus?
  // /// Diese Methode stellt sicher, dass die Textfelder (insbesondere für Passwort und
  // /// Kategorie) aktualisiert werden, wenn diese Werte durch Logik im ViewModel (z.B.
  // /// den Generator) geändert werden.
  // void _onViewModelChanged() {
  //   if (!mounted) return;
  //   if (_passwordController.text != _viewModel.password) {
  //     _passwordController.text = _viewModel.password;
  //   }
  //   if (_categoryController.text != _viewModel.category) {
  //     _categoryController.text = _viewModel.category;
  //   }
  // }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  /// Rendert die Seite (getriggert durch Änderungen im State)
  @override
  Widget build(BuildContext context) {
    // Notifier und State holen
    final notifier = ref.read(editProvider.notifier);
    final state = ref.watch(editProvider); // todo besser in Consumer-Widget aufteilen

    final displayTitle = state.title.isEmpty ? (state.isEditMode ? 'Eintrag bearbeiten' : 'Neuer Eintrag') : state.title;

    // Wenn Passwort oder Kategorie im Notifier geändert wurden (z.B. Generator),
    // synchronisieren wir die Controller.
    //_syncControllers(state);  todo kann das raus?

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

                // --- Kategorie ---
                TextField(
                  controller: _categoryController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Kategorie',
                    prefixIcon: const Icon(Icons.label_outlined),
                    errorText: notifier.getFieldErrorText('category'), // todo sollte nur hören auf: state.error.field == 'category' ? state.error.text : null,
                    border: const OutlineInputBorder(),
                    suffixIcon: state.existingCategories.isNotEmpty
                        ? PopupMenuButton<String>(
                            icon: const Icon(Icons.filter_list),
                            onSelected: (val) {
                              notifier.setCategory(val);
                              _categoryController.text = val;
                            },
                            itemBuilder: (context) => state.existingCategories.map((c) => PopupMenuItem(value: c, child: Text(c))).toList(),
                          )
                        : null,
                  ),
                  onChanged: notifier.setCategory,
                ),
                const SizedBox(height: 16),

                // --- Titel ---
                TextField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Titel',
                    prefixIcon: const Icon(Icons.title_outlined),
                    errorText: notifier.getFieldErrorText('title'), // todo!
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: notifier.setTitle,
                ),
                const SizedBox(height: 16),

                // --- Benutzername ---
                TextField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Benutzername',
                    prefixIcon: const Icon(Icons.person_outline),
                    errorText: notifier.getFieldErrorText('username'), // todo!
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: notifier.setUsername,
                ),
                const SizedBox(height: 16),

                // --- Passwort ---
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PasswordField(
                      controller: _passwordController,
                      label: 'Passwort',
                      prefixIcon: Icons.key_outlined,
                      errorText: notifier.getFieldErrorText('password'), // todo!
                      suffixActions: [
                        IconButton(
                          icon: const Icon(Icons.casino),
                          tooltip: 'Passwort generieren',
                          onPressed: notifier.generatePassword,
                        ),
                      ],
                      onChanged: notifier.setPassword,
                    ),
                    const SizedBox(height: 6),
                    if (state.password.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: PasswordStrengthBar(
                          score: notifier.getPasswordStrength(), // todo!
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // --- URL ---
                TextField(
                  controller: _urlController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'URL',
                    prefixIcon: const Icon(Icons.public_outlined),
                    errorText: notifier.getFieldErrorText('url'), // todo!
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: notifier.setUrl,
                ),
                const SizedBox(height: 16),

                // --- Notizen ---
                TextField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: null,
                  decoration: InputDecoration(
                    labelText: 'Notizen',
                    prefixIcon: const Icon(Icons.article_outlined),
                    errorText: notifier.getFieldErrorText('notes'), // todo!
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: notifier.setNotes,
                ),

                const SizedBox(height: 32),

                // --- Löschen-Button ---
                if (state.isEditMode)
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

        if (state.isBusy)
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

  // todo Dieser Handler scheinen mir ein Anti-Pattern im Sinne von Riverpod zu sein. UI sollte dumm sein. Aber wie löst man das sauber?

  // todo Anti-Pattern auflösen
  // Speichert erst die Änderungen, wenn gewünscht und springt dann zurück.
  Future<void> _handleCancel() async {
    // Busy-Check
    if (ref.read(editProvider).isBusy) return;

    // Änderungen speichern, wenn gewünscht
    final notifier = ref.read(editProvider.notifier);
    if (notifier.isDirty()) {
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

    // Zur vorherigen Seite navigieren
    if (mounted) Navigator.of(context).pop();
  }

  // todo Anti-Pattern auflösen
  // Speichert den Eintrag und springt dann zur Detailansicht.
  Future<void> _handleSave() async {
    // Busy-Check
    if (ref.read(editProvider).isBusy) return;

    // Speichern
    final notifier = ref.read(editProvider.notifier);
    final modified = notifier.isDirty();
    final success = await notifier.save();
    if (!mounted) return;

    // Aktuellen State holen
    final state = ref.read(editProvider);

    // Fehlerfall
    // Hier bleiben, falls das Ergebnis einen Fehler enthält
    if (!success) {
      if (state.error.field == null) {
        Snack.show(context, state.error.text);
      }
      return;
    }

    // Erfolgsfall
    if (!state.isEditMode) {
      // Diese Seite wurde von der Hauptseite aufgerufen.
      // Wir ersetzen im Navigations-Stack diese Seite mit der Detailansicht.
      Navigator.of(context).pushReplacementNamed('/detail', arguments: state.entryId, result: modified);
      return;
    }

    // Diese Seite wurde von der Detailansicht aufgerufen.
    // Wir navigieren einfach wieder zurück.
    Navigator.of(context).pop(modified);
  }

  // todo Anti-Pattern auflösen
  /// Speichert die Änderungen, wenn gewünscht und springt dann zurück zur Detailansicht.
  Future<void> _handleDeleteEntry() async {
    // Busy-Check
    if (ref.read(editProvider).isBusy) return;

    // Sicherheitsabfrage
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Eintrag löschen',
      text: 'Soll dieser Eintrag wirklich gelöscht werden?',
      ok: 'Ja, löschen',
    );
    if (confirmed != true || !mounted) return;

    // Eintrag löschen
    final notifier = ref.read(editProvider.notifier);
    final success = await notifier.deleteEntry();
    if (!mounted) return;

    // Aktuellen State holen
    final state = ref.read(editProvider);

    // Fehlerfall
    if (!success) {
      if (state.error.field == null) {
        Snack.show(context, state.error.text);
      }
      return;
    }

    // Erfolgsfall
    // Das Löschen ist nur im Editiermodus möglich, d.h., diese Seite wurde von der Detailansicht aufgerufen.
    // Wir navigieren zurück zur Detailansicht und weiter zurück zur Hauptansicht.
    Navigator.of(context)..pop()..pop(true);
  }
}
