import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/features/settings/master_password/master_password_notifier.dart';
import 'package:privault/features/settings/master_password/master_password_state.dart';
import 'package:privault/widgets/confirm_dialog.dart';
import 'package:privault/widgets/password_field.dart';

/// Ein modaler Dialog zum Konfigurieren des Passwort-Generators.
class MasterPasswordDialog extends ConsumerStatefulWidget {

  /// Initiale Parameter
  // (keine)

  /// Konstruktor
  const MasterPasswordDialog({super.key});

  /// Statische Methode zum Anzeigen des Dialogs.
  /// Gibt [true] zurück, wenn gespeichert wurde, andernfalls [false] oder [null].
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // User muss explizit Speichern oder Abbrechen
      builder: (context) => MasterPasswordDialog(),
    );
  }

  @override
  ConsumerState<MasterPasswordDialog> createState() => _MasterPasswordDialogState();
}

class _MasterPasswordDialogState extends ConsumerState<MasterPasswordDialog> {

  // ------------------------------------------------------------------------
  // --- TextEditingController ---
  // ------------------------------------------------------------------------

  final _newPasswordController = TextEditingController();
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
      final notifier = ref.read(masterPasswordProvider.notifier);
      await notifier.load();
    });
  }

  /// Gibt Ressourcen frei.
  @override
  void dispose() {
    _newPasswordController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {

    // Listener für Status-Änderungen
    ref.listen(masterPasswordProvider.select((s) => s.status), (previous, next) {
      //final state = ref.read(masterPasswordProvider);

      switch (next) {
        case MasterPasswordActionStatus.saved:
          Navigator.of(context).pop(true); // Zurück zur Detailseite
          break;

        default:
          break;
      }
    });

    // Listener, der die Controller nur bei Initialladung oder Generierung füllt
    ref.listen(masterPasswordProvider, (previous, next) {
      if (previous == next) return;
      final formData = next.formData;
      if (_newPasswordController.text != formData.newPassword) _newPasswordController.text = formData.newPassword;
      if (_passwordController.text != formData.password) _passwordController.text = formData.password;
    });

    // Gezielte Watches für maximale Performance
    final isBusy = ref.watch(masterPasswordProvider.select((s) => s.isBusy));

    // Notifier holen
    final notifier = ref.read(masterPasswordProvider.notifier);

    return AlertDialog(
      title: const Text('Master-Passwort ändern'),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- Neues Master-Passwort ---
            Consumer(
              builder: (ctx, ref, _) {
                final errorText = ref.watch(masterPasswordProvider.select((state) => state.error.field == 'newPassword' ? state.error.text : null));
                return TextField(
                  controller: _newPasswordController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Neues Master-Passwort',
                    prefixIcon: const Icon(Icons.key_outlined),
                    errorText: errorText,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: isBusy ? null : notifier.setNewPassword,
                );
              },
            ),

            const SizedBox(height: 16),

            // --- Bisheriges Master-Passwort ---
            Consumer(
              builder: (ctx, ref, _) {
                final errorText = ref.watch(masterPasswordProvider.select((state) => state.error.field == 'password' ? state.error.text : null));
                return PasswordField(
                  controller: _passwordController,
                  textInputAction: TextInputAction.next,
                  label: 'Bisheriges Master-Passwort',
                  prefixIcon: Icons.key_off_outlined,
                  errorText: errorText,
                  onChanged: isBusy ? null : notifier.setPassword,
                );
              },
            ),

            // --- Allgemeine Fehlermeldung (error.field == null) ---
            Consumer(builder: (context, ref, _) {
              final error = ref.watch(masterPasswordProvider.select((s) => s.error));
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
    final state = ref.read(masterPasswordProvider);
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
        final notifier = ref.read(masterPasswordProvider.notifier);
        notifier.save(); // Statt Cancel die Save-Action ausführen
        return;
      }
    }

    Navigator.of(context).pop(false); // Zur vorherigen Seite navigieren
  }
}