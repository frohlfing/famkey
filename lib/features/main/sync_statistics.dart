/// Repräsentiert die Zusammenfassung eines Synchronisationsvorgangs.
/// Enthält Zähler für heruntergeladene und hochgeladene Änderungen zur Benutzerinformation.
class SyncStatistics {
  /// Anzahl der vom Server neu hinzugefügten Einträge.
  final int pullAdded;

  /// Anzahl der vom Server aktualisierten Einträge.
  final int pullUpdated;

  /// Anzahl der lokal gelöschten Einträge aufgrund von Server-Tombstones.
  final int pullDeleted;

  /// Anzahl der erfolgreich zum Server übertragenen Änderungen (Updates und Deletes).
  final int pushSent;

  /// Gibt an, ob während des Sync-Vorgangs überhaupt Daten bewegt wurden.
  bool get hasChanges => pullAdded > 0 || pullUpdated > 0 || pullDeleted > 0 || pushSent > 0;

  /// Konstruktor
  const SyncStatistics({
    this.pullAdded = 0,
    this.pullUpdated = 0,
    this.pullDeleted = 0,
    this.pushSent = 0,
  });

  /// Erzeugt eine benutzerfreundliche Zusammenfassung der Statistik.
  @override
  String toString() =>
      '✳️ Hinzugefügt: $pullAdded\n'
      '✏️ Aktualisiert: $pullUpdated\n'
      '❌ Gelöscht: $pullDeleted\n'
      '💾 Gesichert: $pushSent';
}
