import 'dart:convert';
import 'dart:typed_data';

/// Plattformunabhängige Abstraktion für Dateizugriffe.
///
/// - Nativ (Android, iOS, Windows, macOS, Linux): `dart:io File`
/// - Web: Origin-Private File System (OPFS)
///
/// Instanzen werden ausschließlich über [createAppFile] erzeugt.
abstract class AppFile {

  /// Gibt eine nicht existierende Datei zurück.
  const factory AppFile.none() = _AppFileNone;

  /// Der vollständige Pfad zur Datei (plattformabhängig).
  String get path;

  /// Der Dateiname ohne Verzeichnispfad.
  String get name;

  /// Der MIME-Typ.
  String get mime;

  /// Gibt an, ob die Datei existiert.
  Future<bool> exists();

  /// Liest den gesamten Dateiinhalt als Bytes.
  Future<Uint8List> readAsBytes();

  /// Liest den gesamten Dateiinhalt als UTF-8 String.
  Future<String> readAsString();

  /// Liest den Dateiinhalt als Liste von Zeilen.
  Future<List<String>> readAsLines();

  /// Liest die Datei zeilenweise als Stream ein (UTF-8).
  ///
  /// Im Gegensatz zu [readAsLines] wird hier nicht die gesamte Datei auf einmal in
  /// den Arbeitsspeicher geladen. Das ist besonders bei großen Dateien effizienter.
  Stream<String> openReadLines();

  /// Schreibt Bytes in die Datei.
  /// Überschreibt vorhandenen Inhalt.
  Future<void> writeAsBytes(Uint8List data);

  /// Schreibt einen String in die Datei (UTF-8).
  /// Mit [append] = true wird an vorhandenen Inhalt angehängt.
  Future<void> writeAsString(String content, {bool append = false});

  /// Löscht die Datei. Kein Fehler, wenn sie nicht existiert.
  Future<void> delete();

  /// Kopiert die Datei nach [newPath] und gibt die neue [AppFile]-Instanz zurück.
  Future<AppFile> copy(String newPath);

  /// Benennt die Datei um / verschiebt sie nach [newPath].
  /// Gibt die neue [AppFile]-Instanz zurück.
  Future<AppFile> rename(String newPath);
}

/// Repräsentiert eine nicht existierende Datei.
class _AppFileNone implements AppFile {
  const _AppFileNone();

  @override
  String get path => '';

  @override
  String get name => '';

  @override
  String get mime => '';

  @override
  Future<bool> exists() async => false;

  @override
  Future<Uint8List> readAsBytes() async => Uint8List(0);

  @override
  Future<String> readAsString() async => '';

  @override
  Future<List<String>> readAsLines() async => [];

  @override
  Stream<String> openReadLines() async* {}

  @override
  Future<void> writeAsBytes(Uint8List data) async {}

  @override
  Future<void> writeAsString(String text, {bool append = false}) async {}

  @override
  Future<void> delete() async {}

  @override
  Future<AppFile> copy(String newPath) async => _AppFileNone();

  @override
  Future<AppFile> rename(String newPath) async => _AppFileNone();

  @override
  Future<void> download() async {}
}

/// Im-Memory-Implementierung von [AppFile].
///
/// Wird vom Web-FilePicker verwendet, da der Browser ausgewählte Dateien nur als Bytes liefert – ohne OPFS-Pfad.
/// Kann auch für Tests verwendet werden.
class AppFileMemory implements AppFile {
  final String _path;
  Uint8List _bytes;

  AppFileMemory(this._path, this._bytes);

  @override
  String get path => _path;

  @override
  String get name {
    final segments = _path.replaceAll('\\', '/').split('/');
    return segments.last;
  }

  @override
  String get mime => getMimeType(_path);

  @override
  Future<bool> exists() async => true;

  @override
  Future<Uint8List> readAsBytes() async => _bytes;

  @override
  Future<String> readAsString() async {
    // `allowMalformed: true` ersetzt ungültige Byte-Sequenzen durch das Unicode-Ersatzzeichen `\uFFFD` statt
    // eine Exception zu werfen – sinnvoll für Text-Dateien die eventuell eine andere Kodierung als UTF-8 haben.
    return utf8.decode(_bytes, allowMalformed: true);
  }

  @override
  Future<List<String>> readAsLines() async {
    final content = await readAsString();
    return content.split('\n');
  }

