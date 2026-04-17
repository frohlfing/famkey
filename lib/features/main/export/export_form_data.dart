/// Formulardaten für den Export-Dialog.
class ExportFormData {
  /// Gibt an ob das ZIP-Archiv verschlüsselt werden soll.
  final bool encrypt;

  /// Passwort für die ZIP-Verschlüsselung (nur relevant wenn [encrypt] true ist).
  final String password;

  /// Konstruktor
  const ExportFormData({
    this.encrypt = false,
    this.password = '',
  });

  /// Daten aktualisieren (immutable)
  ExportFormData copyWith({
    bool? encrypt,
    String? password,
  }) {
    return ExportFormData(
      encrypt: encrypt ?? this.encrypt,
      password: password ?? this.password,
    );
  }

  // @formatter:off
  /// Operator `==` für das Objekt anpassen
  @override
  bool operator == (Object other) =>
    identical(this, other) ||
      other is ExportFormData && (
        runtimeType == other.runtimeType &&
            encrypt == other.encrypt &&
            password == other.password
      );

  /// Liefert den HashCode für das Objekt
  /// (erforderlich, wenn ein Operators überschrieben wird)
  @override
  int get hashCode =>
    encrypt.hashCode ^
    password.hashCode;
// @formatter:on
}