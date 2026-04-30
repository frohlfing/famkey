import 'package:famkey/core/logger.dart';

/// Alle editierbaren Daten im LogConfig-Dialog.
class LogConfigFormData {

  /// Log-Level, der geschrieben wird
  final LogLevel level;

  /// Aufbewahrungsdauer in Tagen
  final int days;

  /// Maximale Dateigröße in KB
  final int size;

  /// Konstruktor
  const LogConfigFormData({
    this.level = LogLevel.info,
    this.days = 7,
    this.size = 512 * 1024,
  });

  /// Daten aktualisieren (immutable)
  LogConfigFormData copyWith({
    LogLevel? level,
    int? days,
    int? size,
  }) {
    return LogConfigFormData(
      level: level ?? this.level,
      days: days ?? this.days,
      size: size ?? this.size,
    );
  }

  // @formatter:off
  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
      other is LogConfigFormData &&
        runtimeType == other.runtimeType &&
        level == other.level &&
        days == other.days &&
        size == other.size;

  @override
  int get hashCode =>
    level.hashCode ^
    days.hashCode ^
    size.hashCode;
// @formatter:on
}