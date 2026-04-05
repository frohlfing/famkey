import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:privault/core/logger.dart';
import 'package:privault/features/main/import/parser.dart';
import 'package:xml/xml.dart';

/// Ein Parser für KeePass XML (2.x) Exportdateien.
///
/// Diese Klasse implementiert die [Parser]-Schnittstelle und ist dafür verantwortlich, eine
/// KeePass-XML-Datei einzulesen und in eine Liste von [ParsedEntry]-Objekten umzuwandeln
class KeepassXmlParser implements Parser {
  /// Pfad zur Datei
  final String path;

  /// Map von UUIDs zu ihrer Zeilennummer
  Map<String, int> _uuidLineMap = {};

  /// Binaries der Dateianhänge
  Map<String, Uint8List> _binaries = {};

  /// Konstruktor
  KeepassXmlParser(this.path);

  @override
  Future<ParsedPayload?> parse() async {
    try {
      // Datei öffnen und Inhalt lesen
      String fileContent;
      try {
        fileContent = await File(path).readAsString();
      } on FileSystemException catch (e) {
        throw ParserError('Die Datei konnte nicht geöffnet werden.', path: path, originalError: e);
        _errorText = 'Die Datei konnte nicht geöffnet werden.';
        Logger().error('Parser-Fehler: $_errorText', context: {'path': path, 'error': e});
        return null;
      }

      // Einmaliger Scan der Datei, um eine Map der UUID-Zeilennummern zu erstellen.
      _uuidLineMap = await _createUuidLineMap(fileContent);

      XmlDocument xml;
      try {
        xml = XmlDocument.parse(fileContent);
      } on XmlException catch (e) {
        _errorText = 'Die XML-Struktur der Datei ist fehlerhaft.';
        Logger().error('Parser-Fehler: $_errorText', context: {'path': path, 'error': e});
        return null;
      }

      // Dateianhänge aus `<Meta><Binaries>`-Block dekodieren
      _binaries = <String, Uint8List>{};
      final binariesElement = xml.rootElement.findElements('Meta').firstOrNull?.findElements('Binaries').firstOrNull;
      if (binariesElement != null) {
        for (final bin in binariesElement.findElements('Binary')) {
          final id = bin.getAttribute('ID');
          if (id == null) continue;
          Uint8List blob;
          try {
            blob = base64.decode(bin.innerText.trim());
          } on FormatException catch (e) {
            final lineNumber = await _findLineNumberOfText(path, '<Binary ID="$id"');
            _errorText = 'Anhang ID=$id konnte nicht dekodiert werden${lineNumber != null ? ' (Zeile $lineNumber)' : ''}.' ;
            Logger().error('Parser-Fehler: $_errorText', context: {'path': path, 'error': e});
            return null;
          }
          if (bin.getAttribute('Compressed') == 'True') {
            try {
              blob = Uint8List.fromList(gzip.decode(blob));
            } on FormatException catch (e) {
              final lineNumber = await _findLineNumberOfText(path, '<Binary ID="$id"');
              _errorText = 'Anhang ID=$id konnte nicht dekomprimiert werden${lineNumber != null ? ' (Zeile $lineNumber)' : ''}.';
              Logger().error('Parser-Fehler: $_errorText', context: {'path': path, 'error': e});
              return null;
            }
          }
          _binaries[id] = blob;
        }
      }

      // Root-Gruppe finden
      final rootGroup = xml.rootElement.findElements('Root').firstOrNull?.findElements('Group').firstOrNull;
      if (rootGroup == null) {
        _errorText = '<Root><Group>`-Element fehlt.';
        Logger().error('Parser-Fehler: $_errorText', context: {'path': path});
        return null;
      }

      // Gruppendaten rekursiv parsen
      // Die Root-Gruppe (die Gruppe direkt unter Root) hat den Namen des Tresors. Die Kategorie lassen wir daher leer.
      return _parseGroups(rootGroup, '');

    } catch (e, st) {
      _errorText = 'Ein unerwarteter Fehler ist aufgetreten. Die Datei ist möglicherweise beschädigt.';
      Logger().fatal('Parser-Fehler: $_errorText', context: {'path': path, 'error': e}, stack: st);
      return null;
    }
  }

