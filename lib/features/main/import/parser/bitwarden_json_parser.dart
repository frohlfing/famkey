import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:privault/features/main/import/parser.dart';

/// Ein Parser für unverschlüsselte Bitwarden JSON-Exportdateien.
///
/// Diese Klasse implementiert die [Parser]-Schnittstelle. Sie liest eine
/// Bitwarden JSON-Datei, löst Ordnerreferenzen auf und lädt zugehörige
/// Anhänge aus dem Dateisystem.
class BitwardenJsonParser implements Parser {
  final String path;
  String? _errorText;

  BitwardenJsonParser(this.path);

  @override
  String? get errorText => _errorText;

  @override
  Future<ParsedPayload?> parse() async {
    try {
      final jsonString = await File(path).readAsString();
      final json = jsonDecode(jsonString);

      // Ordner für schnelle Zuordnung in einer Map speichern (ID -> Name)
      final folders = <String, String>{};
      if (json['folders'] is List) {
        for (final folder in json['folders']) {
          if (folder['id'] != null && folder['name'] != null) {
            folders[folder['id']] = folder['name'];
          }
        }
      }

      final items = json['items'] as List;

      // Da das Laden von Anhängen asynchron ist, verwenden wir Future.wait
      final parsedEntries = await Future.wait(
        items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return _parseItem(item, folders, index);
        })
      );

      return parsedEntries.toList();
    } catch (e, s) {
      _errorText = "Fehler beim Parsen der Bitwarden JSON-Datei oder ihrer Anhänge: $e\n$s";
      return null;
    }
  }

  /// Parst ein einzelnes JSON-Item-Objekt in ein [ParsedEntry]-Objekt.
  Future<ParsedEntry> _parseItem(Map<String, dynamic> item, Map<String, String> folders, int index) async {
    final login = item['login'] as Map<String, dynamic>?;
    final updatedAt = DateTime.parse(item['revisionDate']).toUtc();

    return ParsedEntry(
      uuid: item['id'],
      category: folders[item['folderId']] ?? '',
      title: item['name'] ?? '',
      username: login?['username'] ?? '',
      password: login?['password'] ?? '',
      passwordTimestamp: _parsePasswordTimestamp(item),
      url: (login?['uris'] as List?)?.firstOrNull?['uri'] ?? '',
      notes: item['notes'] ?? '',
      favicon: '',
      updatedAt: updatedAt,
      attachments: await _parseAttachments(item, updatedAt),
      lineNumber: index,
    );
  }

  /// Ermittelt den Zeitstempel der letzten Passwortänderung aus der Passworthistorie.
  DateTime? _parsePasswordTimestamp(Map<String, dynamic> item) {
    final history = item['passwordHistory'] as List?;
    if (history != null && history.isNotEmpty) {
      // Annahme: Der erste Eintrag in der Historie ist der jüngste.
      final lastChangeDate = history.first['lastUsedDate'];
      if (lastChangeDate is String) {
        return DateTime.parse(lastChangeDate).toUtc();
      }
    }
    // Fallback auf das Änderungsdatum des Eintrags selbst.
    return DateTime.parse(item['revisionDate']).toUtc();
  }

  /// Parst die Metadaten der Anhänge und lädt die Binärdaten aus dem Dateisystem.
  ///
  /// Erwartet die Anhänge gemäß Spezifikation im selben Verzeichnis wie die JSON-Datei.
  Future<List<({Uint8List blob, String filename, String mime, DateTime? timestamp})>> _parseAttachments(
    Map<String, dynamic> item,
    DateTime entryTimestamp,
  ) async {
    // KORREKTUR: Der Rückgabetyp wurde angepasst, um `mime` zu enthalten.
    final attachmentsMeta = item['attachments'] as List?;
    if (attachmentsMeta == null || attachmentsMeta.isEmpty) {
      return [];
    }

    final result = <({Uint8List blob, String filename, String mime, DateTime? timestamp})>[];
    final baseDir = p.dirname(path); // Der Ordner, in dem die JSON-Datei liegt.

    for (final attachment in attachmentsMeta) {
      final fileName = attachment['fileName'] as String?;
      if (fileName == null) continue;

      // Die Datei wird direkt im selben Ordner erwartet, nicht in einem Unterordner.
      final attachmentFile = File(p.join(baseDir, fileName));

      if (!await attachmentFile.exists()) {
        throw FileSystemException("Dateianhang nicht gefunden", attachmentFile.path);
      }

      final data = await attachmentFile.readAsBytes();
      result.add((
        blob: data,
        filename: fileName,
        mime: '',
        timestamp: null,
      ));
    }
    return result;
  }
}