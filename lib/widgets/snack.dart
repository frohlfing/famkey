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

  /// Zeigt eine Exception in der SnackBar an.
  static void showException(BuildContext context, dynamic ex, {StackTrace? stackTrace, String? label}) {
    final logLabel = label ?? "Error";
    debugPrint("❌ $logLabel: $ex");
    if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
    Snack.show(context, "Ein unerwarteter Fehler ist aufgetreten.");
  }
}
