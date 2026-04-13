import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:web/web.dart' as web;
import '../app_file.dart';

final _fsIndex = _FsIndex();

/// Implementierung von [AppFile] für eine WebAssembly (WASM)
/// auf Basis des Origin-Private File System (OPFS).
///
/// OPFS ist ein persistentes, origin-gebundenes Dateisystem im Browser.
/// Dateipfade werden als Verzeichnisstruktur im OPFS abgebildet.
///
/// Voraussetzung: Die App muss mit den COOP/COEP-Headern ausgeliefert werden,
/// damit SharedArrayBuffer und Atomics verfügbar sind (für den Drift-Worker).
///
/// Konfiguration in Android Studio:
///  - `Run` → `Edit Configurations` → `Add New Configuration` → `Flutter`
///  - In das Feld `Additional run args` dies einfügen:
///    ```
///    -d chrome
///    --web-header=Cross-Origin-Opener-Policy=same-origin
///    --web-header=Cross-Origin-Embedder-Policy=require-corp
///    ```
///
/// Das OPFS selbst funktioniert auch ohne diese Header.
class AppFileWeb implements AppFile {
  final String _path;

  AppFileWeb(String path) : _path = path;

  @override
  String get path => _path;

  @override
  String get name => p.basename(_path);

  /// Gibt das FileSystemFileHandle für diese Datei zurück.
  /// Legt dabei alle notwendigen Verzeichnisse rekursiv an, wenn [create] = true.
  Future<web.FileSystemFileHandle> _getHandle({bool create = false}) async {
    final root = await web.window.navigator.storage.getDirectory().toDart;
    final segments = _path.split('/').where((s) => s.isNotEmpty).toList();

    // Alle Segmente bis auf das letzte sind Verzeichnisse
    web.FileSystemDirectoryHandle dir = root;
    for (final segment in segments.sublist(0, segments.length - 1)) {
      dir = await dir.getDirectoryHandle(segment, web.FileSystemGetDirectoryOptions(create: create)).toDart;
    }

    // Letzte Komponente ist die Datei
    return dir.getFileHandle(segments.last, web.FileSystemGetFileOptions(create: create)).toDart;
  }

  /// Gibt das FileSystemDirectoryHandle des übergeordneten Verzeichnisses zurück.
  Future<web.FileSystemDirectoryHandle> _getParentDir() async {
    final root = await web.window.navigator.storage.getDirectory().toDart;
    final segments = _path.split('/').where((s) => s.isNotEmpty).toList();

    web.FileSystemDirectoryHandle dir = root;
    for (final segment in segments.sublist(0, segments.length - 1)) {
      dir = await dir.getDirectoryHandle(segment, web.FileSystemGetDirectoryOptions(create: false)).toDart;
    }
    return dir;
  }

