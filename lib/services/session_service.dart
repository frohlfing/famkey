import 'package:flutter/foundation.dart';
import 'package:privault/models/entities/user_entity.dart';
import 'package:privault/services/crypto_service.dart';

/// Hält den Zustand der aktuellen Benutzersitzung im Arbeitsspeicher (RAM).
///
/// Dieser Service ist das Herzstück der Laufzeit-Sicherheit. Er hält den entschlüsselten
/// RSA Private Key des Nutzers im Speicher, solange die App entsperrt ist.
/// Beim Abmelden ([clearSession]) wird dieser Schlüssel explizit mit Nullen überschrieben,
/// um Speicher-Leaks (Cold-Boot-Attacks, Memory Dumps) zu erschweren.
///
/// Als [ChangeNotifier] informiert er die UI automatisch über Login/Logout-Ereignisse.
class SessionService extends ChangeNotifier {
  final CryptoService _cryptoService;

  UserEntity? _user;
  Uint8List? _privateKey;
  String _vaultName = '';
  Map<String, dynamic>? _settings;

  /// Initialisiert eine neue Instanz des [SessionService].
  ///
  /// [cryptoService] wird für das kryptografisch sichere Löschen von Schlüsseln aus dem RAM benötigt.
  SessionService(this._cryptoService);

  // ------------------------------------------------------------------------
  // --- Eigenschaften ---
  // ------------------------------------------------------------------------

  /// Gibt an, ob der Benutzer aktuell angemeldet ist und der Private Key im RAM vorliegt.
  bool get isLoggedIn => _user != null && _privateKey != null && _privateKey!.isNotEmpty;

  /// Der aktuell angemeldete Benutzer.
  UserEntity? get user => _user;

  /// Der entschlüsselte RSA Private Key des Benutzers (als Byte-Array).
  Uint8List? get privateKey => _privateKey;

  /// Der Name des geöffneten Tresors (Mandantenkennung).
  String get vaultName => _vaultName;

  /// Die Konfigurationseinstellungen der aktuellen Sitzung.
  Map<String, dynamic>? get settings => _settings;

  // ------------------------------------------------------------------------
  // --- Öffentliche Methoden ---
  // ------------------------------------------------------------------------

  /// Setzt die aktuelle Sitzung nach einem erfolgreichen Login oder Identitätswechsel.
  ///
  /// Löst ein [notifyListeners] aus, um die UI (z.B. Navigations-Guards) zu aktualisieren.
  void setSession({required UserEntity user, required Uint8List privateKey, required String vaultName, Map<String, dynamic>? settings}) {
    _user = user;
    _privateKey = privateKey;
    _vaultName = vaultName;
    _settings = settings;
    notifyListeners();
  }

  /// Beendet die Sitzung, löscht alle zwischengespeicherten Daten und vernichtet sensible Schlüssel im RAM.
  void clearSession() {
    _user = null;
    _vaultName = '';
    _settings = null;

    if (_privateKey != null) {
      // Nutzt den CryptoService, um das Array mit Nullen zu überschreiben,
      // bevor es dem Garbage Collector übergeben wird.
      _cryptoService.wipeKey(_privateKey);
      _privateKey = null;
    }

    notifyListeners();
  }
}
