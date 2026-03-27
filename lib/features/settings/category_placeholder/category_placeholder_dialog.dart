import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/features/settings/category_placeholder/category_placeholder_notifier.dart';
import 'package:privault/features/settings/category_placeholder/category_placeholder_state.dart';
import 'package:privault/widgets/confirm_dialog.dart';

/// Ein modaler Dialog zum Ändern des Platzhalters für eine leere Kategorie.
class CategoryPlaceholderDialog extends ConsumerStatefulWidget {

  /// Initiale Parameter
  // (keine)

  /// Konstruktor
  const CategoryPlaceholderDialog({super.key});

  /// Statische Methode zum Anzeigen des Dialogs.
  /// Gibt [true] zurück, wenn gespeichert wurde, andernfalls [false] oder [null].
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // User muss explizit Speichern oder Abbrechen
      builder: (context) => CategoryPlaceholderDialog(),
    );
  }

  @override
  ConsumerState<CategoryPlaceholderDialog> createState() => _CategoryPlaceholderDialogState();
}

class _CategoryPlaceholderDialogState extends ConsumerState<CategoryPlaceholderDialog> {

  // ------------------------------------------------------------------------
  // --- TextEditingController ---
  // ------------------------------------------------------------------------

  final _controller = TextEditingController();
  
  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert den Dialog und lädt die Daten, sobald der erste Frame gerendert wurde.
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Daten laden
      final notifier = ref.read(categoryPlaceholderProvider.notifier);
      await notifier.load();
    });
  }

  /// Gibt Ressourcen frei.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {

    // Listener für Status-Änderungen
    ref.listen(categoryPlaceholderProvider.select((s) => s.status), (previous, next) {
      //final state = ref.read(categoryPlaceholderProvider);

      switch (next) {
        case CategoryPlaceholderActionStatus.saved:
          Navigator.of(context).pop(true); // Zurück zur Detailseite
          break;

        default:
          break;
      }
    });

    // Listener, der die Controller nur bei Initialladung oder Generierung füllt
    ref.listen(categoryPlaceholderProvider, (previous, next) {
      if (previous == next) return;
      final value = next.categoryPlaceholder;
      if (_controller.text != value) _controller.text = value;
    });

    // Gezielte Watches für maximale Performance
    final isBusy = ref.watch(categoryPlaceholderProvider.select((s) => s.isBusy));

    // Notifier holen
    final notifier = ref.read(categoryPlaceholderProvider.notifier);

    return AlertDialog(
      title: const Text('Platzhalter für namenlose Kategorie'),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- Platzhalter für leere Kategorien ---
            Consumer(
              builder: (ctx, ref, _) {
                final errorText = ref.watch(categoryPlaceholderProvider.select((state) => state.error.field == 'categoryPlaceholder' ? state.error.text : null));
                return TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Kategorie ohne Namen',
                    prefixIcon: const Icon(Icons.label_outlined),
                    errorText: errorText,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: isBusy ? null : notifier.setCategoryPlaceholder,
                );
              },
            ),

            // --- Allgemeine Fehlermeldung (error.field == null) ---
            Consumer(builder: (context, ref, _) {
              final error = ref.watch(categoryPlaceholderProvider.select((s) => s.error));
              if (error.text.isEmpty || error.field != null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start, // Icon oben ausrichten bei Mehrzeilern
                  children: [
                    Icon(Icons.error, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(child: Text(error.text, softWrap: true, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                  ],
                ),
              );
            }),

          ],
        ),
      ),

      // --- Buttons ---
      actions: [
        TextButton(
          onPressed: isBusy ? null : _handleCancel,
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: isBusy ? null : notifier.save,
          child: isBusy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('OK'),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------------
  // --- Handler ---
  // ------------------------------------------------------------------------

  /// Speichert erst die Änderungen, wenn gewünscht und springt dann zurück.
  Future<void> _handleCancel() async {
    final state = ref.read(categoryPlaceholderProvider);
    if (state.isDirty) {
      final confirmed = await ConfirmDialog.show(
        context,
        title: 'Speichern',
        text: 'Möchtest du die Änderungen speichern?',
        ok: 'Ja, speichern',
        cancel: 'Nein, verwerfen',
      );

      if (!mounted) return;

      if (confirmed == true) {
        final notifier = ref.read(categoryPlaceholderProvider.notifier);
        notifier.save(); // Statt Cancel die Save-Action ausführen
        return;
      }
    }

    Navigator.of(context).pop(false); // Zur vorherigen Seite navigieren
  }
}