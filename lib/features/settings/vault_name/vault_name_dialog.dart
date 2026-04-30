import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famkey/features/settings/vault_name/vault_name_notifier.dart';
import 'package:famkey/features/settings/vault_name/vault_name_state.dart';
import 'package:famkey/widgets/password_field.dart';

/// Ein modaler Dialog zum Umbenennen des Tresors.
class VaultNameDialog extends ConsumerStatefulWidget {

  /// Initiale Parameter
  // (keine)

  /// Konstruktor
  const VaultNameDialog({super.key});

  /// Statische Methode zum Anzeigen des Dialogs.
  /// Gibt [true] zurück, wenn gespeichert wurde, andernfalls [false] oder [null].
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // User muss explizit Speichern oder Abbrechen
      builder: (_) => const VaultNameDialog(),
    );
  }

  @override
  ConsumerState<VaultNameDialog> createState() => _VaultNameDialogState();
}

class _VaultNameDialogState extends ConsumerState<VaultNameDialog> {

  // ------------------------------------------------------------------------
  // --- TextEditingController ---
  // ------------------------------------------------------------------------

  final _vaultNameController = TextEditingController();
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
      final notifier = ref.read(vaultNameProvider.notifier);
      await notifier.load();
    });
  }

  /// Gibt Ressourcen frei.
  @override
  void dispose() {
    _vaultNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {

    // Listener für Status-Änderungen
    ref.listen(vaultNameProvider.select((s) => s.status), (previous, next) {
      //final state = ref.read(vaultNameProvider);

      switch (next) {
        case VaultNameActionStatus.saved:
          Navigator.of(context).pop(true); // Zurück zur Detailseite
          break;

        default:
          break;
      }
    });

    // Listener, der die Controller nur bei Initialladung oder Generierung füllt
    ref.listen(vaultNameProvider, (previous, next) {
      if (previous == next) return;
      final formData = next.formData;
      if (_vaultNameController.text != formData.vaultName) _vaultNameController.text = formData.vaultName;
      if (_passwordController.text != formData.password) _passwordController.text = formData.password;
    });

    // Gezielte Watches für maximale Performance
    final isBusy = ref.watch(vaultNameProvider.select((s) => s.isBusy));

    // Notifier holen
    final notifier = ref.read(vaultNameProvider.notifier);

    return AlertDialog(
      title: const Text('Tresorname ändern'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- Hinweis bei bereits synchronisiertem Tresor ---
            Consumer(
              builder: (ctx, ref, _) {
                final isSynced = ref.watch(vaultNameProvider.select((s) => s.isSynced));
                if (!isSynced) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.orange.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Die Daten auf dem Server verbleiben unter dem bisherigen Tresornamen. '
                            'Wenn du sie löschen möchtest, nutze vorher die Option '
                            '"Nur auf dem Server löschen" in den Einstellungen.',
                            style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // --- Tresorname ---
            Consumer(
              builder: (ctx, ref, _) {
                final errorText = ref.watch(vaultNameProvider.select((state) => state.error.field == 'vaultName' ? state.error.text : null));
                return TextField(
                  controller: _vaultNameController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Tresorname',
                    prefixIcon: const Icon(Icons.shield_outlined),
                    errorText: errorText,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: isBusy ? null : notifier.setVaultName,
                );
              },
            ),

            const SizedBox(height: 16),

            // --- Master-Passwort ---
            Consumer(
              builder: (ctx, ref, _) {
                final errorText = ref.watch(vaultNameProvider.select((state) => state.error.field == 'password' ? state.error.text : null));
                return PasswordField(
                  controller: _passwordController,
                  textInputAction: TextInputAction.next,
                  label: 'Master-Passwort',
                  prefixIcon: Icons.key_outlined,
                  errorText: errorText,
                  onChanged: isBusy ? null : notifier.setPassword,
                );
              },
            ),

            // --- Allgemeine Fehlermeldung (error.field == null) ---
            Consumer(builder: (context, ref, _) {
              final error = ref.watch(vaultNameProvider.select((s) => s.error));
              if (error.text.isEmpty || error.field != null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start, // Icon oben ausrichten bei Mehrzeilern
                  children: [
                    Icon(Icons.error, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(child: Text(error.text, softWrap: true, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                  ],
                ),
              );
            }),

          ],
        ),
      ),

      // --- Buttons ---
      actions: [
        TextButton(
          onPressed: isBusy ? null : () => Navigator.of(context).pop(false),
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
}