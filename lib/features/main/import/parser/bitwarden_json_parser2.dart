import 'dart:convert';
import 'dart:io';
import 'package:privault/features/main/import/parser.dart';

/// Ein Parser für Bitwarden JSON Exportdateien.
///
/// Diese Klasse implementiert die [Parser]-Schnittstelle und ist dafür verantwortlich, eine
/// Bitwarden-JSON-Datei einzulesen und in eine Liste von [ParsedEntry]-Objekten umzuwandeln
class BitwardenJsonParser implements Parser {
  /// Pfad zur Datei
  final String path;

  /// Konstruktor
  BitwardenJsonParser(this.path);

  @override
  Future<ParsedPayload> parse() async {
    // Datei öffnen und Inhalt lesen
    String fileContent;
    try {
      fileContent = await File(path).readAsString();
    } on FileSystemException catch (e) {
      throw ParserError('Die Datei konnte nicht geöffnet werden.', path: path, originalErrorMessage: e.message);
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(fileContent) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw ParserError('Parser-Fehler: Die JSON-Struktur der Datei ist fehlerhaft.', path: path, originalErrorMessage: e.message);
    }

    // Ordner (Kategorien) in eine Map laden
    final foldersMap = _parseFolders(json);

    // Items verarbeiten
    final items = json['items'] as List<dynamic>?;
    if (items == null) {
      throw ParserError('Parser-Fehler: Das Feld "items" fehlt.', path: path);
    }

    final result = <ParsedEntry>[];
    for (int index = 0; index < items.length; index++) {
      final item = items[index];
      if (item is! Map<String, dynamic>) continue;

      final parsedEntry = _parseItem(item, foldersMap, index + 1);
      if (parsedEntry == null) continue;
      result.add(parsedEntry);
    }

    return result;
  }

  /// Parst die Ordner (Kategorien) aus dem Root-Element in eine Map.
  Map<String, String> _parseFolders(Map<String, dynamic> json) {
    final map = <String, String>{};
    final folders = json['folders'] as List<dynamic>?;
    if (folders != null) {
      for (final folder in folders) {
        if (folder is Map<String, dynamic>) {
          final id = folder['id'] as String?;
          final name = folder['name'] as String?;
          if (id != null && name != null) {
            map[id] = name;
          }
        }
      }
    }
    return map;
  }

  /// Parst ein einzelnes `item`-Element in ein [ParsedEntry]-Objekt.
  ParsedEntry? _parseItem(Map<String, dynamic> item, Map<String, String> foldersMap, int lineNumber) {
    // UUID direkt übernehmen (bereits im korrekten Format)
    final uuid = item['id'] as String?;

    // Kategorie aus folderId ermitteln
    final folderId = item['folderId'] as String?;
    final category = folderId != null ? foldersMap[folderId] : null;

    // Allgemeine Felder
    final title = item['name'] as String?;
    final notes = item['notes'] as String?;

    // Zeitpunkt der letzten Änderung
    final revisionDateStr = item['revisionDate'] as String?;
    final updatedAt = revisionDateStr != null ? DateTime.tryParse(revisionDateStr)?.toUtc() : null;

    // Passworthistorie auslesen
    DateTime? passwordTimestamp;
    final passwordHistory = item['passwordHistory'] as List<dynamic>?;
    if (passwordHistory != null && passwordHistory.isNotEmpty) {
      // Den letzten Eintrag in der Passworthistorie nehmen
      final lastHistoryEntry = passwordHistory.last;
      if (lastHistoryEntry is Map<String, dynamic>) {
        final lastUsedDateStr = lastHistoryEntry['lastUsedDate'] as String?;
        if (lastUsedDateStr != null) {
          passwordTimestamp = DateTime.tryParse(lastUsedDateStr)?.toUtc();
        }
      }
    }

    // Typ des Eintrags (1 = Anmeldung, 2 = Sichere Notiz, 3 = Karte, 4 = Identität)
    final itemType = item['type'] as int? ?? 1;

    String? username;
    String? password;
    String? url;

    // Daten basierend auf dem Eintrags-Typ auslesen
    if (itemType == 1) {
      // Anmeldung
      final login = item['login'] as Map<String, dynamic>?;
      if (login != null) {
        username = login['username'] as String?;
        password = login['password'] as String?;

        // Die erste URI als URL übernehmen
        final uris = login['uris'] as List<dynamic>?;
        if (uris != null && uris.isNotEmpty) {
          final firstUri = uris.first as Map<String, dynamic>?;
          url = firstUri?['uri'] as String?;
        }
      }
    }

    return ParsedEntry(
      uuid: uuid,
      category: category,
      title: title,
      username: username,
      password: password,
      passwordTimestamp: passwordTimestamp,
      url: url,
      notes: notes,
      updatedAt: updatedAt,
      lineNumber: lineNumber,
    );
  }
}
