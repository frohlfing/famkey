import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famkey/features/edit/edit_notifier.dart';
import 'package:famkey/features/edit/edit_state.dart';
import 'package:famkey/widgets/confirm_dialog.dart';
import 'package:famkey/widgets/password_field.dart';
import 'package:famkey/widgets/password_strength_bar.dart';
import 'package:famkey/widgets/snack.dart';

/// Der [EditPage] stellt das Formular zum Erstellen oder Bearbeiten eines Tresor-Eintrags bereit.
///
/// Die Ansicht validiert Eingaben in Echtzeit und bietet folgende Hilfsmittel:
/// * Zuweisung zu neuen oder bereits existierenden Kategorien.
/// * Integrierter Passwortgenerator für hochsichere Zufallspasswörter.
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

    // Listener für Status-Änderungen
    ref.listen(editProvider.select((s) => s.status), (previous, next) {
      final state = ref.read(editProvider);

      switch (next) {
        case EditActionStatus.saved:
          Snack.show(context, 'Gespeichert!', success: true);
          // Entscheiden, wohin navigiert wird
          if (previous == EditActionStatus.updating) {
            Navigator.of(context).pop(true); // Zurück zur Detailseite
          } else {
            // Diese Seite wurde direkt von der Hauptseite aufgerufen (die Detailansicht wurde "übersprungen").
            // Wir ersetzen im Navigations-Stack diese Seite mit der Detailansicht.
            Navigator.of(context).pushReplacementNamed('/detail', arguments: state.entryId, result: true);
          }
          break;

        case EditActionStatus.deleted:
          Snack.show(context, 'Gelöscht!', success: true);
          Navigator.of(context)..pop()..pop(true); // Zurück zur Detailansicht und weiter zurück zur Hauptansicht
          break;

        case EditActionStatus.failure:
          if (state.error.field == null) { // Nur allgemeine Fehler anzeigen
            Snack.show(context, state.error.text);
          }
          break;

        default:
          break;
      }
    });

    // Listener, der die Controller nur bei Initialladung oder Generierung füllt
    ref.listen(editProvider, (previous, next) {
      if (previous == next) return;
      final formData = next.formData;
      if (_categoryController.text != formData.category) _categoryController.text = formData.category;
      if (_titleController.text != formData.title) _titleController.text = formData.title;
      if (_usernameController.text != formData.username) _usernameController.text = formData.username;
      if (_passwordController.text != formData.password) _passwordController.text = formData.password;
      if (_urlController.text != formData.url) _urlController.text = formData.url;
      if (_notesController.text != formData.notes) _notesController.text = formData.notes;
    });

    // Gezielte Watches für maximale Performance
    final isBusy = ref.watch(editProvider.select((s) => s.isBusy));
    final isEditMode = ref.watch(editProvider.select((s) => s.isEditMode));

    // Notifier holen
    final notifier = ref.read(editProvider.notifier);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Consumer(builder: (ctx, ref, _) {
              final title = ref.watch(editProvider.select((s) => s.displayTitle));
              return Text(title);
            }),
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
                  builder: (ctx, ref, _) {
                    // state.existingCategories beobachten -> wenn sich dieser Wert ändert, wird das Consumer-Widget neu gerendert
                    final existingCategories = ref.watch(editProvider.select((s) => s.existingCategories));
                    final errorText = ref.watch(editProvider.select((state) => state.error.field == 'category' ? state.error.text : null));
                    return TextField(
                      controller: _categoryController,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Kategorie',
                        prefixIcon: const Icon(Icons.label_outlined),
                        errorText: errorText,
                        border: const OutlineInputBorder(),
                        suffixIcon: existingCategories.isNotEmpty ? PopupMenuButton<String>(
                          icon: const Icon(Icons.filter_list),
                          onSelected: (val) {
                            _categoryController.text = val;
                            notifier.setCategory(val);
                          },
                          itemBuilder: (BuildContext ctx) {
                            return existingCategories.map((String category) => PopupMenuItem<String>(value: category, child: Text(category))).toList();
                          },
                        ) : null,
                      ),
                      onChanged: isBusy ? null : notifier.setCategory,
                    );
                  },
                ),
                const SizedBox(height: 16),

                // --- Titel ---
                Consumer(
                  builder: (ctx, ref, _) {
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
                      onChanged: isBusy ? null : notifier.setTitle,
                    );
                  },
                ),
                const SizedBox(height: 16),

                // --- Benutzername ---
                Consumer(
                  builder: (ctx, ref, _) {
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
                      onChanged: isBusy ? null : notifier.setUsername,
                    );
                  },
                ),
                const SizedBox(height: 16),

                // --- Passwort ---
                Consumer(
                  builder: (ctx, ref, _) {
                    final passwordStrength = ref.watch(editProvider.select((s) => s.passwordStrength));
                    final errorText = ref.watch(editProvider.select((state) => state.error.field == 'password' ? state.error.text : null));
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PasswordField(
                          controller: _passwordController,
                          textInputAction: TextInputAction.next,
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
                          onChanged: isBusy ? null : notifier.setPassword,
                        ),
                        // --- Passwortstärke ---
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
                  builder: (ctx, ref, _) {
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
                      onChanged: isBusy ? null : notifier.setUrl,
                    );
                  },
                ),
                const SizedBox(height: 16),

                // --- Notizen ---
                Consumer(
                  builder: (ctx, ref, _) {
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
                      onChanged: isBusy ? null : notifier.setNotes,
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

                // --- Abstand zum unteren Rand ---
                const SizedBox(height: 48),
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

      if (!mounted) return;

      if (confirmed == true) {
        final notifier = ref.read(editProvider.notifier);
        notifier.save(); // Statt Cancel die Save-Action ausführen
        return;
      }
    }

    Navigator.of(context).pop(); // Zur vorherigen Seite navigieren
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
