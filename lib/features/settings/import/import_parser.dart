import 'package:privault/models/payloads/import_payload.dart';

abstract class ImportParser {
  /// Lädt die Daten aus der Datei. Im Fall eines Fehlers wird null zurückgegeben.
  Future<ImportPayload?> parse();

  /// Gibt den Fehlertext zurück.
  String? get errorText => null;
}


