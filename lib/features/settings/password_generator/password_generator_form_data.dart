/// Alle Daten des Passwort-Generators, die der Benutzer ändern kann.
class PasswordGeneratorFormData {
  /// Eingestellte Länge für den Passwortgenerator.
  final int pwLength;

  /// Der aktuell gewählte Satz an Sonderzeichen für generierte Passwörter.
  final String pwSpecialChars;

  /// Gibt an, ob optisch ähnliche Zeichen ('I', 'l', 'O', '0') ausgelassen werden.
  final bool pwAvoidIlO0;

  /// Konstruktor
  const PasswordGeneratorFormData({
    this.pwLength = 16,
    this.pwSpecialChars = '',
    this.pwAvoidIlO0 = false,
  });

  /// Daten aktualisieren (immutable)
  PasswordGeneratorFormData copyWith({
    int? pwLength,
    String? pwSpecialChars,
    bool? pwAvoidIlO0,
  }) {
    return PasswordGeneratorFormData(
      pwLength: pwLength ?? this.pwLength,
      pwSpecialChars: pwSpecialChars ?? this.pwSpecialChars,
      pwAvoidIlO0: pwAvoidIlO0 ?? this.pwAvoidIlO0,
    );
  }

  // @formatter:off
  /// Operator `==` für das Objekt anpassen
  @override
  bool operator == (Object other) =>
      identical(this, other) ||
          other is PasswordGeneratorFormData && (
              runtimeType == other.runtimeType &&
                  pwLength == other.pwLength &&
                  pwSpecialChars == other.pwSpecialChars &&
                  pwAvoidIlO0 == other.pwAvoidIlO0
          );

  /// Liefert den HashCode für das Objekt
  /// (erforderlich, wenn ein Operators überschrieben wird)
  @override
  int get hashCode =>
      pwLength.hashCode ^
      pwSpecialChars.hashCode ^
      pwAvoidIlO0.hashCode;
// @formatter:on
}