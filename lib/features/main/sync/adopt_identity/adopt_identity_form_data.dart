/// Alle Daten im Dialog, die der Benutzer ändern kann.
class AdoptIdentityFormData {

  /// Das neue Master-Passwort.
  final String newPassword;

  /// Das aktuelle Master-Passwort.
  final String password;

  /// Konstruktor
  const AdoptIdentityFormData({
    this.newPassword = '',
    this.password = '',
  });

  /// Daten aktualisieren (immutable)
  AdoptIdentityFormData copyWith({
    String? newPassword,
    String? password,
  }) {
    return AdoptIdentityFormData(
      newPassword: newPassword ?? this.newPassword,
      password: password ?? this.password,
    );
  }

  // @formatter:off
  /// Operator `==` für das Objekt anpassen
  @override
  bool operator == (Object other) =>
    identical(this, other) ||
      other is AdoptIdentityFormData && (
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