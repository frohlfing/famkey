import 'dart:typed_data';
import 'dart:io';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<bool> isAvailable() async {
    final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
    final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
    return canAuthenticate;
  }

  Future<bool> containsMasterKey(String vaultName) async {
    return await _storage.containsKey(key: 'master_key_$vaultName');
  }

  Future<void> saveMasterKey(String vaultName, Uint8List masterKey) async {
    await _storage.write(
      key: 'master_key_$vaultName',
      value: base64.encode(masterKey),
    );
  }

  Future<Uint8List?> getMasterKey(String vaultName) async {
    // Windows unterstützt den 'biometricOnly' Parameter nicht. 
    // Wir setzen ihn nur auf Android/iOS auf true.
    final bool didAuthenticate = await _auth.authenticate(
      localizedReason: 'Bitte authentifiziere dich, um den Tresor zu öffnen',
      options: AuthenticationOptions(
        biometricOnly: !Platform.isWindows, 
        stickyAuth: true,
      ),
    );

    if (didAuthenticate) {
      final String? base64Key = await _storage.read(key: 'master_key_$vaultName');
      if (base64Key != null) {
        return base64.decode(base64Key);
      }
    }
    return null;
  }

  Future<void> removeMasterKey(String vaultName) async {
    await _storage.delete(key: 'master_key_$vaultName');
  }
}
