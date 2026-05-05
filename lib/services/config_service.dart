import 'package:flutter/material.dart';
import 'package:famkey/core/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ein Wrapper um [SharedPreferences] für App-übergreifende (Tresor-unabhängige) Einstellungen.
/// Der Speicherort ist Plattformabhängig. Unter Windows: `AppData/Roaming/.../`
class ConfigService {

  // ------------------------------------------------------------------------
  // --- Interne Variablen & Konstanten ---
  // ------------------------------------------------------------------------

  static const String _keyLastVault = 'last_vault_name';
  static const String _keyShowOnlyMine = 'show_only_mine';
  static const String _keyAllCategoriesCollapsed = 'all_categories_collapsed';
  static const String _keyTheme = 'theme';
  static const String _keyLogLevel = 'log_level';
  static const String _keyLogDays = 'log_days';
  static const String _keyLogSize = 'log_size';
  static const String _keyHibpCacheDays = 'hibp_cache_days';
  static const String _keyAutoLockMinutes = 'auto_lock_minutes';
  static const String _keyClipboardClearSeconds = 'clipboard_clear_seconds';
  static const String _keyAutofillEnabled = 'autofill_enabled';
  static const String _keyAutofillHotkey = 'autofill_hotkey';

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
  bool get showOnlyMine => _prefs.getBool(_keyShowOnlyMine) ?? false;

  set showOnlyMine(bool value) => _prefs.setBool(_keyShowOnlyMine, value);

  /// Zeigt an, ob alle Kategorien in der Hauptliste eingeklappt sind.
  bool get allCategoriesCollapsed => _prefs.getBool(_keyAllCategoriesCollapsed) ?? false;

  set allCategoriesCollapsed(bool value) => _prefs.setBool(_keyAllCategoriesCollapsed, value);

  /// Das aktuell vom Benutzer gewählte Farbschema (Theme).
  ThemeMode get themeMode {
    final value = _prefs.getString(_keyTheme);
    return ThemeMode.values.firstWhere((e) => e.name == value, orElse: () => ThemeMode.system);
  }

  set themeMode(ThemeMode value) => _prefs.setString(_keyTheme, value.name);

  /// Minimaler Log-Level, der geschrieben wird (0=DEBUG, 1=INFO, 2=WARN, 3=ERROR, 4=FATAL). Default: INFO.
  LogLevel get logLevel => LogLevel.fromPriority(_prefs.getInt(_keyLogLevel) ?? 1);

  set logLevel(LogLevel value) => _prefs.setInt(_keyLogLevel, value.priority);

  /// Maximale Anzahl an Tagen, die in der Log-Datei aufbewahrt wird. Default: 7 Tage.
  int get logDays => _prefs.getInt(_keyLogDays) ?? 7;

  set logDays(int value) => _prefs.setInt(_keyLogDays, value);

  /// Maximale Dateigröße in Bytes, ab der ältere Einträge abgeschnitten werden. Default: 512 KB.
  int get logSize => _prefs.getInt(_keyLogSize) ?? 512 * 1024;

  set logSize(int value) => _prefs.setInt(_keyLogSize, value);

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

  /// Gibt an, ob Autofill (Auto-Type auf Windows, Autofill-Provider auf Android) aktiviert ist.
  bool get autofillEnabled => _prefs.getBool(_keyAutofillEnabled) ?? true;

  set autofillEnabled(bool value) => _prefs.setBool(_keyAutofillEnabled, value);

  /// Das Tastenkürzel für Auto-Type (nur Windows). Standard: Strg+Shift+A.
  String get autofillHotkey => _prefs.getString(_keyAutofillHotkey) ?? 'Strg+Shift+A';

  set autofillHotkey(String value) => _prefs.setString(_keyAutofillHotkey, value);
}
