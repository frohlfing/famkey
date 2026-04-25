/// Alle Daten im Dialog, die der Benutzer ändern kann.
class MasterPasswordFormData {

  /// Das neue Master-Passwort.
  final String newPassword;

  /// Das aktuelle Master-Passwort.
  final String password;

  /// Ob ein neues RSA-Schlüsselpaar generiert werden soll (Notfall-Reset / Key Rotation).
  final bool regenerateKeyPair;

  /// Konstruktor
  const MasterPasswordFormData({
    this.newPassword = '',
    this.password = '',
    this.regenerateKeyPair = false,
  });

  /// Daten aktualisieren (immutable)
  MasterPasswordFormData copyWith({
    String? newPassword,
    String? password,
    bool? regenerateKeyPair,
  }) {
    return MasterPasswordFormData(
      newPassword: newPassword ?? this.newPassword,
      password: password ?? this.password,
      regenerateKeyPair: regenerateKeyPair ?? this.regenerateKeyPair,
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
          password == other.password &&
          regenerateKeyPair == other.regenerateKeyPair
        );

  /// Liefert den HashCode für das Objekt
  /// (erforderlich, wenn ein Operators überschrieben wird)
  @override
  int get hashCode =>
    newPassword.hashCode ^
    password.hashCode ^
    regenerateKeyPair.hashCode;
// @formatter:on
}