  @override
  Stream<String> openReadLines() async* {
    // Implementierung ist identisch zu AppFileWeb
    final content = await readAsString();
    final lines = const LineSplitter().convert(content);
    for (final line in lines) {
      yield line;
    }
  }

  @override
  Future<void> writeAsBytes(Uint8List data) async {
    _bytes = data;
  }

  @override
  Future<void> writeAsString(String content, {bool append = false}) async {
    final existing = append ? await readAsString() : '';
    _bytes = utf8.encode(existing + content);
  }

  @override
  Future<void> delete() async {
    // Im-Memory: kein Dateisystem-Eintrag zu löschen
  }

  @override
  Future<AppFile> copy(String newPath) async {
    return AppFileMemory(newPath, Uint8List.fromList(_bytes));
  }

  @override
  Future<AppFile> rename(String newPath) async {
    return AppFileMemory(newPath, _bytes);
  }
}

/// Plattformunabhängige Abstraktion für ein Verzeichnis.
abstract class AppDirectory {

  /// Vollständiger Pfad (native) oder logischer Pfad (Web).
  String get path;

  /// Ordnername (nur die letzte Ebene).
  String get name;

  /// Prüft, ob das Verzeichnis existiert.
  Future<bool> exists();

  /// Listet Dateien im Verzeichnis auf.
  /// - Wenn [recursive] = false → nur Dateien direkt im Ordner.
  /// - Wenn [recursive] = true  → alle Dateien im gesamten Unterbaum.
  Future<List<AppFile>> list({bool recursive = false});
}

/// Plattformunabhängige Abstraktion für den Datei-Picker.
///
/// Instanzen werden ausschließlich über [createAppFilePicker] erzeugt.
abstract class AppFilePicker {

  /// Öffnet den Datei-Picker und lässt den Benutzer eine oder mehrere Dateien auswählen.
  ///
  /// [allowedExtensions] schränkt die auswählbaren Dateitypen ein (ohne Punkt, z.B. `['json', 'xml']`).
  /// [allowMultiple] erlaubt die Auswahl mehrerer Dateien.
  ///
  /// Gibt eine Liste der ausgewählten Dateien zurück.
  /// Gibt eine leere Liste zurück, wenn der Benutzer abbricht.
  Future<List<AppFile>> pickFiles({
    List<String>? allowedExtensions,
    bool allowMultiple = false,
  });

  /// Öffnet den Verzeichnis-Picker und gibt alle enthaltenen Dateien zurück.
  ///
  /// Wird auf Web nicht unterstützt (gibt leere Liste zurück).
  Future<List<AppFile>> pickDirectory();
}

// ------------------------------------------------------------------------
// --- Helper ---
// ------------------------------------------------------------------------

/// Ermittelt den MIME-Typ basierend auf der Dateiendung.
String getMimeType(String filename) {
  // @formatter:off
  final ext = filename.split('.').last.toLowerCase();
  switch (ext) {
    // Bild
    case 'jpg': return 'image/jpeg';
    case 'jpeg': return 'image/jpeg';
    case 'png': return 'image/png';
    case 'gif': return 'image/gif';
    case 'bmp': return 'image/bmp';
    case 'webp': return 'image/webp';
    // Text
    case 'txt': return 'text/plain';
    case 'md': return 'text/markdown';
    case 'html': return 'text/html';
    case 'csv': return 'text/csv';
    case 'vcf': return 'text/vcard';
    // Audio
    case 'mp3': return 'audio/mpeg';
    case 'wav': return 'audio/wav';
    case 'flac': return 'audio/flac';
    case 'aac': return 'audio/aac';
    case 'ogg': return 'audio/ogg';
    // Video
    case 'mp4': return 'video/mp4';
    case 'avi': return 'video/x-msvideo';
    case 'mov': return 'video/quicktime';
    case 'mkv': return 'video/x-matroska';
    case 'webm': return 'video/webm';
    // PDF
    case 'pdf': return 'application/pdf';
    // Word
    case 'doc': return 'application/msword';
    case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    // Excel
    case 'xls': return 'application/vnd.ms-excel';
    case 'xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    // Powerpoint
    case 'ppt': return 'application/vnd.ms-powerpoint';
    case 'pptx': return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    // Archiv
    case 'zip': return 'application/zip';
    case 'rar': return 'application/vnd.rar';
    case 'tar': return 'application/x-tar';
    case '7z': return 'application/x-7z-compressed';
    // Fallback
    default: return 'application/octet-stream';
  }
  // @formatter:on
}