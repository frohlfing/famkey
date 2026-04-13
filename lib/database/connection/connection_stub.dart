import 'package:drift/drift.dart';

// Fallback, falls keine plattformspezifische Implementierung verfügbar ist.

/// Baut eine Datenbankverbindung auf.
QueryExecutor openConnection(String name, String password) {
  throw UnsupportedError('Plattform nicht unterstützt');
}