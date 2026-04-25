import 'package:flutter/material.dart';

/// Auswahl-Dialog für das automatische Leeren der Zwischenablage.
///
/// Gibt den gewählten Wert zurück (0 = Nie, sonst Sekunden).
/// Gibt null zurück, wenn der Nutzer den Dialog abbricht.
class ClipboardClearDialog extends StatefulWidget {
  const ClipboardClearDialog({super.key, required this.initialValue});

  final int? initialValue;

  static Future<int?> show(BuildContext context, {int? initialValue}) {
    return showDialog<int>(
      context: context,
      builder: (_) => ClipboardClearDialog(initialValue: initialValue),
    );
  }

  @override
  State<ClipboardClearDialog> createState() => _ClipboardClearDialogState();
}

class _ClipboardClearDialogState extends State<ClipboardClearDialog> {

  static const _options = [
    (value: 0, label: 'Nie'),
    (value: 10, label: 'Nach 10 Sekunden'),
    (value: 30, label: 'Nach 30 Sekunden'),
    (value: 60, label: 'Nach 60 Sekunden'),
    (value: 90, label: 'Nach 90 Sekunden'),
  ];

  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue ?? 30;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Zwischenablage leeren'),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: RadioGroup<int>(
        groupValue: _selected,
        onChanged: (v) { if (v != null) setState(() => _selected = v); },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _options.map((opt) => ListTile(
            title: Text(opt.label),
            leading: Radio<int>(value: opt.value),
            onTap: () => setState(() => _selected = opt.value),
          )).toList(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        ElevatedButton(onPressed: () => Navigator.pop(context, _selected), child: const Text('OK')),
      ],
    );
  }
}
