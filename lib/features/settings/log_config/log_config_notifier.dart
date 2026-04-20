import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/features/settings/log_config/log_config_form_data.dart';
import 'package:privault/features/settings/log_config/log_config_state.dart';
import 'package:privault/services/config_service.dart';

final logConfigProvider = NotifierProvider<LogConfigNotifier, LogConfigState>(() {
  return LogConfigNotifier();
});

/// Notifier für den Log-Datei-Dialog.
///
/// Lädt den Inhalt der Logdatei und ermöglicht das Anpassen
/// von [LogLevel] und [maxDays] in der [ConfigService]-Konfiguration.
class LogConfigNotifier extends Notifier<LogConfigState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

  late final ConfigService _configService;

  // ------------------------------------------------------------------------
  // --- Initialisierung ---
  // ------------------------------------------------------------------------

  @override
  LogConfigState build() {
    _configService = getIt<ConfigService>();
    return const LogConfigState();
  }

  // ------------------------------------------------------------------------
  // --- Öffentliche Methoden ---
  // ------------------------------------------------------------------------

  /// LädtKonfiguration der Log-Datei.
  Future<void> load() async {
    if (state.isBusy) return;
    state = const LogConfigState().copyWith(status: LogConfigStatus.progress);

    try {
      final formData = LogConfigFormData(
        minLevel: _configService.logMinLevel,
        maxDays: _configService.logMaxDays,
      );
      state = state.copyWith(
        formData: formData,
        originalFormData: formData,
        status: LogConfigStatus.loaded,
      );
    }

    catch (e, st) {
      Logger().error('Fehler beim Laden der Konfiguration: $e', context: {'stack': st.toString()});
      state = state.copyWith(
        status: LogConfigStatus.failure,
        error: AppError(ErrorCode.unknown, text: 'Konfiguration für die Log-Datei konnte nicht gelesen werden.'),
      );
    }
  }

  /// Speichert geänderte Log-Einstellungen und wendet sie sofort auf den Logger an.
  Future<void> save() async {
    if (state.isBusy) return;

    final formData = state.formData;
    _configService.logMinLevel = formData.minLevel;
    _configService.logMaxDays = formData.maxDays;

    // Sofort wirksam ohne App-Neustart
    Logger().configure(minLevel: formData.minLevel, maxDays: formData.maxDays);

    state = state.copyWith(
      originalFormData: formData,
      status: LogConfigStatus.saved,
    );
  }

  // ------------------------------------------------------------------------
  // --- Setter für den UI-State (synchron) ---
  // ------------------------------------------------------------------------

  /// Setter für den minimalen Log-Level
  void setMinLevel(LogLevel value) {
    final formData = state.formData.copyWith(minLevel: value);
    state = state.copyWith(formData: formData, status: LogConfigStatus.loaded);
  }

  /// Setter für die maximale Aufbewahrungsdauer in Tagen
  void setMaxDays(int value) {
    final formData = state.formData.copyWith(maxDays: value);
    state = state.copyWith(formData: formData, status: LogConfigStatus.loaded);
  }
}