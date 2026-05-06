import 'package:flutter/material.dart';

/// Auswahl-Dialog für die Auto-Sperre.
///
/// Gibt den gewählten Wert zurück (0 = Nie, 1–10 = Minuten).
/// Gibt null zurück, wenn der Nutzer den Dialog abbricht.
class AutolockDialog extends StatefulWidget {
  const AutolockDialog({super.key, required this.initialValue});

  final int? initialValue;

  static Future<int?> show(BuildContext context, {int? initialValue}) {
    return showDialog<int>(
      context: context,
      builder: (_) => AutolockDialog(initialValue: initialValue),
    );
  }

  @override
  State<AutolockDialog> createState() => _AutolockDialogState();
}

class _AutolockDialogState extends State<AutolockDialog> {

  static const _options = [
    (value: 0, label: 'Nie'),
    (value: 1, label: 'Nach 1 Minute'),
    (value: 2, label: 'Nach 2 Minuten'),
    (value: 3, label: 'Nach 3 Minuten'),
    (value: 4, label: 'Nach 4 Minuten'),
    (value: 5, label: 'Nach 5 Minuten'),
    (value: 10, label: 'Nach 10 Minuten'),
  ];

  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Automatische Sperre'),
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
