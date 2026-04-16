import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_file.dart';
import 'package:privault/features/detail/preview/preview_notifier.dart';
import 'package:privault/features/detail/preview/preview_state.dart';
import 'package:privault/features/detail/preview/renderer_factory.dart';

/// Ein modaler Dialog zur Vorschau von Dateianhängen.
class PreviewDialog extends ConsumerStatefulWidget {

  /// Initiale Parameter
  final AppFile file;

  /// Konstruktor
  const PreviewDialog({super.key, required this.file});

  /// Statische Methode zum Anzeigen des Dialogs.
  static Future<void> show(BuildContext context, AppFile file) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User muss explizit Speichern oder Abbrechen
      builder: (context) => PreviewDialog(file: file),
    );
  }

  @override
  ConsumerState<PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends ConsumerState<PreviewDialog> {

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert den Dialog und lädt die Daten, sobald der erste Frame gerendert wurde.
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Daten laden
      final notifier = ref.read(previewProvider.notifier);
      await notifier.load(widget.file);
    });
  }

  // /// Gibt Ressourcen frei.
  // @override
  // void dispose() {
  //   super.dispose();
  // }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {

    // // Listener für Status-Änderungen
    // ref.listen(previewProvider.select((s) => s.status), (previous, next) {
    //   switch (next) {
    //     case PreviewActionStatus.saved:
    //       Navigator.of(context).pop(true); // Zurück zur Detailseite
    //       break;
    //
    //     default:
    //       break;
    //   }
    // });

    // // Listener, der die Controller nur bei Initialladung oder Generierung füllt
    // ref.listen(previewProvider, (previous, next) {
    //   if (previous == next) return;
    //   final formData = next.formData;
    //   if (_passwordController.text != formData.password) _passwordController.text = formData.password;
    // });

    // Gezielte Watches für maximale Performance
    final isBusy = ref.watch(previewProvider.select((s) => s.isBusy));

    // Notifier, State und Renderer holen
    final notifier = ref.read(previewProvider.notifier);
    final state = ref.watch(previewProvider);
    final renderer = createRenderer(state.bytes, state.file.mime);

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              state.file.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      //insetPadding: const EdgeInsets.all(16.0), // Abstand zum Bildschirmrand überall verringern
      //insetPadding: const EdgeInsets.symmetric(horizontal: 16.0), // Abstand zum Bildschirmrand links und rechts verringern
      insetPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0), // Abstand zum Bildschirmrand verringern
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        //width: 450,
        width: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // --- Fehleranzeige ---
            if (state.status == PreviewActionStatus.failure) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start, // Icon oben ausrichten bei Mehrzeilern
                  children: [
                    Icon(Icons.error, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.error.text,
                        softWrap: true,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // --- Vorschau-Inhalt ---
            Expanded(child: renderer.buildWidget()),

            const SizedBox(height: 16),
          ],
        ),
      ),

      // --- Buttons ---
      actions: [
        // Download
        TextButton.icon(
          onPressed: state.isBusy ? null : notifier.download,
          icon: state.status == PreviewActionStatus.progress
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download_outlined),
          label: const Text('Herunterladen'),
        ),

        // Drucken
        if (renderer.isPrintable)
          TextButton.icon(
            onPressed: state.isBusy ? null : notifier.print,
            icon: const Icon(Icons.print_outlined),
            label: const Text('Drucken'),
          ),

        // Schließen
        ElevatedButton(
          autofocus: true,
          onPressed: isBusy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Schließen'),
        ),
      ],
    );
  }
}