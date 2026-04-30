import 'package:famkey/core/app_error.dart';

/// Status der Report-Aktionen
enum ReportActionStatus {
  idle,     // Noch nicht gestartet
  loading,  // Wird geladen und geprüft
  loaded,   // Fertig
  aborted,  // Vom Benutzer abgebrochen
  failure,  // Fehler
}

/// Repräsentiert einen einzelnen Eintrag im Sicherheitsbericht.
class ReportEntry {

  /// Interne Datenbank-ID
  final int id;

  /// Titel des Eintrags
  final String title;

  /// Benutzername
  final String username;

  /// Zeitstempel der letzten Passwortänderung (null = unbekannt)
  final DateTime? passwordTimestamp;

  /// Wie oft das Passwort in Leak-Datenbanken gefunden wurde (0 = sicher, -1 = nicht prüfbar)
  final int pwnedCount;

  /// Passwortstärke nach Zxcvbn (0–4)
  final int strength;

  /// Geschätzte Anzahl Rateversuche nach Zxcvbn (für präzise Sortierung innerhalb eines Scores)
  final int guesses;

  /// Geschätzte Crack-Zeit im Worst-Case-Szenario (10^10 Versuche/Sek.), z.B. "3 hours", "centuries"
  final String crackTime;

  /// Konstruktor
  const ReportEntry({
    required this.id,
    required this.title,
    required this.username,
    required this.passwordTimestamp,
    required this.pwnedCount,
    required this.strength,
    required this.guesses,
    required this.crackTime,
  });
}

/// Altersklassen für das Balkendiagramm
class AgeBucket {
  final String label;
  final int count;
  final int daysMin;
  final int daysMax; // -1 = unbegrenzt

  const AgeBucket({
    required this.label,
    required this.count,
    required this.daysMin,
    required this.daysMax,
  });
}

/// Stärke-Klassen für das Balkendiagramm (Score 0–4)
class StrengthBucket {
  final String label;
  final int count;
  final int score; // 0–4

  const StrengthBucket({
    required this.label,
    required this.count,
    required this.score,
  });
}

/// Der State der Report-Seite.
class ReportState {
  // ------------------------------------------------------------------------
  // --- Felder ---
  // ------------------------------------------------------------------------

  /// Aktueller Aktionsstatus
  final ReportActionStatus status;

  /// Fehlerobjekt (nur relevant bei status == failure)
  final AppError error;

  /// Anzahl aller analysierten Einträge
  final int totalCount;

  /// Anzahl der bisher auf HIBP geprüften Einträge (für Fortschrittsanzeige)
  final int checkedCount;

  /// true, wenn der Benutzer den laufenden Vorgang abbrechen möchte
  final bool isAborting;

  /// Einträge, deren Passwort in mindestens einer Leak-Datenbank gefunden wurde
  final List<ReportEntry> pwnedEntries;

  /// Alle Einträge mit Score 0 oder 1 – dringend zu ändernde Passwörter, aufsteigend nach Guesses
  final List<ReportEntry> urgentPasswords;

  /// Top 10 der Einträge mit Score 2 oder 3, aufsteigend nach Guesses
  final List<ReportEntry> weakestPasswords;

  /// Top 10 Einträge mit den ältesten Passwörtern (aufsteigend nach Datum, nur mit bekanntem Datum)
  final List<ReportEntry> oldestPasswords;

  /// Einträge ohne bekanntes Passwort-Datum
  final List<ReportEntry> unknownAgeEntries;

  /// Altersverteilung der Passwörter (Buckets für das Balkendiagramm)
  final List<AgeBucket> ageBuckets;

  /// Stärkeverteilung der Passwörter (5 Buckets für Score 0–4)
  final List<StrengthBucket> strengthBuckets;

  /// Anzahl der Einträge ohne Passwort (wurden nicht ausgewertet)
  final int noPasswordCount;

  /// Einträge, die manuell vom Bericht ausgeschlossen wurden
  final List<ReportEntry> excludedEntries;

  // ------------------------------------------------------------------------
  // --- Computed Properties ---
  // ------------------------------------------------------------------------

  /// Gibt an, ob die Seite gerade einen Ladevorgang ausführt
  bool get isBusy => status == ReportActionStatus.loading;

  /// Fortschritt in Prozent (0.0–1.0), nur relevant beim Laden
  double get progress => totalCount > 0 ? checkedCount / totalCount : 0.0;

  // ------------------------------------------------------------------------
  // --- Konstruktor ---
  // ------------------------------------------------------------------------

  const ReportState({
    this.status = ReportActionStatus.idle,
    this.error = const AppError.none(),
    this.totalCount = 0,
    this.checkedCount = 0,
    this.isAborting = false,
    this.pwnedEntries = const [],
    this.urgentPasswords = const [],
    this.weakestPasswords = const [],
    this.oldestPasswords = const [],
    this.unknownAgeEntries = const [],
    this.ageBuckets = const [],
    this.strengthBuckets = const [],
    this.noPasswordCount = 0,
    this.excludedEntries = const [],
  });

  // ------------------------------------------------------------------------
  // --- copyWith ---
  // ------------------------------------------------------------------------

  ReportState copyWith({
    ReportActionStatus? status,
    AppError? error,
    int? totalCount,
    int? checkedCount,
    bool? isAborting,
    List<ReportEntry>? pwnedEntries,
    List<ReportEntry>? urgentPasswords,
    List<ReportEntry>? weakestPasswords,
    List<ReportEntry>? oldestPasswords,
    List<ReportEntry>? unknownAgeEntries,
    List<AgeBucket>? ageBuckets,
    List<StrengthBucket>? strengthBuckets,
    int? noPasswordCount,
    List<ReportEntry>? excludedEntries,
  }) {
    return ReportState(
      status: status ?? this.status,
      error: error ?? this.error,
      totalCount: totalCount ?? this.totalCount,
      checkedCount: checkedCount ?? this.checkedCount,
      isAborting: isAborting ?? this.isAborting,
      pwnedEntries: pwnedEntries ?? this.pwnedEntries,
      urgentPasswords: urgentPasswords ?? this.urgentPasswords,
      weakestPasswords: weakestPasswords ?? this.weakestPasswords,
      oldestPasswords: oldestPasswords ?? this.oldestPasswords,
      unknownAgeEntries: unknownAgeEntries ?? this.unknownAgeEntries,
      ageBuckets: ageBuckets ?? this.ageBuckets,
      strengthBuckets: strengthBuckets ?? this.strengthBuckets,
      noPasswordCount: noPasswordCount ?? this.noPasswordCount,
      excludedEntries: excludedEntries ?? this.excludedEntries,
    );
  }
}
