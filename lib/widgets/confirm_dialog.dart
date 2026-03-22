import 'package:flutter/material.dart';

/// Ein modaler Dialog für eine Ja/Nein-Frage.
class ConfirmDialog {

  /// Öffnet den Dialog und gibt bei Bestätigung `true` zurück.
  static Future<bool?> show(BuildContext context, {required String title, required String text, String? ok, String? cancel, bool autofocus = true}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            child: Text(cancel ?? 'Abbrechen'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            autofocus: autofocus,
            child: Text(ok ?? 'OK'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
  }
}
