import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:privault/features/main/import/parser.dart';
import 'package:uuid/uuid.dart';

/// Ein Parser für 1Password 1PUX-Exportdateien.
///
/// Sie liest ein .1pux-Archiv, parst die enthaltene `export.data`-JSON-Datei und
/// extrahiert die dazugehörigen Anhänge aus dem `files`-Verzeichnis des Archivs.
/// Im Fehlerfall wirft die Klasse einen [ParserError].
class OnePassword1PuxParser implements Parser {
  /// Pfad zur .1pux-Datei
  final String _path;

  /// Zeilennummern der Item-IDs
  Map<String, int> _itemIdLineMap = {};

  /// Konstruktor
  OnePassword1PuxParser(this._path);

  @override
  Future<ParsedPayload> parse() async {
    // Datei öffnen und Inhalt lesen
    Uint8List bytes;
    try {
      bytes = await File(_path).readAsBytes();
    } on FileSystemException catch (e) {
      throw ParserError('Die Datei konnte nicht geöffnet werden.', path: _path, originalErrorMessage: e.message);
    }

    // 1pux-Datei als ZIP-Archiv lesen
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } on ArchiveException catch (e) {
      throw ParserError('Die .1pux-Datei ist kein gültiges ZIP-Archiv.', path: _path, originalErrorMessage: e.message);
    }

    // Die zentrale Datendatei 'export.data' finden und lesen
    final exportDataFile = archive.findFile('export.data');
    if (exportDataFile == null) {
      throw ParserError('Die zentrale Datendatei "export.data" wurde im Archiv nicht gefunden.', path: _path);
    }
    final fileContent = utf8.decode(exportDataFile.content as List<int>);

    // Zeilennummern für alle Items vorab ermitteln (Ihre Anforderung)
    _itemIdLineMap = await _createItemIdLineMap(fileContent);

    // JSON parsen
    Map<String, dynamic> json;
    try {
      json = jsonDecode(fileContent);
    } on FormatException catch (e) {
      throw ParserError('Die JSON-Struktur der Datei "export.data" ist fehlerhaft.', path: _path, originalErrorMessage: e.message);
    }

    /*
    // Struktur der JSON-Datei:

    "accounts": [
    {
      "attrs": {
        "uuid": "P7I3CBYVCRHFXA442AQNZYMWTM",
        ...
      },
      "vaults": [
        {
          "attrs": {
            "uuid": "34ym7oul5mmtdbyzfjgxs6zqwa",
            "name": "Persönlich",
            ...
          },
          "items": [...]
        }
      ]
    }
    */

    //  Alle Accounts durchlaufen
    //  pro Account: uuid lesen, alle Vaults durchlaufen
    //  pro Vault: uuid und name lesen, alle Items durchlaufen
    //  pro Item: _parseItem aufrufen

    // todo dieser Code passt nicht zur JSON-Struktur!

    // UUID des 1Password-Accounts extrahieren (diese ist nur innerhalb von 1password.com eindeutig!)
    final accountUuid = json['account']?['uuid'] as String?;
    if (accountUuid == null || accountUuid.isEmpty) {
      throw ParserError('Die Account-UUID ("account.uuid") konnte in der Datei nicht gefunden werden.', path: 'export.data');
    }

    // Alle Einträge aus allen Tresoren extrahieren
    final allItems = <ParsedEntry>[];
    final vaults = json['vaults'] as List?;
    if (vaults == null) {
      throw ParserError('Kein "vaults"-Array in der JSON-Datei gefunden.', path: _path);
    }

    for (final vaultData in vaults) {
      if (vaultData is! Map<String, dynamic>) continue;

      // UUID des Tresors extrahieren (diese ist nur innerhalb eines 1Password-Accounts eindeutig)
      final vaultUuid = vaultData['uuid'] as String?;
      if (vaultUuid == null) {
        throw ParserError('Einem Tresor im Export fehlt die "uuid".', path: 'export.data');
      }

      final vaultName = vaultData['name'] as String? ?? 'Unbenannter Tresor';
      final items = vaultData['items'] as List?;
      if (items == null) continue;

      for (final itemData in items) {
        final parsedEntry = _parseItem(itemData, accountUuid, vaultUuid, vaultName, archive);
        allItems.add(parsedEntry);
      }
    }

