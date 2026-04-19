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

  /// Das Formularfeld, das den Fehler verursacht hat (z.B. `'password'`).
  final String? field;

  /// Konstruktor
  ParserError(this.message, {this.path, this.lineNumber, this.originalErrorMessage, this.field});

  @override
  String toString() {
    return 'ParserError: $message${lineNumber != null ? ' (Zeile $lineNumber)' : ''}';
  }
}

/// Container für einen geparsten Dateianhang.
/// Die Binärdaten sind obligatorisch. Alle anderen Angaben sind optional.
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

/// Container für eine geparste Freigabe (Freund mit Zugriffsrecht).
///
/// Enthält alle Informationen für den **Offline-Import** einer Freigabe.
/// Der [publicKey] stammt aus dem Export und wird für die RSA-Verschlüsselung
/// des Entry-Keys benötigt – kein Serveraufruf erforderlich.
class ParsedSharedUser {
  /// UUID des Freundes (Format: 8-4-4-4-12).
  final String uuid;

  /// Anzeigename des Freundes.
  final String username;

  /// Zugriffsebene (1 = Lesen, 2 = Schreiben).
  final int accessLevel;

  /// Öffentlicher RSA-Schlüssel des Freundes.
  final String publicKey;

  ParsedSharedUser({
    required this.uuid,
    required this.username,
    required this.accessLevel,
    required this.publicKey,
  });
}

/// Container für einen geparsten Eintrag.
/// UUID ist obligatorisch. Alle anderen Angaben sind optional.
class ParsedEntry {

  /// Die globale eindeutige ID des Eintrags (Universally Unique Identifier, v4 wird nicht vorausgesetzt).
  /// Format: 8-4-4-4-12, z.B. "3a0b4a0c-2b8c-4b0c-9a3e-1f4b2a9c7e12"
  /// Wenn leer, wird beim Importieren eine neue UUID generiert.
  final String uuid;

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

  /// Zeitpunkt der letzten Änderung der Stammdaten (UTC).
  final DateTime? updatedAt;

  /// Dateianhänge
  final List<ParsedAttachment>? attachments;

  /// Freigaben – nur beim PriVault-Import befüllt, bei anderen Formaten `null`.
  final List<ParsedSharedUser>? sharedWith;

  /// Zeilennummer in der Importdatei (1-basiert)
  final int? lineNumber;

  /// Konstruktor
  ParsedEntry(this.uuid, {
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
    this.sharedWith,
    this.lineNumber,
  });
}

typedef ParsedPayload = List<ParsedEntry>;

/// Ein Parser für für Exportdaten.
///
/// Die Klasse überführt die Daten in in eine Liste von [ParsedEntry]-Objekten.
abstract class Parser {

  /// Lädt die Daten aus der Datei.
  ///
  /// Gibt im Erfolgsfall eine [ParsedPayload] zurück.
  /// Im Fehlerfall wird ein [ParserError] geworfen.
  Future<ParsedPayload> parse();
}
