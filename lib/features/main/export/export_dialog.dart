import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/features/main/export/export_notifier.dart';
import 'package:privault/features/main/export/export_state.dart';
import 'package:privault/features/detail/preview/renderer_factory.dart';

/// Ein modaler Dialog zum Exportieren des Tresors
class ExportDialog extends ConsumerStatefulWidget {

  /// Konstruktor
  const ExportDialog({super.key});

  /// Statische Methode zum Anzeigen des Dialogs.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User muss explizit Speichern oder Abbrechen
      builder: (context) => ExportDialog(),
    );
  }

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert den Dialog und lädt die Daten, sobald der erste Frame gerendert wurde.
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Daten laden
      final notifier = ref.read(exportProvider.notifier);
      await notifier.load();
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
    // ref.listen(exportProvider.select((s) => s.status), (previous, next) {
    //   switch (next) {
    //     case ExportActionStatus.saved:
    //       Navigator.of(context).pop(true); // Zurück zur Detailseite
    //       break;
    //
    //     default:
    //       break;
    //   }
    // });

    // // Listener, der die Controller nur bei Initialladung oder Generierung füllt
    // ref.listen(exportProvider, (previous, next) {
    //   if (previous == next) return;
    //   final formData = next.formData;
    //   if (_passwordController.text != formData.password) _passwordController.text = formData.password;
    // });

    // Gezielte Watches für maximale Performance
    final isBusy = ref.watch(exportProvider.select((s) => s.isBusy));

    // Notifier, State und Renderer holen
    final notifier = ref.read(exportProvider.notifier);
    final state = ref.watch(exportProvider);
    final renderer = createRenderer(state.mdBytes, state.mdFile.mime);

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              state.mdFile.name,
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
            Expanded(
              child:Stack(
                children: [
                  // --- Vorschau ---
                  Container(
                    width: double.infinity, // Stack ausfüllen
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black26),
                    ),
                    child: renderer.buildWidget(),
                  ),

                  // --- Ladeanzeige ---
                  if (state.status == ExportActionStatus.progress)
                    Container(
                      color: Colors.white.withValues(alpha: 0.3), // Hintergrund leicht abdunkeln
                      child: const Center(child: CircularProgressIndicator()),
                    ),

                  // --- Fehleranzeige ---
                  if (state.status == ExportActionStatus.failure)
                    Center(
                      child: Padding(
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
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),

      // --- Buttons ---
      actions: [

        // Schließen
        ElevatedButton(
          autofocus: true,
          onPressed: isBusy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),

        // Drucken
        if (renderer.isPrintable)
          TextButton.icon(
            onPressed: state.isBusy ? null : notifier.print,
            icon: const Icon(Icons.print_outlined),
            label: const Text('Drucken'),
          ),

        // Exportieren
        ElevatedButton.icon(
          onPressed: state.isBusy ? null : notifier.export,
          icon: const Icon(Icons.download_outlined),
          label: const Text('Exportieren'),
        ),

      ],
    );
  }
}