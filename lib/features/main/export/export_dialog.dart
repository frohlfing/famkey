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
    // Schließt den Dialog automatisch nach erfolgreichem Export.
    ref.listen(exportProvider.select((s) => s.status), (previous, next) {
      switch (next) {
        case ExportActionStatus.success:
          Navigator.of(context).pop(true); // Zurück zur Hauptseite
          break;

        default:
          break;
      }
    });

    // Passwort-Controller synchron halten
    ref.listen(exportProvider, (previous, next) {
      if (previous == next) return;
      final formData = next.formData;
      if (_passwordController.text != formData.password) _passwordController.text = formData.password;
    });

    // Gezielte Watches für maximale Performance
    final isBusy = ref.watch(exportProvider.select((s) => s.isBusy));

    // Notifier, State und Renderer holen
    final notifier = ref.read(exportProvider.notifier);
    final state = ref.watch(exportProvider);
    final renderer = createRenderer(state.mdBytes, state.mdFile.mime);
    final encrypt = state.formData.encrypt;

    return AlertDialog(
      title: const Row(
        children: [
          Expanded(
            child: Text('Tresor exportieren', overflow: TextOverflow.ellipsis),
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

            // --- Vorschau ---
            Expanded(
              child: Stack(
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

                  // --- Fehleranzeige ---
                  if (state.status == ExportActionStatus.failure)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                    //Container(
                    //  color: Colors.white.withValues(alpha: 0.85),
                    //  padding: const EdgeInsets.all(16),
                    //  child: Center(
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

            // --- Fortschrittsanzeige (Laden & Exportieren) ---
            if (state.isBusy) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: state.totalCount > 0
                    ? state.currentCount / state.totalCount
                    : null,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _buildProgressText(state),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // --- ZIP verschlüsseln ---
            Row(
              children: [
                Switch(
                  value: encrypt,
                  onChanged: isBusy ? null : notifier.setEncrypt,
                ),
                const SizedBox(width: 8),
                const Text('ZIP-Archiv verschlüsseln'),
              ],
            ),

            // --- Hinweis zur AES-256-Verschlüsselung ---
            if (encrypt)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Theme.of(context).colorScheme.secondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Verwendet AES-256. Zum Öffnen wird 7-Zip (kostenlos, empfohlen) '
                        'oder WinRAR benötigt – Windows Explorer unterstützt AES-256-ZIP nicht.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
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
                          hintText: 'Passwort für das ZIP-Archiv',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock_outline),
                          isDense: true,
                        ),
                        onChanged: notifier.setPassword,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),

      // --- Buttons ---
      actions: [

        // Abbrechen
        TextButton(
          onPressed: state.isAborting ? null : (state.isBusy ? _handleCancelOperation : () => Navigator.of(context).pop()),
          child: const Text('Abbrechen'),
        ),

        // Drucken – nur wenn Vorschau geladen
        if (renderer.isPrintable)
          TextButton(
            onPressed: isBusy ? null : notifier.print,
            child: const Text('Drucken'),
          ),

        // Exportieren – nur wenn Vorschau geladen
        ElevatedButton(
          onPressed: isBusy ? null : _handleExport,
          child: const Text('Exportieren'),
        ),

      ],
    );
  }

  // ------------------------------------------------------------------------
  // --- Hilfsmethoden ---
  // ------------------------------------------------------------------------}

  /// Fortschrittstext je nach Phase und Fortschritt.
  String _buildProgressText(ExportState state) {
    final total   = state.totalCount;
    final current = state.currentCount;
    final pct     = total > 0 ? ' (${(current / total * 100).toStringAsFixed(0)} %)' : '';
    final counts  = total > 0 ? ' – $current von $total Einträgen$pct' : '';

    return state.status == ExportActionStatus.loading
      ? 'Vorschau wird generiert...$counts'
      : 'Exportdatei wird erstellt...$counts';
  }

  // ------------------------------------------------------------------------
  // --- Handler ---
  // ------------------------------------------------------------------------

  /// Bricht nach einer Rückfrage den laufenden Vorgang ab.
  Future<void> _handleCancelOperation() async {
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
      notifier.cancelOperation();
    }
  }

  /// Startet nach einer Rückfrage den Export.
  Future<void> _handleExport() async {
    final state = ref.read(exportProvider);

    final text = state.formData.encrypt
      ? 'Das Archiv wird mit AES-256 verschlüsselt – dem derzeit sichersten ZIP-Verfahren.\n\n'
        '✅ Als kryptographisch sicher anerkannt.\n\n'
        '⚠️ Zum Öffnen wird 7-Zip (kostenlos, empfohlen) oder WinRAR benötigt. '
        'Windows Explorer und viele andere ZIP-Programme unterstützen AES-256-ZIP nicht.\n\n'
        'Fortfahren?'
      : 'Der Tresor wird als unverschlüsselte ZIP-Datei exportiert. '
        '⚠️ Alle Passwörter sind für jeden lesbar, der die Datei erhält.\n\n'
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