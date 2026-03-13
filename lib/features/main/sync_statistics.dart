/// Repräsentiert die Zusammenfassung eines Synchronisationsvorgangs.
/// Enthält Zähler für heruntergeladene und hochgeladene Änderungen zur Benutzerinformation.
class SyncStatistics {
  /// Anzahl der vom Server neu hinzugefügten Einträge.
  int pullAdded = 0;

  /// Anzahl der vom Server aktualisierten Einträge.
  int pullUpdated = 0;

  /// Anzahl der lokal gelöschten Einträge aufgrund von Server-Tombstones.
  int pullDeleted = 0;

  /// Anzahl der erfolgreich zum Server übertragenen Änderungen (Updates und Deletes).
  int pushSent = 0;

  /// Gibt an, ob während des Sync-Vorgangs überhaupt Daten bewegt wurden.
  bool get hasChanges => pullAdded > 0 || pullUpdated > 0 || pullDeleted > 0 || pushSent > 0;

  /// Setzt alle Zähler auf 0.
  void reset() {
    pullAdded = 0;
    pullUpdated = 0;
    pullDeleted = 0;
    pushSent = 0;
  }

  /// Erzeugt eine benutzerfreundliche Zusammenfassung der Statistik.
  @override
  String toString() =>
      '✳️ Hinzugefügt: $pullAdded\n'
      '✏️ Aktualisiert: $pullUpdated\n'
      '❌ Gelöscht: $pullDeleted\n'
      '💾 Gesichert: $pushSent';
}
