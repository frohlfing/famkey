import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famkey/core/app_file.dart';
import 'package:famkey/features/detail/preview/preview_notifier.dart';
import 'package:famkey/features/detail/preview/preview_state.dart';
import 'package:famkey/core/renderer_factory.dart';

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

    // Gezielte Watches für maximale Performance
    // Hier kann der komplette State beobachtet werde. Wenn sich irgendwas ändert, muss der gesamte Dialog neu gezeichnet werden.
    final state = ref.watch(previewProvider);
    final renderer = createRenderer(state.bytes, state.file.mime);

    // Notifier holen
    final notifier = ref.read(previewProvider.notifier);

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
      insetPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      content: SizedBox(
        width: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  // --- Vorschau ---
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black26),
                    ),
                    child: Theme(
                      data: ThemeData.light(),
                      child: Material(
                        color: Colors.transparent,
                        child: renderer.buildWidget(),
                      ),
                    ),
                  ),

                  // --- Ladeanzeige ---
                  if (state.status == PreviewActionStatus.progress)
                    Container(
                      color: Colors.white.withValues(alpha: 0.3),
                      child: const Center(child: CircularProgressIndicator()),
                    ),

                  // --- Fehleranzeige ---
                  if (state.status == PreviewActionStatus.failure)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error, color: Theme.of(context).colorScheme.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ref.read(previewProvider).error.text,
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
          ],

        ),
      ),

      // --- Buttons ---
      actions: [
        // Download
        TextButton(
          onPressed: state.isBusy ? null : notifier.download,
          child: const Text('Speichern'),
        ),

        // Drucken
        if (renderer.isPrintable)
          TextButton(
            onPressed: state.isBusy ? null : notifier.print,
            child: const Text('Drucken'),
          ),

        // Schließen
        ElevatedButton(
          autofocus: true,
          onPressed: state.isBusy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Schließen'),
        ),
      ],
    );
  }
}