import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/features/sync/adopt_identity/adopt_identity_notifier.dart';
import 'package:privault/features/sync/adopt_identity/adopt_identity_state.dart';
import 'package:privault/features/sync/adopt_identity/user_identity.dart';
import 'package:privault/widgets/password_field.dart';

/// Ein modaler Dialog zum Ändern des Master-Passworts.
class AdoptIdentityDialog extends ConsumerStatefulWidget {

  /// Initiale Parameter
  /// Benutzeridentität, die adoptiert werden muss.
  final UserIdentity userIdentity;

  /// Konstruktor
  const AdoptIdentityDialog({super.key, required this.userIdentity});

  /// Statische Methode zum Anzeigen des Dialogs.
  /// Gibt [true] zurück, wenn gespeichert wurde, andernfalls [false] oder [null].
  static Future<bool?> show(BuildContext context, UserIdentity userIdentity) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // User muss explizit Speichern oder Abbrechen
      builder: (context) => AdoptIdentityDialog(userIdentity: userIdentity),
    );
  }

  @override
  ConsumerState<AdoptIdentityDialog> createState() => _AdoptIdentityDialogState();
}

class _AdoptIdentityDialogState extends ConsumerState<AdoptIdentityDialog> {

  // ------------------------------------------------------------------------
  // --- TextEditingController ---
  // ------------------------------------------------------------------------

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
      final notifier = ref.read(adoptIdentityProvider.notifier);
      await notifier.load(widget.userIdentity);
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
    ref.listen(adoptIdentityProvider.select((s) => s.status), (previous, next) {
      //final state = ref.read(adoptIdentityProvider);

      switch (next) {
        case AdoptIdentityActionStatus.saved:
          Navigator.of(context).pop(true); // Zurück zur Detailseite
          break;

        default:
          break;
      }
    });

    // Listener, der die Controller nur bei Initialladung oder Generierung füllt
    ref.listen(adoptIdentityProvider, (previous, next) {
      if (previous == next) return;
      final password = next.password;
      if (_passwordController.text != password) _passwordController.text = password;
    });

    // Gezielte Watches für maximale Performance
    final isBusy = ref.watch(adoptIdentityProvider.select((s) => s.isBusy));
    final isOnboarding = ref.watch(adoptIdentityProvider.select((s) => s.isOnboarding));

    // Hinweistext
    final text = isOnboarding
        ? "Du verwendest diesen Tresor bereits auf einem anderen Gerät. Bitte gib dein Master-Passwort ein, um die Identität zu übernehmen." // UUIDs stimmen nicht
        : "Du hast das Master-Passwort auf einem anderen Gerät geändert. Bitte gib es zur Synchronisation ein.";

    // Notifier holen
    final notifier = ref.read(adoptIdentityProvider.notifier);

    return AlertDialog(
      title: const Text('Account verknüpfen'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0), // Abstand zum Bildschirmrand verringern
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Hinweistext ---
            Text(text),
            const SizedBox(height: 16),

            // --- Master-Passwort ---
            Consumer(
              builder: (ctx, ref, _) {
                final errorText = ref.watch(adoptIdentityProvider.select((state) => state.error.field == 'password' ? state.error.text : null));
                return PasswordField(
                  controller: _passwordController,
                  textInputAction: TextInputAction.next,
                  label: 'Master-Passwort',
                  prefixIcon: Icons.key_off_outlined,
                  errorText: errorText,
                  onChanged: isBusy ? null : notifier.setPassword,
                );
              },
            ),

            // --- Allgemeine Fehlermeldung (error.field == null) ---
            Consumer(builder: (context, ref, _) {
              final error = ref.watch(adoptIdentityProvider.select((s) => s.error));
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