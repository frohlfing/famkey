import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ConfigService {
  static const String _keyLastVault = 'last_vault_name';
  static const String _keyVaultsMap = 'vaults_map';

  final SharedPreferences _prefs;

  ConfigService(this._prefs);

  String get lastVaultName => _prefs.getString(_keyLastVault) ?? '';
  set lastVaultName(String value) => _prefs.setString(_keyLastVault, value);

  /// Map of VaultName -> Salt (Base64)
  Map<String, String> get vaults {
    final String? jsonStr = _prefs.getString(_keyVaultsMap);
    if (jsonStr == null) return {};
    try {
      return Map<String, String>.from(json.decode(jsonStr));
    } catch (_) {
      return {};
    }
  }

  set vaults(Map<String, String> value) {
    _prefs.setString(_keyVaultsMap, json.encode(value));
  }

  void addVault(String name, String saltBase64) {
    final map = vaults;
    map[name] = saltBase64;
    vaults = map;
  }

  /// Entfernt einen Tresor aus der Liste der bekannten Tresore.
  void removeVault(String name) {
    final map = vaults;
    if (map.containsKey(name)) {
      map.remove(name);
      vaults = map;
      if (lastVaultName == name) {
        lastVaultName = '';
      }
    }
  }
}
