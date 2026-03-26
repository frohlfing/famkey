import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/features/settings/password_generator/password_generator_notifier.dart';
import 'package:privault/features/settings/password_generator/password_generator_state.dart';
import 'package:privault/widgets/confirm_dialog.dart';

/// Ein modaler Dialog zum Konfigurieren des Passwort-Generators.
class PasswordGeneratorDialog extends ConsumerStatefulWidget {

  /// Initiale Parameter
  // (keine)

  /// Konstruktor
  const PasswordGeneratorDialog({super.key});

  /// Statische Methode zum Anzeigen des Dialogs.
  /// Gibt [true] zurück, wenn gespeichert wurde, andernfalls [false] oder [null].
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // User muss explizit Speichern oder Abbrechen
      builder: (context) => PasswordGeneratorDialog(),
    );
  }

  @override
  ConsumerState<PasswordGeneratorDialog> createState() => _PasswordGeneratorDialogState();
}

class _PasswordGeneratorDialogState extends ConsumerState<PasswordGeneratorDialog> {

  // ------------------------------------------------------------------------
  // --- TextEditingController ---
  // ------------------------------------------------------------------------

  final _pwLengthController = TextEditingController();
  final _pwSpecialCharsController = TextEditingController();

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert den Dialog und lädt die Daten, sobald der erste Frame gerendert wurde.
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Daten laden
      final notifier = ref.read(passwordGeneratorProvider.notifier);
      await notifier.load();
    });
  }

  /// Gibt Ressourcen frei.
  @override
  void dispose() {
    _pwLengthController.dispose();
    _pwSpecialCharsController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {

    // Listener für Status-Änderungen
    ref.listen(passwordGeneratorProvider.select((s) => s.status), (previous, next) {
      //final state = ref.read(passwordGeneratorProvider);

      switch (next) {
        case PasswordGeneratorActionStatus.saved:
          Navigator.of(context).pop(true); // Zurück zur Detailseite
          break;

        default:
          break;
      }
    });

    // Listener, der die Controller nur bei Initialladung oder Generierung füllt
    ref.listen(passwordGeneratorProvider, (previous, next) {
      if (previous == next) return;
      final formData = next.formData;
      if (_pwLengthController.text != formData.pwLength.toString()) _pwLengthController.text = formData.pwLength.toString();
      if (_pwSpecialCharsController.text != formData.pwSpecialChars) _pwSpecialCharsController.text = formData.pwSpecialChars;
    });

    // Gezielte Watches für maximale Performance
    final isBusy = ref.watch(passwordGeneratorProvider.select((s) => s.isBusy));

    // Notifier holen
    final notifier = ref.read(passwordGeneratorProvider.notifier);

    return AlertDialog(
      title: const Text('Passwort-Generator'),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- Länge ---
            Consumer(
              builder: (ctx, ref, _) {
                final errorText = ref.watch(passwordGeneratorProvider.select((state) => state.error.field == 'pwLength' ? state.error.text : null));
                return TextField(
                  controller: _pwLengthController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Länge',
                    prefixIcon: const Icon(Icons.onetwothree_outlined),
                    errorText: errorText,
                    border: const OutlineInputBorder(),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: isBusy ? null : notifier.decrementLength,
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: isBusy ? null : notifier.incrementLength,
                        ),
                      ],
                    ),
                  ),
                  onChanged: isBusy ? null : (val) => notifier.setPwLength(int.tryParse(val) ?? 0),
                );
              },
            ),

            const SizedBox(height: 16),

            // --- Sonderzeichen ---
            Consumer(
              builder: (ctx, ref, _) {
                final errorText = ref.watch(passwordGeneratorProvider.select((state) => state.error.field == 'pwSpecialChars' ? state.error.text : null));
                return TextField(
                  controller: _pwSpecialCharsController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Sonderzeichen',
                    prefixIcon: const Icon(Icons.emoji_symbols_outlined),
                    errorText: errorText,
                    border: const OutlineInputBorder(),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.star),
                          tooltip: 'Standard',
                          onPressed: isBusy ? null : notifier.setDefaultPwSpecialChars,
                        ),
                        IconButton(
                          icon: const Icon(Icons.all_inclusive),
                          tooltip: 'Alle',
                          onPressed: isBusy ? null : notifier.setAllPwSpecialChars,
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle),
                          tooltip: 'Keine',
                          onPressed: isBusy ? null : notifier.setNonePwSpecialChars,
                        ),
                      ],
                    ),
                  ),
                  onChanged: isBusy ? null : notifier.setPwSpecialChars,
                );
              },
            ),

            const SizedBox(height: 16),

            // --- Lesbarkeit optimieren ---
            Consumer(
              builder: (ctx, ref, _) {
                final value = ref.watch(passwordGeneratorProvider.select((state) => state.formData.pwAvoidIlO0));
                return SwitchListTile(
                  title: const Text('Lesbarkeit optimieren'),
                  subtitle: const Text('Ähnliche Zeichen (I, l, O, 0) ausschließen'),
                  contentPadding: EdgeInsets.zero,
                  value: value,
                  onChanged: isBusy ? null : notifier.setPwAvoidIlO0,
                );
              },
            ),

            // --- Allgemeine Fehlermeldung (error.field == null) ---
            Consumer(builder: (context, ref, _) {
              final error = ref.watch(passwordGeneratorProvider.select((s) => s.error));
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
    final state = ref.read(passwordGeneratorProvider);
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
        final notifier = ref.read(passwordGeneratorProvider.notifier);
        notifier.save(); // Statt Cancel die Save-Action ausführen
        return;
      }
    }

    Navigator.of(context).pop(false); // Zur vorherigen Seite navigieren
  }
}