  @override
  Future<bool> exists() async {
    try {
      await _getHandle(create: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Uint8List> readAsBytes() async {
    final handle = await _getHandle(create: false);
    final file = await handle.getFile().toDart;
    final buffer = await file.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }

  @override
  Future<String> readAsString() async {
    final bytes = await readAsBytes();
    return utf8.decode(bytes);
  }

  @override
  Future<List<String>> readAsLines() async {
    final content = await readAsString();
    return content.split('\n');
  }

  @override
  Stream<String> openReadLines() async* {
    // OPFS kann nicht streamen, daher Fallback-Lösung:
    final content = await readAsString(); // Datei komplett lesen
    final lines = const LineSplitter().convert(content); // in Zeilen splitten
    for (final line in lines) {
      yield line; // Zeile für Zeile zurückgeben
    }
  }

  @override
  Future<void> writeAsBytes(Uint8List data) async {
    final handle = await _getHandle(create: true);
    final writable = await handle.createWritable().toDart;
    await writable.write(data.buffer.toJS).toDart;
    await writable.close().toDart;
    await _fsIndex.put(_path);
  }

  @override
  Future<void> writeAsString(String content, {bool append = false}) async {
    if (append) {
      // Vorhandenen Inhalt laden und anhängen
      String existing = '';
      if (await exists()) {
        existing = await readAsString();
      }
      await writeAsBytes(utf8.encode(existing + content));
    } else {
      await writeAsBytes(utf8.encode(content));
    }
    await _fsIndex.put(_path);
  }

  @override
  Future<void> delete() async {
    try {
      final parentDir = await _getParentDir();
      final segments = _path.split('/').where((s) => s.isNotEmpty).toList();
      await parentDir.removeEntry(segments.last).toDart;
    } catch (_) {
      // Ignorieren wenn Datei nicht existiert
    }
    _fsIndex.remove(_path);
  }

  @override
  Future<AppFile> copy(String newPath) async {
    final bytes = await readAsBytes();
    final target = AppFileWeb(newPath);
    await target.writeAsBytes(bytes);
    return target;
  }

  @override
  Future<AppFile> rename(String newPath) async {
    final copy = await this.copy(newPath);
    await delete();
    return copy;
  }
}

/// Web-Implementierung von [AppDirectory] auf Basis des Origin-Private File System (OPFS).
///
/// - OPFS kennt keine echten Ordner. Ein Verzeichnis "existiert", wenn mindestens eine Datei darin existiert.
/// - Das direkte Durchsuchen des OPFS ist nicht möglich. Um das Auflisten der Dateien trotzdem zu ermöglichen,
///   wird eine `.index.json` durch `AppFileWeb` gepflegt.
class AppDirectoryWeb implements AppDirectory {
  @override
  final String path;
  static const String indexFileName = '.index.json';

  AppDirectoryWeb(this.path);

  @override
  Future<bool> exists() async {
    // Prüfen, ob der Ordner im Index existiert
    final files = await _fsIndex.list(path);
    return files.isNotEmpty;
  }

  @override
  Future<List<AppFile>> list({bool recursive = false}) async {
    final files = await _fsIndex.list(path, recursive: recursive);
    return files.map((f) => AppFileWeb(f)).toList();
  }
}

/// Web-Implementierung des [AppFilePicker] via HTML `<input type="file">`.
///
/// Da der Browser keine Dateipfade preisgibt, liefert der Picker [AppFileMemory]-
/// Instanzen, die die Bytes der ausgewählten Dateien im Speicher halten.
class AppFilePickerWeb implements AppFilePicker {

  @override
  Future<List<AppFile>> pickFiles({
    List<String>? allowedExtensions,
    bool allowMultiple = false,
  }) async {
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..multiple = allowMultiple;

    if (allowedExtensions != null && allowedExtensions.isNotEmpty) {
      input.accept = allowedExtensions.map((e) => '.$e').join(',');
    }

    // Picker öffnen und auf Auswahl warten
    final files = await _pickFromInput(input);
    return files;
  }

  @override
  Future<List<AppFile>> pickDirectory() async {
    // Verzeichnis-Picker ist im Browser nicht zuverlässig verfügbar
    return [];
  }

  /// Fügt das Input-Element ins DOM, öffnet den Picker und liest die Bytes.
  Future<List<AppFile>> _pickFromInput(web.HTMLInputElement input) async {
    final completer = Completer<List<AppFile>>();

    input.onchange = (web.Event _) {
      () async {
        final fileList = input.files;
        if (fileList == null || fileList.length == 0) {
          if (!completer.isCompleted) completer.complete([]);
          return;
        }
        final result = <AppFile>[];
        for (int i = 0; i < fileList.length; i++) {
          final file = fileList.item(i);
          if (file == null) continue;
          final bytes = await _readFileBytes(file);
          result.add(AppFileMemory(file.name, bytes));
        }
        if (!completer.isCompleted) completer.complete(result);
      }();
    }.toJS;

    // Abbruch: wenn das Window wieder fokussiert wird ohne Datei-Auswahl
    web.window.addEventListener(
      'focus',
      (web.Event _) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!completer.isCompleted) completer.complete([]);
        });
      }.toJS,
    );

    input.click();
    return completer.future;
  }

  /// Liest eine Browser-`File` als `Uint8List`.
  Future<Uint8List> _readFileBytes(web.File file) async {
    final buffer = await file.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }
}

/// Repräsentiert einen baumartigen Dateisystem-Index für OPFS.
/// Jeder Knoten ist entweder:
/// - ein Ordner (Map)
/// - oder eine Datei (bool oder null)
///
/// Beispielstruktur:
/// {
///   "temp": {
///     "1234": {
///       "foo": {
///         "baz.txt": true
///       }
///     }
///   }
/// }
///
/// Öffentliche Methoden:
/// - [put] fügt Dateien hinzu und legt Ordner automatisch an.
/// - [remove] löscht Dateien und entfernt leere Ordner.
/// - [list] listet Dateien eines Ordners (optional rekursiv).
class _FsIndex {
  static const String indexFileName = '.index.json';

  /// Gemeinsamer Cache für alle Instanzen.
  static Map<String, dynamic>? _cachedIndex;

