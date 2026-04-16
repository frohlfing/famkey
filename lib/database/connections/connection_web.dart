import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';

/// Baut eine Datenbankverbindung zu WasmDatabase (SQLite im Browser) für eine WebAssembly (WASM) auf.
///
/// Parameter `password` wird hier bewusst ignoriert, da die SQLite-Datei nicht verschlüsselt ist (technisch nicht möglich).
QueryExecutor openConnection(String name, String password) {
  // Hinweis: Keine DB-Verschlüsselung auf Web-Plattform (kein SQLCipher).
  // Die Sicherheit liegt ausschließlich in der AES-Verschlüsselung der Inhalte.
  if (kDebugMode) {
    debugPrint("⚠️ Web-Plattform: DB-Verschlüsselung (SQLCipher) deaktiviert.");
  }

  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: name,
      sqlite3Uri: Uri.parse('sqlite3.wasm'), // Quelle: https://github.com/simolus3/sqlite3.dart/releases/tag/sqlite3-2.9.4
      driftWorkerUri: Uri.parse('drift_worker.js'),  // https://github.com/simolus3/drift/releases/tag/drift-2.31.0
    );
    return result.resolvedExecutor;
  });
}