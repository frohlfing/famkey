import 'package:flutter/material.dart';
import 'package:privault/core/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ein Wrapper um [SharedPreferences] für App-übergreifende (Tresor-unabhängige) Einstellungen.
/// Der Speicherort ist Plattformabhängig. Unter Windows: `AppData/Roaming/.../`
class ConfigService {

  // ------------------------------------------------------------------------
  // --- Interne Variablen & Konstanten ---
  // ------------------------------------------------------------------------

  static const String _keyLastVault = 'last_vault_name';
  static const String _keyShowOnlyMine = 'show_only_mine';
  static const String _keyTheme = 'theme';
  static const String _keyLogMinLevel = 'log_min_level';
  static const String _keyLogMaxDays = 'log_max_days';
  static const String _keyHibpCacheDays = 'hibp_cache_days';
  static const String _keyAutoLockMinutes = 'auto_lock_minutes';
  static const String _keyClipboardClearSeconds = 'clipboard_clear_seconds';

  final SharedPreferences _prefs;

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Konstruktor
  ConfigService(this._prefs);

  // ------------------------------------------------------------------------
  // --- Eigenschaften ---
  // ------------------------------------------------------------------------

  /// Der Name des zuletzt erfolgreich geöffneten Tresors.
  /// Wird genutzt, um beim Neustart der App das Login-Feld vorauszufüllen.
  String get lastVaultName => _prefs.getString(_keyLastVault) ?? '';

  set lastVaultName(String value) => _prefs.setString(_keyLastVault, value);

  /// Zeigt an, ob in der Hauptliste aktuell nur die eigenen Einträge angezeigt werden sollen.
  // todo diese Einstellung wird in der Hauptansicht noch nicht berücksichtigt.
  // todo Weitere Einstellung: Bei Start alle Kategorien aufklappen
  bool get showOnlyMine => _prefs.getBool(_keyShowOnlyMine) ?? false;

  set showOnlyMine(bool value) => _prefs.setBool(_keyShowOnlyMine, value);

  /// Das aktuell vom Benutzer gewählte Farbschema (Theme).
  ThemeMode get themeMode {
    final value = _prefs.getString(_keyTheme);
    return ThemeMode.values.firstWhere((e) => e.name == value, orElse: () => ThemeMode.system);
  }

  set themeMode(ThemeMode value) => _prefs.setString(_keyTheme, value.name);

  /// Minimaler Log-Level, der geschrieben wird (0=debug, 1=info, 2=warm, 3=error, 4=fatal)
  LogLevel get logMinLevel => LogLevel.fromPriority(_prefs.getInt(_keyLogMinLevel) ?? 1);

  set logMinLevel(LogLevel value) => _prefs.setInt(_keyLogMinLevel, value.priority);

  /// Maximale Anzahl an Tagen, die in der Log-Datei aufbewahrt wird
  int get logMaxDays => _prefs.getInt(_keyLogMaxDays) ?? 7;

  set logMaxDays(int value) => _prefs.setInt(_keyLogMaxDays, value);

  /// Anzahl der Tage, die ein HIBP-Prüfergebnis (Darknet-Check) gecacht wird (Standard: 1 Tag)
  int get hibpCacheDays => _prefs.getInt(_keyHibpCacheDays) ?? 1;

  set hibpCacheDays(int value) => _prefs.setInt(_keyHibpCacheDays, value);

  /// Inaktivitätsdauer in Minuten bis zur automatischen Sperre. null = nie (Standard).
  int? get autoLockMinutes {
    final val = _prefs.getInt(_keyAutoLockMinutes) ?? 0;
    return val == 0 ? null : val;
  }

  set autoLockMinutes(int? value) => _prefs.setInt(_keyAutoLockMinutes, value ?? 0);

  /// Dauer in Sekunden bis zum automatischen Leeren der Zwischenablage. null = nie. Standard: 30 s.
  int? get clipboardClearSeconds {
    final val = _prefs.getInt(_keyClipboardClearSeconds) ?? 30;
    return val == 0 ? null : val;
  }

  set clipboardClearSeconds(int? value) => _prefs.setInt(_keyClipboardClearSeconds, value ?? 0);
}
