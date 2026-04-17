import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../renderer.dart';

/// Renderer für Text-basierte Inhalte wie TXT, Markdown, CSV, VCard und JSON.
class TextRenderer implements Renderer {
  /// Rohdaten des Dokuments.
  final Uint8List? bytes;

  /// Konstruktor.
  const TextRenderer(this.bytes);

  @override
  bool get isPrintable => bytes != null && bytes!.isNotEmpty;

  /// Gibt den Inhalt der Datei als Text zurück.
  // `allowMalformed: true` ersetzt ungültige Byte-Sequenzen durch das Unicode-Ersatzzeichen `\uFFFD` statt
  // eine Exception zu werfen – sinnvoll für Text-Dateien die eventuell eine andere Kodierung als UTF-8 haben.
  String? get text => bytes == null ? null : utf8.decode(bytes!, allowMalformed: true);

  @override
  Widget buildWidget() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        text ?? '',
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
        ),
      ),
    );
  }

  @override
  Future<void> print(String jobName) async {
    await Printing.layoutPdf(
      name: jobName,
      onLayout: (format) async {
        final doc = pw.Document();
        doc.addPage(pw.Page(
          pageFormat: format,
          build: (_) => pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Text(text ?? '', style: const pw.TextStyle(fontSize: 11)),
          ),
        ));
        return doc.save();
      },
    );
  }
}