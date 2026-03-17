import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/features/edit/edit_notifier.dart';
import 'package:privault/features/edit/edit_state.dart';
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

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  /// Rendert die Seite (getriggert durch Änderungen im State)
  @override
  Widget build(BuildContext context) {

    // Listener für Side-Effects (Navigation, SnackBars)
    // Er wird nur einmal ausgelöst, wenn sich der Status ändert, und verursacht keine Rebuilds.
    ref.listen(editProvider.select((s) => s.status), (previous, next) {
      if (next == EditActionStatus.saveSuccess) {
        Snack.show(context, 'Gespeichert!');
        final entryId = ref.read(editProvider).entryId;

        // Entscheiden, wohin navigiert wird
        if (previous == EditActionStatus.updating) {
          Navigator.of(context).pop(true); // Zurück zur Detailseite
        }

        else {
          // Diese Seite wurde direkt von der Hauptseite aufgerufen (die Detailansicht wurde "übersprungen").
          // Wir ersetzen im Navigations-Stack diese Seite mit der Detailansicht.
          Navigator.of(context).pushReplacementNamed('/detail', arguments: entryId, result: true);
        }
      }

      else if (next == EditActionStatus.deleteSuccess) {
        Snack.show(context, 'Gelöscht!');
        Navigator.of(context)..pop()..pop(true); // Zurück zur Detailansicht und weiter zurück zur Hauptansicht
      }

      else if (next == EditActionStatus.failure) {
        final error = ref.read(editProvider).error;
        if (error.field == null) { // Nur allgemeine Fehler anzeigen
          Snack.show(context, error.text);
        }
      }
    });

    // Listener, der die Controller nur bei Initialladung oder Generierung füllt
    ref.listen(editProvider, (previous, next) {
      if (_categoryController.text != next.category) _categoryController.text = next.category;
      if (_titleController.text != next.title) _titleController.text = next.title;
      if (_usernameController.text != next.username) _usernameController.text = next.username;
      if (_passwordController.text != next.password) _passwordController.text = next.password;
      if (_urlController.text != next.url) _urlController.text = next.url;
      if (_notesController.text != next.notes) _notesController.text = next.notes;
    });

    // Gezielte `watches` für maximale Performance
    final isBusy = ref.watch(editProvider.select((s) => s.isBusy));
    final isEditMode = ref.watch(editProvider.select((s) => s.isEditMode));
    final displayTitle = ref.watch(editProvider.select((s) => s.displayTitle));

    // Notifier holen
    final notifier = ref.read(editProvider.notifier);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(displayTitle), // todo in ein Consumer packen
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: isBusy ? null : _handleCancel,
              tooltip: "Zurück",
            ),
            actions: [
              IconButton(
                tooltip: 'Speichern',
                icon: const Icon(Icons.check),
                onPressed: isBusy ? null : notifier.save,
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
                Consumer(
                  builder: (context, ref, _) {
                    // state.existingCategories beobachten -> wenn sich dieser Wert ändert, wird das Consumer-Widget neu gerendert
                    final existingCategories = ref.watch(editProvider.select((s) => s.existingCategories));
                    final errorText = ref.watch(editProvider.select((state) => state.error.field == 'category' ? state.error.text : null));
                    return TextField(
                      controller: _categoryController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Kategorie',
                        prefixIcon: const Icon(Icons.label_outlined),
                        errorText: errorText,
                        border: const OutlineInputBorder(),
                        suffixIcon: existingCategories.isNotEmpty ? PopupMenuButton<String>(
                          icon: const Icon(Icons.filter_list),
                          onSelected: (val) {
                            notifier.setCategory(val);
                            _categoryController.text = val;
                          },
                          itemBuilder: (context) => existingCategories.map((c) => PopupMenuItem(value: c, child: Text(c))).toList(),
                        ) : null,
                      ),
                      onChanged: notifier.setCategory,
                    );
                  },
                ),
                const SizedBox(height: 16),

                // --- Titel ---
                Consumer(
                  builder: (context, ref, _) {
                    // errorText für Feld 'title' beobachten -> wenn sich dieser Wert ändert, wird das Consumer-Widget neu gerendert
                    final errorText = ref.watch(editProvider.select((state) => state.error.field == 'title' ? state.error.text : null));
                    return TextField(
                      controller: _titleController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Titel',
                        prefixIcon: const Icon(Icons.title_outlined),
                        errorText: errorText,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: notifier.setTitle,
                    );
                  },
                ),
                const SizedBox(height: 16),

                // --- Benutzername ---
                Consumer(
                  builder: (context, ref, _) {
                    final errorText = ref.watch(editProvider.select((state) => state.error.field == 'username' ? state.error.text : null));
                    return TextField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Benutzername',
                        prefixIcon: const Icon(Icons.person_outline),
                        errorText: errorText,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: notifier.setUsername,
                    );
                  },
                ),
                const SizedBox(height: 16),

                // --- Passwort ---
                Consumer(
                  builder: (context, ref, _) {
                    final password = ref.watch(editProvider.select((s) => s.password));
                    final passwordStrength = ref.watch(editProvider.select((s) => s.passwordStrength));
                    final errorText = ref.watch(editProvider.select((state) => state.error.field == 'password' ? state.error.text : null));
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PasswordField(
                          controller: _passwordController,
                          label: 'Passwort',
                          prefixIcon: Icons.key_outlined,
                          errorText: errorText,
                          suffixActions: [
                            IconButton(
                              icon: const Icon(Icons.casino),
                              tooltip: 'Passwort generieren',
                              onPressed: isBusy ? null : notifier.generatePassword,
                            ),
                          ],
                          onChanged: notifier.setPassword,
                        ),
                        const SizedBox(height: 6),
                        if (password.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: PasswordStrengthBar(score: passwordStrength),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // --- URL ---
                Consumer(
                  builder: (context, ref, _) {
                    final errorText = ref.watch(editProvider.select((state) => state.error.field == 'url' ? state.error.text : null));
                    return TextField(
                      controller: _urlController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'URL',
                        prefixIcon: const Icon(Icons.public_outlined),
                        errorText: errorText,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: notifier.setUrl,
                    );
                  },
                ),
                const SizedBox(height: 16),

                // --- Notizen ---
                Consumer(
                  builder: (context, ref, _) {
                    final errorText = ref.watch(editProvider.select((state) => state.error.field == 'notes' ? state.error.text : null));
                    return TextField(
                      controller: _notesController,
                      minLines: 3,
                      maxLines: null,
                      decoration: InputDecoration(
                        labelText: 'Notizen',
                        prefixIcon: const Icon(Icons.article_outlined),
                        errorText: errorText,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: notifier.setNotes,
                    );
                  },
                ),
                const SizedBox(height: 32),

                // --- Löschen-Button ---
                if (isEditMode)
                  ElevatedButton.icon(
                    onPressed: isBusy ? null : _handleDeleteEntry,
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

        if (isBusy)
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

  /// Speichert erst die Änderungen, wenn gewünscht und springt dann zurück.
  Future<void> _handleCancel() async {
    final state = ref.read(editProvider);
    if (state.isDirty) {
      final confirmed = await ConfirmDialog.show(
        context,
        title: 'Eintrag speichern',
        text: 'Möchtest du die Änderungen speichern?',
        ok: 'Ja, speichern',
        cancel: 'Nein, verwerfen',
      );
      if (mounted && confirmed == true) {
        final notifier = ref.read(editProvider.notifier);
        notifier.save(); // Statt Cancel die Save-Action ausführen
        return;
      }
    }
    if (mounted) Navigator.of(context).pop(); // Zur vorherigen Seite navigieren
  }

  /// Speichert die Änderungen, wenn gewünscht und springt dann zurück zur Detailansicht.
  Future<void> _handleDeleteEntry() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Eintrag löschen',
      text: 'Soll dieser Eintrag wirklich gelöscht werden?',
      ok: 'Ja, löschen',
    );
    if (mounted && confirmed == true) {
      final notifier = ref.read(editProvider.notifier);
      notifier.deleteEntry();
    }
  }
}
