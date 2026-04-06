import 'dart:typed_data';

/// Ein strukturierter Fehler, der von einem Parser geworfen wird.
/// Enthält alle relevanten Informationen für Logging und UI-Anzeige.
class ParserError implements Exception {
  /// Die benutzerfreundliche Fehlermeldung.
  final String message;

  /// Der Pfad zur Datei, die den Fehler verursacht hat.
  final String? path;

  /// Die Zeilennummer in der Datei, falls ermittelbar.
  final int? lineNumber;

  /// Die ursprüngliche Fehlermeldung, die den Fehler ausgelöst hat (fürs Logging).
  final String? originalErrorMessage;

  // /// Der Stack Trace der ursprünglichen Exception (fürs Logging).
  // final StackTrace? stackTrace;

  /// Konstruktor
  ParserError(this.message, {this.path, this.lineNumber, this.originalErrorMessage});

  @override
  String toString() {
    return 'ParserError: $message${lineNumber != null ? ' (Zeile $lineNumber)' : ''}';
  }
}

/// Container für einen geparsten Dateianhang.
/// Die Binärdaten der Datei muss gegeben sein, alles andere ist optional.
class ParsedAttachment {

  /// Binärdaten
  final Uint8List binary;

  /// Der Dateiname des Anhangs.
  final String? filename;

  /// Der Internet Media-Type der Datei (z. B. "image/jpeg").
  final String? mime;

  /// Zeitstempel der Datei (UTC).
  final DateTime? timestamp;

  /// Konstruktor
  ParsedAttachment(this.binary, {this.filename, this.mime, this.timestamp});
}

/// Container für einen geparsten Eintrag.
/// Alle Angaben sind optional.
class ParsedEntry {

  /// Die globale eindeutige ID des Eintrags (Universally Unique Identifier v4).
  final String? uuid;

  /// Die Kategorie des Eintrags.
  final String? category;

  /// Der Anzeigename oder Titel des Eintrags.
  final String? title;

  /// Der Benutzername für diesen Eintrag.
  final String? username;

  /// Das Passwort des Eintrags.
  final String? password;

  /// Der Zeitstempel des Passworts (UTC, optional).
  final DateTime? passwordTimestamp;

  /// Die zugehörige Web-Adresse.
  final String? url;

  /// Ergänzende Notizen zum Eintrag.
  final String? notes;

  /// Der binäre Dateninhalt des Website-Icons (Favicon) als Base64-String.
  final String? favicon;

  /// Zeitpunkt der letzten Änderung (UTC).
  final DateTime? updatedAt;

  /// Dateianhänge
  final List<ParsedAttachment>? attachments;

  /// Zeilennummer in der Importdatei (1-basiert)
  final int? lineNumber;

  /// Konstruktor
  ParsedEntry({
    this.uuid,
    this.category,
    this.title,
    this.username,
    this.password,
    this.passwordTimestamp,
    this.url,
    this.notes,
    this.favicon,
    this.updatedAt,
    this.attachments,
    this.lineNumber,
  });
}

typedef ParsedPayload = List<ParsedEntry>;

/// Der Parser überführt die Daten der Importdatei in eine einheitliche strukturierte Form.
abstract class Parser {

  /// Lädt die Daten aus der Datei.
  ///
  /// Gibt im Erfolgsfall eine [ParsedPayload] zurück.
  /// Im Fehlerfall wird ein [ParserError] geworfen.
  Future<ParsedPayload> parse();
}
