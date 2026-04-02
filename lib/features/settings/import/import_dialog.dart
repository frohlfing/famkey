import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/features/settings/import/import_form_data.dart';
import 'package:privault/features/settings/import/import_notifier.dart';
import 'package:privault/features/settings/import/import_state.dart';

/// Ein modaler Dialog zum Importieren von Daten aus anderen Passwort-Managern.
class ImportDialog extends ConsumerStatefulWidget {

  /// Initiale Parameter
  // (keine)

  /// Konstruktor
  const ImportDialog({super.key});

  /// Statische Methode zum Anzeigen des Dialogs.
  /// Gibt [true] zurück, wenn der Import erfolgreich war, andernfalls [false].
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // User muss explizit Speichern oder Abbrechen
      builder: (context) => const ImportDialog(),
    );
  }

  @override
  ConsumerState<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<ImportDialog> {

  // ------------------------------------------------------------------------
  // --- TextEditingController ---
  // ------------------------------------------------------------------------

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
    _fileController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------------
  // --- Handler ---
  // ------------------------------------------------------------------------

  /// Öffnet den File-Picker zur Auswahl der Importdatei.
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any, // Später evtl. einschränken je nach Format
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      _fileController.text = path;
      ref.read(importProvider.notifier).setFile(path);
    }
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
      if (_fileController.text != formData.file) _fileController.text = formData.file;
    });

    // Gezielte Watches für maximale Performance
    final isBusy = ref.watch(importProvider.select((s) => s.isBusy));
    final status = ref.watch(importProvider.select((s) => s.status));
    //final status = state.status;
    //final isBusy = state.isBusy;

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

            if (status == ImportActionStatus.initial || status == ImportActionStatus.failure) ...[
              const Text('Wähle das Format und die Datei aus, die du importieren möchtest.'),
              const SizedBox(height: 24),

              // --- Format-Auswahl ---
              const Text('Dateiformat', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<ImportFileFormat>(
                initialValue: state.formData.format == ImportFileFormat.none ? null : state.formData.format,
                decoration: InputDecoration(
                  errorText: state.error.field == 'format' ? state.error.text : null,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                hint: const Text('Format wählen'),
                items: const [
                  DropdownMenuItem(value: ImportFileFormat.keepassXml, child: Text('KeePass XML (2.x)')),
                  DropdownMenuItem(value: ImportFileFormat.bitwardenJson, child: Text('Bitwarden JSON')),
                ],
                onChanged: isBusy ? null : (val) => notifier.setFormat(val ?? ImportFileFormat.none),
              ),

              const SizedBox(height: 16),

              // --- Dateiauswahl ---
              const Text('Importdatei', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _fileController,
                readOnly: true,
                onTap: isBusy ? null : _pickFile,
                decoration: InputDecoration(
                  hintText: 'Datei auswählen...',
                  errorText: state.error.field == 'file' ? state.error.text : null,
                  prefixIcon: const Icon(Icons.file_open_outlined),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: isBusy ? null : _pickFile,
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],

            // --- Status-Anzeigen ---
            if (status == ImportActionStatus.parse || status == ImportActionStatus.import) ...[
            //if (isBusy) ...[
              const Center(
                child: Column(
                  children: [
                    SizedBox(height: 24),
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Import wird verarbeitet...'),
                  ],
                ),
              ),
            ],

            if (status == ImportActionStatus.success) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start, // Icon oben ausrichten bei Mehrzeilern
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Import erfolgreich abgeschlossen!\n\n${state.statistics}'),
                        ],
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

      actions: _buildActions(context, state, notifier),

    );
  }

  /// Erstellt die Aktion-Buttons je nach Status.
  List<Widget> _buildActions(BuildContext context, ImportState state, ImportNotifier notifier) {
    if (state.isBusy) return [];

    if (state.status == ImportActionStatus.success) {
      return [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Schließen'),
        ),
      ];
    }

    if (state.status == ImportActionStatus.failure) {
      // todo Nachfrage "Überspringen" bei Konflikten (nicht Parser-Fehler)
      // Für jetzt erst mal nur Schließen/Wiederholen
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: notifier.import,
          child: const Text('Wiederholen'),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Abbrechen'),
      ),
      ElevatedButton(
        onPressed: notifier.import,
        child: const Text('Importieren'),
      ),
    ];
  }
}
