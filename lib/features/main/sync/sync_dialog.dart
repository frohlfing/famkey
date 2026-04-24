import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/features/main/sync/adopt_identity/adopt_identity_dialog.dart';
import 'package:privault/features/main/sync/sync_notifier.dart';
import 'package:privault/features/main/sync/sync_state.dart';

/// Ein modaler Dialog zum Synchronisieren des Tresors.
class SyncDialog extends ConsumerStatefulWidget {

  /// Initiale Parameter
  // (keine)

  /// Konstruktor
  const SyncDialog({super.key});

  /// Statische Methode zum Anzeigen des Dialogs.
  /// Gibt [true] bei Erfolg zurück, andernfalls [false] oder [null].
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // User muss explizit Speichern oder Abbrechen
      builder: (context) => const SyncDialog(),
    );
  }

  @override
  ConsumerState<SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends ConsumerState<SyncDialog> {

  // ------------------------------------------------------------------------
  // --- TextEditingController ---
  // ------------------------------------------------------------------------

  //final _controller = TextEditingController();

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert den Dialog und lädt die Daten, sobald der erste Frame gerendert wurde.
  @override
  void initState() {
    super.initState();

    // Sobald der Dialog erscheint, triggern wir den Sync-Prozess
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(syncProvider.notifier);
      notifier.sync();
    });
  }

  // /// Gibt Ressourcen frei.
  // @override
  // void dispose() {
  //   //_controller.dispose();
  //   super.dispose();
  // }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {

    // Listener für Status-Änderungen
    ref.listen(syncProvider.select((s) => s.status), (previous, next) {
      if (next == SyncStatus.askForAdoption) _showAdoptIdentityDialog();
    });

    // Gezielte Watches für maximale Performance
    // Hier kann der komplette State beobachtet werde. Wenn sich irgendwas ändert, muss der gesamte Dialog neu gezeichnet werden.
    final state = ref.watch(syncProvider);

    return AlertDialog(
      title: const Text('Synchronisation'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            if (state.status == SyncStatus.progress) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Daten werden abgeglichen...'),
            ],

            if (state.status == SyncStatus.success)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Synchronisation erfolgreich abgeschlossen.\n\n${state.syncStatistics}',
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
              ),

            if (state.status == SyncStatus.failure || state.status == SyncStatus.askForRekeying)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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

      // --- Button ---
      actions: [
        if (state.status != SyncStatus.progress)
          ElevatedButton(
            autofocus: true,
            onPressed: state.isBusy ? null : () => Navigator.of(context).pop(state.status == SyncStatus.success),
            child: const Text('OK'),
          ),
      ],
    );
  }

  /// Adoptiert die auf dem Server gespeicherte Identität
  Future<void> _showAdoptIdentityDialog() async {
    final state = ref.read(syncProvider);
    final ok = await AdoptIdentityDialog.show(context, state.adoptionUserIdentity);
    if (mounted && ok == true) {
      final notifier = ref.read(syncProvider.notifier);
      notifier.sync(); // Sync-Prozess erneut ausführen
    }
  }
}