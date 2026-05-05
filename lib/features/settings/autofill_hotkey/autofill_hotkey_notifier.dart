import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famkey/core/app_error.dart';
import 'package:famkey/core/logger.dart';
import 'package:famkey/core/service_locator.dart';
import 'package:famkey/features/settings/autofill_hotkey/autofill_hotkey_state.dart';
import 'package:famkey/services/config_service.dart';

final autofillHotkeyProvider = NotifierProvider<AutofillHotkeyNotifier, AutofillHotkeyState>(() {
  return AutofillHotkeyNotifier();
});

class AutofillHotkeyNotifier extends Notifier<AutofillHotkeyState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

  late final ConfigService _configService;

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert einen Notifier.
    @override
  AutofillHotkeyState build() {
    _configService = getIt<ConfigService>();
    return AutofillHotkeyState();
  }

  /// Lädt die Daten für die Anzeige.
  Future<void> load() async {
    if (state.isBusy) return;
    final hotkey = _configService.autofillHotkey;
    state = const AutofillHotkeyState().copyWith(
      hotkey: hotkey,
      originalHotkey: hotkey,
      status: AutofillHotkeyStatus.loaded,
    );
  }

  // ------------------------------------------------------------------------
  // --- Speichern ---
  // ------------------------------------------------------------------------

  /// Speichert den Platzhalter für die Kategorie.
  Future<void> save() async {
    if (state.isBusy) return;

    // 1. Benutzereingabe bereinigen
    final hotkey = state.hotkey.trim();

    // 2. UI-State aktualisieren
    state = state.copyWith(
      hotkey: hotkey,
      status: AutofillHotkeyStatus.progress, error: AppError.none(),
    );

    try {

      // 3. Benutzereingabe validieren
      if (hotkey.isEmpty) {
        state = state.copyWith(status: AutofillHotkeyStatus.failure, error: AppError(ErrorCode.valueRequired, field: 'hotkey'));
        return;
      }

      // 4. Hotkey in die Konfiguration schreiben
      _configService.autofillHotkey = hotkey;

      // 5. State aktualisieren
      state = state.copyWith(
        originalHotkey: hotkey,
        status: AutofillHotkeyStatus.saved,
      );

    } catch (e, st) {
      log.fatal("Fehler beim Speichern: $e", stack: st);
      state = state.copyWith(status: AutofillHotkeyStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  // ------------------------------------------------------------------------
  // --- Setter für den UI-State (synchron) ---
  // ------------------------------------------------------------------------

  /// Setter für Hotkey.
  void setHotkey(String value) {
    final error = state.error.field == 'hotkey' ? AppError.none() : null;
    state = state.copyWith(hotkey: value, error: error);
  }
  
}
