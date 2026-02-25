import 'dart:math';
import 'package:zxcvbn/zxcvbn.dart';

/// Ein Hilfsdienst zur Generierung und Bewertung von Passwörtern.
///
/// Dieser Service ist bewusst zustandslos und bündelt die reine Logik zur
/// Passwortverarbeitung, um ViewModels (wie EditViewModel oder SettingsViewModel)
/// schlank zu halten und Code-Duplizierung zu vermeiden.
class PasswordService {
  // Die Zxcvbn-Bibliothek bewertet Passwörter sehr realistisch,
  // da sie Wörterbücher und typische Muster (wie "123456" oder "qwertz") erkennt.
  final _zxcvbn = Zxcvbn();

  /// Bewertet die Stärke eines Passworts.
  ///
  /// Nutzt den Zxcvbn-Algorithmus zur Einschätzung der Entropie.
  ///
  /// Rückgabewerte (Score):
  /// - 0: Zu erraten in < 10^3 Versuchen (Sehr schwach)
  /// - 1: Zu erraten in < 10^6 Versuchen (Schwach)
  /// - 2: Zu erraten in < 10^8 Versuchen (Mittel)
  /// - 3: Zu erraten in < 10^10 Versuchen (Gut)
  /// - 4: Starkes, unerratbares Passwort (Sehr stark)
  int estimateStrength(String password) {
    if (password.isEmpty) return 0;

    // Evaluate prüft auf Wörterbücher, Tastaturmuster und Leetspeak.
    final result = _zxcvbn.evaluate(password);

    return (result.score ?? 0).toInt();
  }

  /// Generiert ein kryptografisch sicheres Zufallspasswort.
  ///
  /// [length] Die gewünschte Länge des Passworts.
  /// [avoidIlO0] Wenn `true`, werden optisch leicht verwechselbare Zeichen
  ///             (großes i, kleines L, großes O, Null) weggelassen.
  /// [specialChars] Eine Zeichenkette von Sonderzeichen, die im Passwort
  ///                verwendet werden dürfen. Falls `null`, wird ein Standard-Set genutzt.
  String generatePassword(int length, bool avoidIlO0, String? specialChars) {
    // Basis-Zeichensatz (ohne die verwechselbaren Zeichen I, l, O, 0)
    final chars = StringBuffer("abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ123456789");

    // Falls nicht verboten, die verwechselbaren Zeichen wieder hinzufügen
    if (!avoidIlO0) {
      chars.write("IlO0");
    }

    // Sonderzeichen anfügen (Standard falls keine übergeben wurden)
    chars.write(specialChars ?? "!@#\$%^&*()_+-=[]{}|;:,.<>?");

    final source = chars.toString();

    // Random.secure() greift auf die sichere Entropiequelle des OS zu
    final random = Random.secure();

    // Aus dem Pool zufällig Zeichen ziehen und zu einem String zusammensetzen
    return List.generate(length, (index) => source[random.nextInt(source.length)]).join();
  }
}
