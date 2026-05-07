import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famkey/features/settings/delete_vault/delete_vault_notifier.dart';
import 'package:famkey/features/settings/delete_vault/delete_vault_state.dart';
import 'package:famkey/widgets/snack.dart';

/// Ein modaler Dialog mit Löschoptionen für den Tresor.
///
/// Zeigt bei nicht-synchronisierten Tresoren nur die lokale Löschoption.
/// Bei synchronisierten Tresoren stehen drei Varianten zur Wahl.
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

    // Gezielte Watches für maximale Performance
    final state = ref.watch(deleteVaultProvider);
    final isBusy = state.isBusy;

    // Notifier holen
    final notifier = ref.read(deleteVaultProvider.notifier);

    // Noch nicht geladen → Ladeindikator
    if (state.status == DeleteVaultActionStatus.initial) {
      return const AlertDialog(
        title: Text('Tresor löschen'),
        content: SizedBox(height: 64, child: Center(child: CircularProgressIndicator())),
      );
    }

    if (!state.isRegistered) {
      return AlertDialog(
        title: const Text('Tresor löschen'),
        content: const Text('Alle lokalen Daten dieses Tresors werden unwiderruflich entfernt.'),
        actions: [
          TextButton(onPressed: isBusy ? null : () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white),
            onPressed: isBusy ? null : notifier.deleteVaultLocal,
            child: isBusy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Löschen'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Tresor löschen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            'Dieser Tresor wurde bereits synchronisiert. '
            'Bitte wähle, was gelöscht werden soll:',
          ),
          const SizedBox(height: 20),

          _DeleteOption(
            icon: Icons.cloud_off_outlined,
            label: 'Nur auf dem Server löschen',
            description: 'Lokale Daten bleiben erhalten. Beim nächsten Sync wird der Tresor neu registriert.',
            onPressed: isBusy ? null : notifier.deleteVaultServer,
          ),
          const SizedBox(height: 12),
          _DeleteOption(
            icon: Icons.phone_android_outlined,
            label: 'Nur auf diesem Gerät löschen',
            description: 'Die Daten auf dem Server bleiben erhalten.',
            onPressed: isBusy ? null : notifier.deleteVaultLocal,
          ),
          const SizedBox(height: 12),
          _DeleteOption(
            icon: Icons.delete_forever_outlined,
            label: 'Server und Gerät löschen',
            description: 'Alle Daten werden unwiderruflich entfernt.',
            isDestructive: true,
            onPressed: isBusy ? null : notifier.deleteVaultBoth,
          ),

          // --- Allgemeine Fehlermeldung ---
          Consumer(builder: (context, ref, _) {
            final error = ref.watch(deleteVaultProvider.select((s) => s.error));
            if (error.text.isEmpty) return const SizedBox.shrink();
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
      actions: [
        TextButton(onPressed: isBusy ? null : () => Navigator.pop(context, false), child: const Text('Abbrechen')),
      ],
    );
  }
}

/// Eine einzelne Lösch-Option im Dialog.
class _DeleteOption extends StatelessWidget {

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback? onPressed;
  final bool isDestructive;

  const _DeleteOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.onPressed,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red.shade800 : Colors.blueGrey.shade700;
    final effectiveColor = onPressed == null ? color.withValues(alpha: 0.4) : color;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: effectiveColor.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: effectiveColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: effectiveColor)),
                  const SizedBox(height: 2),
                  Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
