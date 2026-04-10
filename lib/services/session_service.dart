import 'package:flutter/foundation.dart';
import 'package:privault/database/database.dart';
import 'package:privault/services/crypto_service.dart';

/// Hält den Zustand der aktuellen Benutzersitzung im Arbeitsspeicher.
class SessionService {

  // ------------------------------------------------------------------------
  // --- Verwendete Dienste (Abhängigkeiten) ---
  // ------------------------------------------------------------------------

  final CryptoService _cryptoService;

  // ------------------------------------------------------------------------
  // --- Interne Variablen & Konstanten ---
  // ------------------------------------------------------------------------

  UserEntity? _user;
  Uint8List? _privateKey;
  Uint8List? _indexKey;
  String _vaultName = '';
  SettingsEntity? _settings;

  // ------------------------------------------------------------------------
  // --- Initialisierung / Lifecycle ---
  // ------------------------------------------------------------------------

  /// Konstruktor
  SessionService(this._cryptoService);

  /// Setzt die aktuelle Sitzung nach einem erfolgreichen Login oder Identitätswechsel.
  void setSession({required UserEntity user, required Uint8List privateKey, required String vaultName, required SettingsEntity settings}) {
    _user = user;
    _privateKey = privateKey;
    _indexKey = _cryptoService.deriveKeyFromKey(privateKey, null, 'entry-index-encryption');
    _vaultName = vaultName;
    _settings = settings;
  }

  /// Beendet die Sitzung, löscht alle zwischengespeicherten Daten und vernichtet sensible Schlüssel im RAM.
  void clearSession() {
    _user = null;
    _vaultName = '';
    _settings = null;

    if (_privateKey != null) {
      // Array mit Nullen zu überschreiben, bevor es dem Garbage Collector übergeben wird.
      _cryptoService.wipeKey(_privateKey);
      _privateKey = null;
    }

    if (_indexKey != null) {
      _cryptoService.wipeKey(_indexKey);
      _indexKey = null;
    }
  }

  // ------------------------------------------------------------------------
  // --- Eigenschaften ---
  // ------------------------------------------------------------------------

  /// Der aktuell angemeldete Benutzer.
  UserEntity? get user => _user;

  /// Der entschlüsselte RSA Private-Key des Benutzers (als Byte-Array).
  Uint8List? get privateKey => _privateKey;

  /// Der abgeleitete AES-Schlüssel für die lokale Verschlüsselung des encryptedIndex.
  Uint8List? get indexKey => _indexKey;

  /// Der Name des geöffneten Tresors (Mandantenkennung).
  String get vaultName => _vaultName;

  /// Die Konfigurationseinstellungen der aktuellen Sitzung.
  SettingsEntity? get settings => _settings;

  // ------------------------------------------------------------------------
  // --- Setter ---
  // ------------------------------------------------------------------------

  /// Setter für den aktuellen Benutzer.
  void setUser(UserEntity value) {
    _user = value;
  }

  /// Setter für den RSA Private-Key des Benutzers.
  void setPrivateKey(Uint8List value) {
    _privateKey = value;
    _indexKey = _cryptoService.deriveKeyFromKey(value, null, 'entry-index-encryption');
  }

  /// Setter für den Namen des geöffneten Tresors.
  void setVaultName(String value) {
    _vaultName = value;
  }

  /// Setter für die Konfigurationseinstellungen.
  void setSettings(SettingsEntity value) {
    _settings = value;
  }
}
