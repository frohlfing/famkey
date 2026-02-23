import 'package:privault/models/dtos/user_response.dart';

class SaltMismatchException implements Exception {
  final UserResponse userResponse;

  SaltMismatchException(this.userResponse);

  @override
  String toString() {
    return 'SaltMismatchException: Das Master-Passwort wurde auf einem anderen Gerät geändert oder dies ist ein neues Gerät.';
  }
}
