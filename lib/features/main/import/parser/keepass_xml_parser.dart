import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:privault/features/main/import/parser.dart';
import 'package:xml/xml.dart';

/// Ein Parser für KeePass XML (2.x) Exportdateien.
///
/// Diese Klasse implementiert die [Parser]-Schnittstelle.
/// Sie überführt die Datei in eine Liste von [ParsedEntry]-Objekten.
/// Im Fehlerfall wirft sie einen [ParserError].
class KeepassXmlParser implements Parser {
  /// Pfad zur Datei
  final String _path;

  /// Zeilennummern der base64-kodierten UUIDs
  Map<String, int> _uuidLineMap = {};

  /// Binaries der Dateianhänge
  Map<String, Uint8List> _binaries = {};

  /// Konstruktor
  KeepassXmlParser(this._path);

  @override
  Future<ParsedPayload> parse() async {
    // Datei öffnen und Inhalt lesen
    String fileContent;
    try {
      fileContent = await File(_path).readAsString();
    } on FileSystemException catch (e) {
      throw ParserError('Die Datei konnte nicht geöffnet werden.', path: _path, originalErrorMessage: e.message);
    }

    // Einmaliger Scan der Datei, um eine Map von der base64-kodierten UUIDs zu ihrer Zeilennummer zu erstellen.
    _uuidLineMap = await _createUuidLineMap(fileContent);

    // XML parsen
    XmlDocument xml;
    try {
      xml = XmlDocument.parse(fileContent);
    } on XmlException catch (e) {
      throw ParserError('Die XML-Struktur der Datei ist fehlerhaft.', path: _path, originalErrorMessage: e.message);
    }

    // Dateianhänge aus `<Meta><Binaries>`-Block dekodieren
    _binaries = await _parseBinaries(xml);

    // Gruppendaten rekursiv parsen
    final rootGroup = xml.rootElement.findElements('Root').firstOrNull?.findElements('Group').firstOrNull;
    if (rootGroup == null) {
      throw ParserError('Das Element `<Root><Group>` fehlt.', path: _path);
    }
    return _parseGroups(rootGroup, ''); // Die Root-Gruppe (die Gruppe direkt unter Root) hat den Namen des Tresors. Die Kategorie lassen wir daher leer.
  }

  /// Erstellt eine Map von base64-kodierte UUIDs zu ihrer Zeilennummer.
  Future<Map<String, int>> _createUuidLineMap(String fileContent) async {
    final map = <String, int>{};
    final lines = const LineSplitter().convert(fileContent);
    final uuidRegex = RegExp(r'<UUID>(.*?)<\/UUID>');
    for (int i = 0; i < lines.length; i++) {
      final match = uuidRegex.firstMatch(lines[i]);
      if (match != null && match.groupCount > 0) {
        final uuid = match.group(1)!;
        map[uuid] = i + 1; // Zeilennummern sind 1-basiert
      }
    }
    return map;
  }

  /// Dekodiert Dateianhänge aus `<Meta><Binaries>`-Block speichert sie in eine Map
  Future<Map<String, Uint8List>> _parseBinaries(XmlDocument xml) async {
    final map = <String, Uint8List>{};
    final binariesElement = xml.rootElement.findElements('Meta').firstOrNull?.findElements('Binaries').firstOrNull;
    if (binariesElement != null) {
      for (final bin in binariesElement.findElements('Binary')) {
        final id = bin.getAttribute('ID');
        if (id == null) continue;
        Uint8List blob;
        try {
          blob = base64.decode(bin.innerText.trim());
        } on FormatException catch (e) {
          final lineNumber = await _findLineNumberOfText(_path, '<Binary ID="$id"');
          throw ParserError('Anhang ID=$id konnte nicht dekodiert werden.', path: _path, lineNumber: lineNumber, originalErrorMessage: e.message);
        }
        if (bin.getAttribute('Compressed') == 'True') {
          try {
            blob = Uint8List.fromList(gzip.decode(blob));
          } on FormatException catch (e) {
            final lineNumber = await _findLineNumberOfText(_path, '<Binary ID="$id"');
            throw ParserError('Anhang ID=$id konnte nicht dekomprimiert werden.', path: _path, lineNumber: lineNumber, originalErrorMessage: e.message);
          }
        }
        map[id] = blob;
      }
    }
    return map;
  }

