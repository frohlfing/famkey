import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famkey/features/settings/delete_vault/delete_vault_notifier.dart';
import 'package:famkey/features/settings/delete_vault/delete_vault_state.dart';
import 'package:famkey/widgets/password_field.dart';
import 'package:famkey/widgets/snack.dart';

/// Ein modaler Dialog zum Löschen des Tresors.
///
/// Über zwei Schalter wählt der Benutzer, ob der Tresor auf dem Server,
/// auf dem Gerät oder an beiden Orten gelöscht werden soll.
/// Der Master-Schlüssel muss zur Bestätigung eingegeben werden.
class DeleteVaultDialog extends ConsumerStatefulWidget {

  /// Initiale Parameter
  // (keine)

  /// Konstruktor
  const DeleteVaultDialog({super.key});

  /// Statische Methode zum Anzeigen des Dialogs.
  /// Gibt [true] zurück, wenn der Server-Eintrag entfernt wurde (Reload nötig),
  /// andernfalls [false] oder [null].
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DeleteVaultDialog(),
    );
  }

  @override
  ConsumerState<DeleteVaultDialog> createState() => _DeleteVaultDialogState();
}

class _DeleteVaultDialogState extends ConsumerState<DeleteVaultDialog> {

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
      await ref.read(deleteVaultProvider.notifier).load();
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
    ref.listen(deleteVaultProvider.select((s) => s.status), (previous, next) {
      switch (next) {
        case DeleteVaultActionStatus.saved:
          Navigator.of(context).pop(true); // Einstellungen neu laden
          break;

        case DeleteVaultActionStatus.deleted:
          Snack.show(context, 'Tresor gelöscht!', success: true);
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          break;

        default:
          break;
      }
    });

    // Controller mit State synchronisieren — stellt sicher, dass das Passwortfeld
    // beim Neu-Öffnen des Dialogs leer ist, obwohl der Provider weiterlebt.
    ref.listen(deleteVaultProvider.select((s) => s.password), (previous, next) {
      if (_passwordController.text != next) _passwordController.text = next;
    });

    // Gezielte Watches
    final isBusy = ref.watch(deleteVaultProvider.select((s) => s.isBusy));
    final isRegistered = ref.watch(deleteVaultProvider.select((s) => s.isRegistered));
    final isInitial = ref.watch(deleteVaultProvider.select((s) => s.status == DeleteVaultActionStatus.initial));
    final canConfirm = ref.watch(deleteVaultProvider.select((s) => s.canConfirm));

    // Notifier holen
    final notifier = ref.read(deleteVaultProvider.notifier);

    // Noch nicht geladen → Ladeindikator
    if (isInitial) {
      return const AlertDialog(
        title: Text('Tresor löschen'),
        content: SizedBox(height: 64, child: Center(child: CircularProgressIndicator())),
      );
    }

    return AlertDialog(
      title: const Text('Tresor löschen'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- Schalter: Server (nur bei synchronisierten Tresoren) ---
            if (isRegistered)
              Consumer(builder: (ctx, ref, _) {
                final value = ref.watch(deleteVaultProvider.select((s) => s.deleteServer));
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tresor auf dem Server löschen'),
                  value: value,
                  onChanged: isBusy ? null : notifier.setDeleteServer,
                );
              }),

            // --- Schalter: Gerät ---
            Consumer(builder: (ctx, ref, _) {
              final value = ref.watch(deleteVaultProvider.select((s) => s.deleteLocal));
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tresor auf diesem Gerät löschen'),
                value: value,
                onChanged: isBusy ? null : notifier.setDeleteLocal,
              );
            }),

            // --- Hinweisfeld (je nach Schalterstellung) ---
            Consumer(builder: (ctx, ref, _) {
              final deleteServer = ref.watch(deleteVaultProvider.select((s) => s.deleteServer));
              final deleteLocal = ref.watch(deleteVaultProvider.select((s) => s.deleteLocal));
              return _buildHint(context, isRegistered: isRegistered, deleteServer: deleteServer, deleteLocal: deleteLocal);
            }),

            const SizedBox(height: 16),

            // --- Master-Schlüssel ---
            Consumer(builder: (ctx, ref, _) {
              final errorText = ref.watch(deleteVaultProvider.select((s) => s.error.field == 'password' ? s.error.text : null));
              return PasswordField(
                controller: _passwordController,
                textInputAction: TextInputAction.done,
                label: 'Master-Schlüssel',
                prefixIcon: Icons.key_outlined,
                errorText: errorText,
                onChanged: isBusy ? null : notifier.setPassword,
              );
            }),

            // --- Allgemeine Fehlermeldung (error.field == null) ---
            Consumer(builder: (context, ref, _) {
              final error = ref.watch(deleteVaultProvider.select((s) => s.error));
              if (error.text.isEmpty || error.field != null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white),
          onPressed: isBusy || !canConfirm ? null : () => _askAndDelete(notifier),
          child: isBusy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Löschen'),
        ),
      ],
    );
  }

  /// Zeigt einen Bestätigungsdialog und führt die Löschaktion erst danach aus.
  Future<void> _askAndDelete(DeleteVaultNotifier notifier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bist du sicher?'),
        content: const Text('Diese Aktion kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ja, löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) notifier.confirm();
  }

  /// Baut das Hinweisfeld je nach Schalterstellung.
  Widget _buildHint(BuildContext context, {required bool isRegistered, required bool deleteServer, required bool deleteLocal}) {
    if (!deleteServer && !deleteLocal) return const SizedBox.shrink();

    final String text;
    final bool isDestructive;

    if (deleteServer && deleteLocal) {
      text = 'Alle Daten werden unwiderruflich entfernt.';
      isDestructive = true;
    } else if (deleteServer) {
      text = 'Lokale Daten bleiben erhalten. Beim nächsten Sync wird der Tresor neu registriert.';
      isDestructive = false;
    } else if (isRegistered) {
      // deleteLocal only, registriert → Serverdaten bleiben
      text = 'Die Daten auf dem Server bleiben erhalten.';
      isDestructive = false;
    } else {
      // deleteLocal only, nicht registriert → vollständige lokale Löschung
      text = 'Alle lokalen Daten werden unwiderruflich entfernt.';
      isDestructive = true;
    }

    final bgColor = isDestructive ? Colors.red.shade50 : Colors.orange.shade50;
    final borderColor = isDestructive ? Colors.red.shade300 : Colors.orange.shade300;
    final iconColor = isDestructive ? Colors.red.shade800 : Colors.orange.shade800;
    final textColor = isDestructive ? Colors.red.shade900 : Colors.orange.shade900;
    final icon = isDestructive ? Icons.warning_amber_rounded : Icons.info_outline;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: TextStyle(fontSize: 12, color: textColor)),
            ),
          ],
        ),
      ),
    );
  }
}
