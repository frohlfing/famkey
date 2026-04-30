import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famkey/features/settings/sync_server/sync_server_notifier.dart';
import 'package:famkey/features/settings/sync_server/sync_server_state.dart';
import 'package:famkey/widgets/confirm_dialog.dart';
import 'package:famkey/widgets/password_field.dart';

/// Ein modaler Dialog zum Konfigurieren des Sync-Servers.
class SyncServerDialog extends ConsumerStatefulWidget {

  /// Initiale Parameter
  // (keine)

  /// Konstruktor
  const SyncServerDialog({super.key});

  /// Statische Methode zum Anzeigen des Dialogs.
  /// Gibt [true] zurück, wenn gespeichert wurde, andernfalls [false] oder [null].
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // User muss explizit Speichern oder Abbrechen
      builder: (_) => const SyncServerDialog(),
    );
  }

  @override
  ConsumerState<SyncServerDialog> createState() => _SyncServerDialogState();
}

class _SyncServerDialogState extends ConsumerState<SyncServerDialog> {

  // ------------------------------------------------------------------------
  // --- TextEditingController ---
  // ------------------------------------------------------------------------

  final _hostController = TextEditingController();
  final _apiTokenController = TextEditingController();

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert den Dialog und lädt die Daten, sobald der erste Frame gerendert wurde.
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Daten laden
      final notifier = ref.read(syncServerProvider.notifier);
      await notifier.load();
    });
  }

  /// Gibt Ressourcen frei.
  @override
  void dispose() {
    _hostController.dispose();
    _apiTokenController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {

    // Listener für Status-Änderungen
    ref.listen(syncServerProvider.select((s) => s.status), (previous, next) {
      //final state = ref.read(syncServerProvider);

      switch (next) {
        case SyncServerActionStatus.saved:
          Navigator.of(context).pop(true); // Zurück zur Detailseite
          break;

        default:
          break;
      }
    });

    // Listener, der die Controller nur bei Initialladung oder Generierung füllt
    ref.listen(syncServerProvider, (previous, next) {
      if (previous == next) return;
      final formData = next.formData;
      if (_hostController.text != formData.host) _hostController.text = formData.host;
      if (_apiTokenController.text != formData.apiToken) _apiTokenController.text = formData.apiToken;
    });

    // Gezielte Watches für maximale Performance
    final isBusy = ref.watch(syncServerProvider.select((s) => s.isBusy));

    // Notifier holen
    final notifier = ref.read(syncServerProvider.notifier);

    return AlertDialog(
      title: const Text('Sync-Server'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0), // Abstand zum Bildschirmrand verringern
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // scrollen funktioniert auch, wenn Inhalte anfangs passen
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // --- Host ---
              Consumer(
                builder: (ctx, ref, _) {
                  final errorText = ref.watch(syncServerProvider.select((state) => state.error.field == 'host' ? state.error.text : null));
                  return TextField(
                    controller: _hostController,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Serveradresse',
                      prefixIcon: const Icon(Icons.cloud_outlined),
                      errorText: errorText,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: isBusy ? null : notifier.setHost,
                  );
                },
              ),

              const SizedBox(height: 16),

              // --- API-Token ---
              Consumer(
                builder: (ctx, ref, _) {
                  final errorText = ref.watch(syncServerProvider.select((state) => state.error.field == 'apiToken' ? state.error.text : null));
                  return PasswordField(
                    controller: _apiTokenController,
                    textInputAction: TextInputAction.next,
                    label: 'API-Token',
                    prefixIcon: Icons.vpn_key_outlined,
                    errorText: errorText,
                    onChanged: isBusy ? null : notifier.setApiToken,
                  );
                },
              ),

              const SizedBox(height: 12),

              // --- Button für Verbindungtest ---
              ElevatedButton.icon(
                onPressed: notifier.testConnection,
                icon: const Icon(Icons.swap_calls_outlined),
                label: const Text('Verbindung testen'),
              ),

              // --- Erfolgsmeldung für Verbindungstest oder allgemeine Fehlermeldung ---
              Consumer(builder: (context, ref, _) {
                final testSuccessful = ref.watch(syncServerProvider.select((s) => s.status == SyncServerActionStatus.testSuccessful));
                final error = ref.watch(syncServerProvider.select((s) => s.error));
                if (!testSuccessful && (error.text.isEmpty || error.field != null)) return const SizedBox.shrink();
                final text = testSuccessful ? 'Verbindung erfolgreich' : error.text;
                final icon = testSuccessful ? Icons.check_circle : Icons.error;
                final color = testSuccessful ? Colors.green : Theme.of(context).colorScheme.error;
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start, // Icon oben ausrichten bei Mehrzeilern
                    children: [
                      Icon(icon, color: color),
                      const SizedBox(width: 8),
                      Expanded(child: Text(text, softWrap: true, style: TextStyle(color: color))),
                    ],
                  ),
                );
              }),

            ],
          ),
        ),
      ),

      // --- Buttons ---
      actions: [
        TextButton(
          onPressed: isBusy ? null : _handleCancel,
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: isBusy ? null : notifier.save,
          child: isBusy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('OK'),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------------
  // --- Handler ---
  // ------------------------------------------------------------------------

  /// Speichert erst die Änderungen, wenn gewünscht und springt dann zurück.
  Future<void> _handleCancel() async {
    final state = ref.read(syncServerProvider);
    if (state.isDirty) {
      final confirmed = await ConfirmDialog.show(
        context,
        title: 'Speichern',
        text: 'Möchtest du die Änderungen speichern?',
        ok: 'Ja, speichern',
        cancel: 'Nein, verwerfen',
      );

      if (!mounted) return;

      if (confirmed == true) {
        final notifier = ref.read(syncServerProvider.notifier);
        notifier.save(); // Statt Cancel die Save-Action ausführen
        return;
      }
    }

    Navigator.of(context).pop(false); // Zur vorherigen Seite navigieren
  }
}