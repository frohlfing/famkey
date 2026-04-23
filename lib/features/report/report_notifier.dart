import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto_hash;
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:privault/core/app_error.dart';
import 'package:privault/core/app_file.dart';
import 'package:privault/core/app_file_factory.dart';
import 'package:privault/core/env.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/features/report/report_state.dart';
import 'package:privault/models/payloads/entry_payload.dart';
import 'package:privault/services/config_service.dart';
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
  late final ConfigService _configService;

  // ------------------------------------------------------------------------
  // --- Interne Variablen ---
  // ------------------------------------------------------------------------

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

  /// CancelToken zum sofortigen Abbruch laufender HIBP-Anfragen
  CancelToken _hibpCancelToken = CancelToken();

  /// Alle Report-Einträge (intern, für Neuberechnungen nach Einzelprüfung)
  List<ReportEntry> _allEntries = [];

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  @override
  ReportState build() {
    _cryptoService = getIt<CryptoService>();
    _databaseService = getIt<DatabaseService>();
    _passwordService = getIt<PasswordService>();
    _sessionService = getIt<SessionService>();
    _configService = getIt<ConfigService>();

    return const ReportState();
  }

  /// Startet die vollständige Sicherheitsanalyse.
  ///
  /// 1. Alle Einträge aus der DB laden und entschlüsseln
  /// 2. Jeden Passwort-Hash gegen die HIBP-API prüfen (mit Cache)
  /// 3. Statistiken (Älteste, Altersverteilung) berechnen
  Future<void> load() async {
    if (state.isBusy) return;

    // Zwischenergebnisse für den Report
    final reportEntries = <ReportEntry>[];

    // Neuen CancelToken für diese Analyse-Runde erstellen
    _hibpCancelToken = CancelToken();

    // 1. Ladeanzeige einblenden
    state = const ReportState().copyWith(status: ReportActionStatus.loading, error: AppError.none());
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      if (_sessionService.privateKey == null) {
        throw Exception('Der private Schlüssel ist nicht in der Session.');
      }
      if (_sessionService.user == null) {
        throw Exception('Der Benutzer liegt nicht in der Session.');
      }

      // Cache von Disk laden
      await _loadHibpCache();

      // 1. Alle Einträge laden
      final entries = await _databaseService.getEntries();

      // Gesamtanzahl für die Fortschrittsanzeige im State setzen
      state = state.copyWith(totalCount: entries.length);

      // 2. Einträge durchlaufen, Entschlüsseln und analysieren...
      for (final entry in entries) {

        // Eintrag entschlüsseln
        final perm = await _databaseService.getPermissionByEntryIdAndUserId(entry.id, _sessionService.user!.id);
        if (perm == null) throw Exception('Zum Eintrag ${entry.id} sind keine Zugriffsrechte gespeichert.');
        final entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, _sessionService.privateKey!);
        final decrypted = await _cryptoService.decrypt(entry.encryptedData, entryKey);
        final payload = EntryPayload.fromJson(json.decode(utf8.decode(decrypted)));

        // HIBP-Prüfung (k-Anonymitäts-Modell, mit Cache)
        final pwnedCount = await _checkHibp(payload.password);

        // Passwortstärke ermitteln
        final strength = _passwordService.estimateStrength(payload.password);

        // Zwischenergebnis speichern
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
        await Future.delayed(const Duration(milliseconds: 10)); // Rendering-Frame freigeben

        // Wurde abgebrochen?
        if (state.isAborting) {
          await _saveHibpCache();
          state = state.copyWith(status: ReportActionStatus.aborted, isAborting: false);
          return;
        }
      }

      // Cache auf Disk speichern
      await _saveHibpCache();

      // 3. Ergebnisse aufbereiten
      _allEntries = reportEntries;

      final pwnedEntries = reportEntries.where((e) => e.pwnedCount > 0).toList()..sort((a, b) => b.pwnedCount.compareTo(a.pwnedCount)); // meiste Treffer zuerst

      final oldestPasswords = _buildOldestList(reportEntries);
      final unknownAgeEntries = _buildUnknownAgeList(reportEntries);
      final ageBuckets = _buildAgeBuckets(reportEntries);

      state = state.copyWith(
        status: ReportActionStatus.loaded,
        pwnedEntries: pwnedEntries,
        oldestPasswords: oldestPasswords,
        unknownAgeEntries: unknownAgeEntries,
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
  // --- HIBP-Cache ---
  // ------------------------------------------------------------------------

  /// Lädt den HIBP-Cache aus der JSON-Datei im App-Verzeichnis.
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

  int c = 0;

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
  /// API-Antworten werden per Präfix gecacht (Gültigkeit: [ConfigService.hibpCacheDays]).
  ///
  /// Gibt die Anzahl der Leak-Vorkommen zurück (0 = nicht gefunden, -1 = Prüfung nicht möglich).
  Future<int> _checkHibp(String password) async {
    if (password.isEmpty) return 0;

    try {
      // SHA-1 des Passworts berechnen
      final bytes = utf8.encode(password);
      final sha1Hex = crypto_hash.sha1.convert(bytes).toString().toUpperCase();
      final prefix = sha1Hex.substring(0, 5);
      final suffix = sha1Hex.substring(5);

      // Cache prüfen
      final cacheDays = _configService.hibpCacheDays;
      final nowTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final cached = _hibpCache[prefix];
      String body;
      if (cached != null && (nowTs - cached.ts) < cacheDays * 86400) {
        body = cached.body;
      }
      else {
        c = c + 1;
        // HIBP-API anfragen
        final response = await _hibpDio.get<String>('range/$prefix', cancelToken: _hibpCancelToken);
        if (response.data == null) return -1; // Netzwerkfehler
        body = response.data!;
        _hibpCache[prefix] = (body: body, ts: nowTs);
      }

      // Antwort zeilenweise parsen und Suffix im Body suchen: "SUFFIX:COUNT\r\n..."
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

  // ------------------------------------------------------------------------
  // --- Passwort-Alter ---
  // ------------------------------------------------------------------------

  /// Baut die Top-10-Liste der Einträge mit den ältesten Passwörtern.
  ///
  /// Enthält nur Einträge mit bekanntem Datum.
  List<ReportEntry> _buildOldestList(List<ReportEntry> entries) {
    return (entries
      .where((e) => e.passwordTimestamp != null)
      .toList()
      ..sort((a, b) => a.passwordTimestamp!.compareTo(b.passwordTimestamp!))
    ).take(10).toList();
  }

  /// Gibt alle Einträge ohne bekanntes Passwort-Datum zurück.
  List<ReportEntry> _buildUnknownAgeList(List<ReportEntry> entries) {
    return entries.where((e) => e.passwordTimestamp == null).toList();
  }

  /// Baut die Altersverteilung der Passwörter für das Balkendiagramm.
  List<AgeBucket> _buildAgeBuckets(List<ReportEntry> entries) {
    final now = DateTime.now();

    int bucket0 = 0; // < 30 Tage
    int bucket1 = 0; // 30–90 Tage
    int bucket2 = 0; // 90–180 Tage
    int bucket3 = 0; // 180 Tage–1 Jahr
    int bucket4 = 0; // > 1 Jahr
    int bucketN = 0; // Unbekannt

    for (final e in entries) {
      if (e.passwordTimestamp == null) {
        bucketN++;
        continue;
      }
      final days = now.difference(e.passwordTimestamp!).inDays;
      if (days < 30)       { bucket0++; }
      else if (days < 90)  { bucket1++; }
      else if (days < 180) { bucket2++; }
      else if (days < 365) { bucket3++; }
      else                 { bucket4++; }
    }

    return [
      AgeBucket(label: '< 30 T.',     count: bucket0, daysMin: 0,   daysMax: 29),
      AgeBucket(label: '30–90 T.',    count: bucket1, daysMin: 30,  daysMax: 89),
      AgeBucket(label: '90–180 T.',   count: bucket2, daysMin: 90,  daysMax: 179),
      AgeBucket(label: '180 T.–1 J.', count: bucket3, daysMin: 180, daysMax: 364),
      AgeBucket(label: '> 1 Jahr',    count: bucket4, daysMin: 365, daysMax: -1),
      AgeBucket(label: 'Unbekannt',   count: bucketN, daysMin: -1,  daysMax: -1),
    ];
  }

  // ------------------------------------------------------------------------
  // --- Einzelprüfung nach Navigation ---
  // ------------------------------------------------------------------------

  /// Prüft einen einzelnen Eintrag erneut gegen HIBP und aktualisiert den State.
  ///
  /// Wird nach der Rückkehr von der Detailseite aufgerufen, damit geänderte
  /// Passwörter sofort aus der Rot-Liste verschwinden (oder dort verbleiben).
  Future<void> recheckEntry(int entryId) async {
    if (state.status != ReportActionStatus.loaded || _allEntries.isEmpty) return;

    try {
      final entry = await _databaseService.getEntry(entryId);

      if (entry == null) {
        // Eintrag wurde gelöscht → aus allen Listen entfernen
        _allEntries = _allEntries.where((e) => e.id != entryId).toList();
      } else {
        // Eintrag entschlüsseln
        final perm = await _databaseService.getPermissionByEntryIdAndUserId(entry.id, _sessionService.user!.id);
        if (perm == null) return;
        final entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, _sessionService.privateKey!);
        final decrypted = await _cryptoService.decrypt(entry.encryptedData, entryKey);
        final payload = EntryPayload.fromJson(json.decode(utf8.decode(decrypted)));

        final pwnedCount = await _checkHibp(payload.password);
        final strength = _passwordService.estimateStrength(payload.password);

        final updated = ReportEntry(
          id: entry.id,
          title: payload.title,
          username: payload.username,
          passwordTimestamp: payload.passwordTimestamp,
          pwnedCount: pwnedCount,
          strength: strength,
        );

        _allEntries = [for (final e in _allEntries) if (e.id == entryId) updated else e];
      }

      // Abgeleitete Listen neu berechnen
      final pwnedEntries = _allEntries.where((e) => e.pwnedCount > 0).toList()..sort((a, b) => b.pwnedCount.compareTo(a.pwnedCount));
      state = state.copyWith(
        pwnedEntries: pwnedEntries,
        oldestPasswords: _buildOldestList(_allEntries),
        unknownAgeEntries: _buildUnknownAgeList(_allEntries),
        ageBuckets: _buildAgeBuckets(_allEntries),
      );
    } catch (e, st) {
      Logger().fatal('Fehler beim Neuprüfen des Eintrags $entryId: $e', stack: st);
    }
  }

  // ------------------------------------------------------------------------
  // --- Abbruch-Button ---
  // ------------------------------------------------------------------------

  /// Signalisiert dem laufenden Vorgang, dass er abgebrochen werden soll.
  /// Bricht außerdem laufende HIBP-API-Anfragen sofort ab.
  void abortLoading() {
    _hibpCancelToken.cancel();
    state = state.copyWith(isAborting: true);
  }
}
