import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famkey/features/settings/autolock_dialog/autolock_notifier.dart';
import 'package:famkey/features/settings/autolock_dialog/autolock_state.dart';

/// Ein modaler Dialog zum Ändern der automatischen Sperre.
class AutolockDialog extends ConsumerStatefulWidget {

  /// Konstruktor
  const AutolockDialog({super.key});

  /// Statische Methode zum Anzeigen des Dialogs.
  /// Gibt [true] zurück, wenn gespeichert wurde, andernfalls [false] oder [null].
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AutolockDialog(),
    );
  }

  @override
  ConsumerState<AutolockDialog> createState() => _AutolockDialogState();
}

class _AutolockDialogState extends ConsumerState<AutolockDialog> {

  static const _options = [
    (value: 0, label: 'Nie'),
    (value: 30, label: 'Nach 30 Sekunden'),
    (value: 60, label: 'Nach 1 Minute'),
    (value: 120, label: 'Nach 2 Minuten'),
    (value: 180, label: 'Nach 3 Minuten'),
    (value: 300, label: 'Nach 5 Minuten'),
    (value: 600, label: 'Nach 10 Minuten'),
  ];

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert den Dialog und lädt die Daten, sobald der erste Frame gerendert wurde.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(autolockProvider.notifier).load();
    });
  }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {

    // Listener für Status-Änderungen
    ref.listen(autolockProvider.select((s) => s.status), (previous, next) {
      if (next == AutolockActionStatus.saved) Navigator.of(context).pop(true);
    });

    // Gezielte Watches für maximale Performance
    final selectedValue = ref.watch(autolockProvider.select((s) => s.selectedValue));
    final isBusy = ref.watch(autolockProvider.select((s) => s.isBusy));

    // Notifier holen
    final notifier = ref.read(autolockProvider.notifier);

    return AlertDialog(
      title: const Text('Automatische Sperre'),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: RadioGroup<int>(
        groupValue: selectedValue,
        onChanged: (v) { if (v != null) notifier.setSelectedValue(v); },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _options.map((opt) => ListTile(
            title: Text(opt.label),
            leading: Radio<int>(value: opt.value),
            onTap: () => notifier.setSelectedValue(opt.value),
          )).toList(),
        ),
      ),

      // --- Buttons ---
      actions: [
        TextButton(onPressed: isBusy ? null : () => Navigator.pop(context, false), child: const Text('Abbrechen')),
        ElevatedButton(onPressed: isBusy ? null : notifier.save, child: const Text('OK')),
      ],
    );
  }
}