    return allItems;
  }

  /// Parst ein einzelnes JSON-Item aus `export.data` in ein [ParsedEntry]-Objekt.
  ParsedEntry _parseItem(dynamic itemData, String accountUuid, String vaultUuid, String category, Archive archive) {
    if (itemData is! Map<String, dynamic>) {
      throw ParserError('Ein Eintrag in der "items"-Liste hat ein ungültiges Format.', path: _path);
    }
    final Map<String, dynamic> item = itemData;

    /*
     "items": [
       {
          "uuid": "otukqhy4bud2mpe7fflippxj6a",
          "createdAt": 1775516074,
          "updatedAt": 1775516075,
          "state": "active",
          "details": {
             "loginFields": [ ... ],
             "notesPlain": "Das ist eine Notiz.\nEine zweite Zeile.",
             "sections": [ ... ],
             "passwordHistory": [ ... ]
             "documentAttributes": [ ... ]
          },
          "overview": {...}
          ...
        }
      ]
     */

    // UUID des Eintrags extrahieren (diese ist nur innerhalb eines 1Password-Tresors eindeutig)
    final onePassUuid = item['uuid'] as String?;
    final lineNumber = _itemIdLineMap[onePassUuid];
    if (onePassUuid == null || onePassUuid.isEmpty) {
      throw ParserError('Einem Eintrag fehlt die "uuid".', path: 'export.data', lineNumber: lineNumber);
    }

    // Die deterministische UUID (v5) wird aus der Kombination von accountUuid, vaultUuid und itemUuid erzeugt.
    // Ein einfacher Separator wie ':' stellt sicher, dass es keine Überschneidungen gibt.
    final globallyUniqueName = '1password.com:$accountUuid:$vaultUuid:$onePassUuid';
    final uuid = const Uuid().v5(Namespace.url.value, globallyUniqueName);

    // Zeitstempel
    final updatedAtStr = item['updatedAt'] as String? ?? item['createdAt'] as String?;
    final updatedAt = DateTime.tryParse(updatedAtStr ?? '')?.toUtc();

    // Kategorie
    // todo Wenn state == "archived", dann category = vaultName + " (archived), sonst category = vaultName

    // todo notesPlain und die Tags aus overview in das Notizfeld übernehmen: "Tags: foo, bar\n"

    /*
    "overview": {
      "title": "Rotkäpchen",
      "url": "netflix.de",
      "tags": [
        "foo",
        "bar"
      ],
      ...
    }
    */

    // Titel
    final title = item['title'] as String?; // todo korrigieren (Titel ist unter overview )
    if (title == null || title.isEmpty) {
      throw ParserError('Titel für Eintrag "$onePassUuid" fehlt.', path: 'export.data', lineNumber: lineNumber);
    }

    /*
    "details": {
      "loginFields": [
        {
          "designation": "username"
          "name": "username",
          "value": "eey11234@laoia.com",
          ...
        },
        {
          "designation": "password"
          "name": "password",
          "value": "3tmXEUvTKcuDmiUYHfjB",
          ...
        }
      ],
    }
    */

    // todo Username und Passwort aus loginFields extrahieren (designation == username oder password)
    // todo diese Implementierung ist komplett falsch!
    // Felder wie Benutzername, Passwort und Notizen extrahieren
    String? username;
    String? password;
    String? notes;
    final fields = item['fields'] as List?;
    if (fields != null) {
      for (final field in fields) {
        if (field is! Map<String, dynamic>) continue;
        final purpose = field['purpose'] as String?;
        if (purpose == 'USERNAME') {
          username = field['value'] as String?;
        }
        else if (purpose == 'PASSWORD') {
          password = field['value'] as String?;
        }
        else if (purpose == 'NOTES') {
          notes = field['value'] as String?;
        }
      }
    }

    // todo Informationen aus Section extrahieren un in das Notizfeld eintragen: "<title>: <value>\n",
    // todo hier im Beispiel: Vorname: Franz\nGeburtsdatum:25.03.2005 (und ein Anhang Toilette.pdf)
    // todo Wenn value=null, dann nicht eintragen
    // todo Wenn key = "date" -> Datum umwandeln
    /*
    "details": {
      "sections": [
        {
          "title": "Identifikation",
          "name": "name",
          "fields": [
            {
              "title": "Vorname",
              "value": {
                "string": "Franz"
              },
              ...
            },
            {
              "title": "Geburtsdatum",
              "value": {
                "date": 1775563260
              },
              ...
            },
            {
              "title": "Datum",
              "value": {
                "date": null
              },
               ...
            },
              "title": "",
              "value": {
                "file": {
                  "fileName": "Toilette.pdf",
                  "documentId": "klzphzepec27e65nhqbik5to3m",
                  "decryptedSize": 50914
                }
              },
     */

    // TODO passwordTimestamp aus passwordHistory extrahieren
    /*
    "passwordHistory": [{
      "value": "12345password",
      "time": 1458322355
    }],
     */


    // Anhänge verarbeiten
    final attachments = _parseAttachments(item, archive);

    return ParsedEntry(
      uuid,
      category: category,
      title: title,
      username: username,
      password: password,
      //passwordTimestamp: null, // todo
      url: (item['urls'] as List?)?.firstOrNull?['url'] as String?,
      notes: notes,
      updatedAt: updatedAt,
      attachments: attachments.isEmpty ? null : attachments,
      lineNumber: lineNumber,
    );
  }

  // todo _parseAttachments anpassen:
  // todo Dateianhänge werden aus sections (s.o) oder aus documentAttributes geholt:
  // todo Die Dateien liegen im Zip unter files/<documentId>__<fileName>

  /*
  "details": {
    "documentAttributes": {
      "fileName": "Kaffeemaschine.pdf",
      "documentId": "fnw6i2bjtj3agh5cl6cifnzdkq",
      ...
    }
  },
  */

  /// Verarbeitet die Anhänge für einen einzelnen Eintrag, indem sie aus dem ZIP-Archiv gelesen werden.
  List<ParsedAttachment> _parseAttachments(Map<String, dynamic> item, Archive archive) {
    final attachments = <ParsedAttachment>[];
    final filesMeta = item['files'] as List?;
    if (filesMeta == null) return attachments;

    for (final fileData in filesMeta) {
      if (fileData is! Map<String, dynamic>) continue;

      final fileName = fileData['name'] as String?;
      final contentPath = fileData['contentPath'] as String?;
      if (fileName == null || contentPath == null) continue;

      // Finde die Datei im ZIP-Archiv
      final archiveFile = archive.findFile(contentPath);
      if (archiveFile == null) {
        throw ParserError('Dateianhang "$fileName" wurde im Archiv nicht gefunden unter: $contentPath.', path: _path);
      }

      final binaryData = archiveFile.content as Uint8List;
      attachments.add(ParsedAttachment(binaryData, filename: fileName));
    }

    return attachments;
  }

  /// Erstellt eine Map von Item-UUIDs zu ihrer Zeilennummer (Ihre Anforderung)
  Future<Map<String, int>> _createItemIdLineMap(String fileContent) async {
    final map = <String, int>{};
    final lines = const LineSplitter().convert(fileContent);
    final idRegex = RegExp(r'"uuid":\s*"(.*?)"');
    for (int i = 0; i < lines.length; i++) {
      final match = idRegex.firstMatch(lines[i]);
      if (match != null && match.groupCount > 0) {
        final id = match.group(1)!;
        map.putIfAbsent(id, () => i + 1);
      }
    }
    return map;
  }
}
