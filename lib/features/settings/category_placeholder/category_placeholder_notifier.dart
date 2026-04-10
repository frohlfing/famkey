import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/settings/category_placeholder/category_placeholder_state.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';

final categoryPlaceholderProvider = NotifierProvider<CategoryPlaceholderNotifier, CategoryPlaceholderState>(() {
  return CategoryPlaceholderNotifier();
});

class CategoryPlaceholderNotifier extends Notifier<CategoryPlaceholderState> {

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
  CategoryPlaceholderState build() {
    // Dienste aus getIt holen
    _databaseService = getIt<DatabaseService>();
    _sessionService = getIt<SessionService>();

    // Initialer State
    return CategoryPlaceholderState();
  }

  /// Lädt die Daten für die Anzeige.
  Future<void> load() async {
    if (state.isBusy) return;

    // UI-State zurücksetzen
    state = const CategoryPlaceholderState().copyWith(status: CategoryPlaceholderActionStatus.progress);
    
    try {
      // Daten aus der Datenbank laden
      _settings = await _databaseService.getSettings();
      if (_settings == null) throw Exception('Die Einstellungen sind nicht in der Datenbank hinterlegt.'); // wird bereits direkt nach dem Login angelegt

      // UI-State aktualisieren
      state = state.copyWith(
        categoryPlaceholder: _settings!.categoryPlaceholder,
        originalCategoryPlaceholder: _settings!.categoryPlaceholder,
        status: CategoryPlaceholderActionStatus.loaded,
      );

    } catch (e, st) {
      Logger().fatal('Fehler beim Laden: $e', stack: st);
      state = state.copyWith(status: CategoryPlaceholderActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Speichern ---
  // ------------------------------------------------------------------------

  /// Speichert den Platzhalter für die Kategorie.
  Future<void> save() async {
    if (state.isBusy) return;

    // 1. Benutzereingabe bereinigen
    final categoryPlaceholder = state.categoryPlaceholder.trim();

    // 2. UI-State aktualisieren
    state = state.copyWith(
      categoryPlaceholder: categoryPlaceholder,
      status: CategoryPlaceholderActionStatus.progress, error: AppError.none(),
    );

    try {

      // 3. Benutzereingabe validieren
      if (categoryPlaceholder.isEmpty) {
        state = state.copyWith(status: CategoryPlaceholderActionStatus.failure, error: AppError(ErrorCode.valueRequired, field: 'categoryPlaceholder'));
        return;
      }

      // 4. Datenbank und Session aktualisieren
      if (categoryPlaceholder != state.originalCategoryPlaceholder) {
        if (_settings == null) throw Exception("Die Einstellungen sind nicht geladen.");
        final updatedSettings = _settings!.copyWith(
          categoryPlaceholder: categoryPlaceholder,
        );
        _settings = await _databaseService.saveSettings(updatedSettings);
        _sessionService.setSettings(_settings!);
      }

      // 5. State aktualisieren
      state = state.copyWith(
        originalCategoryPlaceholder: categoryPlaceholder,
        status: CategoryPlaceholderActionStatus.saved,
      );

    } catch (e, st) {
      Logger().fatal("Fehler beim Speichern: $e", stack: st);
      state = state.copyWith(status: CategoryPlaceholderActionStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Setter für den UI-State (synchron) ---
  // ------------------------------------------------------------------------

  /// Setter für Kategorie-Platzhalter.
  void setCategoryPlaceholder(String value) {
    final error = state.error.field == 'category_placeholder' ? AppError.none() : null;
    state = state.copyWith(categoryPlaceholder: value, error: error);
  }
  
}
