import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;

import '../renderer.dart';

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
  Future<bool> printNatively(String jobName) async {
    return false;
  }

  @override
  pw.Widget buildPrintableWidget() {
    final image = bytes == null ? null : pw.MemoryImage(bytes!);

    if (image == null) {
      return pw.Center(
        child: pw.Text('Das Bild konnte nicht geladen werden.'),
      );
    }

    return pw.Center(
      child: pw.Image(
        image,
        fit: pw.BoxFit.contain,
      ),
    );
  }
}