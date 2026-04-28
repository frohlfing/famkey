// Exportiert das Interface, damit Nutzer nur diese Datei importieren müssen
export 'system_settings_service/system_settings_service.dart';

// Interface
import 'system_settings_service/system_settings_service.dart';

// Plattformspezifische Implementierung
// Da `dart.library.io` sowohl für Windows als auch Mobile gilt, leiten
// wir beide auf eine native-Datei um, die dann intern unterscheidet.
import 'system_settings_service/system_settings_service_stub.dart'
  if (dart.library.ffi) 'system_settings_service/system_settings_service_native.dart'
  if (dart.library.js_interop) 'system_settings_service/system_settings_service_web.dart';

/// Factory
class SystemSettingsServiceFactory {
  static SystemSettingsService create() => createSystemSettingsService();
}