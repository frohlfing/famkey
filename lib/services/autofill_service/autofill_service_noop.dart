import 'package:famkey/services/autofill_service.dart';

/// Platzhalter-Implementierung für Plattformen ohne Autofill-Unterstützung (Windows, Web).
class AutofillServiceNoop implements AutofillService {
  @override
  bool get isSupported => false;

  @override
  String? get pendingDomain => null;

  @override
  bool get hasAutofillRequest => false;

  @override
  Future<void> init() async {}

  @override
  Future<void> complete(String username, String password) async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<bool> isAutofillEnabled() async => false;

  @override
  Future<void> openSystemSettings() async {}
}
