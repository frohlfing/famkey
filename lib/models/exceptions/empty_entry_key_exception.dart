import 'package:privault/models/dtos/user_response.dart';

/// Eine spezialisierte Exception, die während des Synchronisationsprozesses ausgelöst wird.
///
/// Sie signalisiert, dass es eine Berechtigung mit geleerten Entry-Key gibt.
/// Das passiert, wenn der Fingerprint eines Freund geändert wurde. In diesem Fall werden seine
/// Entry-Keys geleert (da die unbrauchbar geworden sind) und das Vertrauen entzogen.
class EmptyEntryKeyException implements Exception {
  /// Konstruktor
  EmptyEntryKeyException();

  @override
  String toString() {
    return 'EmptyEntryKeyException: Mindestens ein Freund hat Zugriff auf einen Eintrag, aber der Entry-Key fehlt.';
  }
}
