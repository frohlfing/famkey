import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:privault/features/main/import/parser.dart';
import 'package:uuid/uuid.dart';

/// Ein Parser für unverschlüsselte Bitwarden JSON-Exportdateien.
///
/// Diese Klasse implementiert die [Parser]-Schnittstelle.
/// Sie überführt die Datei in eine Liste von [ParsedEntry]-Objekten.
/// Im Fehlerfall wirft sie einen [ParserError].
///
/// Die Dateianhänge werden im Unterordner "attachments" erwartet.
class BitwardenJsonParser implements Parser {
  /// Pfad zur Datei
  final String _path;

  /// Zeilennummern der Item-IDs
  Map<String, int> _itemIdLineMap = {};

  /// Ordner
  Map<String, String> _folders = {};

  /// Konstruktor
  BitwardenJsonParser(this._path);

  @override
  Future<ParsedPayload> parse() async {
    // Datei öffnen und Inhalt lesen
    String fileContent;
    try {
      fileContent = await File(_path).readAsString();
    } on FileSystemException catch (e) {
      throw ParserError('Die Datei konnte nicht geöffnet werden.', path: _path, originalErrorMessage: e.message);
    }

    // Einmaliger Scan der Datei, um eine Map der Item-IDs zu ihrer Zeilennummer zu erstellen.
    _itemIdLineMap = await _createItemIdLineMap(fileContent);

    // JSON parsen
    Map<String, dynamic> json;
    try {
      json = jsonDecode(fileContent);
    } on FormatException catch (e) {
      throw ParserError('Die JSON-Struktur der Datei ist fehlerhaft.', path: _path, originalErrorMessage: e.message);
    }

    // Ordner (Kategorien) in eine Map (id-> name) laden
    _folders = _parseFolders(json);

    // Alle "items" aus der JSON-Datei verarbeiten
    final items = json['items'] as List?;
    if (items == null) {
      throw ParserError('Das Array `items` fehlt.', path: _path);
    }
    return await Future.wait(items.map((item) => _parseItem(item))); // Future.wait, da das Laden von Anhängen asynchron ist
  }

  /// Erstellt eine Map von Item-IDs zu ihrer Zeilennummer, indem die Datei einmalig am Anfang durchlaufen wird.
  Future<Map<String, int>> _createItemIdLineMap(String fileContent) async {
    final map = <String, int>{};
    final lines = const LineSplitter().convert(fileContent);
    final idRegex = RegExp(r'"id":\s*"(.*?)"'); // Sucht nach "id" gefolgt von einem Doppelpunkt und einem String-Wert
    for (int i = 0; i < lines.length; i++) {
      final match = idRegex.firstMatch(lines[i]);
      if (match != null && match.groupCount > 0) {
        final id = match.group(1)!;
        // Fügt nur hinzu, wenn es noch nicht existiert, da die ID eines Items die erste ist, die wir wollen.
        map.putIfAbsent(id, () => i + 1); // Zeilennummern sind 1-basiert
      }
    }
    return map;
  }

  /// Lädt die Ordnernamen aus dem Root-Element in eine Map.
  Map<String, String> _parseFolders(Map<String, dynamic> json) {
    final map = <String, String>{};
    if (json['folders'] is List) {
      for (final folder in json['folders']) {
        if (folder is Map && folder['id'] != null && folder['name'] != null) {
          map[folder['id']] = folder['name'];
        }
      }
    }
    return map;
  }

  /// Parst ein einzelnes JSON-Item in ein [ParsedEntry]-Objekt.
  Future<ParsedEntry> _parseItem(dynamic itemData) async {
    if (itemData is! Map<String, dynamic>) {
      throw ParserError('Ein Objekt im Array `items` ist ungültig.', path: _path);
    }
    final Map<String, dynamic> item = itemData;

    // UUID und ihre Zeilennummer ermitteln
    var (uuid, lineNumber) = _parseUuid(item);

    // Login für Benutzername und Passwort nehmen
    final login = item['login'] as Map<String, dynamic>?;

    // Ordner für die Kategorie nehmen
    final folderId = item['folderId'] as String?;
    final category = _folders[folderId]?.trim();

    // Zeitstempel der letzten Änderung ermitteln
    final updatedAt = _parseUpdatedAt(item);

    // Zeitstempel der letzten Passwortänderung ermitteln
    final passwordTimestamp = _parsePasswordTimestamp(item);

    // Anhänge des Eintrags verarbeiten
    final attachments = await _parseAttachments(item);

    return ParsedEntry(
      uuid,
      category: category,
      title: item['name']?.trim() as String?,
      username: login?['username']?.trim() as String?,
      password: login?['password'] as String?, // Passwort nicht trimmen!
      passwordTimestamp: passwordTimestamp,
      url: (login?['uris'] as List?)?.firstOrNull?['uri']?.trim() as String?,
      notes: item['notes'] as String?,
      updatedAt: updatedAt,
      attachments: attachments,
      lineNumber: lineNumber,
    );
  }

