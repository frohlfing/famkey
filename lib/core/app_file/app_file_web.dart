import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:famkey/core/app_file.dart';
import 'package:uuid/uuid.dart';
import 'package:web/web.dart' as web;

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

  @override
  String get mime => getMimeType(_path);

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
    // `allowMalformed: true` ersetzt ungültige Byte-Sequenzen durch das Unicode-Ersatzzeichen `\uFFFD` statt
    // eine Exception zu werfen – sinnvoll für Text-Dateien die eventuell eine andere Kodierung als UTF-8 haben.
    return utf8.decode(bytes, allowMalformed: true);
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

// --- type-Deklarationen für AppDirectoryWeb.list() ---

// JS-Interop für den AsyncIterator von FileSystemDirectoryHandle.entries()
extension type _IteratorResult(JSObject _) implements JSObject {
  external JSBoolean get done;
  external JSArray<JSAny> get value; // [JSString name, FileSystemHandle handle]
}

extension type _AsyncIterator(JSObject _) implements JSObject {
  external JSPromise<_IteratorResult> next();
}

// entries() fehlt in den package:web-Bindings → manuell deklarieren
extension _DirectoryEntries on web.FileSystemDirectoryHandle {
  external _AsyncIterator entries();
}

/// Web-Implementierung von [AppDirectory] auf Basis des Origin-Private File System (OPFS).
///
/// OPFS kennt keine echten Ordner. Ein Verzeichnis "existiert", wenn mindestens eine Datei darin existiert.
class AppDirectoryWeb implements AppDirectory {
  AppDirectoryWeb(this.path);

  @override
  final String path;

  @override
  String get name => p.basename(path);

  /// Navigiert vom OPFS-Root zum Zielverzeichnis.
  /// Gibt null zurück wenn das Verzeichnis nicht existiert.
  Future<web.FileSystemDirectoryHandle?> _resolveDir() async {
    final root = await web.window.navigator.storage.getDirectory().toDart;
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    web.FileSystemDirectoryHandle dir = root;
    for (final segment in segments) {
      try {
        dir = await dir.getDirectoryHandle(segment, web.FileSystemGetDirectoryOptions(create: false)).toDart;
      } on web.DOMException catch (e) { // Browser-Fehler aus package:web
        if (e.name == 'NotFoundError') return null; // 'NotFoundError' ist laut Web-Spec garantiert wenn ein Verzeichnis nicht existiert.
        rethrow;
      }
    }
    return dir;
  }

  @override
  Future<bool> exists() async {
    final dir = await _resolveDir();
    if (dir == null) return false;
    // Verzeichnis existiert – prüfen ob es mindestens einen Eintrag hat
    final iter = dir.entries();
    final first = await iter.next().toDart;
    return !first.done.toDart;
  }

  @override
  Future<List<AppFile>> list({bool recursive = false}) async {
    final dir = await _resolveDir();
    if (dir == null) return [];
    final result = <AppFile>[];
    await _collectEntries(dir, path, result, recursive: recursive);
    return result;
  }

  /// Iteriert über die OPFS-API alle Einträge eines Verzeichnisses via AsyncIterator.
  Future<void> _collectEntries(web.FileSystemDirectoryHandle dir, String currentPath, List<AppFile> result, {required bool recursive}) async {
    final iter = dir.entries();
    while (true) {
      final next = await iter.next().toDart;
      if (next.done.toDart) break;

      final entry  = next.value;
      final name   = (entry[0] as JSString).toDart;
      final handle = entry[1];
      final full   = '$currentPath/$name';

      // 'kind' ist entweder 'file' oder 'directory'
      final kind = (handle as web.FileSystemHandle).kind;

      if (kind == 'file') {
        result.add(AppFileWeb(full));
      } else if (kind == 'directory' && recursive) {
        await _collectEntries(handle as web.FileSystemDirectoryHandle, full, result, recursive: true);
      }
    }
  }
}

/// Web-Implementierung des [AppFilePicker] via HTML `<input type="file">`.
///
/// Da der Browser keine Dateipfade preisgibt, liefert der Picker [AppFileMemory]-
/// Instanzen, die die Bytes der ausgewählten Dateien im Speicher halten.
class AppFilePickerWeb implements AppFilePicker {

  @override
  Future<List<AppFile>> pickFiles({List<String>? allowedExtensions, bool allowMultiple = false}) async {
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
    web.window.addEventListener('focus', (web.Event _) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!completer.isCompleted) completer.complete([]);
      });
    }.toJS);

    input.click();
    return completer.future;
  }

  /// Liest eine Browser-`File` als `Uint8List`.
  Future<Uint8List> _readFileBytes(web.File file) async {
    final buffer = await file.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
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

/// Löst einen Browser-Download aus.
Future<void> downloadAppFile(AppFile file) async {
  final bytes = await file.readAsBytes();
  final blob = web.Blob([bytes.buffer.toJS].toJS, web.BlobPropertyBag(type: 'application/octet-stream'));
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = file.name
    ..click();
  Future.delayed(const Duration(seconds: 1), () => web.URL.revokeObjectURL(url));
}