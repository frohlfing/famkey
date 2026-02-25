import 'package:privault/models/dtos/user_response.dart';

/// Eine spezialisierte Exception, die während des Synchronisationsprozesses ausgelöst wird.
/// Sie signalisiert, dass das lokal gespeicherte `Salt` des Benutzers nicht mit dem auf
/// dem Server übereinstimmt.
///
/// **Haupt-Szenarien für diese Exception:**
/// 1. **Adoption (Onboarding für Zweitgerät):** Der Benutzer meldet sich zum ersten Mal auf einem
///    neuen Gerät an. Das neue Gerät hat eine andere Identität (Salt, RSA-Paar) als der
///    Server und muss die des Servers "adoptieren".
/// 2. **Master-Passwort-Änderung:** Das Master-Passwort wurde auf einem anderen Gerät geändert.
///    Dies erzeugt ein neues Salt und einen neuen Private Key, die auf den Server hochgeladen
///    wurden. Das aktuelle Gerät muss nun ebenfalls diese neuen Daten übernehmen.
///
/// Die Exception transportiert die [UserResponse] vom Server, die alle notwendigen Daten
/// (neues Salt, neuer verschlüsselter Private Key) für den Adoptionsprozess enthält.
/// Der [GuardDialog] kann diese Daten nutzen, um den Benutzer nach seinem (neuen) Master-Passwort
/// zu fragen und die lokale Datenbank neu zu verschlüsseln.
class SaltMismatchException implements Exception {
  /// Die vom Server empfangenen Benutzerdaten, die den Konflikt ausgelöst haben.
  final UserResponse userResponse;

  /// Erstellt eine neue Instanz der [SaltMismatchException].
  SaltMismatchException(this.userResponse);

  @override
  String toString() {
    return 'SaltMismatchException: Das Master-Passwort wurde auf einem anderen Gerät geändert oder dies ist ein neues Gerät.';
  }
}
