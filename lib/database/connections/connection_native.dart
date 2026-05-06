import 'dart:ffi';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:famkey/core/env.dart';

/// Baut eine Datenbankverbindung zu SQLite für eine Desktop- oder Mobile-Platform auf.
QueryExecutor openConnection(String name, String password) {
  return LazyDatabase(() async {
    // DLL-Bindung für SQLCipher
    if (Platform.isWindows) {
      final dllPath = p.join(Directory.current.path, 'native', 'sqlcipher', 'windows', 'sqlite3mc_x64.dll');
      if (File(dllPath).existsSync()) {
        open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open(dllPath));
        debugPrint('✅ SQLiteMC DLL registriert');
      } else {
        debugPrint('❌ SQLiteMC DLL nicht gefunden: $dllPath');
      }
    }

    // Datenbank öffnen
    final path = p.join(env.vaultStoragePath, '$name.db3'); // WICHTIG: Zentralen Speicherpfad aus dem ConfigService nutzen!
    final rawDb = sqlite3.open(path);

    // Datenbank entsperren
    rawDb.execute("PRAGMA cipher = 'sqlcipher';");
    rawDb.execute("PRAGMA hexkey = '$password';");

    // Ab hier übernimmt Drift und prüft, ob die Tabellen aktualisiert werden müssen.
    return NativeDatabase.opened(rawDb);
  });
}