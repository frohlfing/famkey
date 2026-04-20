import 'package:privault/core/app_error.dart';

/// Status der Report-Aktionen
enum ReportActionStatus {
  idle,     // Noch nicht gestartet
  loading,  // Wird geladen und geprüft
  loaded,   // Fertig
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

  /// Wie oft das Passwort in Leak-Datenbanken gefunden wurde (0 = sicher)
  final int pwnedCount;

  /// Passwortstärke nach Zxcvbn (0–4)
  final int strength;

  /// Konstruktor
  const ReportEntry({
    required this.id,
    required this.title,
    required this.username,
    required this.passwordTimestamp,
    required this.pwnedCount,
    required this.strength,
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

  /// Einträge, deren Passwort in mindestens einer Leak-Datenbank gefunden wurde
  final List<ReportEntry> pwnedEntries;

  /// Top 10 Einträge mit den ältesten Passwörtern (aufsteigend nach Datum)
  final List<ReportEntry> oldestPasswords;

  /// Altersverteilung der Passwörter (Buckets für das Balkendiagramm)
  final List<AgeBucket> ageBuckets;

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
    this.pwnedEntries = const [],
    this.oldestPasswords = const [],
    this.ageBuckets = const [],
  });

  // ------------------------------------------------------------------------
  // --- copyWith ---
  // ------------------------------------------------------------------------

  ReportState copyWith({
    ReportActionStatus? status,
    AppError? error,
    int? totalCount,
    int? checkedCount,
    List<ReportEntry>? pwnedEntries,
    List<ReportEntry>? oldestPasswords,
    List<AgeBucket>? ageBuckets,
  }) {
    return ReportState(
      status: status ?? this.status,
      error: error ?? this.error,
      totalCount: totalCount ?? this.totalCount,
      checkedCount: checkedCount ?? this.checkedCount,
      pwnedEntries: pwnedEntries ?? this.pwnedEntries,
      oldestPasswords: oldestPasswords ?? this.oldestPasswords,
      ageBuckets: ageBuckets ?? this.ageBuckets,
    );
  }
}