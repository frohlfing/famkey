import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/features/settings/master_password/master_password_notifier.dart';
import 'package:privault/features/settings/master_password/master_password_state.dart';
import 'package:privault/widgets/password_field.dart';
import 'package:privault/widgets/password_strength_bar.dart';

/// Ein modaler Dialog zum Ändern des Master-Passworts.
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
      builder: (_) => const MasterPasswordDialog(),
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0), // Abstand zum Bildschirmrand verringern
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- Neues Master-Passwort ---
            Consumer(
              builder: (ctx, ref, _) {
                final passwordStrength = ref.watch(masterPasswordProvider.select((s) => s.passwordStrength));
                final errorText = ref.watch(masterPasswordProvider.select((state) => state.error.field == 'newPassword' ? state.error.text : null));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PasswordField(
                      controller: _newPasswordController,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      label: 'Neues Master-Passwort',
                      prefixIcon: Icons.key_outlined,
                      errorText: errorText,
                      onChanged: isBusy ? null : notifier.setNewPassword,
                    ),
                    // --- Passwortstärke ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: PasswordStrengthBar(score: passwordStrength),
                    ),
                  ],
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

            // --- Schlüsselpaar neu generieren (Notfall-Reset) ---
            const SizedBox(height: 16),
            Consumer(
              builder: (ctx, ref, _) {
                final regenerateKeyPair = ref.watch(masterPasswordProvider.select((s) => s.formData.regenerateKeyPair));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      value: regenerateKeyPair,
                      onChanged: isBusy ? null : notifier.setRegenerateKeyPair,
                      title: const Text('Neues RSA-Schlüsselpaar erzeugen'),
                      subtitle: const Text('Notfall-Reset'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (regenerateKeyPair)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.warning_amber_outlined, size: 18, color: Colors.orange.shade800),
                                    const SizedBox(width: 6),
                                    const Text('Konsequenzen:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const Text('• Alle Freundschaften werden als unverifiziert markiert (⚠ Fingerprint-Warnung).'),
                                const Text('• Freigegebene Einträge sind für Freunde gesperrt, bis sie deinen neuen Fingerprint bestätigen.'),
                                const SizedBox(height: 8),
                                const Text('Im Normalfall ist kein neues Schlüsselpaar erforderlich. Verwende die Option nur bei Verlust des Gerätes oder Verdacht auf kompromittierten Schlüssel.'),
                                const SizedBox(height: 8),
                                const Text('Synchronisier baldmöglichst, damit die neue Identität überall wirksam wird.'),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

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