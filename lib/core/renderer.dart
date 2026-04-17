import 'package:flutter/widgets.dart';

/// Gemeinsames Interface für die Darstellung und den Druck von Anhangs-Inhalten.
abstract class Renderer {
  /// Gibt an, ob dieser Inhalt sinnvoll gedruckt werden kann.
  bool get isPrintable;

  /// Baut das Widget für die Vorschau.
  Widget buildWidget();

  /// Druckt den Inhalt.
  /// [jobName] ist der angezeigte Druckauftrag-Name im System-Druckdialog.
  Future<void> print(String jobName);
}