  /// Lädt den Index einmalig aus der Datei.
  Future<Map<String, dynamic>> _load() async {
    if (_cachedIndex != null) return _cachedIndex!;
    final file = createAppFile(indexFileName);
    if (!await file.exists()) {
      _cachedIndex = {};
      return _cachedIndex!;
    }
    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      _cachedIndex = {};
      return _cachedIndex!;
    }
    final decoded = jsonDecode(content);
    _cachedIndex = Map<String, dynamic>.from(decoded as Map);
    return _cachedIndex!;
  }

  /// Speichert den Cache zurück in die Datei.
  Future<void> _save(Map<String, dynamic> index) async {
    _cachedIndex = index;
    final file = createAppFile(indexFileName);
    await file.writeAsString(jsonEncode(index));
  }

  // --- Öffentliche Methoden ---

  /// Fügt eine Datei in den Index ein.
  ///
  /// Beispiel:
  /// put("temp/1234/foo/baz.txt")
  ///
  /// Legt automatisch alle Zwischenordner an:
  /// "temp" → "1234" → "foo" → "baz.txt"
  Future<void> put(String path) async {
    final index = await _load();
    final parts = path.split('/');
    Map<String, dynamic> node = index;

    // Ordnerkette anlegen
    for (int i = 0; i < parts.length - 1; i++) {
      node = Map<String, dynamic>.from(
        node.putIfAbsent(parts[i], () => <String, dynamic>{}) as Map,
      );
    }

    // Datei markieren
    node[parts.last] = true;
    await _save(index);
  }

  /// Entfernt eine Datei aus dem Index.
  ///
  /// Löscht automatisch leere Ordner, wenn keine weiteren Einträge vorhanden sind.
  Future<void> remove(String path) async {
    final index = await _load();
    final parts = path.split('/');

    List<Map<String, dynamic>> stack = [index];
    Map<String, dynamic> node = index;

    // Ordnerkette durchlaufen
    for (int i = 0; i < parts.length - 1; i++) {
      final next = node[parts[i]];
      if (next is! Map) return; // Pfad existiert nicht
      node = Map<String, dynamic>.from(next);
      stack.add(node);
    }

    // Datei löschen
    node.remove(parts.last);

    // Leere Ordner rückwärts entfernen
    for (int i = parts.length - 2; i >= 0; i--) {
      final parent = stack[i];
      final key = parts[i];
      final child = parent[key];
      if (child is Map && child.isEmpty) {
        parent.remove(key);
      } else {
        break;
      }
    }

    await _save(index);
  }

  /// Listet alle Dateien eines Ordners.
  ///
  /// Wenn [recursive] = false → nur Dateien direkt unterhalb des Ordners.
  /// Wenn [recursive] = true → alle Dateien im gesamten Unterbaum.
  ///
  /// Beispiel:
  /// list("temp/1234") → []
  /// list("temp/1234", recursive: true) → ["temp/1234/foo/baz.txt"]
  Future<List<String>> list(String path, {bool recursive = false}) async {
    final index = await _load();
    final node = _resolveNode(index, path);
    if (node == null) return [];

    if (!recursive) {
      return node.entries
          .where((e) => e.value is! Map)
          .map((e) => '$path/${e.key}')
          .toList();
    }

    final result = <String>[];
    _walk(node, path, result);
    return result;
  }

  // --- Interne Hilfsfunktionen ---

  /// Findet den Knoten für einen gegebenen Pfad.
  Map<String, dynamic>? _resolveNode(Map<String, dynamic> root, String path) {
    if (path.isEmpty) return root;
    Map<String, dynamic> node = root;
    for (final part in path.split('/')) {
      final next = node[part];
      if (next is! Map) return null;
      node = Map<String, dynamic>.from(next);
    }
    return node;
  }

  /// Rekursive Tiefensuche durch den Baum.
  void _walk(Map<String, dynamic> node, String base, List<String> out) {
    node.forEach((name, value) {
      final full = base.isEmpty ? name : '$base/$name';
      if (value is Map) {
        _walk(Map<String, dynamic>.from(value), full, out);
      } else {
        out.add(full);
      }
    });
  }
}

// ------------------------------------------------------------------------

/// Erzeugt eine [AppFile]-Instanz für den angegebenen Pfad (Web/OPFS).
AppFile createAppFile(String path) => AppFileWeb(path);

/// Erzeugt eine [AppDirectory]-Instanz für den angegebenen Pfad (Web/OPFS).
AppDirectory createAppDirectory(String path) => AppDirectoryWeb(path);

/// Liefert ein temporäres Verzeichnis (Web/OPFS).
Future<AppDirectory> createTempAppDirectory() => Future.value(AppDirectoryWeb(p.join('temp', Uuid().v4())));

/// Liefert eine temporäre Datei in einem temporären Verzeichnis (Web/OPFS).
/// Wenn filename nicht angegeben ist, wird eine UUID als Dateiname verwendet.
Future<AppFile> createTempAppFile([String? filename]) {
  final path = p.join('temp', Uuid().v4(), filename ?? Uuid().v4());
  return Future.value(AppFileWeb(path));
}

/// Erzeugt eine [AppFilePicker]-Instanz (Web/OPFS).
AppFilePicker createAppFilePicker() => AppFilePickerWeb();
