import 'dart:io';
import 'package:flutter/material.dart';
import 'package:privault/core/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Ein Wrapper um [SharedPreferences] für App-übergreifende (Tresor-unabhängige) Einstellungen.
/// Der Speicherort ist Plattformabhängig. Unter Windows: `AppData/Roaming/.../`
class ConfigService {

  // ------------------------------------------------------------------------
  // --- Interne Variablen & Konstanten ---
  // ------------------------------------------------------------------------

  static const String _keyLastVault = 'last_vault_name';
  static const String _keyShowOnlyMine = 'show_only_mine';
  static const String _keyTheme = 'theme';
  static const String _keyStoragePath = 'vault_storage_path';
  static const String _keyLogMinLevel = 'log_min_level';
  static const String _keyLogMaxDays = 'log_max_days';

  final SharedPreferences _prefs;

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Konstruktor
  ConfigService(this._prefs);

  /// Initialisierung (wird einmalig beim App-Start aufgerufen)
  Future<void> init() async {
    if (vaultStoragePath.isEmpty) {
      final supportDir = await getApplicationSupportDirectory();
      final defaultPath = p.join(supportDir.path, 'vaults');
      final dir = Directory(defaultPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      vaultStoragePath = defaultPath;
    }
  }

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

  /// Das aktuell vom Benutzer gewählte Farbschema (Theme).
  ThemeMode get themeMode {
    final value = _prefs.getString(_keyTheme);
    return ThemeMode.values.firstWhere((e) => e.name == value, orElse: () => ThemeMode.system);
  }

  set themeMode(ThemeMode value) => _prefs.setString(_keyTheme, value.name);

  /// (Flutter-Spezifisch) Der Basispfad, in dem die SQLite-Tresordateien abgelegt werden.
  String get vaultStoragePath => _prefs.getString(_keyStoragePath) ?? '';

  set vaultStoragePath(String value) => _prefs.setString(_keyStoragePath, value);

  /// Minimaler Log-Level, der geschrieben wird (0=debug, 1=info, 2=warm, 3=error, 4=fatal)
  LogLevel get logMinLevel => LogLevel.fromPriority(_prefs.getInt(_keyLogMinLevel) ?? 1);

  set logMinLevel(LogLevel value) => _prefs.setInt(_keyLogMinLevel, value.priority);

  /// Maximale Anzahl an Tagen, die in der Log-Datei aufbewahrt wird
  int get logMaxDays => _prefs.getInt(_keyLogMaxDays) ?? 7;

  set logMaxDays(int value) => _prefs.setInt(_keyLogMaxDays, value);
}
