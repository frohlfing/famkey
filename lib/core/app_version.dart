/// Stellt Versionsinformationen der Anwendung bereit.
class AppVersion {
  /// Wird nach einem Redesign oder bei einem Migrations-Bruch erhöht.
  static const int major = 1;

  /// Wird nach Änderung der Funktionalität erhöht. Wird auf 0 zurückgesetzt, wenn MAJOR erhöht wird.
  static const int minor = 0;

  /// Wird nach einer Fehlerbehebung (Bugfix) erhöht. Wird auf 0 zurückgesetzt, wenn MAJOR oder MINOR erhöht wird.
  static const int patch = 0;

  /// Minimal erforderliche Server-Minor-Version.
  static const int requiredServerMinor = 0;
}
