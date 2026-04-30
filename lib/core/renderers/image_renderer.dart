import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:famkey/core/renderer.dart';

/// Renderer für Bildinhalte.
class ImageRenderer implements Renderer {
  /// Rohdaten des Bildes.
  final Uint8List? bytes;

  /// Konstruktor.
  const ImageRenderer(this.bytes);

  @override
  bool get isPrintable => bytes != null && bytes!.isNotEmpty;

  @override
  Widget buildWidget() {
    return InteractiveViewer(
      child: Center(
        child: Image.memory(
          bytes ?? Uint8List(0),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Center(
            child: Text('Das Bild konnte nicht geladen werden.', style: TextStyle(color: Colors.red)),
          ),
        ),
      ),
    );
  }

  @override
  Future<void> print(String jobName) async {
    if (bytes == null || bytes!.isEmpty) return;
    await Printing.layoutPdf(
      name: jobName,
      onLayout: (format) async {
        final doc = pw.Document();
        doc.addPage(pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Center(
            child: pw.Image(pw.MemoryImage(bytes!), fit: pw.BoxFit.contain),
          ),
        ));
        return doc.save();
      },
    );
  }
}