  /// Verarbeitet rekursiv Gruppen und deren Einträge.
  /// Im Fall eines Fehlers wird null zurückgegeben.
  Future<List<ParsedEntry>?> _parseGroups(XmlElement group, String category) async {
    final result = <ParsedEntry>[];

    // Einträge in der aktuellen Gruppe verarbeiten
    for (final entry in group.findElements('Entry')) {
      final parsedEntry = await _parseEntry(entry, category);
      if (parsedEntry == null) return null;
      result.add(parsedEntry);
    }

    // Rekursiv in Untergruppen absteigen
    for (final subGroup in group.findElements('Group')) {
      var subGroupName = subGroup.findElements('Name').firstOrNull?.innerText ?? '';
      final nestedCategory = category.isNotEmpty ? '$category/$subGroupName' : subGroupName;
      final parsedEntries = await _parseGroups(subGroup, nestedCategory);
      if (parsedEntries == null) return null;
      result.addAll(parsedEntries);
    }

    return result;
  }

  /// Parst ein einzelnes `<Entry>`-Element in ein [ParsedEntry]-Objekt.
  Future<ParsedEntry?> _parseEntry(XmlElement entry, String category) async {
    // UUID ermitteln
    String? uuid;
    final base64Uuid = entry.findElements('UUID').firstOrNull?.innerText ?? '';
    final lineNumber = _uuidLineMap[base64Uuid];
    if (base64Uuid.isNotEmpty) {
        Uint8List bytes;
        try {
          bytes = base64.decode(base64Uuid);
        } on FormatException catch (e) {
          _errorText = 'UUID "$base64Uuid" konnte nicht dekodiert werden${lineNumber != null ? ' (Zeile $lineNumber)' : ''}.';
          Logger().error('Parser-Fehler: $_errorText', context: {'path': path, 'error': e});
          return null;
        }
        if (bytes.length != 16) {
          _errorText = 'UUID "$base64Uuid" ist ungültig. 16 Bytes erwartet${lineNumber != null ? ' (Zeile $lineNumber)' : ''}.';
          Logger().error('Parser-Fehler: $_errorText', context: {'path': path});
          return null;
        }
        final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        uuid = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    }

    // `<String>`-Elemente einlesen
    final strings = _parseStringElements(entry);

    // Zeitpunkt der letzten Änderung ermitteln
    final times = entry.findElements('Times').firstOrNull;
    final lastModStr = times?.findElements('LastModificationTime').firstOrNull?.innerText ?? times?.findElements('CreationTime').firstOrNull?.innerText;
    final updatedAt = DateTime.tryParse(lastModStr ?? '')?.toUtc();

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

    // Anhänge des Eintrags extrahieren
    final attachments = <ParsedAttachment>[];
    for (final bin in entry.findElements('Binary')) {
      final fileName = bin.findElements('Key').firstOrNull?.innerText;
      final ref = bin.findElements('Value').firstOrNull?.getAttribute('Ref');
      if (fileName == null || ref == null) continue;
      final binary = _binaries[ref];
      if (binary == null) {
        final refLineNumber = await _findLineNumberOfText(path, '<Value Ref="$ref"');
        _errorText = 'Anhang "$fileName" verweist auf eine nicht existierende Binär-Referenz "$ref"${refLineNumber != null ? ' (Zeile $refLineNumber)' : ''}.';
        Logger().error('Parser-Fehler: $_errorText', context: {'path': path});
        return null;
      }
      attachments.add(ParsedAttachment(binary: binary, filename: fileName));
    }

    return ParsedEntry(
      uuid: uuid,
      category: category.isEmpty ? null : category,
      title: strings['Title'],
      username: strings['UserName'],
      password: strings['Password'],
      passwordTimestamp: passwordTimestamp,
      url: strings['URL'],
      notes: strings['Notes'],
      updatedAt: updatedAt,
      attachments: attachments.isEmpty ? null : attachments,
      lineNumber: lineNumber,
    );
  }

  /// Extrahiert alle `<String>`-Elemente eines Eintrags in eine Map.
  Map<String, String> _parseStringElements(XmlElement parent) {
    return {
      for (final s in parent.findElements('String'))
        if (s.findElements('Key').isNotEmpty && s.findElements('Value').isNotEmpty)
          s.findElements('Key').first.innerText: s.findElements('Value').first.innerText,
    };
  }

  /// Erstellt eine Map von UUIDs zu ihrer Zeilennummer, indem die Datei einmalig am Anfang durchlaufen wird.
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
}