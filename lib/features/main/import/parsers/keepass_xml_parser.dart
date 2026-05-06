import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../../../../core/app_file.dart';
import '../parser.dart';

/// Ein Parser für KeePass XML (2.x) Exportdateien.
///
/// Spezifikation: https://github.com/keepassxreboot/keepassxc-specs/blob/master/kdbx-xml/rfc.md
/// - Die Datei ist mit UTF-8 (Unicode) kodiert.
/// - Die UUID ist Base64-kodiert (z.B. `DzqV4eP8VE+rUTqV4eP8VA==`).
///   Die Dekodierung ergibt 16-Bytes, eine 32 Zeichen lange global eindeutige Hex-Zeichenfolge (im Beispiel `0f3a95e1e3fc544fab5130ea7ada6c70`).
///   Mit Bindestrichen (8‑4‑4‑4‑12) ergibt das dann das Ziel-Format (`0f3a95e1-e3fc-544f-ab51-30ea7ada6c70`).
/// - Datums-/Zeitangaben sind im ISO 8601-Format angegeben (`YYYY-MM-DDTHH:mm:ss` bzw `YYYY-MM-DDTHH:mm:ssZ`).
/// - Die Zeichen `< > & " '` sind durch `&lt;` `&gt;` `&amp;` `&quot;` `&apos;` ersetzt.
/// - Die Binärdaten der Dateianhänge sind in der XML-Datei eingebettet.
///
class KeepassXmlParser implements Parser {
  /// XML-Datei
  final AppFile _file;

  /// Zeilennummern der base64-kodierten UUIDs
  Map<String, int> _uuidLineMap = {};

  /// Binaries der Dateianhänge
  Map<String, Uint8List> _binaries = {};

  /// Konstruktor
  KeepassXmlParser(this._file);

  /// Lädt die Daten aus der Datei.
  ///
  /// Gibt im Erfolgsfall eine [ParsedPayload] zurück.
  /// Im Fehlerfall wird ein [ParserError] geworfen.
  ///
  /// Struktur der XML-Datei:
  /// ```xml
  /// <KeePassFile>
  ///   <Meta/>
  ///   <Root>
  ///     <Group/>
  ///     <DeletedObjects>
  ///   </Root>
  ///   </Meta>
  /// </KeePassFile>
  /// ```
  @override
  Future<ParsedPayload> parse() async {
    // Datei öffnen und Inhalt lesen
    String fileContent;
    try {
      fileContent = await AppFile(_file.path).readAsString();
    } catch (e) {
      throw ParserError('Die Datei konnte nicht geöffnet werden.', path: _file.path, originalErrorMessage: e.toString());
    }

    // Einmaliger Scan der Datei, um eine Map von der base64-kodierten UUIDs zu ihrer Zeilennummer zu erstellen.
    _uuidLineMap = await _createUuidLineMap(fileContent);

    // XML parsen
    XmlDocument xml;
    try {
      xml = XmlDocument.parse(fileContent);
    } on XmlException catch (e) {
      throw ParserError('Die XML-Struktur der Datei ist fehlerhaft.', path: _file.path, originalErrorMessage: e.message);
    }

    // Dateianhänge aus `<Meta><Binaries>`-Block dekodieren
    _binaries = await _parseBinaries(xml);

    // Gruppendaten rekursiv parsen
    final rootGroup = xml.rootElement.findElements('Root').firstOrNull?.findElements('Group').firstOrNull;
    if (rootGroup == null) {
      throw ParserError('Die KeePass-Datei ist fehlerhaft. `<Root><Group>` fehlt.', path: _file.path);
    }
    return _parseGroups(rootGroup, ''); // Die Root-Gruppe (die Gruppe direkt unter Root) hat den Namen des Tresors. Die Kategorie lassen wir daher leer.
  }

  /// Erstellt eine Map von base64-kodierte UUIDs zu ihrer Zeilennummer.
  Future<Map<String, int>> _createUuidLineMap(String fileContent) async {
    final map = <String, int>{};
    final lines = const LineSplitter().convert(fileContent);
    final uuidRegex = RegExp(r'<UUID>(.*?)</UUID>');
    for (int i = 0; i < lines.length; i++) {
      final match = uuidRegex.firstMatch(lines[i]);
      if (match != null && match.groupCount > 0) {
        final uuid = match.group(1)!;
        map[uuid] = i + 1; // Zeilennummern sind 1-basiert
      }
    }
    return map;
  }

