/// Repräsentiert die Zusammenfassung eines Importvorgangs.
class ImportStatistics {
  /// Anzahl der hinzugefügten Einträge.
  final int added;

  /// Anzahl der übersprungenen Einträge (aufgrund von Konflikten).
  final int skipped;

  /// Konstruktor
  const ImportStatistics({
    this.added = 0,
    this.skipped = 0,
  });

  /// Erzeugt eine benutzerfreundliche Zusammenfassung der Statistik.
  @override
  String toString() =>
      '✳️ Hinzugefügt: $added\n'
      '⚠️ Übersprungen (aufgrund von Konflikten): $skipped\n';
}
