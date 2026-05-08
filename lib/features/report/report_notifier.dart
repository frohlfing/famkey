import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famkey/core/app_error.dart';
import 'package:famkey/core/logger.dart';
import 'package:famkey/core/service_locator.dart';
import 'package:famkey/features/report/report_state.dart';
import 'package:famkey/models/payloads/entry_payload.dart';
import 'package:famkey/services/config_service.dart';
import 'package:famkey/services/crypto_service.dart';
import 'package:famkey/services/database_service.dart';
import 'package:famkey/services/password_service.dart';
import 'package:famkey/services/session_service.dart';

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

  /// Alle analysierten Report-Einträge (intern, für Neuberechnungen nach Einzelprüfung)
  List<ReportEntry> _allEntries = [];

  /// Vom Bericht ausgeschlossene Einträge (nur id/title/username, nicht analysiert)
  List<ReportEntry> _excludedEntries = [];

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
  /// 3. Statistiken (Stärke, Älteste, Altersverteilung) berechnen
  Future<void> load() async {
    if (state.isBusy) return;

    final reportEntries  = <ReportEntry>[];
    final excludedList   = <ReportEntry>[];
    int noPasswordCount  = 0;

    // Ladeanzeige einblenden
    state = const ReportState().copyWith(status: ReportActionStatus.loading, error: AppError.none());
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      if (_sessionService.privateKey == null) {
        throw Exception('Der private Schlüssel ist nicht in der Session.');
      }
      if (_sessionService.user == null) {
        throw Exception('Der Benutzer liegt nicht in der Session.');
      }

      // 1. Alle Einträge laden
      final entries = await _databaseService.getEntries();

      // Gesamtanzahl für die Fortschrittsanzeige im State setzen
      state = state.copyWith(totalCount: entries.length);

      // 2. Einträge durchlaufen, entschlüsseln und analysieren
      for (final entry in entries) {

        // Eintrag entschlüsseln
        final perm = await _databaseService.getPermissionByEntryIdAndUserId(entry.id, _sessionService.user!.id);
        if (perm == null) throw Exception('Zum Eintrag ${entry.id} sind keine Zugriffsrechte gespeichert.');
        final entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, _sessionService.privateKey!);
        final decrypted = await _cryptoService.decrypt(entry.encryptedData, entryKey);
        final payload = EntryPayload.fromJson(json.decode(utf8.decode(decrypted)));

        // Einträge ohne Passwort ignorieren
        if (payload.password.isEmpty) {
          noPasswordCount++;
          state = state.copyWith(checkedCount: state.checkedCount + 1);
          await Future.delayed(const Duration(milliseconds: 10));
          if (state.isAborting) {
            state = state.copyWith(status: ReportActionStatus.aborted, isAborting: false);
            return;
          }
          continue;
        }

        // Vom Bericht ausgeschlossene Einträge nur minimal erfassen
        if (payload.reportExcluded) {
          excludedList.add(ReportEntry(
            id: entry.id,
            title: payload.title,
            username: payload.username,
            passwordTimestamp: null,
            pwnedCount: 0,
            strength: 0,
            guesses: 0,
            crackTime: '',
          ));
          state = state.copyWith(checkedCount: state.checkedCount + 1);
          await Future.delayed(const Duration(milliseconds: 10));
          if (state.isAborting) {
            state = state.copyWith(status: ReportActionStatus.aborted, isAborting: false);
            return;
          }
          continue;
        }

        // HIBP-Prüfung (k-Anonymitäts-Modell, mit Cache)
        final pwnedCount = await _passwordService.checkHibp(payload.password, cacheDays: _configService.hibpCacheDays);

        // Passwortstärke, Guesses und Crack-Zeit ermitteln
        final (:score, :guesses, :crackTime) = _passwordService.evaluatePassword(payload.password);

        // Zwischenergebnis speichern
        reportEntries.add(ReportEntry(
          id: entry.id,
          title: payload.title,
          username: payload.username,
          passwordTimestamp: payload.passwordTimestamp,
          pwnedCount: pwnedCount,
          strength: score,
          guesses: guesses,
          crackTime: crackTime,
        ));

        // Fortschritt hochzählen und State aktualisieren
        state = state.copyWith(checkedCount: state.checkedCount + 1);
        await Future.delayed(const Duration(milliseconds: 10)); // Rendering-Frame freigeben

        // Wurde abgebrochen?
        if (state.isAborting) {
          state = state.copyWith(status: ReportActionStatus.aborted, isAborting: false);
          return;
        }
      }

      // 3. Ergebnisse aufbereiten
      _allEntries      = reportEntries;
      _excludedEntries = excludedList;

      state = state.copyWith(
        status: ReportActionStatus.loaded,
        pwnedEntries: reportEntries.where((e) => e.pwnedCount > 0).toList()..sort((a, b) => b.pwnedCount.compareTo(a.pwnedCount)),
        urgentPasswords: _buildUrgentList(reportEntries),
        weakestPasswords: _buildWeakestList(reportEntries),
        oldestPasswords: _buildOldestList(reportEntries),
        unknownAgeEntries: _buildUnknownAgeList(reportEntries),
        ageBuckets: _buildAgeBuckets(reportEntries),
        strengthBuckets: _buildStrengthBuckets(reportEntries),
        noPasswordCount: noPasswordCount,
        excludedEntries: excludedList,
      );

    } catch (e, st) {
      log.fatal('Fehler beim Laden des Reports: $e', stack: st);
      state = state.copyWith(
        status: ReportActionStatus.failure,
        error: AppError(ErrorCode.unknown),
      );
    }
  }

  // ------------------------------------------------------------------------
  // --- Passwortstärke ---
  // ------------------------------------------------------------------------

  /// Alle Einträge mit Score 0 (Sehr schwach) oder 1 (Schwach), aufsteigend nach Guesses.
  List<ReportEntry> _buildUrgentList(List<ReportEntry> entries) {
    return entries.where((e) => e.strength <= 1).toList()
      ..sort((a, b) => a.guesses.compareTo(b.guesses));
  }

  /// Top 10 der Einträge mit Score ab 2 (Mittel, Gut, Stark), aufsteigend nach Guesses.
  List<ReportEntry> _buildWeakestList(List<ReportEntry> entries) {
    return (entries.where((e) => e.strength >= 2).toList()
      ..sort((a, b) => a.guesses.compareTo(b.guesses)))
      .take(10).toList();
  }

  /// Stärkeverteilung aller Einträge (Score 0–4).
  List<StrengthBucket> _buildStrengthBuckets(List<ReportEntry> entries) {
    final counts = List.filled(5, 0);
    for (final e in entries) {
      counts[e.strength.clamp(0, 4)]++;
    }
    const labels = ['Sehr schwach', 'Schwach', 'Mittel', 'Gut', 'Stark'];
    return [
      for (var i = 0; i < 5; i++)
        StrengthBucket(label: labels[i], count: counts[i], score: i),
    ];
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
    final now = DateTime.now().toUtc();

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
    if (state.status != ReportActionStatus.loaded) return;

    try {
      final entry = await _databaseService.getEntry(entryId);

      if (entry == null) {
        // Eintrag wurde gelöscht → aus allen Listen entfernen
        _allEntries      = _allEntries.where((e) => e.id != entryId).toList();
        _excludedEntries = _excludedEntries.where((e) => e.id != entryId).toList();
      } else {
        // Eintrag entschlüsseln
        final perm = await _databaseService.getPermissionByEntryIdAndUserId(entry.id, _sessionService.user!.id);
        if (perm == null) return;
        final entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, _sessionService.privateKey!);
        final decrypted = await _cryptoService.decrypt(entry.encryptedData, entryKey);
        final payload = EntryPayload.fromJson(json.decode(utf8.decode(decrypted)));

        if (_allEntries.any((e) => e.id == entryId)) {
          final pwnedCount = await _passwordService.checkHibp(payload.password, cacheDays: _configService.hibpCacheDays);
          final (:score, :guesses, :crackTime) = _passwordService.evaluatePassword(payload.password);
          final updated = ReportEntry(
            id: entry.id,
            title: payload.title,
            username: payload.username,
            passwordTimestamp: payload.passwordTimestamp,
            pwnedCount: pwnedCount,
            strength: score,
            guesses: guesses,
            crackTime: crackTime,
          );
          _allEntries = [for (final e in _allEntries) if (e.id == entryId) updated else e];
        } else if (_excludedEntries.any((e) => e.id == entryId)) {
          // Nur Titel/Benutzername aktualisieren (kein HIBP)
          _excludedEntries = [
            for (final e in _excludedEntries)
              if (e.id == entryId)
                ReportEntry(id: e.id, title: payload.title, username: payload.username, passwordTimestamp: null, pwnedCount: 0, strength: 0, guesses: 0, crackTime: '')
              else
                e,
          ];
        }
      }

      state = state.copyWith(
        pwnedEntries:     _allEntries.where((e) => e.pwnedCount > 0).toList()..sort((a, b) => b.pwnedCount.compareTo(a.pwnedCount)),
        urgentPasswords:  _buildUrgentList(_allEntries),
        weakestPasswords: _buildWeakestList(_allEntries),
        oldestPasswords:  _buildOldestList(_allEntries),
        unknownAgeEntries: _buildUnknownAgeList(_allEntries),
        ageBuckets:       _buildAgeBuckets(_allEntries),
        strengthBuckets:  _buildStrengthBuckets(_allEntries),
        excludedEntries:  _excludedEntries,
      );
    } catch (e, st) {
      log.fatal('Fehler beim Neuprüfen des Eintrags $entryId: $e', stack: st);
    }
  }

  // ------------------------------------------------------------------------
  // --- Bericht-Ausschluss ---
  // ------------------------------------------------------------------------

  /// Schließt einen Eintrag vom Sicherheitsbericht aus (oder schließt ihn wieder ein).
  ///
  /// Entschlüsselt den Eintrag, schaltet [EntryPayload.reportExcluded] um,
  /// verschlüsselt ihn neu und speichert ihn in der Datenbank. Danach wird
  /// der Eintrag sofort aus allen Report-Listen entfernt.
  Future<void> toggleReportExcluded(int entryId) async {
    if (state.status != ReportActionStatus.loaded) return;

    try {
      final entry = await _databaseService.getEntry(entryId);
      if (entry == null) return;

      final perm = await _databaseService.getPermissionByEntryIdAndUserId(entry.id, _sessionService.user!.id);
      if (perm == null) return;

      final entryKey  = await _cryptoService.decryptRsa(perm.encryptedKey, _sessionService.privateKey!);
      final decrypted = await _cryptoService.decrypt(entry.encryptedData, entryKey);
      final payload   = EntryPayload.fromJson(json.decode(utf8.decode(decrypted)));

      final updatedPayload = EntryPayload(
        category:          payload.category,
        title:             payload.title,
        username:          payload.username,
        password:          payload.password,
        passwordTimestamp: payload.passwordTimestamp,
        url:               payload.url,
        notes:             payload.notes,
        favicon:           payload.favicon,
        reportExcluded:    !payload.reportExcluded,
      );

      final updatedBytes     = Uint8List.fromList(utf8.encode(json.encode(updatedPayload.toJson())));
      final updatedEncrypted = await _cryptoService.encrypt(updatedBytes, entryKey);

      await _databaseService.saveEntry(entry.copyWith(
        encryptedData: updatedEncrypted,
        updatedAt: DateTime.now().toUtc(),
      ));

      if (updatedPayload.reportExcluded) {
        // Ausschließen: aus _allEntries entfernen, in _excludedEntries aufnehmen
        final source = _allEntries.firstWhere((e) => e.id == entryId, orElse: () => ReportEntry(id: entryId, title: payload.title, username: payload.username, passwordTimestamp: null, pwnedCount: 0, strength: 0, guesses: 0, crackTime: ''));
        _allEntries      = _allEntries.where((e) => e.id != entryId).toList();
        _excludedEntries = [..._excludedEntries, ReportEntry(id: entryId, title: source.title, username: source.username, passwordTimestamp: null, pwnedCount: 0, strength: 0, guesses: 0, crackTime: '')];
      } else {
        // Wieder einschließen: aus _excludedEntries entfernen, neu analysieren
        _excludedEntries = _excludedEntries.where((e) => e.id != entryId).toList();
        if (payload.password.isNotEmpty) {
          final pwnedCount = await _passwordService.checkHibp(payload.password, cacheDays: _configService.hibpCacheDays);
          final (:score, :guesses, :crackTime) = _passwordService.evaluatePassword(payload.password);
          _allEntries = [
            ..._allEntries,
            ReportEntry(
              id: entryId,
              title: payload.title,
              username: payload.username,
              passwordTimestamp: payload.passwordTimestamp,
              pwnedCount: pwnedCount,
              strength: score,
              guesses: guesses,
              crackTime: crackTime,
            ),
          ];
        }
      }

      state = state.copyWith(
        pwnedEntries:     _allEntries.where((e) => e.pwnedCount > 0).toList()..sort((a, b) => b.pwnedCount.compareTo(a.pwnedCount)),
        urgentPasswords:  _buildUrgentList(_allEntries),
        weakestPasswords: _buildWeakestList(_allEntries),
        oldestPasswords:  _buildOldestList(_allEntries),
        unknownAgeEntries: _buildUnknownAgeList(_allEntries),
        ageBuckets:       _buildAgeBuckets(_allEntries),
        strengthBuckets:  _buildStrengthBuckets(_allEntries),
        excludedEntries:  _excludedEntries,
      );
    } catch (e, st) {
      log.fatal('Fehler beim Umschalten von reportExcluded für Eintrag $entryId: $e', stack: st);
    }
  }

  // ------------------------------------------------------------------------
  // --- Abbruch-Button ---
  // ------------------------------------------------------------------------

  /// Signalisiert dem laufenden Vorgang, dass er abgebrochen werden soll.
  /// Die laufende HIBP-Anfrage wird noch zu Ende geführt, bevor der Abbruch greift.
  void abortLoading() {
    state = state.copyWith(isAborting: true);
  }
}
