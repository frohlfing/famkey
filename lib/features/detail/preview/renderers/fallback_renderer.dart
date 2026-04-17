import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import '../renderer.dart';

/// Fallback-Renderer, wenn für den Dateityp keine Vorschau verfügbar ist.
class FallbackRenderer implements Renderer {
  /// Konstruktor.
  const FallbackRenderer();

  @override
  bool get isPrintable => false;

  @override
  Widget buildWidget() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Keine Vorschau verfügbar.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Nutze "Herunterladen" um die Datei zu öffnen.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Future<void> print(String jobName) async {}
}