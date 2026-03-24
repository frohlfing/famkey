import 'package:flutter/material.dart';

/// Ein modaler Dialog zur Eingabeaufforderung.
class InputDialog {

  /// Öffnet den Dialog und gibt bei Bestätigung den eingegebenen Wert zurück.
  static Future<String?> show(
    BuildContext context, {
    required String title,
    String? text,
    String? label,
    String? value,
    String? errorText,
  }) {
    final controller = TextEditingController(text: value);
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (text != null) Text(text),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: label,
                    errorText: errorText,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    // Sobald getippt wird, Fehlermeldung löschen
                    if (errorText != null) {
                      setDialogState(() => errorText = null);
                    }
                  },
                  onSubmitted: (val) => Navigator.of(ctx).pop(val),
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Abbrechen'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }
}
