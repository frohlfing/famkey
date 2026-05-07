import 'package:flutter/material.dart';

/// Statusmeldung am unteren Bildschirmrand
class Snack {

  /// Zeigt eine farbige Statusmeldung am unteren Bildschirmrand an.
  /// Nutzt Grün für Erfolgsmeldungen und Rot für Fehlerhinweise.
  static void show(BuildContext context, String message, {bool success = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? Colors.green.shade800 : Colors.red.shade800,
        ),
      );
  }
}
