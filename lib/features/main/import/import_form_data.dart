/// Ein Enum für den Status von Aktionen
enum ImportFileFormat {
  none, // Keine Datei
  bitwardenJson, // Bitwarden JSON
  keepassXml, // KeePass XML (2.x)
  onePassword1Pux, // 1Password 1PUX (8.x)

  // In Planung (späterer Ausbau):
  //genericCsv, // nicht spezifische CSV-Datei
  //msecureCsv // mSecure 6 CSV
  //protonJson Proton Pass JSON
}

/// Erweiterung für [ImportFileFormat], um jedem Code eine Dateierweiterung zuzuweisen.
extension ImportFileFormatExtension on ImportFileFormat {
  List<String> get allowedExtensions {
    return switch (this) {
      ImportFileFormat.bitwardenJson => ['json'],
      ImportFileFormat.keepassXml => ['xml'],
      ImportFileFormat.onePassword1Pux => ['1pux'],
      _ => ['json', 'xml', '1pux'], // Default-Fall (Catch-all) -> alle unterstützen Formate
    };
  }
}

/// Alle Daten im Dialog, die der Benutzer ändern kann.
class ImportFormData {

  /// Das Format der Importdatei.
  final ImportFileFormat format;

  /// Der Pfad zur Datei.
  final String path;

  /// Konstruktor
  const ImportFormData({
    this.format = ImportFileFormat.none,
    this.path = '',
  });

  /// Daten aktualisieren (immutable)
  ImportFormData copyWith({
    ImportFileFormat? format,
    String? path,
  }) {
    return ImportFormData(
      format: format ?? this.format,
      path: path ?? this.path,
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
      path == other.path
    );

  /// Liefert den HashCode für das Objekt
  /// (erforderlich, wenn ein Operators überschrieben wird)
  @override
  int get hashCode =>
    format.hashCode ^
    path.hashCode;
  // @formatter:on
}