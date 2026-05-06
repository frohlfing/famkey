import 'package:famkey/services/autotype_service.dart';

/// Platzhalter-Implementierung für Plattformen ohne Auto-Type-Unterstützung (Android, Web).
class AutotypeServiceNoop implements AutotypeService {
  @override
  bool get isSupported => false;

  @override
  Future<void> init() async {}

  @override
  Future<void> unregisterHotkey() async {}

  @override
  Future<void> reregisterHotkey() async {}

  @override
  Future<String> getLastWindowTitle() async => '';

  @override
  Future<bool> typeCredentials(String username, String password) async => false;
}
