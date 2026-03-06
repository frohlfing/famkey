import 'dart:typed_data';
import 'dart:io';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

/// Implementierung für die Biometrie-Unterstützung (FaceID / Fingerabdruck).
///
/// Der Master-Key wird nicht einfach auf der Festplatte abgelegt, sondern durch den
/// Hardware-Sicherheitschip des Betriebssystems (Keychain bei iOS, Keystore bei Android)
/// geschützt. Nur eine erfolgreiche biometrische Abfrage schaltet den Schlüssel frei.
class BiometricService {
  // ------------------------------------------------------------------------
  // --- Interne Variablen ---
  // ------------------------------------------------------------------------

  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ------------------------------------------------------------------------
  // --- Eigenschaften & Methoden ---
  // ------------------------------------------------------------------------

  String _getKeyName(String vaultName) => 'privault_key_$vaultName';

  /// Prüft, ob das aktuelle Gerät Biometrie (Fingerabdruck, FaceID) oder
  /// alternative Sicherheitsmechanismen (Geräte-PIN/Windows Hello) unterstützt.
  Future<bool> isAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      return false;
    }
  }

  /// Prüft, ob für den angegebenen [vaultName] bereits ein Master-Key
  /// im sicheren Speicher hinterlegt ist, ohne eine biometrische Abfrage zu starten.
  Future<bool> containsMasterKey(String vaultName) async {
    return await _storage.containsKey(key: _getKeyName(vaultName));
  }

  /// Speichert den [masterKey] im sicheren Speicher (Keystore/Keychain) des Betriebssystems.
  Future<void> saveMasterKey(String vaultName, Uint8List masterKey) async {
    final base64Key = base64.encode(masterKey);
    await _storage.write(key: _getKeyName(vaultName), value: base64Key);
  }

  /// Startet den System-Dialog (Biometrie) und gibt bei Erfolg den gespeicherten Master-Key zurück.
  ///
  /// Liefert `null`, wenn der Vorgang abgebrochen wurde, die Biometrie fehlschlägt
  /// oder noch kein Schlüssel für diesen [vaultName] gespeichert wurde.
  Future<Uint8List?> getMasterKey(String vaultName) async {
    try {
      // Prüfe vor dem OS-Prompt, ob der Schlüssel überhaupt im Storage existiert.
      final String? base64Key = await _storage.read(key: _getKeyName(vaultName));
      if (base64Key == null || base64Key.isEmpty) return null;

      // OS-Dialog aufrufen (Windows Hello, FaceID, Fingerabdruck)
      // Hinweis: Windows unterstützt den 'biometricOnly' Parameter nicht.
      // Wir setzen ihn nur auf Android/iOS auf true, um stärkere Sicherheit zu erzwingen.
      final bool authenticated = await _auth.authenticate(
        localizedReason: "Tresor '$vaultName' entschlüsseln",
        options: AuthenticationOptions(biometricOnly: !Platform.isWindows, stickyAuth: true),
      );

      return authenticated ? base64.decode(base64Key) : null;
    } catch (e) {
      // Bricht der User ab oder es gibt ein OS-Problem, wird das hier abgefangen.
      return null;
    }
  }

  /// Löscht den gespeicherten Master-Key für diesen Tresor aus dem Keystore.
  Future<void> removeMasterKey(String vaultName) async {
    await _storage.delete(key: _getKeyName(vaultName));
  }
}
