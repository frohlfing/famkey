import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:privault/core/app_file.dart';
import 'package:uuid/uuid.dart';

/// Implementierung von [AppFile] für eine Desktop- oder Mobile-Platform auf Basis von `dart:io File`.
class AppFileNative implements AppFile {
  final File _file;

  AppFileNative(String path) : _file = File(path);

  @override
  String get path => _file.path;

  @override
  String get name => p.basename(_file.path);

  @override
  String get mime => getMimeType(_file.path);

  @override
  Future<bool> exists() => _file.exists();

  @override
  Future<Uint8List> readAsBytes() => _file.readAsBytes();

  @override
  Future<String> readAsString() => _file.readAsString();

  @override
  Future<List<String>> readAsLines() => _file.readAsLines();

  @override
  Stream<String> openReadLines() {
    return _file.openRead() // Datei als Stream öffnen
        .transform(utf8.decoder) // die Bytes zu UTF-8 Strings dekodieren
        .transform(const LineSplitter()); // den Text so lange puffern, bis ein Zeilenumbruch erkannt wird
  }

  @override
  Future<void> writeAsBytes(Uint8List data) async {
    await _ensureParentDir();
    await _file.writeAsBytes(data);
  }

  @override
  Future<void> writeAsString(String content, {bool append = false}) async {
    await _ensureParentDir();
    await _file.writeAsString(content, mode: append ? FileMode.append : FileMode.write);
  }

  @override
  Future<void> delete() async {
    if (await _file.exists()) await _file.delete();
  }

  @override
  Future<AppFile> copy(String newPath) async {
    await _file.copy(newPath);
    return AppFileNative(newPath);
  }

  @override
  Future<AppFile> rename(String newPath) async {
    await _file.rename(newPath);
    return AppFileNative(newPath);
  }

  Future<void> _ensureParentDir() async {
    final dir = Directory(p.dirname(_file.path));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }
}

/// Nativ-Implementierung von [AppDirectory] auf Basis von `dart:io Directory`.
/// Wird auf Android, iOS, Windows, macOS und Linux verwendet.
class AppDirectoryNative implements AppDirectory {
  AppDirectoryNative(this.path);

  @override
  final String path;

  @override
  String get name => p.basename(path);

  @override
  Future<bool> exists() async {
    final dir = Directory(path);
    return dir.exists();
  }

  @override
  Future<List<AppFile>> list({bool recursive = false}) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];

    final List<AppFile> files = [];

    // `dir.list()` kann rekursiv alle Unterverzeichnisse durchlaufen.
    await for (final entity in dir.list(recursive: recursive, followLinks: false)) {
      if (entity is File) {
        files.add(AppFileNative(entity.path));
      }
    }

    return files;
  }
}

/// Nativ-Implementierung des [AppFilePicker] via `package:file_picker`.
class AppFilePickerNative implements AppFilePicker {

  @override
  Future<List<AppFile>> pickFiles({List<String>? allowedExtensions, bool allowMultiple = false}) async {
    final result = await FilePicker.platform.pickFiles(
      type: allowedExtensions != null ? FileType.custom : FileType.any,
      allowedExtensions: allowedExtensions,
      allowMultiple: allowMultiple,
    );

    if (result == null) return [];

    return result.files.where((f) => f.path != null).map((f) => AppFileNative(f.path!)).toList();
  }

  @override
  Future<List<AppFile>> pickDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return [];

    final dir = Directory(path);
    final files = await dir.list().where((e) => e is File).cast<File>().toList();

    return files.map((f) => AppFileNative(f.path)).toList();
  }
}

/// Erzeugt eine [AppFile]-Instanz für den angegebenen Pfad (nativ).
AppFile createAppFile(String path) => AppFileNative(path);

/// Erzeugt eine [AppDirectory]-Instanz für den angegebenen Pfad (nativ).
AppDirectory createAppDirectory(String path) => AppDirectoryNative(path);

/// Liefert ein temporäres Verzeichnis (nativ).
Future<AppDirectory> createTempAppDirectory() async => AppDirectoryNative((await getTemporaryDirectory()).path);

/// Liefert eine temporäre Datei in einem temporären Verzeichnis (nativ).
/// Wenn filename nicht angegeben ist, wird eine UUID als Dateiname verwendet.
Future<AppFile> createTempAppFile([String? filename]) async {
  final tempDir = await getTemporaryDirectory();
  final path = p.join(tempDir.path, filename ?? Uuid().v4());
  return AppFileNative(path);
}

/// Erzeugt eine [AppFilePicker]-Instanz (nativ).
AppFilePicker createAppFilePicker() => AppFilePickerNative();

/// Öffnet den Systemdialog zum Speichern der Datei auf der Festplatte.
/// Funktioniert sowohl für AppFileNative als auch für AppFileMemory.
Future<void> downloadAppFile(AppFile file) async {
  // 1. Die Bytes der Datei laden (egal ob von Disk oder aus dem RAM)
  final bytes = await file.readAsBytes();

  // 2. Den "Speichern unter"-Dialog aufrufen
  // FilePicker.platform.saveFile öffnet den nativen Dateimanager
  final String? outputPath = await FilePicker.platform.saveFile(
    dialogTitle: 'Datei speichern unter...',
    fileName: file.name,
    // Optional: Du könntest hier die Extension einschränken
    // type: FileType.custom,
    // allowedExtensions: [p.extension(file.path).replaceAll('.', '')],
  );

  // 3. Wenn der Nutzer nicht abgebrochen hat, die Daten schreiben
  if (outputPath != null) {
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(bytes);
  }
}
