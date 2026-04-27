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

    // UI-State zurücksetzen
    state = const LogConfigState().copyWith(status: LogConfigStatus.progress);

    try {
      // UI-State aktualisieren
      final formData = LogConfigFormData(
        level: _configService.logLevel,
        days: _configService.logDays,
        size: _configService.logSize ~/ 1024,
      );
      state = state.copyWith(
        formData: formData,
        originalFormData: formData,
        status: LogConfigStatus.loaded,
      );
    }

    catch (e, st) {
      Logger().error('Fehler beim Laden der Konfiguration: $e', context: {'stack': st.toString()});
      state = state.copyWith(status: LogConfigStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  /// Speichert geänderte Log-Einstellungen und wendet sie sofort auf den Logger an.
  Future<void> save() async {
    if (state.isBusy) return;

    final formData = state.formData;
    _configService.logLevel = formData.level;
    _configService.logDays = formData.days;
    _configService.logSize = formData.size * 1024;

    // Sofort wirksam ohne App-Neustart
    Logger().configure(level: formData.level, days: formData.days, size: formData.size);

    state = state.copyWith(
      originalFormData: formData,
      status: LogConfigStatus.saved,
    );
  }

  // ------------------------------------------------------------------------
  // --- Setter für den UI-State (synchron) ---
  // ------------------------------------------------------------------------

  /// Setter für den Log-Level
  void setLevel(LogLevel value) {
    final formData = state.formData.copyWith(level: value);
    state = state.copyWith(formData: formData, status: LogConfigStatus.loaded);
  }

  /// Setter für die Aufbewahrungsdauer in Tagen
  void setDays(int value) {
    final formData = state.formData.copyWith(days: value);
    state = state.copyWith(formData: formData, status: LogConfigStatus.loaded);
  }

  /// Verringert die Aufbewahrungsdauer um einen Tag.
  void decrementDays() {
    setDays(state.formData.days - 1);
  }

  /// Erhöht die Aufbewahrungsdauer um einen Tag.
  void incrementDays() {
    setDays(state.formData.days + 1);
  }

  /// Setter für die Dateigröße in KB.
  void setSize(int value) {
    final formData = state.formData.copyWith(size: value);
    state = state.copyWith(formData: formData, status: LogConfigStatus.loaded);
  }

  /// Verringert  die Dateigröße um 256 KB.
  void decrementSize() {
    setSize(state.formData.size - 256);
  }

  /// Erhöht  die Dateigröße um 256 KB.
  void incrementSize() {
    setSize(state.formData.size + 256);
  }
}