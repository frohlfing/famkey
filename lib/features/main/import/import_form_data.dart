/// Ein Enum für den Status von Aktionen
enum ImportFileFormat {
  none, // Keine Datei
  keepassXml, // KeePass XML (2.x)
  bitwardenJson, // Bitwarden JSON

  // In Planung (späterer Ausbau):
  //genericCsv, // nicht spezifische CSV-Datei
  //msecureCsv // mSecure 6 CSV
  //1passwordPux 1Password PUX
  //protonJson Proton Pass JSON
}

/// Erweiterung für [ImportFileFormat], um jedem Code eine Dateierweiterung zuzuweisen.
extension ImportFileFormatExtension on ImportFileFormat {
  List<String> get allowedExtensions {
    return switch (this) {
      ImportFileFormat.keepassXml => ['xml'],
      ImportFileFormat.bitwardenJson => ['json'],
      _ => ['xml', 'json'], // Default-Fall (Catch-all) -> alle unterstützen Formate
    };
  }
}

/// Alle Daten im Dialog, die der Benutzer ändern kann.
class ImportFormData {

  /// Das neue Master-Passwort.
  final ImportFileFormat format;

  /// Das aktuelle Master-Passwort.
  final String file;

  /// Konstruktor
  const ImportFormData({
    this.format = ImportFileFormat.none,
    this.file = '',
  });

  /// Daten aktualisieren (immutable)
  ImportFormData copyWith({
    ImportFileFormat? format,
    String? file,
  }) {
    return ImportFormData(
      format: format ?? this.format,
      file: file ?? this.file,
    );
  }

  // @formatter:off
  /// Operator `==` für das Objekt anpassen
  @override
  bool operator == (Object other) =>
      identical(this, other) ||
          other is ImportFormData && (
              runtimeType == other.runtimeType &&
                  format == other.format &&
                  file == other.file
          );

  /// Liefert den HashCode für das Objekt
  /// (erforderlich, wenn ein Operators überschrieben wird)
  @override
  int get hashCode =>
      format.hashCode ^
      file.hashCode;
// @formatter:on
}