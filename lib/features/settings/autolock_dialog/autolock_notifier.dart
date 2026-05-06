import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famkey/core/app_error.dart';
import 'package:famkey/core/service_locator.dart';
import 'package:famkey/features/settings/autolock_dialog/autolock_state.dart';
import 'package:famkey/services/autolock_service.dart';
import 'package:famkey/services/config_service.dart';

final autolockProvider = NotifierProvider<AutolockNotifier, AutolockState>(() {
  return AutolockNotifier();
});

class AutolockNotifier extends Notifier<AutolockState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

  late final ConfigService _configService;
  late final AutolockService _autoLockService;

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  @override
  AutolockState build() {
    _configService = getIt<ConfigService>();
    _autoLockService = getIt<AutolockService>();
    return const AutolockState();
  }

  /// Lädt die aktuelle Einstellung aus der Konfiguration.
  Future<void> load() async {
    if (state.isBusy) return;
    final minutes = _configService.autoLockMinutes;
    state = AutolockState(
      selectedValue: minutes ?? 0,
      status: AutolockActionStatus.loaded,
    );
  }

  // ------------------------------------------------------------------------
  // --- Speichern ---
  // ------------------------------------------------------------------------

  /// Speichert den ausgewählten Wert in der Konfiguration und konfiguriert den Dienst.
  void save() {
    if (state.isBusy) return;
    state = state.copyWith(status: AutolockActionStatus.progress, error: AppError.none());
    final minutes = state.selectedValue == 0 ? null : state.selectedValue;
    _configService.autoLockMinutes = minutes;
    _autoLockService.configure(minutes);
    state = state.copyWith(status: AutolockActionStatus.saved);
  }

  // ------------------------------------------------------------------------
  // --- Setter für den UI-State (synchron) ---
  // ------------------------------------------------------------------------

  /// Setter für den ausgewählten Wert.
  void setSelectedValue(int value) {
    state = state.copyWith(selectedValue: value);
  }
}
