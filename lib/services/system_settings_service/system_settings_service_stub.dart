import 'package:famkey/services/system_settings_service/system_settings_service.dart';

/// Fallback, falls keine plattformspezifische Implementierung verfügbar ist.
SystemSettingsService createSystemSettingsService()
  => throw UnsupportedError('Plattform nicht unterstützt');
