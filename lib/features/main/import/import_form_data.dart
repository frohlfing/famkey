import '../../../core/app_file.dart';

/// Ein Enum für den Status von Aktionen
enum ImportFileFormat {
  none, // Keine Datei
  bitwardenJson, // Bitwarden JSON
  keepassXml, // KeePass XML (2.x)
  onePassword1Pux, // 1Password 1PUX (8.x)
  FamKeyZip, // FamKey ZIP-Export

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
      ImportFileFormat.FamKeyZip => ['zip'],
      _ => ['json', 'xml', '1pux', 'zip'], // Default-Fall (Catch-all) -> alle unterstützen Formate
    };
  }

  /// Gibt an, ob das Format ein optionales Passwort unterstützt.
  bool get supportsPassword => this == ImportFileFormat.FamKeyZip;
}

/// Alle Daten im Dialog, die der Benutzer ändern kann.
class ImportFormData {

  /// Das Format der Importdatei.
  final ImportFileFormat format;

  /// Die zu importierende Datei.
  final AppFile file;

  /// Gibt an, ob die Datei verschlüsselt ist (gesteuert durch den Switch in der UI).
  final bool encrypt;

  /// Passwort zum Entschlüsseln – nur relevant wenn [encrypt] true ist.
  final String password;

  /// Konstruktor
  const ImportFormData({
    this.format = ImportFileFormat.none,
    this.file = const AppFile.none(),
    this.encrypt  = false,
    this.password = '',
  });

  /// Daten aktualisieren (immutable).
  ImportFormData copyWith({
    ImportFileFormat? format,
    AppFile? file,
    bool? encrypt,
    String? password,
  }) {
    return ImportFormData(
      format: format ?? this.format,
      file: file ?? this.file,
      encrypt: encrypt  ?? this.encrypt,
      password: password ?? this.password,
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
      file.path == other.file.path &&
      encrypt == other.encrypt &&
      password == other.password
    );

  /// Liefert den HashCode für das Objekt
  /// (erforderlich, wenn ein Operators überschrieben wird)
  @override
  int get hashCode =>
    format.hashCode ^
    file.path.hashCode ^
    encrypt.hashCode ^
    password.hashCode;
  // @formatter:on
}