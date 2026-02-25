import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Ein Wrapper um [SharedPreferences] für App-übergreifende (Tresor-unabhängige) Einstellungen.
///
/// Hier werden Informationen gespeichert, die die App benötigt, *bevor* 
/// eine SQLite-Datenbank überhaupt geöffnet werden kann (z.B. welcher Tresor 
/// zuletzt geöffnet war, oder das Salt für das Passwort-Hashing).
class ConfigService {
  // ------------------------------------------------------------------------
  // --- Konstanten ---
  // ------------------------------------------------------------------------

  static const String _keyLastVault = 'last_vault_name';
  static const String _keyShowOnlyMine = 'show_only_mine';
  static const String _keyTheme = 'theme';
  static const String _keyVaults = 'vaults';
  static const String _keyStoragePath = 'vault_storage_path'; // Spezifisch für Flutter/Drift-Pfade

  // ------------------------------------------------------------------------
  // --- Felder ---
  // ------------------------------------------------------------------------

  final SharedPreferences _prefs;

  // ------------------------------------------------------------------------
  // --- Konstruktor ---
  // ------------------------------------------------------------------------

  /// Initialisiert eine neue Instanz des [ConfigService].
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

  /// Das aktuell vom Benutzer gewählte Farbschema (Theme).
  String get theme => _prefs.getString(_keyTheme) ?? '';
  set theme(String value) => _prefs.setString(_keyTheme, value);

  /// Eine Map, die Tresornamen auf das Base64-encodierte Salt des Masterschlüssels abbildet.
  /// 
  /// Das Salt muss bekannt sein, *bevor* die Datenbank geöffnet werden kann, 
  /// da es zur Ableitung des AES-Master-Keys aus dem eingegebenen Passwort benötigt wird.
  Map<String, String> get vaults {
    final String jsonStr = _prefs.getString(_keyVaults) ?? '{}';
    try {
      final Map<String, dynamic> map = jsonDecode(jsonStr);
      return map.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return {};
    }
  }

  set vaults(Map<String, String> value) {
    final String jsonStr = jsonEncode(value);
    _prefs.setString(_keyVaults, jsonStr);
  }
  
  /// (Flutter-Spezifisch) Der Basispfad, in dem die SQLite-Tresordateien abgelegt werden.
  String get vaultStoragePath => _prefs.getString(_keyStoragePath) ?? '';
  set vaultStoragePath(String value) => _prefs.setString(_keyStoragePath, value);

  // ------------------------------------------------------------------------
  // --- Öffentliche Methoden ---
  // ------------------------------------------------------------------------

  /// (Flutter-Spezifisch) Initialisiert den Standardpfad für die SQLite-Dateien
  /// im OS-spezifischen App-Datenverzeichnis (z.B. AppData/Roaming/.../vaults unter Windows).
  Future<void> ensureDefaultPath() async {
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
}