  /// Sucht in einer Datei nach einem bestimmten Text und gibt die Zeilennummer zurück.
  /// Verwendet einen Stream, um die Datei effizient zu lesen.
  Future<int?> _findLineNumberOfText(String filePath, String searchText) async {
    try {
      final file = File(filePath);
      int lineNumber = 1;
      await for (final line in file.openRead().transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.contains(searchText)) return lineNumber;
        lineNumber++;
      }
    } catch (_) {
      // Ignorieren, da dies eine Hilfsfunktion ist. Im Fehlerfall geben wir einfach null zurück.
    }
    return null;
  }

  /// Verarbeitet rekursiv Gruppen und deren Einträge.
  /// Im Fall eines Fehlers wird null zurückgegeben.
  Future<List<ParsedEntry>> _parseGroups(XmlElement group, String category) async {
    final result = <ParsedEntry>[];

    // Einträge in der aktuellen Gruppe verarbeiten
    for (final entry in group.findElements('Entry')) {
      final parsedEntry = await _parseEntry(entry, category);
      result.add(parsedEntry);
    }

    // Rekursiv in Untergruppen absteigen
    for (final subGroup in group.findElements('Group')) {
      var subGroupName = subGroup.findElements('Name').firstOrNull?.innerText.trim() ?? '';
      final nestedCategory = category.isNotEmpty ? '$category/$subGroupName' : subGroupName;
      final parsedEntries = await _parseGroups(subGroup, nestedCategory);
      result.addAll(parsedEntries);
    }

    return result;
  }

  /// Parst ein einzelnes `<Entry>`-Element in ein [ParsedEntry]-Objekt.
  Future<ParsedEntry> _parseEntry(XmlElement entry, String category) async {
    // UUID und ihre Zeilennummer ermitteln
    var (uuid, lineNumber) = _parseUuid(entry);

    // `<String>`-Elemente einlesen
    final strings = _parseStringElements(entry);

    // Zeitpunkt der letzten Änderung ermitteln
    final updatedAt = _parseUpdatedAt(entry);

    // Zeitstempel der letzten Passwortänderung ermitteln
    final passwordTimestamp = _parsePasswordTimestamp(entry);

    // Anhänge des Eintrags verarbeiten
    final attachments = await _parseAttachments(entry);

    return ParsedEntry(
      uuid,
      category: category.isEmpty ? null : category,
      title: strings['Title']?.trim(),
      username: strings['UserName']?.trim(),
      password: strings['Password'], // Passwort nicht trimmen!
      passwordTimestamp: passwordTimestamp,
      url: strings['URL']?.trim(),
      notes: strings['Notes']?.trim(),
      updatedAt: updatedAt,
      attachments: attachments,
      lineNumber: lineNumber,
    );
  }

  /// Ermittelt die UUID des Eintrags und gibt sie zusammen mit ihrer Zeilennummer zurück.
  /// Es wird eine gültige base64-kodierte UUID erwartet.
  (String uuid, int? lineNumber) _parseUuid(XmlElement entry) {
    final base64Uuid = entry.findElements('UUID').firstOrNull?.innerText ?? '';
    final lineNumber = _uuidLineMap[base64Uuid];
    if (base64Uuid.isEmpty) { // UUID ist obligatorisch
      throw ParserError('UUID fehlt.', path: _path, lineNumber: lineNumber);
    }

    Uint8List bytes;
    try {
      bytes = base64.decode(base64Uuid);
    } on FormatException catch (e) {
      throw ParserError('UUID "$base64Uuid" konnte nicht dekodiert werden.', path: _path, lineNumber: lineNumber, originalErrorMessage: e.message);
    }

    if (bytes.length != 16) {
      throw ParserError('UUID "$base64Uuid" ist ungültig. 16 Bytes erwartet.', path: _path, lineNumber: lineNumber);
    }

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final uuid = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';

    return (uuid, lineNumber);
  }

  /// Extrahiert alle `<String>`-Elemente eines Eintrags in eine Map.
  Map<String, String> _parseStringElements(XmlElement parent) {
    return {
      for (final s in parent.findElements('String'))
        if (s.findElements('Key').isNotEmpty && s.findElements('Value').isNotEmpty)
          s.findElements('Key').first.innerText: s.findElements('Value').first.innerText,
    };
  }

  /// Ermittelt den Zeitpunkt der letzten Änderung
  DateTime? _parseUpdatedAt(XmlElement entry) {
    final times = entry.findElements('Times').firstOrNull;
    final lastModStr = times?.findElements('LastModificationTime').firstOrNull?.innerText ?? times?.findElements('CreationTime').firstOrNull?.innerText;
    return DateTime.tryParse(lastModStr ?? '')?.toUtc();
  }

  /// Ermittelt den Zeitstempel der letzten Passwortänderung für einen Eintrag.
  DateTime? _parsePasswordTimestamp(XmlElement entry) {
    // Zeitstempel der letzten Passwortänderung aus der Historie ermitteln
    // Die Historie ist chronologisch, wir suchen den letzten Eintrag mit einem Passwort.
    DateTime? passwordTimestamp;
    final history = entry.findElements('History').firstOrNull;
    if (history != null) {
      for (final hist in history.findElements('Entry').toList().reversed) {
        if (_parseStringElements(hist).containsKey('Password')) {
          final timeStr = hist.findElements('Times').firstOrNull?.findElements('LastModificationTime').firstOrNull?.innerText;
          passwordTimestamp = DateTime.tryParse(timeStr ?? '')?.toUtc();
          if (passwordTimestamp != null) break;
        }
      }
    }
    return passwordTimestamp;
  }

  /// Parst die Anhänge für einen einzelnen Eintrag.
  Future<List<ParsedAttachment>?> _parseAttachments(XmlElement entry) async {
    final attachments = <ParsedAttachment>[];
    for (final bin in entry.findElements('Binary')) {
      final fileName = bin.findElements('Key').firstOrNull?.innerText.trim();
      final ref = bin.findElements('Value').firstOrNull?.getAttribute('Ref');
      if (fileName == null || ref == null) continue;
      final binary = _binaries[ref];
      if (binary == null) {
        final lineNumber = await _findLineNumberOfText(_path, '<Value Ref="$ref"');
        throw ParserError('Anhang "$fileName" verweist auf eine nicht existierende Binär-Referenz "$ref".', path: _path, lineNumber: lineNumber);
      }
      attachments.add(ParsedAttachment(binary, filename: fileName));
    }
    return attachments.isEmpty ? null : attachments;
  }
}