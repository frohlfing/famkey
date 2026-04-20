import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto_hash;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/features/report/report_state.dart';
import 'package:privault/models/payloads/entry_payload.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/password_service.dart';
import 'package:privault/services/session_service.dart';

final reportProvider = NotifierProvider<ReportNotifier, ReportState>(() {
  return ReportNotifier();
});

/// Notifier für die Sicherheitsanalyse-Seite.
///
/// Lädt alle Einträge aus der Datenbank, entschlüsselt sie und prüft
/// jedes Passwort gegen die HaveIBeenPwned-API (k-Anonymitäts-Modell).
class ReportNotifier extends Notifier<ReportState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

  late final CryptoService _cryptoService;
  late final DatabaseService _databaseService;
  late final PasswordService _passwordService;
  late final SessionService _sessionService;

  // ------------------------------------------------------------------------
  // --- Interne Variablen ---
  // ------------------------------------------------------------------------

  /// Separater Dio-Client für die externe HIBP-API
  final Dio _hibpDio = Dio(BaseOptions(
    baseUrl: 'https://api.pwnedpasswords.com/',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'User-Agent': 'PriVault-PasswordManager',
      'Add-Padding': 'true', // HIBP-Empfehlung: padding gegen Traffic-Analyse
    },
  ));

  // ------------------------------------------------------------------------
  // --- Initialisierung ---
  // ------------------------------------------------------------------------

  @override
  ReportState build() {
    _cryptoService   = getIt<CryptoService>();
    _databaseService = getIt<DatabaseService>();
    _passwordService = getIt<PasswordService>();
    _sessionService  = getIt<SessionService>();

    return const ReportState();
  }

  // ------------------------------------------------------------------------
  // --- Öffentliche Methoden ---
  // ------------------------------------------------------------------------

  /// Startet die vollständige Sicherheitsanalyse.
  ///
  /// 1. Alle Einträge aus der DB laden und entschlüsseln
  /// 2. Jeden Passwort-Hash gegen die HIBP-API prüfen
  /// 3. Statistiken (Älteste, Altersverteilung) berechnen
  Future<void> load() async {
    if (state.isBusy) return;

    state = const ReportState().copyWith(
      status: ReportActionStatus.loading,
      error: AppError.none(),
    );

    try {
      if (_sessionService.privateKey == null) {
        throw Exception('Der private Schlüssel ist nicht in der Session.');
      }
      if (_sessionService.user == null) {
        throw Exception('Der Benutzer liegt nicht in der Session.');
      }

      // 1. Alle Einträge laden
      final entries = await _databaseService.getEntries();

      state = state.copyWith(totalCount: entries.length);

      // 2. Entschlüsseln und analysieren
      final reportEntries = <ReportEntry>[];

      for (final entry in entries) {
        // Berechtigung und Entry-Key per RSA entschlüsseln
        final perm = await _databaseService.getPermissionByEntryIdAndUserId(
            entry.id, _sessionService.user!.id);
        if (perm == null) continue;

        late EntryPayload payload;
        try {
          final entryKey = await _cryptoService.decryptRsa(
              perm.encryptedKey, _sessionService.privateKey!);
          final decrypted = await _cryptoService.decrypt(entry.encryptedData, entryKey);
          payload = EntryPayload.fromJson(json.decode(utf8.decode(decrypted)));
        } catch (e) {
          Logger().fatal('Report: Eintrag ${entry.id} konnte nicht entschlüsselt werden: $e');
          state = state.copyWith(checkedCount: state.checkedCount + 1);
          continue;
        }

        // HIBP-Prüfung (k-Anonymitäts-Modell)
        final pwnedCount = await _checkHibp(payload.password);

        // Passwortstärke ermitteln
        final strength = _passwordService.estimateStrength(payload.password);

        reportEntries.add(ReportEntry(
          id: entry.id,
          title: payload.title,
          username: payload.username,
          passwordTimestamp: payload.passwordTimestamp,
          pwnedCount: pwnedCount,
          strength: strength,
        ));

        // Fortschritt hochzählen und State aktualisieren
        state = state.copyWith(checkedCount: state.checkedCount + 1);
      }

      // 3. Ergebnisse aufbereiten
      final pwnedEntries = reportEntries
          .where((e) => e.pwnedCount > 0)
          .toList()
        ..sort((a, b) => b.pwnedCount.compareTo(a.pwnedCount)); // meiste Treffer zuerst

      final oldestPasswords = _buildOldestList(reportEntries);
      final ageBuckets = _buildAgeBuckets(reportEntries);

      state = state.copyWith(
        status: ReportActionStatus.loaded,
        pwnedEntries: pwnedEntries,
        oldestPasswords: oldestPasswords,
        ageBuckets: ageBuckets,
      );

    } catch (e, st) {
      Logger().fatal('Fehler beim Laden des Reports: $e', stack: st);
      state = state.copyWith(
        status: ReportActionStatus.failure,
        error: AppError(ErrorCode.unknown),
      );
    }
  }

  // ------------------------------------------------------------------------
  // --- Interne Methoden ---
  // ------------------------------------------------------------------------

  /// Prüft ein Passwort gegen die HaveIBeenPwned-API.
  ///
  /// Nutzt das k-Anonymitäts-Modell:
  /// - Berechnet SHA-1 des Passworts
  /// - Sendet nur die ersten 5 Zeichen des Hashes
  /// - HIBP gibt alle Hashes zurück, die mit diesem Präfix beginnen
  /// - Lokal wird geprüft, ob der vollständige Hash enthalten ist
  ///
  /// Gibt die Anzahl der Leak-Vorkommen zurück (0 = nicht gefunden).
  Future<int> _checkHibp(String password) async {
    if (password.isEmpty) return 0;

    try {
      // SHA-1 des Passworts berechnen
      final bytes = utf8.encode(password);
      final sha1Digest = crypto_hash.sha1.convert(bytes);
      final sha1Hex = sha1Digest.toString().toUpperCase();

      // Nur die ersten 5 Zeichen an die API senden
      final prefix = sha1Hex.substring(0, 5);
      final suffix = sha1Hex.substring(5);

      // HIBP-API anfragen
      final response = await _hibpDio.get<String>('range/$prefix');
      final body = response.data ?? '';

      // Antwort zeilenweise parsen: "SUFFIX:COUNT\r\n..."
      for (final line in body.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final colonIdx = trimmed.indexOf(':');
        if (colonIdx < 0) continue;
        final lineSuffix = trimmed.substring(0, colonIdx);
        if (lineSuffix == suffix) {
          return int.tryParse(trimmed.substring(colonIdx + 1)) ?? 1;
        }
      }

      return 0; // Nicht gefunden → sicher

    } on DioException catch (e) {
      // Netzwerkfehler: Wir überspringen diesen Eintrag still
      Logger().fatal('HIBP-Anfrage fehlgeschlagen: ${e.message}');
      return -1; // -1 = Prüfung nicht möglich (kein Netzwerk o.ä.)
    } catch (e) {
      Logger().fatal('HIBP: Unbekannter Fehler: $e');
      return -1;
    }
  }

  /// Baut die Top-10-Liste der Einträge mit den ältesten Passwörtern.
  ///
  /// Einträge ohne Zeitstempel kommen ans Ende.
  List<ReportEntry> _buildOldestList(List<ReportEntry> entries) {
    final withDate = entries
        .where((e) => e.passwordTimestamp != null)
        .toList()
      ..sort((a, b) => a.passwordTimestamp!.compareTo(b.passwordTimestamp!));

    final withoutDate = entries.where((e) => e.passwordTimestamp == null).toList();

    return [...withDate, ...withoutDate].take(10).toList();
  }

  /// Baut die Altersverteilung der Passwörter für das Balkendiagramm.
  List<AgeBucket> _buildAgeBuckets(List<ReportEntry> entries) {
    final now = DateTime.now();

    int bucket0  = 0; // < 30 Tage
    int bucket1  = 0; // 30–90 Tage
    int bucket2  = 0; // 90–180 Tage
    int bucket3  = 0; // 180 Tage–1 Jahr
    int bucket4  = 0; // > 1 Jahr
    int bucketN  = 0; // Unbekannt

    for (final e in entries) {
      if (e.passwordTimestamp == null) {
        bucketN++;
        continue;
      }
      final days = now.difference(e.passwordTimestamp!).inDays;
      if (days < 30)        bucket0++;
      else if (days < 90)   bucket1++;
      else if (days < 180)  bucket2++;
      else if (days < 365)  bucket3++;
      else                  bucket4++;
    }

    return [
      AgeBucket(label: '< 30 T.',      count: bucket0, daysMin: 0,   daysMax: 29),
      AgeBucket(label: '30–90 T.',     count: bucket1, daysMin: 30,  daysMax: 89),
      AgeBucket(label: '90–180 T.',    count: bucket2, daysMin: 90,  daysMax: 179),
      AgeBucket(label: '180 T.–1 J.',  count: bucket3, daysMin: 180, daysMax: 364),
      AgeBucket(label: '> 1 Jahr',     count: bucket4, daysMin: 365, daysMax: -1),
      AgeBucket(label: 'Unbekannt',    count: bucketN, daysMin: -1,  daysMax: -1),
    ];
  }
}