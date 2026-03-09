import 'package:flutter/material.dart';

/// Ein modaler Dialog zur Passwortabfrage.
class PasswordDialog {
  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String text,
    String? errorText,
  }) {
    final controller = TextEditingController();
    bool obscureText = true; // Passwort ausgeblendet
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
              TextField(
                controller: controller,
                obscureText: obscureText,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Master-Passwort',
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                  suffixIcon: IconButton(
                    icon: Icon(obscureText ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setDialogState(() => obscureText = !obscureText),
                  ),
                ),
                onSubmitted: (_) {
                  if (controller.text.isNotEmpty) {
                    Navigator.of(ctx).pop(controller.text);
                  }
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
