/// Alle Daten des Passwort-Generators, die der Benutzer ändern kann.
class MasterPasswordFormData {

  /// Das neue Master-Passwort.
  final String newPassword;

  /// Das aktuelle Master-Passwort.
  final String password;

  /// Konstruktor
  const MasterPasswordFormData({
    this.newPassword = '',
    this.password = '',
  });

  /// Daten aktualisieren (immutable)
  MasterPasswordFormData copyWith({
    String? newPassword,
    String? password,
  }) {
    return MasterPasswordFormData(
      newPassword: newPassword ?? this.newPassword,
      password: password ?? this.password,
    );
  }

  // @formatter:off
  /// Operator `==` für das Objekt anpassen
  @override
  bool operator == (Object other) =>
    identical(this, other) ||
      other is MasterPasswordFormData && (
        runtimeType == other.runtimeType &&
          newPassword == other.newPassword &&
          password == other.password
        );

  /// Liefert den HashCode für das Objekt
  /// (erforderlich, wenn ein Operators überschrieben wird)
  @override
  int get hashCode =>
    newPassword.hashCode ^
    password.hashCode;
// @formatter:on
}