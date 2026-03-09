import 'package:flutter/material.dart';

/// Ein modaler Dialog zur Personensuche.
///
/// Dieser Dialog wird im `SettingsScreen` aufgerufen.
class FriendSearchDialog {
  static Future<String?> show(BuildContext context, {String? errorText}) async {
    final controller = TextEditingController();

    /// Öffnet den Dialog und gibt bei Bestätigung das eingegebene Namen zurück.
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Person suchen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Name der Person',
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                ),
                onSubmitted: (val) {
                  final name = val.trim();
                  if (name.isNotEmpty) {
                    Navigator.of(ctx).pop(name);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.of(ctx).pop(name);
                }
              },
              child: const Text('Suchen'),
            ),
          ],
        ),
      ),
    );
  }
}