import 'dart:typed_data';

class ParsedEntry {

  /// Die globale eindeutige ID des Eintrags (Universally Unique Identifier v4).
  final String uuid;

  /// Die Kategorie des Eintrags.
  final String category;

  /// Der Anzeigename oder Titel des Eintrags.
  final String title;

  /// Der Benutzername für diesen Eintrag.
  final String username;

  /// Das Passwort des Eintrags.
  final String password;

  /// Der Zeitstempel des Passworts (UTC, optional).
  final DateTime? passwordTimestamp;

  /// Die zugehörige Web-Adresse.
  final String url;

  /// Ergänzende Notizen zum Eintrag.
  final String notes;

  /// Der binäre Dateninhalt des Website-Icons (Favicon) als Base64-String.
  final String favicon;

  /// Zeitpunkt der letzten Änderung (UTC).
  final DateTime? updatedAt;

  /// Dateianhänge
  final List<({Uint8List blob, String filename, String mime, DateTime? timestamp})> attachments;

  /// Zeilennummer in der Importdatei (1-basiert)
  final int? lineNumber;

  /// Konstruktor
  ParsedEntry({
    required this.uuid,
    required this.category,
    required this.title,
    required this.username,
    required this.password,
    required this.passwordTimestamp,
    required this.url,
    required this.notes,
    required this.favicon,
    required this.updatedAt,
    required this.attachments,
    required this.lineNumber,
  });
}

typedef ParsedPayload = List<ParsedEntry>;

abstract class Parser {
  /// Lädt die Daten aus der Datei. Im Fall eines Fehlers wird null zurückgegeben.
  Future<ParsedPayload?> parse();

  /// Gibt den Fehlertext zurück.
  String? get errorText => null;
}
