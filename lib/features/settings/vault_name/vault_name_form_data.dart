/// Alle Daten des Passwort-Generators, die der Benutzer ändern kann.
class VaultNameFormData {

  /// Der Tresorname.
  final String vaultName;

  /// Das Master-Passwort.
  final String password;

  /// Konstruktor
  const VaultNameFormData({
    this.vaultName = '',
    this.password = '',
  });

  /// Daten aktualisieren (immutable)
  VaultNameFormData copyWith({
    String? vaultName,
    String? password,
  }) {
    return VaultNameFormData(
      vaultName: vaultName ?? this.vaultName,
      password: password ?? this.password,
    );
  }

  // @formatter:off
  /// Operator `==` für das Objekt anpassen
  @override
  bool operator == (Object other) =>
    identical(this, other) ||
      other is VaultNameFormData && (
        runtimeType == other.runtimeType &&
        vaultName == other.vaultName &&
        password == other.password
      );

  /// Liefert den HashCode für das Objekt
  /// (erforderlich, wenn ein Operators überschrieben wird)
  @override
  int get hashCode =>
    vaultName.hashCode ^
    password.hashCode;
// @formatter:on
}