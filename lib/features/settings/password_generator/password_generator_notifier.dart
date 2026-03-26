import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/settings/password_generator/password_generator_form_data.dart';
import 'package:privault/features/settings/password_generator/password_generator_state.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';

final passwordGeneratorProvider = NotifierProvider<PasswordGeneratorNotifier, PasswordGeneratorState>(() {
  return PasswordGeneratorNotifier();
});

class PasswordGeneratorNotifier extends Notifier<PasswordGeneratorState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

  late final DatabaseService _databaseService;
  late final SessionService _sessionService;

  // ------------------------------------------------------------------------
  // --- Interne Variablen (nicht reaktiv, nicht UI‑relevant) ---
  // ------------------------------------------------------------------------

  /// Die Datenbank-Entität.
  SettingsEntity? _settings;

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert einen Notifier.
  ///
  /// Die Verwendung von `Ref.watch` oder `Ref.listen` innerhalb dieser Methode ist unbedenklich.
  /// Ändert sich eine Abhängigkeit dieses Notifiers (bei Verwendung von `Ref.watch`), wird der Build-Prozess erneut ausgeführt. Der Notifier selbst wird jedoch nicht neu erstellt. Seine Instanz bleibt zwischen den Build-Ausführungen erhalten.
  @override
  PasswordGeneratorState build() {
    // Dienste aus getIt holen
    _databaseService = getIt<DatabaseService>();
    _sessionService = getIt<SessionService>();

    // Initialer State
    return PasswordGeneratorState();
  }

  /// Lädt die Daten für die Anzeige.
  Future<void> load() async {
    if (state.isBusy) return;

    // UI-State zurücksetzen
    state = const PasswordGeneratorState().copyWith(status: PasswordGeneratorActionStatus.progress);
    
    try {
      // Daten aus der Datenbank laden
      _settings = await _databaseService.getSettings();
      if (_settings == null) throw Exception('Die Einstellungen sind nicht in der Datenbank hinterlegt.'); // wird bereits direkt nach dem Login angelegt

      // UI-State aktualisieren
      final formData = PasswordGeneratorFormData(
        pwLength: _settings!.pwLength,
        pwSpecialChars: _settings!.pwSpecialChars,
        pwAvoidIlO0: _settings!.pwAvoidIlO0,
      );
      state = state.copyWith(
        formData: formData,
        originalFormData: formData,
        status: PasswordGeneratorActionStatus.loaded,
      );

    } catch (e, st) {
      Logger().fatal('Fehler beim Laden: $e', stack: st);
      state = state.copyWith(status: PasswordGeneratorActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Speichern ---
  // ------------------------------------------------------------------------

  /// Speichert Einstellungen für den Passwort-Generator.
  Future<void> save() async {
    if (state.isBusy) return;

    var formData = state.formData;

    // 1. UI-State aktualisieren
    state = state.copyWith(
      formData: formData,
      status: PasswordGeneratorActionStatus.progress, error: AppError.none(),
    );

    try {

      // 2. Benutzereingabe validieren
      if (formData.pwLength < 1) {
        state = state.copyWith(status: PasswordGeneratorActionStatus.failure, error: AppError(ErrorCode.valueInvalid, field: 'pwLength'));
        return;
      }

      // 3. Datenbank und Session aktualisieren
      if (formData != state.originalFormData) {
        if (_settings == null) throw Exception("Die Einstellungen sind nicht geladen.");
        final updatedSettings = _settings!.copyWith(
          pwLength: formData.pwLength,
          pwSpecialChars: formData.pwSpecialChars,
          pwAvoidIlO0: formData.pwAvoidIlO0,
        );
        _settings = await _databaseService.saveSettings(updatedSettings);
        _sessionService.setSettings(_settings);
      }

      // 4. UI-State aktualisieren
      state = state.copyWith(
        originalFormData: formData,
        status: PasswordGeneratorActionStatus.saved,
      );

    } catch (e, st) {
      Logger().fatal("Fehler beim Speichern: $e", stack: st);
      state = state.copyWith(status: PasswordGeneratorActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Setter für den UI-State (synchron) ---
  // ------------------------------------------------------------------------

  /// Setter für Passwortlänge
  void setPwLength(int value) {
    final error = state.error.field == 'pwLength' ? AppError.none() : null;
    final formData = state.formData.copyWith(pwLength: value);
    state = state.copyWith(formData: formData, error: error);
  }

  /// Verringert die Passwortlänge um ein Zeichen.
  void decrementLength() {
    setPwLength(state.formData.pwLength - 1);
  }

  /// Erhöht die Passwortlänge um ein Zeichen.
  void incrementLength() {
    setPwLength(state.formData.pwLength + 1);
  }

  /// Setter für Passwort-Sonderzeichen
  void setPwSpecialChars(String value) {
    final error = state.error.field == 'pwSpecialChars' ? AppError.none() : null;
    final formData = state.formData.copyWith(pwSpecialChars: value);
    state = state.copyWith(formData: formData, error: error);
  }

  /// Setzt keine Passwort-Sonderzeichen
  void setNonePwSpecialChars() {
    setPwSpecialChars('');
  }

  /// Setzt empfohlene Passwort-Sonderzeichen.
  void setDefaultPwSpecialChars() {
    setPwSpecialChars('!@#\$%^&*()_+-=[]{}|;:,.<>?'); // todo Zeichen sortieren
  }

  /// Setzt alle Passwort-Sonderzeichen.
  void setAllPwSpecialChars() {
    setPwSpecialChars('!"#\$%&\'()*+,-./:;<=>?@[\\]^_`{|}~');
  }

  /// Setter für "verwechselbare Zeichen auslassen".
  void setPwAvoidIlO0(bool value) {
    final error = state.error.field == 'pwAvoidIlO0' ? AppError.none() : null;
    final formData = state.formData.copyWith(pwAvoidIlO0: value);
    state = state.copyWith(formData: formData, error: error);
  }
}