  /// Ermittelt die UUID des Eintrags und gibt sie zusammen mit ihrer Zeilennummer zurück.
  /// Es wird eine gültige UUID erwartet (Format: 8-4-4-4-12, z.B. "3a0b4a0c-2b8c-4b0c-9a3e-1f4b2a9c7e12").
  (String uuid, int? lineNumber) _parseUuid(Map<String, dynamic> item) {
    final id = item['id'] as String?;
    final lineNumber = _itemIdLineMap[id];
    if (id == null || id.isEmpty) { // ID ist obligatorisch
      throw ParserError('Das Item-Attribut "id" fehlt', path: _path, lineNumber: lineNumber);
    }

    // UUID-Prüfung
    // 1. Struktur und Bindestriche: Sie prüft, ob der String exakt dem kanonischen Format entspricht. Das bedeutet: 8-4-4-4-12 Zeichen, getrennt durch Bindestriche an den Stellen 9, 14, 19 und 24. Wenn ein Bindestrich fehlt oder an der falschen Stelle sitzt, gibt die Methode false zurück.
    // 2. Zeichen: Sie stellt sicher, dass nur gültige Hexadezimal-Zeichen (0-9, a-f, A-F) verwendet werden.
    // 3. Länge: Der String muss exakt 36 Zeichen lang sein.
    // v4 wird nicht vorausgesetzt (im dritten Block eine 4 an erster Stelle)
    if (!Uuid.isValidUUID(fromString: id)) {
      throw ParserError('Die ID "$id" ist keine gültige UUID.', path: _path, lineNumber: lineNumber);
    }

    return (id, lineNumber);
  }

  /// Ermittelt den Zeitpunkt der letzten Änderung
  DateTime? _parseUpdatedAt(Map<String, dynamic> item) {
    final revisionDateStr = item['revisionDate'] as String?;
    return DateTime.tryParse(revisionDateStr ?? '')?.toUtc();
  }

  /// Ermittelt den Zeitstempel der letzten Passwortänderung für einen Eintrag.
  DateTime? _parsePasswordTimestamp(Map<String, dynamic> item) {
    DateTime? passwordTimestamp;
    final passwordHistory = item['passwordHistory'] as List?;
    if (passwordHistory != null && passwordHistory.isNotEmpty) {
      final lastChangeDate = passwordHistory.first['lastUsedDate'] as String?;
      passwordTimestamp = DateTime.tryParse(lastChangeDate ?? '')?.toUtc();
    }
    return passwordTimestamp;
  }

  /// Parst die Anhänge für einen einzelnen Eintrag.
  /// Die Dateianhänge werden im Unterordner "attachments" erwartet.
  Future<List<ParsedAttachment>?> _parseAttachments(Map<String, dynamic> item) async {
    final attachments = <ParsedAttachment>[];
    final attachmentsMeta = item['attachments'] as List?;
    if (attachmentsMeta == null) return attachments;

    final baseDir = p.join(p.dirname(_path), 'attachments');

    for (final attachmentData in attachmentsMeta) {
      if (attachmentData is! Map<String, dynamic>) continue;

      final fileName = attachmentData['fileName']?.trim() as String?;
      if (fileName == null) continue;

      var attachmentPath = p.join(baseDir, fileName);
      try {
        final file = File(attachmentPath);
        if (!await file.exists()) {
          final lineNumber = await _findLineNumberOfText(_path, '"fileName": "$fileName"');
          throw ParserError('Anhang "$fileName" nicht gefunden. Datei im Unterordner "attachments" erwartet.', path: _path, lineNumber: lineNumber);
        }
        final binaryData = await file.readAsBytes();
        attachments.add(ParsedAttachment(binaryData, filename: fileName));
      } on FileSystemException catch (e) {
        final lineNumber = await _findLineNumberOfText(_path, '"fileName": "$fileName"');
        throw ParserError('Anhang "$fileName" konnte nicht gelesen werden.', path: _path, lineNumber: lineNumber, originalErrorMessage: e.message);
      }
    }

    return attachments.isEmpty ? null : attachments;
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