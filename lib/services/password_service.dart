import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto_hash;
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:privault/core/app_file.dart';
import 'package:privault/core/app_file_factory.dart';
import 'package:privault/core/env.dart';
import 'package:privault/core/logger.dart';
import 'package:zxcvbn/zxcvbn.dart';

/// Standardlänge für Passwörter.
const defaultPwLength = 20;

/// Empfohlene Passwort-Sonderzeichen.
const defaultPwSpecialChars = '!?§\$€%&#@()[]{}<>=_~-+*,;.:/|';

/// Alle druckbaren Sonderzeichen (ohne Leerzeichen).
const allPwSpecialChars = '!?§\$€%&#@()[]{}<>=_~-+*,;.:/|\\^´`\'"';

/// Hilfsdienst zur Generierung und Bewertung von Passwörtern sowie HIBP-Prüfungen.
class PasswordService {

  // ------------------------------------------------------------------------
  // --- Interne Variablen ---
  // ------------------------------------------------------------------------

  // Die Zxcvbn-Bibliothek bewertet Passwörter sehr realistisch,
  // da sie Wörterbücher und typische Muster (wie "123456" oder "qwertz") erkennt.
  final _zxcvbn = Zxcvbn();

  /// Separater Dio-Client für die externe HIBP-API
  final Dio _hibpDio = Dio(
    BaseOptions(
      baseUrl: 'https://api.pwnedpasswords.com/',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': 'PriVault-PasswordManager',
        'Add-Padding': 'true', // HIBP-Empfehlung: padding gegen Traffic-Analyse
      },
    ),
  );

  /// Cache: SHA-1-Präfix (5 Hex-Zeichen) → API-Antwort + Zeitstempel (Unix-Sekunden)
  AppFile _hibpCacheFile = const AppFile.none();
  Map<String, ({String body, int ts})> _hibpCache = {};
  bool _hibpCacheLoaded = false;

  // ------------------------------------------------------------------------
  // --- Passwortstärke ---
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
  /// - 4: Starkes, unerratbares Passwort (Stark)
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

  /// Bewertet ein Passwort vollständig und gibt Score, Guesses und Crack-Zeit zurück.
  ///
  /// - [score]: Zxcvbn-Score 0–4, abgeleitet aus [guesses] (Schwellwerte: 10^3, 10^6, 10^8, 10^10).
  /// - [guesses]: Geschätzte minimale Anzahl an Rateversuchen. Berechnet als Produkt der
  ///   Einzelschätzungen aller erkannten Teilmuster (Wörterbücher, Tastatursequenzen,
  ///   Leet-Speak, Datum etc.). Kann für starke Passwörter sehr groß werden.
  /// - [crackTime]: Menschenlesbare Crack-Zeit im Worst-Case-Szenario (10^10 Versuche/Sek.,
  ///   entspricht GPU-Cracking eines ungesalzenen Hashes). Englischer String der Zxcvbn-Bibliothek,
  ///   z.B. "3 hours", "centuries", "less than a second". Leerstring bei leerem Passwort.
  ///
  /// Da Score, Guesses und Crack-Zeit in einem einzigen [Zxcvbn.evaluate]-Aufruf berechnet werden,
  /// entstehen gegenüber [estimateStrength] keine Mehrkosten.
  ({int score, int guesses, String crackTime}) evaluatePassword(String password) {
    if (password.isEmpty) return (score: 0, guesses: 1, crackTime: '');
    final result = _zxcvbn.evaluate(password);
    return (
      score: (result.score ?? 0).toInt(),
      guesses: result.guesses,
      crackTime: result.crack_times_display?['offline_fast_hashing_1e10_per_second'] ?? '',
    );
  }

  // ------------------------------------------------------------------------
  // --- Passwortgenerator ---
  // ------------------------------------------------------------------------

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

  // ------------------------------------------------------------------------
  // --- HIBP-Cache ---
  // ------------------------------------------------------------------------

  /// Lädt den HIBP-Cache beim ersten Aufruf aus der JSON-Datei im App-Verzeichnis.
  Future<void> _loadHibpCache() async {
    try {
      final path = env.isWeb ? 'hibp_cache.json' : p.join(env.storagePath, 'hibp_cache.json');
      _hibpCacheFile = createAppFile(path);

      if (!await _hibpCacheFile.exists()) {
        _hibpCache = {};
        return;
      }

      final raw = json.decode(await _hibpCacheFile.readAsString()) as Map<String, dynamic>;
      _hibpCache = {};
      for (final e in raw.entries) {
        final m = e.value as Map<String, dynamic>;
        _hibpCache[e.key] = (body: m['body'] as String, ts: m['ts'] as int);
      }
    } catch (e) {
      Logger().fatal('HIBP-Cache: Fehler beim Laden: $e');
      _hibpCache = {};
    }
  }

  /// Speichert den HIBP-Cache als JSON-Datei.
  Future<void> _saveHibpCache() async {
    try {
      final m = _hibpCache.map((k, v) => MapEntry(k, {'body': v.body, 'ts': v.ts}));
      await _hibpCacheFile.writeAsString(json.encode(m));
    } catch (e) {
      Logger().fatal('HIBP-Cache: Fehler beim Speichern: $e');
    }
  }

  // ------------------------------------------------------------------------
  // --- Darknet-Check (HaveIBeenPwned) ---
  // ------------------------------------------------------------------------

  /// Prüft ein Passwort gegen die HaveIBeenPwned-API.
  ///
  /// Nutzt das k-Anonymitäts-Modell:
  /// - Berechnet SHA-1 des Passworts
  /// - Sendet nur die ersten 5 Zeichen des Hashes (Präfix)
  /// - HIBP gibt alle Hashes zurück, die mit diesem Präfix beginnen
  /// - Lokal wird geprüft, ob der vollständige Hash enthalten ist
  ///
  /// Der Disk-Cache wird beim ersten Aufruf automatisch geladen und nach jedem
  /// neuen API-Ergebnis (Cache-Miss) sofort gespeichert. [cacheDays] bestimmt
  /// die Gültigkeit eines gecachten Eintrags.
  ///
  /// Gibt die Anzahl der Leak-Vorkommen zurück (0 = sicher, -1 = Prüfung nicht möglich).
  Future<int> checkHibp(String password, {int cacheDays = 1}) async {
    if (password.isEmpty) return 0;

    if (!_hibpCacheLoaded) {
      await _loadHibpCache();
      _hibpCacheLoaded = true;
    }

    try {
      // SHA-1 des Passworts berechnen
      final bytes = utf8.encode(password);
      final sha1Hex = crypto_hash.sha1.convert(bytes).toString().toUpperCase();
      final prefix = sha1Hex.substring(0, 5);
      final suffix = sha1Hex.substring(5);

      // Cache prüfen
      final nowTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final cached = _hibpCache[prefix];
      String body;
      if (cached != null && (nowTs - cached.ts) < cacheDays * 86400) {
        body = cached.body;
      } else {
        // HIBP-API anfragen
        final response = await _hibpDio.get<String>('range/$prefix');
        if (response.data == null) return -1; // Netzwerkfehler
        body = response.data!;
        _hibpCache[prefix] = (body: body, ts: nowTs);
        await _saveHibpCache();
      }

      // Antwort zeilenweise parsen und Suffix im Body suchen: "SUFFIX:COUNT\r\n..."
      for (final line in body.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final colonIdx = trimmed.indexOf(':');
        if (colonIdx < 0) continue;
        if (trimmed.substring(0, colonIdx) == suffix) {
          return int.tryParse(trimmed.substring(colonIdx + 1)) ?? 1;
        }
      }

      return 0; // Nicht gefunden → sicher

    } on DioException catch (e) {
      Logger().fatal('HIBP-Anfrage fehlgeschlagen: ${e.message}');
      return -1; // -1 = Prüfung nicht möglich (kein Netzwerk o.ä.)
    } catch (e) {
      Logger().fatal('HIBP: Unbekannter Fehler: $e');
      return -1;
    }
  }
}
