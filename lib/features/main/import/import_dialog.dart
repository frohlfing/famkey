import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_file.dart';
import 'package:privault/core/app_file_factory.dart';
import 'package:privault/widgets/confirm_dialog.dart';
import 'package:privault/widgets/password_field.dart';
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
      final file = next.formData.file;
      if (_pathController.text != file.path) _pathController.text = file.path;
      // todo Passwort seten?
    });

    // Gezielte Watches für maximale Performance
    final isBusy = ref.watch(importProvider.select((s) => s.isBusy));
    final status = ref.watch(importProvider.select((s) => s.status));
    final formData = ref.watch(importProvider.select((s) => s.formData));
    final fileSelected = ref.watch(importProvider.select((s) => s.formData.file)) != const AppFile.none();

    // Notifier holen
    final notifier = ref.read(importProvider.notifier);

    return AlertDialog(
      title: const Text('Import'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0), // Abstand zum Bildschirmrand verringern
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // scrollen funktioniert auch, wenn Inhalte anfangs passen
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // --- Formular ----
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
                    DropdownMenuItem(value: ImportFileFormat.privaultZip, child: Text('PriVault ZIP')),
                    DropdownMenuItem(value: ImportFileFormat.bitwardenJson, child: Text('Bitwarden JSON')),
                    DropdownMenuItem(value: ImportFileFormat.keepassXml, child: Text('KeePass XML (2.x)'), ),
                    DropdownMenuItem(value: ImportFileFormat.onePassword1Pux, child: Text('1Password 1PUX'), ),
                  ],
                  onChanged: isBusy ? null : (val) => notifier.setFormat(val ?? ImportFileFormat.none),
                ),

                const SizedBox(height: 16),

                // --- Dateiauswahl ---
                const Text('Importdatei', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _pathController,
                  readOnly: true,
                  onTap: isBusy ? null : _pickFile,
                  decoration: InputDecoration(
                    hintText: 'Datei auswählen',
                    errorText: state.error.field == 'path' ? state.error.text : null,
                    prefixIcon: const Icon(Icons.file_open_outlined),
                    suffixIcon: _isPickingFile ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    ) : IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: isBusy ? null : _pickFile
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),

                // --- Verschlüsselung Switch ---
                // Wird nur angezeigt, wenn das Format Passwörter unterstützt
                // und eine Datei ausgewählt wurde.
                if (formData.format.supportsPassword && fileSelected) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: formData.encrypt,
                    onChanged: isBusy ? null : notifier.setEncrypt,
                    title: const Text('Die Datei ist verschlüsselt'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],

                // --- Passwort-Feld ---
                // Wird nur angezeigt, wenn der Switch aktiviert ist.
                if (formData.format.supportsPassword && fileSelected && formData.encrypt) ...[
                  const SizedBox(height: 8),
                  PasswordField(
                    controller: _passwordController,
                    label: 'Passwort',
                    prefixIcon: Icons.lock_outline,
                    errorText: state.error.field == 'password' ? state.error.text : null,
                    onChanged: notifier.setPassword,
                  ),
                ],
              ],

              // --- Fortschrittsanzeige ---
              if (status == ImportActionStatus.progress && state.totalCount == 0)
                const Center(
                  child: Column(
                    children: [
                      SizedBox(height: 24),
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Importdatei wird eingelesen...'),
                    ],
                  ),
                ),

              if (status == ImportActionStatus.progress && state.totalCount > 0)
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),

                      // Fortschrittsanzeige
                      LinearProgressIndicator(value: state.currentCount / state.totalCount),
                      const SizedBox(height: 16),
                      Text(
                        "${state.currentCount} von ${state.totalCount} Einträgen verarbeitet (${(state.currentCount / state.totalCount * 100).toStringAsFixed(0)}%)",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),

                      // Abbrechen-Button
                      ElevatedButton.icon(
                        onPressed: state.isAborting ? null : _handleAbortImport,
                        icon: const Icon(Icons.stop),
                        label: const Text('Abbrechen'),
                      ),
                    ],
                  ),
                ),

              // --- Erfolgsmeldung ---
              if (status == ImportActionStatus.success)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start, // Icon oben ausrichten bei Mehrzeilern
                    children: [
                      const Icon(Icons.check_outlined, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Import abgeschlossen!'),
                            const SizedBox(height: 8),
                            Text('✳️ Hinzugefügt: ${state.addedCount} ${state.addedCount == 1 ? 'Eintrag' : 'Einträge'}'),
                            if (state.skippedCount > 0)
                              Text('⚠️ Übersprungen: ${state.skippedCount} ${state.skippedCount == 1 ? 'Duplikat' : 'Duplikate'}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // --- Fehleranzeige ---
              if (status == ImportActionStatus.failure && state.error.field == null)
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
      final picker = createAppFilePicker();
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
