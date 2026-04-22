import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/renderer_factory.dart';
import 'package:privault/features/main/export/export_notifier.dart';
import 'package:privault/features/main/export/export_state.dart';
import 'package:privault/widgets/confirm_dialog.dart';

/// Ein modaler Dialog zum Exportieren des Tresors.
class ExportDialog extends ConsumerStatefulWidget {

  /// Konstruktor
  const ExportDialog({super.key});

  /// Statische Methode zum Anzeigen des Dialogs.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User muss explizit Speichern oder Abbrechen
      builder: (context) => const ExportDialog(),
    );
  }

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {

  final TextEditingController _passwordController = TextEditingController();

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

  /// Gibt Ressourcen frei.
  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {

    // Listener für Status-Änderungen
    ref.listen(exportProvider.select((s) => s.status), (previous, next) {
      if (next == ExportActionStatus.aborted) Navigator.of(context).pop(true);
    });

    // Passwort-Controller synchron halten
    ref.listen(exportProvider.select((s) => s.formData.password), (previous, next) {
      if (_passwordController.text != next) _passwordController.text = next;
    });

    // Gezielte Watches für maximale Performance
    final isBusy   = ref.watch(exportProvider.select((s) => s.isBusy));
    final status   = ref.watch(exportProvider.select((s) => s.status));
    final encrypt  = ref.watch(exportProvider.select((s) => s.formData.encrypt));
    final notifier = ref.read(exportProvider.notifier);

    return AlertDialog(
      title: const Text('Tresor exportieren'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- Fortschrittsanzeige ---
            if (status == ExportActionStatus.loading)
              Consumer(
                builder: (ctx, ref, _) {
                  final total     = ref.watch(exportProvider.select((s) => s.total));
                  final processed = ref.watch(exportProvider.select((s) => s.processed));
                  return Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        LinearProgressIndicator(value: total > 0 ? processed / total : 0),
                        const SizedBox(height: 16),
                        Text(
                          '$processed von $total Einträgen verarbeitet (${total > 0 ? (processed / total * 100).toStringAsFixed(0) : 0}%)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _handleAbortLoading,
                          icon: const Icon(Icons.stop),
                          label: const Text('Abbrechen'),
                        ),
                      ],
                    ),
                  );
                },
              ),

            // --- Vorschau & Formular ---
            if (status == ExportActionStatus.loaded || status == ExportActionStatus.progress) ...[
              Expanded(
                child: Stack(
                  children: [
                    // --- Vorschau ---
                    Consumer(
                      builder: (ctx, ref, _) {
                        final mdBytes  = ref.watch(exportProvider.select((s) => s.mdBytes));
                        final mime     = ref.watch(exportProvider.select((s) => s.mdFile.mime));
                        final renderer = createRenderer(mdBytes, mime);
                        return Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.black26),
                          ),
                          child: renderer.buildWidget(),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // --- ZIP verschlüsseln ---
              Row(
                children: [
                  Switch(
                    value: encrypt,
                    onChanged: isBusy ? null : notifier.setEncrypt,
                  ),
                  const SizedBox(width: 8),
                  const Text('Exportdatei verschlüsseln'),
                ],
              ),

              // --- Passwort (nur sichtbar wenn Verschlüsselung aktiv) ---
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: encrypt
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: TextField(
                          controller: _passwordController,
                          obscureText: true,
                          enabled: !isBusy,
                          decoration: const InputDecoration(
                            labelText: 'Passwort',
                            hintText: 'Passwort für die Exportdatei',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock_outline),
                            isDense: true,
                          ),
                          onChanged: notifier.setPassword,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],

            if (status == ExportActionStatus.success)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    Icon(Icons.check_outlined, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(child: Text('Die Exportdatei wurde erfolgreich gespeichert.')),
                  ],
                ),
              ),

            // --- Fehleranzeige ---
            if (status == ExportActionStatus.failure)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ref.read(exportProvider).error.text,
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

      // --- Buttons ---
      actions: [
        // Abbrechen - nicht während des Ladens und nicht nach erfolgreich Speichern
        if (status != ExportActionStatus.loading && status != ExportActionStatus.success)
          TextButton(
            onPressed: isBusy ? null : () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),

        // Drucken – nur wenn Vorschau geladen
        if (status == ExportActionStatus.loaded || status == ExportActionStatus.progress)
          TextButton(
            onPressed: isBusy ? null : notifier.print,
            child: const Text('Drucken'),
          ),

        // Exportieren – nur wenn Exportdatei generiert wurde
        if (status == ExportActionStatus.loaded || status == ExportActionStatus.progress)
          ElevatedButton(
            onPressed: isBusy ? null : _handleExport,
            child: const Text('Exportieren'),
          ),

        // Schließen - nachdem die Exportdatei erfolgreich gespeichert wurde
        if (status == ExportActionStatus.success)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Schließen'),
          ),
      ],
    );
  }

  // ------------------------------------------------------------------------
  // --- Handler ---
  // ------------------------------------------------------------------------

  /// Bricht nach einer Rückfrage den laufenden Vorgang ab.
  Future<void> _handleAbortLoading() async {
    final isLoading = ref.read(exportProvider).status == ExportActionStatus.loading;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Vorgang abbrechen',
      text: isLoading
        ? 'Möchtest du das Generieren der Vorschau wirklich abbrechen?'
        : 'Möchtest du den Export wirklich abbrechen?',
      cancel: 'Nein, fortfahren',
      ok: 'Ja, abbrechen',
      autofocus: false,
    );
    if (mounted && confirmed == true) {
      final notifier = ref.read(exportProvider.notifier);
      notifier.abortLoading();
    }
  }

  /// Startet nach einer Rückfrage den Export.
  Future<void> _handleExport() async {
    final state = ref.read(exportProvider);

    final text = state.formData.encrypt
      ? 'Der Tresor wird als ZIP‑Datei exportiert und mit AES‑256 verschlüsselt – dem derzeit\n'
        'sichersten Verfahren für ZIP‑Dateien. \n\n'
        '⚠️ Unter Windows ist zum Öffnen ein externes Zip-Tool wie z.B. 7-Zip (kostenlos) oder \n'
        'WinRAR notwendig. Der Windows-Explorer kann keine passwortgeschützten Archive öffnen. \n\n'
        'Fortfahren?'
      : 'Der Tresor wird als unverschlüsselte ZIP-Datei exportiert. '
        '⚠️ Alle Passwörter sind für jeden lesbar, der Zugriff auf die Datei erhält.\n\n'
        'Fortfahren?';

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Exportieren',
      text: text,
      ok: 'Ja, exportieren',
    );

    if (mounted && confirmed == true) {
      final notifier = ref.read(exportProvider.notifier);
      notifier.export();
    }
  }
}