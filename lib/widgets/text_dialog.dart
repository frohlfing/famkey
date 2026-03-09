import 'package:flutter/material.dart';

/// Ein modaler Hinweis.
class TextDialog {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String text,
    String? ok,
  }) {
    /// Öffnet den Dialog.
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            autofocus: true,
            child: Text(ok ?? 'OK'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }
}
