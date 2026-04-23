import 'dart:math';
import 'package:zxcvbn/zxcvbn.dart';

/// Standardlänge für Passwörter.
const defaultPwLength = 20;

/// Empfohlene Passwort-Sonderzeichen.
const defaultPwSpecialChars = '!?§\$€%&#@()[]{}<>=_~-+*,;.:/|';

/// Alle druckbaren Sonderzeichen (ohne Leerzeichen).
const allPwSpecialChars = '!?§\$€%&#@()[]{}<>=_~-+*,;.:/|\\^´`\'"';

/// Ein Hilfsdienst zur Generierung und Bewertung von Passwörtern.
class PasswordService {

  // ------------------------------------------------------------------------
  // --- Interne Variablen ---
  // ------------------------------------------------------------------------

  // Die Zxcvbn-Bibliothek bewertet Passwörter sehr realistisch,
  // da sie Wörterbücher und typische Muster (wie "123456" oder "qwertz") erkennt.
  final _zxcvbn = Zxcvbn();

  // ------------------------------------------------------------------------
  // --- Methoden ---
  // ------------------------------------------------------------------------

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

    // Was der Algorithmus intern prüft:
    // 1. Wörterbücher — vergleicht gegen Listen mit häufigen Passwörtern (password123), Vornamen, Städtenamen usw.
    // 2. Tastaturmuster — erkennt Sequenzen wie qwerty, asdf, 12345
    // 3. Leet-Speak — erkennt Substitutionen wie p@ssw0rd
    // 4. Wiederholungen & Sequenzen — z.B. aaaa oder abcabc
    // 5. Datumsangaben — z.B. 12.04.1990

    // Das Ergebnis (result) enthält u.a.:
    // - result.score — ganzzahl 0–4
    // - result.guesses — geschätzte Anzahl an Rateversuchen
    // - result.crackTime* — geschätzte Crack-Zeit in verschiedenen Szenarien
    // - result.feedback — konkrete Hinweise wie "Verwende kein häufiges Wort"

    final result = _zxcvbn.evaluate(password);

    return (result.score ?? 0).toInt();
  }

  /// Generiert ein kryptografisch sicheres Zufallspasswort.
  ///
  /// Mit [specialChars] werden die Sonderzeichen angegeben, die im Passwort verwendet werden dürfen.
  /// Wenn [avoidIlO0] `true` ist, werden optisch leicht verwechselbare Zeichen (großes i, kleines L, großes o, Zahl 0) weggelassen.
  String generatePassword({int length = defaultPwLength, String specialChars = defaultPwSpecialChars, bool withUmlauts = true, bool avoidIlO0 = true}) {
    // Basis-Zeichensatz (ohne die verwechselbaren Zeichen I, l, O, 0)
    final chars = StringBuffer('abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ123456789');

    // Falls nicht verboten, die verwechselbaren Zeichen hinzufügen
    if (!avoidIlO0) {
      chars.write('IlO0');
    }

    if (withUmlauts) {
      chars.write('äöüÄÖÜß');
    }

    // Sonderzeichen anfügen (Standard falls keine übergeben wurden)
    chars.write(specialChars);

    // Duplikate entfernen
    final source = chars.toString().split('').toSet().join();

    // Random.secure() greift auf die sichere Entropiequelle des OS zu
    final random = Random.secure();

    // Aus dem Pool zufällig Zeichen ziehen und zu einem String zusammensetzen
    return List.generate(length, (index) => source[random.nextInt(source.length)]).join();
  }
}