  /// Dekodiert Dateianhänge aus `<Meta><Binaries>`-Block und speichert sie in eine Map.
  ///
  /// Struktur der XML-Datei (nur die relevanten Teile):
  /// ```xml
  /// <Meta>
  ///   <Binaries>
  ///     <Binary ID="0" Compressed="False">VIHBkZiBmaBhIHBkZiBmaWxlLg==</Binary>
  ///     <Binary ID="1" Compressed="True">U2VyIGVyIGVyIGZpZyBmaWxlLg==</Binary>
  ///     ...
  ///   </Binaries>
  ///   ...
  /// </Meta>
  /// ```
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
          final lineNumber = await _findLineNumberOfText(_file.path, '<Binary ID="$id"');
          throw ParserError('Die KeePass-Datei ist fehlerhaft. Anhang ID=$id konnte nicht dekodiert werden.', path: _file.path, lineNumber: lineNumber, originalErrorMessage: e.message);
        }
        if (bin.getAttribute('Compressed') == 'True') {
          try {
            blob = Uint8List.fromList(GZipDecoder().decodeBytes(blob));
          } on FormatException catch (e) {
            final lineNumber = await _findLineNumberOfText(_file.path, '<Binary ID="$id"');
            throw ParserError('Die KeePass-Datei ist fehlerhaft. Anhang ID=$id konnte nicht dekomprimiert werden.', path: _file.path, lineNumber: lineNumber, originalErrorMessage: e.message);
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
      final file = AppFile(filePath);
      int lineNumber = 1;
      await for (final line in file.openReadLines()) {
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
  ///
  /// Struktur der XML-Datei (nur die relevanten Teile):
  /// ```xml
  /// <Group>
  ///   <Name>Arbeit</Name>
  ///   <Entry/>
  ///   <Entry/>
  ///   ...
  /// </Group>
  /// ```
  /// Die Kategorie wird von `Group.Name` übernommen.
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
  ///
  /// Struktur der XML-Datei (nur die relevanten Teile):
  /// ```xml
  /// <Entry>
  ///   <UUID>ESIzRFVmd4iZAKq7zN3u/w==</UUID>
  ///   <String>
  ///     <Key>Title</Key>
  ///     <Value>Amazon</Value>
  ///   </String>
  ///   <String>
  ///     <Key>UserName</Key>
  ///     <Value>frank@example.com</Value>
  ///   </String>
  ///   <String>
  ///     <Key>Password</Key>
  ///     <Value>MeinAmazonPasswort!</Value>
  ///   </String>
  ///   <String>
  ///     <Key>URL</Key>
  ///     <Value>https://amazon.de</Value>
  ///   </String>
  ///   <String>
  ///     <Key>Notes</Key>
  ///     <Value>Prime seit 2016.</Value>
  ///   </String>
  ///   <Times/>
  ///   <Binary/>
  ///   <History/>
  ///   ...
  /// </Entry>
  /// ```
  Future<ParsedEntry> _parseEntry(XmlElement entry, String category) async {
    // UUID und ihre Zeilennummer ermitteln
    final (uuid, lineNumber) = _parseUuid(entry);

    // `<String>`-Elemente einlesen
    final strings = _parseStringElements(entry);

    // Zeitpunkt der letzten Änderung ermitteln
    final updatedAt = _parseUpdatedAt(entry);

    // Zeitstempel der letzten Passwortänderung ermitteln
    final passwordTimestamp = _parsePasswordTimestamp(entry, strings['Password']);

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
      throw ParserError('UUID fehlt.', path: _file.path, lineNumber: lineNumber);
    }

    Uint8List bytes;
    try {
      bytes = base64.decode(base64Uuid);
    } on FormatException catch (e) {
      throw ParserError('Die KeePass-Datei ist fehlerhaft. UUID "$base64Uuid" konnte nicht dekodiert werden.', path: _file.path, lineNumber: lineNumber, originalErrorMessage: e.message);
    }

    if (bytes.length != 16) {
      throw ParserError('Die KeePass-Datei ist fehlerhaft. UUID "$base64Uuid" ist ungültig. 16 Bytes erwartet.', path: _file.path, lineNumber: lineNumber);
    }

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final uuid = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';

    return (uuid, lineNumber);
  }

  /// Extrahiert alle `<String>`-Elemente eines Eintrags in eine Map.
  ///
  /// Struktur der XML-Datei (nur die relevanten Teile):
  /// ```xml
  /// <Entry>
  ///   <String>
  ///     <Key>Title</Key>
  ///     <Value>Amazon</Value>
  ///   </String>
  ///   ...
  /// </Entry>
  /// ```
  Map<String, String> _parseStringElements(XmlElement parent) {
    return {
      for (final s in parent.findElements('String'))
        if (s.findElements('Key').isNotEmpty && s.findElements('Value').isNotEmpty)
          s.findElements('Key').first.innerText: s.findElements('Value').first.innerText,
    };
  }

  /// Ermittelt den Zeitpunkt der letzten Änderung
  ///
  /// Struktur der XML-Datei (nur die relevanten Teile):
  /// ```xml
  /// <Entry>
  ///   <Times>
  ///     <LastModificationTime>2024-11-02T12:00:00Z</LastModificationTime>
  ///     <CreationTime>2016-05-01T10:00:00Z</CreationTime>
  ///   </Times>
  ///   ...
  /// </Entry>
  /// ```
  DateTime? _parseUpdatedAt(XmlElement entry) {
    final times = entry.findElements('Times').firstOrNull;
    final lastModStr = times?.findElements('LastModificationTime').firstOrNull?.innerText ?? times?.findElements('CreationTime').firstOrNull?.innerText;
    return DateTime.tryParse(lastModStr ?? '')?.toUtc();
  }

  /// Ermittelt den Zeitstempel der letzten Passwortänderung für einen Eintrag.
  ///
  /// Struktur der XML-Datei (nur die relevanten Teile):
  /// ```xml
  /// <Entry>
  ///   <History>
  ///     <Entry>
  ///       <String>
  ///         <Key>Password</Key>
  ///         <Value>geheim</Value>
  ///       </String>
  ///       <String>
  ///         ...
  ///       </String>
  ///       <Times>
  ///         <LastModificationTime>2023-11-01T06:30:00Z</LastModificationTime>
  ///       </Times>
  ///       ...
  ///     </Entry>
  ///   </History>
  ///   ...
  /// </Entry>
  ///
  /// Die Historie ist chronologisch sortiert.
  /// ```
  DateTime? _parsePasswordTimestamp(XmlElement entry, String? currentPassword) {
    // Wir suchen den neuesten History-Eintrag, dessen Passwort sich vom aktuellen unterscheidet.
    // Das ist der Zeitpunkt der letzten echten Passwortänderung.
    final history = entry.findElements('History').firstOrNull;
    if (history != null) {
      for (final hist in history.findElements('Entry').toList().reversed) {
        final strings = _parseStringElements(hist);
        if (strings.containsKey('Password') && strings['Password'] != currentPassword) {
          final timeStr = hist.findElements('Times').firstOrNull?.findElements('LastModificationTime').firstOrNull?.innerText;
          final ts = DateTime.tryParse(timeStr ?? '')?.toUtc();
          if (ts != null) return ts;
        }
      }
    }
    return null;
  }

  /// Parst die Anhänge für einen einzelnen Eintrag.
  ///
  /// Struktur der XML-Datei (nur die relevanten Teile):
  /// ```xml
  /// <Entry>
  ///   <Binary>
  ///     <Key>github_backup_codes.pdf</Key>
  ///     <Value Ref="0" />
  ///   </Binary>
  ///   <Binary>
  ///     ...
  ///   </Binary>
  ///   ...
  /// </Entry>
  /// ```
  Future<List<ParsedAttachment>?> _parseAttachments(XmlElement entry) async {
    final attachments = <ParsedAttachment>[];
    for (final bin in entry.findElements('Binary')) {
      final fileName = bin.findElements('Key').firstOrNull?.innerText.trim();
      final ref = bin.findElements('Value').firstOrNull?.getAttribute('Ref');
      if (fileName == null || ref == null) continue;
      final binary = _binaries[ref];
      if (binary == null) {
        final lineNumber = await _findLineNumberOfText(_file.path, '<Value Ref="$ref"');
        throw ParserError('Die KeePass-Datei ist fehlerhaft. Binär-Referenz "$ref" fehlt.', path: _file.path, lineNumber: lineNumber);
      }
      attachments.add(ParsedAttachment(binary, filename: fileName));
    }
    return attachments.isEmpty ? null : attachments;
  }
}