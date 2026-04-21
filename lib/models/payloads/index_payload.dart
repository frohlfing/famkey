/// Repräsentiert die lokal verschlüsselten Anzeigedaten eines Eintrags.
///
/// Dieses Objekt wird als JSON serialisiert und mittels AES-256-GCM verschlüsselt
/// in der Spalte `encryptedIndex` der `EntryEntity` gespeichert.
///
/// Der AES-Schlüssel wird aus dem RSA-Private-Key abgeleitet und ist für alle Einträge gleich.
/// Vorteil gegenüber `EntryPayload`: Kann schnell entpackt werden.
///
/// Das Objekt wird nicht synchronisiert und nicht mit Freunden geteilt, sondern dient dazu,
/// die Einträge auflisten und suchen zu können.
class IndexPayload {
  /// Die Kategorie des Eintrags.
  final String category;

  /// Der Titel des Eintrags.
  final String title;

  /// Die zugehörige Adresse der Webseite oder des Dienstes.
  final String url;

  /// Ergänzende Notizen zum Eintrag.
  final String notes;

  /// Der binäre Dateninhalt des Website-Icons (Favicon) als Base64-String.
  final String favicon;

  // Bewusst weggelassen gegenüber EntryPayload (haben in der Listenansicht nichts zu suchen):
  // username, password, passwordTimestamp

  /// Konstruktor
  const IndexPayload({
    required this.category,
    required this.title,
    required this.url,
    required this.notes,
    required this.favicon,
  });

  /// Erstellt eine [IndexPayload] aus einer JSON-Map.
  factory IndexPayload.fromJson(Map<String, dynamic> json) {
    return IndexPayload(
      category: json['category'] as String? ?? '',
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      favicon: json['favicon'] as String? ?? '',
    );
  }

  /// Konvertiert eine [IndexPayload] in eine Map für die JSON-Serialisierung.
  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'title': title,
      'url': url,
      'notes': notes,
      'favicon': favicon,
    };
  }
}