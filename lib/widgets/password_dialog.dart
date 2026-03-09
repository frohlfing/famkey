import 'package:flutter/material.dart';
import 'package:privault/widgets/password_field.dart';

/// Ein modaler Dialog zur Passwortabfrage.
class PasswordDialog {
  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String text,
    String? errorText,
  }) {
    final controller = TextEditingController();

    /// Öffnet den Dialog und gibt bei Bestätigung das eingegebene Passwort zurück.
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text),
              const SizedBox(height: 16),
              PasswordField(
                controller: controller,
                label: 'Master-Passwort',
                errorText: errorText,
                autofocus: true,
                onSubmitted: (val) {
                  if (val.isNotEmpty) Navigator.of(ctx).pop(val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  Navigator.of(ctx).pop(controller.text);
                }
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }
}
