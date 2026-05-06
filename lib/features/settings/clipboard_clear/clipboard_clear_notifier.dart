import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famkey/core/app_error.dart';
import 'package:famkey/core/service_locator.dart';
import 'package:famkey/features/settings/clipboard_clear/clipboard_clear_state.dart';
import 'package:famkey/services/config_service.dart';

final clipboardClearProvider = NotifierProvider<ClipboardClearNotifier, ClipboardClearState>(() {
  return ClipboardClearNotifier();
});

class ClipboardClearNotifier extends Notifier<ClipboardClearState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

  late final ConfigService _configService;

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  @override
  ClipboardClearState build() {
    _configService = getIt<ConfigService>();
    return const ClipboardClearState();
  }

  /// Lädt die aktuelle Einstellung aus der Konfiguration.
  Future<void> load() async {
    if (state.isBusy) return;
    final seconds = _configService.clipboardClearSeconds;
    state = ClipboardClearState(
      selectedValue: seconds ?? 0,
      status: ClipboardClearActionStatus.loaded,
    );
  }

  // ------------------------------------------------------------------------
  // --- Speichern ---
  // ------------------------------------------------------------------------

  /// Speichert den ausgewählten Wert in der Konfiguration.
  void save() {
    if (state.isBusy) return;
    state = state.copyWith(status: ClipboardClearActionStatus.progress, error: AppError.none());
    final seconds = state.selectedValue == 0 ? null : state.selectedValue;
    _configService.clipboardClearSeconds = seconds;
    state = state.copyWith(status: ClipboardClearActionStatus.saved);
  }

  // ------------------------------------------------------------------------
  // --- Setter für den UI-State (synchron) ---
  // ------------------------------------------------------------------------

  /// Setter für den ausgewählten Wert.
  void setSelectedValue(int value) {
    state = state.copyWith(selectedValue: value);
  }
}
