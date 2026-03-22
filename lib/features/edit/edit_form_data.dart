/// Alle Daten auf der Bearbeitungsseite, die für den Dirty-Check relevant sind.
class EditFormData {
  /// Die Kategorie des Eintrags.
  final String category;

  /// Der Titel des Eintrags.
  final String title;

  /// Der Benutzername des Eintrags.
  final String username;

  /// Das Passwort des Eintrags.
  final String password;

  /// Die URL des Eintrags (z.B. Login-Seite eines Webdienstes).
  final String url;

  /// Notizen zum Eintrag.
  final String notes;

  /// Konstruktor
  const EditFormData({
    this.category = '',
    this.title = '',
    this.username = '',
    this.password = '',
    this.url = '',
    this.notes = '',
  });

  /// Daten aktualisieren (immutable)
  EditFormData copyWith({
    String? category,
    String? title,
    String? username,
    String? password,
    String? url,
    String? notes,
  }) {
    return EditFormData(
      category: category ?? this.category,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      url: url ?? this.url,
      notes: notes ?? this.notes,
    );
  }

  // @formatter:off
  /// Operator `==` für das Objekt anpassen
  @override
  bool operator == (Object other) =>
    identical(this, other) ||
    other is EditFormData && (
      runtimeType == other.runtimeType &&
      category == other.category &&
      title == other.title &&
      username == other.username &&
      password == other.password &&
      url == other.url &&
      notes == other.notes
    );

  /// Liefert den HashCode für das Objekt
  /// (erforderlich, wenn ein Operators überschrieben wird)
  @override
  int get hashCode =>
    category.hashCode ^
    title.hashCode ^
    username.hashCode ^
    password.hashCode ^
    url.hashCode ^
    notes.hashCode;
  // @formatter:on
}