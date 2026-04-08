import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:privault/features/main/import/parser.dart';
import 'package:uuid/uuid.dart';

/// Ein Parser für 1Password 1PUX Exportdateien.
///
/// Spezifikation: https://support.1password.com/1pux-format/
///
/// - Die `.1pux`-Datei ist ein Standard-ZIP-Archiv.
/// - Das Archiv ist unverschlüsselt.
/// - Die Hauptdatendatei `export.data` im Archiv ist mit UTF-8 kodiert und JSON-basiert.
/// - Die UUID eines Eintrags ist keine Standard-UUID, sondern nur innerhalb eines 1Password-Tresors eindeutig.
/// - Datums-/Zeitangaben sind UNIX-Zeitstempel.
/// - Der Ordner "files" im Archiv enthält die Dateianhänge. Der Name jeder Datei beginnt mit ihrer Dokument-ID
class OnePassword1PuxParser implements Parser {
  /// Pfad zur .1pux-Datei
  final String _path;

  /// Zeilennummern der Item-IDs
  Map<String, int> _itemIdLineMap = {};

  /// Konstruktor
  OnePassword1PuxParser(this._path);

  /// Lädt die Daten aus der Datei.
  ///
  /// Gibt im Erfolgsfall eine [ParsedPayload] zurück.
  /// Im Fehlerfall wird ein [ParserError] geworfen.
  ///
  /// Struktur der JSON-Datei `export.data` (nur die relevanten Teile):
  /// ```json
  /// "accounts": [
  ///   {
  ///     "attrs": {
  ///     "uuid": "P7I3CBYVCRHFXA442AQNZYMWTM",
  ///     ...
  ///   },
  ///   "vaults": [
  ///     {
  ///       "attrs": {
  ///         "uuid": "34ym7oul534ym7oul534ym7oul",
  ///         "name": "Persönlich",
  ///         ...
  ///       },
  ///       "items": [...]
  ///     }
  ///   ]
  /// }
  /// ```
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
      throw ParserError('Die 1pux-Datei konnte nicht entpackt werden.', path: _path, originalErrorMessage: e.message);
    }

    // Die zentrale Datendatei 'export.data' finden und lesen
    final exportDataFile = archive.findFile('export.data');
    if (exportDataFile == null) {
      throw ParserError('Die 1pux-Datei ist fehlerhaft. `export.data` ist nicht eingebettet.', path: _path);
    }
    final fileContent = utf8.decode(exportDataFile.content as List<int>);

    // Zeilennummern für alle Items vorab ermitteln (Ihre Anforderung)
    _itemIdLineMap = await _createItemIdLineMap(fileContent);

    // JSON parsen
    Map<String, dynamic> json;
    try {
      json = jsonDecode(fileContent);
    } on FormatException catch (e) {
      throw ParserError('Die 1pux-Datei ist fehlerhaft. `export.data` ist nicht JSON-basiert.', path: _path, originalErrorMessage: e.message);
    }

    // Alle Einträge aus allen Tresoren extrahieren
    final allItems = <ParsedEntry>[];

    final accounts = json['accounts'] as List?;
    if (accounts == null || accounts.isEmpty) {
      throw ParserError('Die 1pux-Datei ist fehlerhaft. `accounts` fehlt.', path: 'export.data');
    }

    //  Alle Accounts durchlaufen...
    for (final accountData in accounts) {
      if (accountData is! Map<String, dynamic>) continue;

      // UUID des 1Password-Accounts extrahieren (diese ist nur innerhalb von 1password.com eindeutig!)
      final accountAttrs = accountData['attrs'] as Map<String, dynamic>?;
      final accountUuid = accountAttrs?['uuid'] as String?;
      if (accountUuid == null || accountUuid.isEmpty) {
        throw ParserError('Die 1pux-Datei ist fehlerhaft. `accounts[].attrs.uuid` fehlt.', path: 'export.data');
      }

      // Alle Tresore des Accounts durchlaufen...
      final vaults = accountData['vaults'] as List?;
      if (vaults == null) continue;
      for (final vaultData in vaults) {
        if (vaultData is! Map<String, dynamic>) continue;

        // UUID des Tresors extrahieren (diese ist nur innerhalb eines 1Password-Accounts eindeutig)
        final vaultAttrs = vaultData['attrs'] as Map<String, dynamic>?;
        final vaultUuid = vaultAttrs?['uuid'] as String?;
        if (vaultUuid == null || vaultUuid.isEmpty) {
          throw ParserError('Die 1pux-Datei ist fehlerhaft. `vaults[].attrs.uuid` fehlt.', path: 'export.data');
        }

        // Name des Tresors extrahieren
        final vaultName = vaultAttrs?['name'] as String? ?? 'Unbenannter Tresor';

        // Alle Einträge des Tresors durchlaufen...
        final items = vaultData['items'] as List?;
        if (items == null) continue;
        for (final itemData in items) {
          // Eintrag parsen
          final parsedEntry = _parseItem(itemData, accountUuid, vaultUuid, vaultName, archive);
          allItems.add(parsedEntry);
        }
      }
    }

    return allItems;
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

  /// Parst einen einzelnen Eintrag.
  ///
  /// JSON-Struktur (nur die relevanten Teile):
  /// ```json
  /// "items": [
  ///   {
  ///     "uuid": "34ym7oul534ym7oul534ym7oul",
  ///     "createdAt": 1775516074,
  ///     "updatedAt": 1775516075,
  ///     "state": "active",
  ///     "overview": {...}
  ///     "details": {
  ///       "loginFields": [ ... ],
  ///       "passwordHistory": [ ... ]
  ///       "sections": [ ... ],
  ///       "documentAttributes": [ ... ]
  ///       "notesPlain": "Das ist eine Notiz.\nEine zweite Zeile.",
  ///     },
  ///     ...
  ///   }
  /// ]
  /// ```
  ParsedEntry _parseItem(dynamic itemData, String accountUuid, String vaultUuid, String vaultName, Archive archive) {
    if (itemData is! Map<String, dynamic>) {
      throw ParserError('Die 1pux-Datei ist fehlerhaft.`items` beinhaltet ungültige Daten.', path: _path);
    }
    final Map<String, dynamic> item = itemData;

    // UUID des Eintrags extrahieren (diese ist nur innerhalb eines 1Password-Tresors eindeutig)
    final onePassUuid = item['uuid'] as String?;
    final lineNumber = _itemIdLineMap[onePassUuid];
    if (onePassUuid == null || onePassUuid.isEmpty) {
      throw ParserError('Die 1pux-Datei ist fehlerhaft. Ein Eintrag hat keine UUID.', path: 'export.data', lineNumber: lineNumber);
    }

    // Die deterministische UUID (v5) wird aus der Kombination von accountUuid, vaultUuid und itemUuid erzeugt.
    // Ein einfacher Separator wie ':' stellt sicher, dass es keine Überschneidungen gibt.
    final globallyUniqueName = '1password.com:$accountUuid:$vaultUuid:$onePassUuid';
    final uuid = const Uuid().v5(Namespace.url.value, globallyUniqueName);

    // Zeitpunkt der letzten Änderung ermitteln
    final updatedAt = _parseUnix(item['updatedAt']) ?? _parseUnix(item['createdAt']);

    // Kategorie aus `vaultName` und `state` zusammensetzen
    // state: String. "active" indicates the normal state of an item. "archived" indicates that the item was archived.
    final state = item['state'] as String? ?? 'active';
    final category = state == 'archived' ? '$vaultName (archived)' : vaultName;

    // Titel, URL und Tags aus `overview` parsen
    final (title, url, tags) = _parseOverview(item['overview'] as Map<String, dynamic>?);

    // Username und Passwort aus loginFields parsen
    final details = item['details'] as Map<String, dynamic>? ?? {};
    final (username, password) = _parseLoginFields(details['loginFields'] as List?);

    // Zeitstempel des Passworts aus `details.passwordHistory` extrahieren
    final passwordTimestamp = _parsePasswordHistory(details['passwordHistory'] as List?);

    // Notiz und Dateianhänge aus `details.sections extrahieren
    final (sectionNotes, attachments) = _parseSections(details['sections'] as List?, archive, lineNumber);

    // Dateianhang aus `details.documentAttributes` extrahieren.
    final attachment = _parseDocumentAttributes(details['documentAttributes'] as Map<String, dynamic>?, archive, lineNumber);
    if (attachment != null) {
      attachments.add(attachment);
    }

    // Notizen aus `details.notesPlain`, `details.sections` und `overview.tags` bilden.
    final notes = _buildNotes(details['notesPlain'], sectionNotes, tags);

    return ParsedEntry(
      uuid,
      category: category,
      title: title,
      username: username,
      password: password,
      passwordTimestamp: passwordTimestamp,
      url: url,
      notes: notes,
      updatedAt: updatedAt,
      attachments: attachments.isEmpty ? null : attachments,
      lineNumber: lineNumber,
    );
  }

  /// Wandelt ein UNIX Timestamp in ein DateTime-Objekt um.
  DateTime? _parseUnix(dynamic value) {
    if (value == null) return null;
    final seconds = value is int ? value : int.tryParse(value.toString());
    return seconds != null ? DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true) : null;
  }

  /// Parst Titel, URL und Tags aus `overview`.
  ///
  /// JSON-Struktur (nur die relevanten Teile):
  /// ```json
  /// "overview": {
  ///   "title": "Rotkäppchen",
  ///   "url": "wolf.de",
  ///   "urls": [
  ///      {
  ///        "url": "https://example.de",
  ///        ...
  ///      }
  ///    ],
  ///   "tags": ["foo", "bar"],
  ///   ...
  /// }
  /// ```
  (String? title, String? url, List<String>? tags) _parseOverview(Map<String, dynamic>? overview) {
    if (overview == null) return (null, null, null);

    final title = overview['title'] as String?;

    var url = overview['url'] as String?;
    if (url == null) {
      final urls = overview['urls'] as List?;
      url = urls?.firstOrNull?['url'];
    }

    final tags = (overview['tags'] as List?)?.whereType<String>().toList();

    return (title, url, tags);
  }

  /// Parst Username und Passwort aus loginFields
  ///
  /// JSON-Struktur (nur die relevanten Teile):
  /// ```json
  /// "loginFields": [
  ///   {
  ///     "designation": "username"
  ///     "name": "username",
  ///     "value": "eey11234@laoia.com",
  ///     ...
  ///   },
  ///   {
  ///     "designation": "password"
  ///     "name": "password",
  ///     "value": "3tmXEUvTKcuDmiUYHfjB",
  ///     ...
  ///   }
  /// ],
  /// ```
  (String? username, String? password) _parseLoginFields(List? loginFields) {
    String? username;
    String? password;
    if (loginFields != null) {
      for (final f in loginFields) {
        if (f is! Map<String, dynamic>) continue;
        final designation = f['designation'] as String?;
        if (designation == 'username') {
          username = f['value'] as String?;
        } else if (designation == 'password') {
          password = f['value'] as String?;
        }
      }
    }
    return (username, password);
  }

  /// Zeitstempel des Passworts aus `details.passwordHistory` extrahieren
  ///
  /// JSON-Struktur (nur die relevanten Teile):
  /// ```json
  /// "passwordHistory": [
  ///   {
  ///     "value": "12345password",
  ///     "time": 1458322355
  ///   },
  ///   ...
  /// ],
  /// ```
  DateTime? _parsePasswordHistory(List? passwordHistory) {
    DateTime? passwordTimestamp;
    if (passwordHistory != null && passwordHistory.isNotEmpty) {
      final last = passwordHistory.last;
      if (last is Map<String, dynamic>) {
        passwordTimestamp = _parseUnix(last['time']);
      }
    }
    return passwordTimestamp;
  }

  /// Parst `details.sections` und liefert:
  /// - sectionNotes: Formatierter Text für das Notizfeld
  /// - attachments: Liste der Dateianhängen
  ///
  /// JSON-Struktur (nur die relevanten Teile):
  /// ```json
  /// "sections": [
  ///   {
  ///     "title": "Identifikation",
  ///     "name": "name",
  ///     "fields": [
  ///       {
  ///         "title": "Vorname",
  ///         "value": { "string": "Franz" }
  ///         ...
  ///       },
  ///       {
  ///         "title": "Geburtsdatum",
  ///         "value": { "date": 1775563260 }
  ///         ...
  ///       },
  ///       {
  ///         "title": "",
  ///         "value": {"file": { "fileName": "Toilette.pdf", "documentId": "34ym7oul534ym7oul534ym7oul", ... }
  ///       },
  ///       ...
  ///     ]
  ///   },
  /// ]
  /// ```
  /// Supported section ID types:
  /// Address, Concealed, Credit Card Number, Credit Card Type, Date, Email,
  /// Gender, Menu, Month Year, One Time Password, Phone, Reference, String, URL.
  (String? notes, List<ParsedAttachment> attachments) _parseSections(List? sections, Archive archive, int? lineNumber) {
    if (sections == null || sections.isEmpty) {
      return (null, []);
    }
    final buffer = StringBuffer();
    final attachments = <ParsedAttachment>[];

    // Alle Sections durchlaufen...
    for (final section in sections) {
      if (section is! Map<String, dynamic>) continue;
      final fields = section['fields'] as List?;
      if (fields == null || fields.isEmpty) continue;

      // Titel der Section
      final sectionTitle = section['title'] as String? ?? '';
      if (sectionTitle.isNotEmpty) {
        buffer.writeln('[$sectionTitle]');
      }

      // Alle Felder der Section durchlaufen...
      for (final field in fields) {
        if (field is! Map<String, dynamic>) continue;
        final fieldTitle = field['title'] as String? ?? '';
        final value = field['value'] as Map<String, dynamic>?;
        if (value == null) continue;

        // Dateianhang extrahieren
        if (value.containsKey('file')) {
          final file = value['file'] as Map<String, dynamic>?;
          if (file != null) {
            final documentId = file['documentId'] as String?;
            final fileName = file['fileName'] as String?;
            if (documentId != null && documentId.isNotEmpty) {
              attachments.add(_buildAttachment(documentId, fileName, archive, lineNumber));
            }
          }
        }

        // Datum extrahieren
        else if (value.containsKey('date')) {
          final dt = _parseUnix(value['date']);
          if (fieldTitle.isNotEmpty && dt != null) {
            buffer.writeln('$fieldTitle: ${dt.toIso8601String()}');
          }
        }

        // Normaler Text/String extrahieren
        else {
          // Wir nehmen den ersten Wert, der kein null ist
          final dynamic v = value.values.firstWhere((val) => val != null, orElse: () => null);
          if (v != null) {
            final text = v.toString().trim();
            if (fieldTitle.isNotEmpty && text.isNotEmpty) {
              buffer.writeln('$fieldTitle: $text');
            }
          }
        }
      }

      // Leerzeile nach jeder Sektion für bessere Lesbarkeit
      buffer.writeln();
    }

    final notes = buffer.toString().trim();
    return (notes.isNotEmpty ? notes : null, attachments);
  }

  /// Lädt die Datei aus dem Archiv und erstellt daraus ein [ParsedAttachment]-Objekt.
  ///
  /// Die Datei liegt im Archiv im Ordner "files".
  /// Der Name jeder Datei beginnt mit ihrer Dokument-ID (z.B. 34ym7oul534ym7oul534ym7oul__Kaffeemaschine.pdf).
  ParsedAttachment _buildAttachment(String documentId, String? fileName, Archive archive, int? lineNumber) {
    final archiveFile = archive.files.where((f) => f.name.startsWith('files/$documentId')).firstOrNull;
    if (archiveFile == null) {
      throw ParserError('Die 1pux-Datei ist fehlerhaft. Dateianhang mit ID "$documentId" ist nicht eingebettet.', path: _path, lineNumber: lineNumber);
    }
    final binary = archiveFile.content as Uint8List;
    return ParsedAttachment(binary, filename: fileName);
  }

  /// Extrahiert einen Dateianhang aus `documentAttributes`
  ///
  /// JSON-Struktur (nur die relevanten Teile):
  /// ```json
  /// "documentAttributes": {
  ///   "fileName": "Kaffeemaschine.pdf",
  ///   "documentId": "34ym7oul534ym7oul534ym7oul",
  ///   ...
  /// }
  /// ```
  ParsedAttachment? _parseDocumentAttributes(Map<String, dynamic>? documentAttributes, Archive archive, int? lineNumber) {
    if (documentAttributes == null) return null;
    final documentId = documentAttributes['documentId'] as String?;
    final fileName = documentAttributes['fileName'] as String?;
    if (documentId == null || documentId.isEmpty) {
      return null;
    }
    return _buildAttachment(documentId, fileName, archive, lineNumber);
  }

  /// Fügt `details.notesPlain`, `details.sections` und `overview.tags` zu einer Notiz zusammen.
  String _buildNotes(String? notesPlain, String? sectionNotes, List<String>? tags) {
    final parts = <String>[];

    if (notesPlain != null && notesPlain.trim().isNotEmpty) {
      parts.add(notesPlain.trim());
    }

    if (sectionNotes != null && sectionNotes.trim().isNotEmpty) {
      parts.add(sectionNotes.trim());
    }

    if (tags != null && tags.isNotEmpty) {
      parts.add('Tags: ${tags.join(", ")}');
    }

    // Alle Teile mit einer Leerzeile verbinden
    return parts.join('\n\n');
  }

}
