/// Wrapper für plattformspezifische Systemdialoge (Interface).
abstract class SystemSettingsService {

  /// Capabilities - Kann die App-Info-Seite geöffnet werden?
  bool get canOpenAppSettings;

  /// Capabilities - Kann die Biometrie-Seite geöffnet werden?
  bool get canOpenBiometricSettings;

  /// Capabilities - Kann die Autofill-Seite geöffnet werden?
  bool get canOpenAutofillSettings;

  /// Öffnet die App-Info-Seite in den Systemeinstellungen.
  Future<void> openAppSettings();

  /// Öffnet die Systemeinstellungen zur Optimierung des Fingerabdruck- und Gesichtserkennung.
  Future<void> openBiometricSettings();

  /// Öffnet die Systemeinstellungen zur Auswahl des Autofill-Dienstes.
  Future<void> openAutofillSettings();

}