import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famkey/features/settings/clipboard_clear/clipboard_clear_notifier.dart';
import 'package:famkey/features/settings/clipboard_clear/clipboard_clear_state.dart';

/// Ein modaler Dialog zum Ändern des automatischen Leerens der Zwischenablage.
class ClipboardClearDialog extends ConsumerStatefulWidget {

  /// Konstruktor
  const ClipboardClearDialog({super.key});

  /// Statische Methode zum Anzeigen des Dialogs.
  /// Gibt [true] zurück, wenn gespeichert wurde, andernfalls [false] oder [null].
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ClipboardClearDialog(),
    );
  }

  @override
  ConsumerState<ClipboardClearDialog> createState() => _ClipboardClearDialogState();
}

class _ClipboardClearDialogState extends ConsumerState<ClipboardClearDialog> {

  static const _options = [
    (value: 0, label: 'Nie'),
    (value: 10, label: 'Nach 10 Sekunden'),
    (value: 30, label: 'Nach 30 Sekunden'),
    (value: 60, label: 'Nach 60 Sekunden'),
    (value: 90, label: 'Nach 90 Sekunden'),
  ];

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert den Dialog und lädt die Daten, sobald der erste Frame gerendert wurde.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(clipboardClearProvider.notifier).load();
    });
  }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {

    // Listener für Status-Änderungen
    ref.listen(clipboardClearProvider.select((s) => s.status), (previous, next) {
      if (next == ClipboardClearActionStatus.saved) Navigator.of(context).pop(true);
    });

    // Gezielte Watches für maximale Performance
    final selectedValue = ref.watch(clipboardClearProvider.select((s) => s.selectedValue));
    final isBusy = ref.watch(clipboardClearProvider.select((s) => s.isBusy));

    // Notifier holen
    final notifier = ref.read(clipboardClearProvider.notifier);

    return AlertDialog(
      title: const Text('Zwischenablage leeren'),
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
