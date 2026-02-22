import 'dart:math';
import 'package:zxcvbn/zxcvbn.dart';

class PasswordService {
  final _zxcvbn = Zxcvbn();

  int estimateStrength(String password) {
    if (password.isEmpty) return 0;
    final result = _zxcvbn.evaluate(password);
    return (result.score ?? 0).toInt();
  }

  String generatePassword(int length, bool avoidIlO0, String? specialChars) {
    final chars = StringBuffer("abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ123456789");
    if (!avoidIlO0) {
      chars.write("IlO0");
    }
    chars.write(specialChars ?? "!@#\$%^&*()_+-=[]{}|;:,.<>?");
    
    final source = chars.toString();
    final random = Random.secure();
    return List.generate(length, (index) => source[random.nextInt(source.length)]).join();
  }
}
