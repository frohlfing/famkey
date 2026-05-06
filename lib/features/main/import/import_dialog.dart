import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famkey/core/app_file.dart';
import 'package:famkey/widgets/confirm_dialog.dart';
import 'package:famkey/widgets/password_field.dart';
import 'import_form_data.dart';
import 'import_notifier.dart';
import 'import_state.dart';

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
      builder: (_) => const ImportDialog(),
    );
  }

  @override
  ConsumerState<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<ImportDialog> {

  // ------------------------------------------------------------------------
  // --- Interne Variablen ---
  // ------------------------------------------------------------------------

  /// Lokaler Guard, um mehrfaches Öffnen des Pickers zu verhindern
  var _isPickingFile = false;

  // ------------------------------------------------------------------------
  // --- TextEditingController ---
  // ------------------------------------------------------------------------

  final _pathController = TextEditingController();
  final _passwordController = TextEditingController();

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
    _pathController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {

    // Listener, der den Pfad-Controller bei Dateiauswahl aktualisiert
    ref.listen(importProvider.select((s) => s.formData.file), (previous, next) {
      if (_pathController.text != next.path) _pathController.text = next.path;
    });

    // Gezielte Watches für maximale Performance
    final isBusy = ref.watch(importProvider.select((s) => s.isBusy));
    final status = ref.watch(importProvider.select((s) => s.status));

    // Notifier holen
    final notifier = ref.read(importProvider.notifier);

    return AlertDialog(
      title: const Text('Import'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // --- Formular ----
              if (status == ImportActionStatus.initial || status == ImportActionStatus.failure) ...[
                const Text('Wähle das Format und die Datei aus, die du importieren möchtest.'),
                const SizedBox(height: 24),

                // --- Format-Auswahl ---
                Consumer(
                  builder: (ctx, ref, _) {
                    final errorText = ref.watch(importProvider.select((state) => state.error.field == 'format' ? state.error.text : null));
                    final format = ref.watch(importProvider.select((s) => s.formData.format));
                    return DropdownButtonFormField<ImportFileFormat>(
                      initialValue: format == ImportFileFormat.none ? null : format,
                      decoration: InputDecoration(
                        labelText: 'Dateiformat',
                        errorText: errorText,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      hint: const Text('Format wählen'),
                      items: const [
                        DropdownMenuItem(value: ImportFileFormat.FamKeyZip, child: Text('FamKey ZIP')),
                        DropdownMenuItem(value: ImportFileFormat.bitwardenJson, child: Text('Bitwarden JSON')),
                        DropdownMenuItem(value: ImportFileFormat.keepassXml, child: Text('KeePass XML (2.x)')),
                        DropdownMenuItem(value: ImportFileFormat.onePassword1Pux, child: Text('1Password 1PUX')),
                      ],
                      onChanged: isBusy ? null : (val) => notifier.setFormat(val ?? ImportFileFormat.none),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // --- Dateiauswahl ---
                Consumer(
                  builder: (ctx, ref, _) {
                    final errorText = ref.watch(importProvider.select((state) => state.error.field == 'path' ? state.error.text : null));
                    return TextField(
                      controller: _pathController,
                      readOnly: true,
                      onTap: isBusy ? null : _pickFile,
                      decoration: InputDecoration(
                        labelText: 'Importdatei',
                        errorText: errorText,
                        prefixIcon: const Icon(Icons.file_open_outlined),
                        suffixIcon: _isPickingFile ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        ) : IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: isBusy ? null : _pickFile,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    );
                  },
                ),

                // --- Verschlüsselung & Passwort Sektion ---
                Consumer(
                  builder: (ctx, ref, _) {
                    final format = ref.watch(importProvider.select((s) => s.formData.format));
                    final fileSelected = ref.watch(importProvider.select((s) => s.formData.file != const AppFile.none()));

                    // Wenn das Format keine Passwörter unterstützt oder keine Datei gewählt ist, zeigen wir nichts
                    if (!format.supportsPassword || !fileSelected) return const SizedBox.shrink();

                    final encrypt = ref.watch(importProvider.select((s) => s.formData.encrypt));

                    return Column(
                      children: [
                        const SizedBox(height: 8),
                        SwitchListTile(
                          value: encrypt,
                          onChanged: isBusy ? null : notifier.setEncrypt,
                          title: const Text('Die Datei ist verschlüsselt'),
                          contentPadding: EdgeInsets.zero,
                        ),

                        // Passwort-Feld einblenden, wenn Verschlüsselung aktiv ist
                        if (encrypt) ...[
                          const SizedBox(height: 8),
                          Consumer(
                            builder: (ctx, ref, _) {
                              final errorText = ref.watch(importProvider.select((state) => state.error.field == 'password' ? state.error.text : null));
                              return PasswordField(
                                controller: _passwordController,
                                label: 'Passwort',
                                prefixIcon: Icons.lock_outline,
                                errorText: errorText,
                                onChanged: notifier.setPassword,
                              );
                            },
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],

              // --- Fortschrittsanzeige ---
              if (status == ImportActionStatus.progress)
                Consumer(
                  builder: (ctx, ref, _) {
                    final total   = ref.watch(importProvider.select((s) => s.total));
                    final currentCount = ref.watch(importProvider.select((s) => s.currentCount));
                    final isAborting   = ref.watch(importProvider.select((s) => s.isAborting));

                    if (total == 0) {
                      return const Center(
                        child: Column(
                          children: [
                            SizedBox(height: 24),
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Importdatei wird eingelesen...'),
                          ],
                        ),
                      );
                    }

                    return Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 24),
                          LinearProgressIndicator(value: currentCount / total),
                          const SizedBox(height: 16),
                          Text(
                            '$currentCount von $total Einträgen verarbeitet (${(currentCount / total * 100).toStringAsFixed(0)}%)',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: isAborting ? null : _handleAbortImport,
                            icon: const Icon(Icons.stop),
                            label: const Text('Abbrechen'),
                          ),
                        ],
                      ),
                    );
                  },
                ),

              // --- Erfolgsmeldung ---
              if (status == ImportActionStatus.success)
                Consumer(
                  builder: (ctx, ref, _) {
                    final added = ref.watch(importProvider.select((s) => s.added));
                    final skipped = ref.watch(importProvider.select((s) => s.skipped));
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_outlined, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Import abgeschlossen!',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text('✳️ Hinzugefügt: $added ${added == 1 ? 'Eintrag' : 'Einträge'}'),
                                if (skipped > 0)
                                  Text('⚠️ Übersprungen: $skipped ${skipped == 1 ? 'Duplikat' : 'Duplikate'}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

              // --- Fehleranzeige ---
              Consumer(
                builder: (context, ref, _) {
                  final error = ref.watch(importProvider.select((s) => s.error));
                  if (error.text.isEmpty || error.field != null) return const SizedBox.shrink();
                  return  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error, color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            error.text,
                            softWrap: true,
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

            ],
          ),
        ),
      ),

      // --- Buttons ---
      actions: [
        if (status == ImportActionStatus.initial || status == ImportActionStatus.failure)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),

        if (status == ImportActionStatus.initial)
          ElevatedButton(
            autofocus: true,
            onPressed: notifier.import,
            child: const Text('Importieren'),
          ),

        if (status == ImportActionStatus.success)
          ElevatedButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('OK'),
          ),
      ],
    );
  }

  // ------------------------------------------------------------------------
  // --- Handler ---
  // ------------------------------------------------------------------------

  /// Öffnet den File-Picker zur Auswahl der Importdatei.
  Future<void> _pickFile() async {
    if (_isPickingFile) return;
    setState(() => _isPickingFile = true); // Mit setState wird erst die anonymen Funktion aufgerufen, danach wird das Widget als "dirty" markiert (wodurch im nächsten Frame die build-Methode neu rendert)
    try {
      // Datei auswählen
      final state = ref.read(importProvider);
      final picker = AppFilePicker();
      final files = await picker.pickFiles(
        allowedExtensions: state.formData.format.allowedExtensions,
      );
      if (!mounted || files.isEmpty) return;
      final file = files.first;

      // Datei an den TextController und an den Notifier übergeben
      //_pathController.text = file.name;   // Nur Dateiname anzeigen, nicht Pfad
      _pathController.text = file.path;
      final notifier = ref.read(importProvider.notifier);
      notifier.setFile(file);
    }
    finally {
      if (mounted) setState(() => _isPickingFile = false);
    }
  }

  /// Bricht nach einer Nachfrage den Import ab.
  Future<void> _handleAbortImport() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Import abbrechen',
      text: 'Möchtest du den Import wirklich abbrechen?',
      cancel: 'Nein, fortfahren',
      ok: 'Ja, abbrechen',
      autofocus: false,
    );
    if (mounted && confirmed == true) {
      final notifier = ref.read(importProvider.notifier);
      notifier.abortImport();
    }
  }

}
