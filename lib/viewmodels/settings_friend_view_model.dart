import 'package:flutter/foundation.dart';
import 'package:privault/models/entities/user_entity.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';

/// Das [SettingsFriendViewModel] dient als spezialisiertes Datenmodell für die UI-Darstellung
/// von Freunden innerhalb der Tresor-Einstellungen.
///
/// **Hauptaufgaben:**
/// * Aufbereitung von Benutzerdaten ([UserEntity]) für die Listenansicht.
/// * Berechnung und Bereitstellung des kryptografischen Fingerprints zur Identitätsprüfung.
/// * Synchronisation des Verifizierungsstatus zwischen UI und Datenmodell.
///
/// **Kryptografie:**
/// Die Klasse nutzt den [CryptoService], um aus dem öffentlichen RSA-Schlüssel eines Benutzers
/// einen SHA-256 Fingerprint zu erzeugen. Dieser Fingerprint ist die Basis für das "Out-of-Band" Vertrauensmodell
/// (Benutzer vergleichen Fingerprints über einen sicheren Drittkanal).
class SettingsFriendViewModel extends ChangeNotifier {
  // ------------------------------------------------------------------------
  // --- Felder ---
  // ------------------------------------------------------------------------

  final CryptoService _cryptoService;
  final DatabaseService _databaseService;
  
  /// Die zugrundeliegende Benutzer-Entität.
  final UserEntity user;

  bool _needsRekeying = false;

  // ------------------------------------------------------------------------
  // --- Konstruktor ---
  // ------------------------------------------------------------------------

  /// Initialisiert eine neue Instanz der [SettingsFriendViewModel] Klasse.
  SettingsFriendViewModel(this._cryptoService, this._databaseService, this.user);

  // ------------------------------------------------------------------------
  // --- Eigenschaften ---
  // ------------------------------------------------------------------------

  /// Ruft den Anzeigenamen des Freundes ab.
  String get name => user.name;
  
  /// Gibt an, ob die Identität dieses Benutzers (per Fingerprint-Vergleich) manuell verifiziert wurde.
  bool get isVerified => user.isVerified;

  set isVerified(bool value) {
    // Hinweis: Die dauerhafte Speicherung in der DB erfolgt über das SettingsViewModel.
    // Hier ändern wir nur den lokalen Zustand für das reaktive UI-Update.
    notifyListeners();
  }

  /// Signalisiert der UI, ob für diesen Freund Einträge neu verschlüsselt werden müssen.
  /// Dies ist der Fall, wenn sein RSA-Key geändert wurde und die lokalen Permission-Keys geleert wurden.
  bool get needsRekeying => _needsRekeying;

  /// Berechnet den SHA-256 Fingerprint über den [CryptoService] basierend auf dem Public Key.
  /// Nutzt ein unsichtbares Leerzeichen (\u200B) nach den Doppelpunkten für bessere Zeilenumbrüche in der UI.
  String get fingerprint {
    return _cryptoService.fingerprint(user.publicKey).replaceAll(":", ":\u200B");
  }

  // ------------------------------------------------------------------------
  // --- Öffentliche Methoden ---
  // ------------------------------------------------------------------------

  /// Aktualisiert den Rekeying-Status basierend auf dem aktuellen Zustand der Datenbank.
  Future<void> refreshStatus() async {
    if (user.id != null) {
      _needsRekeying = await _databaseService.hasAccessWithoutKey(user.id!);
      notifyListeners();
    }
  }
}
