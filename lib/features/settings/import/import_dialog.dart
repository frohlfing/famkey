import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/features/settings/import/import_notifier.dart';
import 'package:privault/features/settings/import/import_state.dart';

/// Ein modaler Dialog zum Ändern des Master-Passworts.
class ImportDialog extends ConsumerStatefulWidget {

  /// Initiale Parameter
  // (keine)

  /// Konstruktor
  const ImportDialog({super.key});

  /// Statische Methode zum Anzeigen des Dialogs.
  /// Gibt [true] zurück, wenn gespeichert wurde, andernfalls [false] oder [null].
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // User muss explizit Speichern oder Abbrechen
      builder: (context) => ImportDialog(),
    );
  }

  @override
  ConsumerState<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<ImportDialog> {

  // ------------------------------------------------------------------------
  // --- TextEditingController ---
  // ------------------------------------------------------------------------

  final _formatController = TextEditingController();
  final _fileController = TextEditingController();

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert den Dialog und lädt die Daten, sobald der erste Frame gerendert wurde.
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Daten laden
      final notifier = ref.read(importProvider.notifier);
      await notifier.load();
    });
  }

  /// Gibt Ressourcen frei.
  @override
  void dispose() {
    _formatController.dispose();
    _fileController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(importProvider);

    // // Listener für Status-Änderungen
    // ref.listen(importProvider.select((s) => s.status), (previous, next) {
    //   switch (next) {
    //     case ImportActionStatus.parse:
    //       break;
    //      
    //     case ImportActionStatus.import:
    //       break;
    //
    //     default:
    //       break;
    //   }
    // });

    // Listener, der die Controller nur bei Initialladung oder Generierung füllt
    ref.listen(importProvider, (previous, next) {
      if (previous == next) return;
      final formData = next.formData;
      if (_formatController.text != formData.format.toString()) _formatController.text = formData.format.toString(); // todo vermutlich kein TextController für Auswahlliste erforderlich
      if (_fileController.text != formData.file) _fileController.text = formData.file;
    });

    // Gezielte Watches für maximale Performance
    final isBusy = ref.watch(importProvider.select((s) => s.isBusy));
    final status = ref.watch(importProvider.select((s) => s.status));

    // Notifier holen
    final notifier = ref.read(importProvider.notifier);

    return AlertDialog(
      title: const Text('Import'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0), // Abstand zum Bildschirmrand verringern
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- Format ---
            // todo hier Consumer für eine Auswahlliste "Format" hinzufügen (Auswahlmöglichkeit: "KeePass XML (2.x)", "Bitwarden JSON")
            //  nur anklickbar, wenn status == open
            const SizedBox(height: 16),

            // --- Datei ---
            // todo nur anklickbar, wenn status == open
            Consumer(
              builder: (ctx, ref, _) {
                final errorText = ref.watch(importProvider.select((state) => state.error.field == 'file' ? state.error.text : null));
                return TextField(
                  controller: _fileController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Importdatei',
                    prefixIcon: const Icon(Icons.person_outline),
                    errorText: errorText,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: isBusy ? null : notifier.setFile,
                );
                // todo Textfeld erweitern um einen File-Picker, mit dem der Benutzer eine Datei vom Dateisystem auswählen kann
              },
            ),

            if (status == ImportActionStatus.parse || status == ImportActionStatus.import) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text("Daten werden importiert..."),
            ],
            if (status == ImportActionStatus.success) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start, // Icon oben ausrichten bei Mehrzeilern
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Import erfolgreich abgeschlossen.\n\n✳️ Hinzugefügt: ${state.addedCount}\n',
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (status == ImportActionStatus.failure) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16),
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

          ],
        ),
      ),

      // --- Buttons ---
      // todo Buttons hinzufügen/ändern, um je nach Status den Import zu starten, nach einem Fehler fortzuführen (Fehlerhaften Eintrag überspringen) oder abzubrechen, und nach einblenden der Statistik zu beenden.

      actions: [
        TextButton(
          onPressed: isBusy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: isBusy ? null : notifier.import,
          child: isBusy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('OK'),
        ),
      ],
    );
  }
}