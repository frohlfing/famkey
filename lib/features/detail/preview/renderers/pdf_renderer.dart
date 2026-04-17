import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../renderer.dart';

/// Renderer für PDF-Dokumente.
class PdfRenderer implements Renderer {
  /// Rohdaten des PDFs.
  final Uint8List? bytes;

  /// Konstruktor.
  const PdfRenderer(this.bytes);

  @override
  bool get isPrintable => bytes != null && bytes!.isNotEmpty;

  @override
  Widget buildWidget() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.picture_as_pdf_outlined, size: 64),
          const SizedBox(height: 16),
          const Text(
            'PDF-Vorschau ist noch nicht implementiert.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Nutze "Herunterladen" oder "Drucken".',
            style: TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Druckt das PDF verlustfrei direkt aus den Originalbytes.
  @override
  Future<void> print(String jobName) async {
    final data = bytes;
    if (data == null || data.isEmpty) return;
    await Printing.layoutPdf(
      name: jobName,
      onLayout: (_) async => data,
    );
  }
}