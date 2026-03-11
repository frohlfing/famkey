import 'package:privault/core/app_error.dart';

/// Ein generisches Ergebnis-Objekt für Operationen im ViewModel oder Service.
///
/// [T] ist der Typ der Daten, die im Erfolgsfall zurückgegeben werden.
class CommandResult<T> {
  /// Die Nutzdaten im Erfolgsfall (optional).
  final T? data;

  /// Fehlercode im Fehlerfall.
  final AppError? errorCode;

  /// Fehlertext im Fehlerfall.
  final String? errorMessage;

  // Betroffen des Feld im Fehlerfall
  final String? field;

  /// Konstruktor für ein neutrales Ergebnis
  CommandResult() : data = null, errorCode = null, errorMessage = null, field = null;

  /// Konstruktor für ein positives Ergebnis, optional mit Daten.
  CommandResult.success([this.data]) : errorCode = null, errorMessage = null, field = null;

  /// Konstruktor für ein negatives Ergebnis
  CommandResult.failure(this.errorCode, {String? message, this.field}) : data = null, errorMessage = message ?? errorCode!.defaultMessage;

  /// Gibt true zurück, wenn die Operation erfolgreich war (keine Fehler vorhanden).
  bool get isSuccess => errorCode == null;

  /// Gibt true zurück, wenn Fehler vorliegen.
  bool get hasError => errorCode != null;

  /// Gibt den Fehlertext für das Feld zurück, falls vorhanden.
  String? getFieldError(String field) => this.field == field ? errorMessage : null;
}
