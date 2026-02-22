import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

class ConfigService {
  static const String _keyLastVault = 'last_vault_name';
  static const String _keyStoragePath = 'vault_storage_path';
  static const String _keyVaultsMap = 'vaults_map';

  final SharedPreferences _prefs;

  ConfigService(this._prefs);

  String get lastVaultName => _prefs.getString(_keyLastVault) ?? '';
  set lastVaultName(String value) => _prefs.setString(_keyLastVault, value);

  String get vaultStoragePath => _prefs.getString(_keyStoragePath) ?? '';
  set vaultStoragePath(String value) => _prefs.setString(_keyStoragePath, value);

  /// Map of VaultName -> Salt (Base64) - VORERST NOCH DA FÜR ROLLBACK-KOMPATIBILITÄT
  Map<String, String> get vaults {
    final String? jsonStr = _prefs.getString(_keyVaultsMap);
    if (jsonStr == null) return {};
    return {}; // Wird im nächsten Schritt geleert
  }

  /// Initialisiert den Standardpfad unter AppData/Roaming/.../vaults
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
