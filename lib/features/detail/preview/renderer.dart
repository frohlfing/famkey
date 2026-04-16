import 'package:flutter/widgets.dart';
import 'package:pdf/widgets.dart' as pw;

/// Gemeinsames Interface für die Darstellung und den Druck von Anhangs-Inhalten.
abstract class Renderer {
  /// Gibt an, ob dieser Inhalt sinnvoll gedruckt werden kann.
  bool get isPrintable;

  /// Baut das Widget für die Vorschau.
  Widget buildWidget();

  /// Optionaler nativer Druckpfad (z. B. HTML über die WebView-Engine).
  ///
  /// Gibt `true` zurück, wenn der Druck nativ initiiert wurde –
  /// in diesem Fall überspringt [PreviewNotifier] den PDF-Fallback.
  /// Standard-Implementierung: `false` (kein nativer Druck, Fallback greift).
  ///
  /// [jobName] ist der angezeigte Druckauftrag-Name im System-Druckdialog.
  Future<bool> printNatively(String jobName) async => false;

  /// Baut das Widget für die PDF-Druckausgabe (Fallback).
  ///
  /// Wird nur aufgerufen, wenn [printNatively] `false` zurückgibt.
  pw.Widget buildPrintableWidget();
}