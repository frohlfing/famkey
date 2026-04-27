import 'package:privault/services/autofill_service.dart';

/// Web-Stub: Autofill ist im Browser nicht verfügbar.
///
/// PriVault läuft selbst im Browser (WebAssembly), daher kann es keine
/// systemeigene Autofill-Integration anbieten. Alle Methoden sind No-ops.
///
/// Eine Browser-Extension für Chrome/Edge ist als zukünftige Erweiterung (V2)
/// geplant: Die Extension würde über Native Messaging mit PriVault kommunizieren
/// und Formularfelder automatisch befüllen.
class AutofillServiceWeb implements AutofillService {
  @override
  Future<void> init() async {}

  @override
  String? get pendingDomain => null;

  @override
  bool get hasAutofillRequest => false;

  @override
  Future<void> complete(String username, String password) async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<bool> isAutofillEnabled() async => false;

  @override
  Future<String> getLastWindowTitle() async => '';

  @override
  Future<bool> typeCredentials(String username, String password) async => false;

  @override
  Future<void> openSystemSettings() async {}
}
