import 'package:privault/core/logger.dart';

/// Alle editierbaren Daten im LogConfig-Dialog.
class LogConfigFormData {

  /// Minimaler Log-Level, der geschrieben wird
  final LogLevel minLevel;

  /// Maximale Aufbewahrungsdauer in Tagen
  final int maxDays;

  /// Konstruktor
  const LogConfigFormData({
    this.minLevel = LogLevel.info,
    this.maxDays = 7,
  });

  /// Daten aktualisieren (immutable)
  LogConfigFormData copyWith({
    LogLevel? minLevel,
    int? maxDays,
  }) {
    return LogConfigFormData(
      minLevel: minLevel ?? this.minLevel,
      maxDays: maxDays ?? this.maxDays,
    );
  }

  // @formatter:off
  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
      other is LogConfigFormData &&
        runtimeType == other.runtimeType &&
        minLevel == other.minLevel &&
        maxDays == other.maxDays;

  @override
  int get hashCode =>
    minLevel.hashCode ^
    maxDays.hashCode;
// @formatter:on
}