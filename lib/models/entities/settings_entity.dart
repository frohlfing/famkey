/// Repräsentiert die privaten Konfigurationseinstellungen des aktuell geöffneten Tresors.
/// Diese Entität speichert sensible Synchronisationsparameter und kryptografische Basiselemente.
///
/// **Besonderheit:**
/// Diese Tabelle fungiert als Singleton-Speicher und enthält systembedingt exakt einen Datensatz,
/// welcher die Konfiguration für die aktuelle Tresor-Instanz beschreibt.
class SettingsEntity {

    /// Die interne ID (Primärschlüssel).
    /// Da es sich um einen Singleton-Datensatz handelt, ist der Wert hierbei stets 1.
    final int id;

    // --- Kryptografie ---

    /// Das Salt, welches zur Ableitung des Master-Keys (Argon2id) verwendet wird.
    final String salt;

    /// Der private RSA-Schlüssel des Benutzers - verschlüsselt mit dem Master-Key (AES-256-GCM).
    final String encryptedPrivateKey;

    // --- Sync-Einstellungen ---

    /// Die URL des Sync-Servers (Host).
    final String host;

    /// Das API-Token zur Authentifizierung gegenüber dem Sync-Server.
    final String apiToken;

    // --- Biometrie ---

    /// Gibt an, ob Fingerabdruck bzw. Gesichtserkennung als Anmeldeoption zur Verfügung steht.
    final bool useBiometric;

    // --- Passwort-Generator ---

    /// Die vom Passwortgenerator verwendete Passwortlänge.
    final int pwLength;

    /// Die vom Passwortgenerator verwendeten Sonderzeichen.
    final String pwSpecialChars;

    /// Gibt an, ob der Passwortgenerator verwechselbare Zeichen (I, l, O, 0) ausschließen soll.
    final bool pwAvoidIlO0;

    // --- Aussehen ---

    /// Der Name, der in der UI als Platzhalter für Einträge ohne explizite Kategorie verwendet wird.
    final String categoryPlaceholder;

    // --- Synchronisation ---

    /// Zeitpunkt der letzten erfolgreichen Synchronisation (UTC, Serverzeit).
    final DateTime lastSyncAt;

    /// Konstruktor
    SettingsEntity({
        this.id = 1,
        this.salt = '',
        this.encryptedPrivateKey = '',
        this.host = '',
        this.apiToken = '',
        this.useBiometric = false, // DEFAULT: Deaktiviert
        this.pwLength = 16,
        this.pwSpecialChars = '',
        this.pwAvoidIlO0 = true,
        this.categoryPlaceholder = '',
        required this.lastSyncAt,
    });

    /// Konvertiert eine [SettingsEntity] in eine Map (z.B. für SQLite oder JSON).
    Map<String, dynamic> toMap() {
        return {
            'id': id,
            'salt': salt,
            'encrypted_private_key': encryptedPrivateKey,
            'host': host,
            'api_token': apiToken,
            'use_biometric': useBiometric ? 1 : 0,
            'pw_length': pwLength,
            'pw_special_chars': pwSpecialChars,
            'pw_avoid_ilo0': pwAvoidIlO0 ? 1 : 0,
            'category_placeholder': categoryPlaceholder,
            'last_sync_at': lastSyncAt.toIso8601String(),
        };
    }

    /// Erstellt ein [SettingsEntity] Objekt aus einer Map.
    factory SettingsEntity.fromMap(Map<String, dynamic> map) {
        return SettingsEntity(
            id: map['id'] as int? ?? 1,
            salt: map['salt'] as String? ?? '',
            encryptedPrivateKey: map['encrypted_private_key'] as String? ?? '',
            host: map['host'] as String? ?? '',
            apiToken: map['api_token'] as String? ?? '',
            useBiometric: (map['use_biometric'] as int? ?? 0) == 1,
            pwLength: map['pw_length'] as int? ?? 16,
            pwSpecialChars: map['pw_special_chars'] as String? ?? '',
            pwAvoidIlO0: (map['pw_avoid_ilo0'] as int? ?? 1) == 1,
            categoryPlaceholder: map['category_placeholder'] as String? ?? '',
            lastSyncAt: DateTime.parse(map['last_sync_at'] as String).toUtc(),
        );
    }

    /// Erzeugt eine Kopie des Objekts mit modifizierten Eigenschaften.
    SettingsEntity copyWith({
        int? id,
        String? salt,
        String? encryptedPrivateKey,
        String? host,
        String? apiToken,
        bool? useBiometric,
        int? pwLength,
        String? pwSpecialChars,
        bool? pwAvoidIlO0,
        String? categoryPlaceholder,
        DateTime? lastSyncAt,
    }) {
        return SettingsEntity(
            id: id ?? this.id,
            salt: salt ?? this.salt,
            encryptedPrivateKey: encryptedPrivateKey ?? this.encryptedPrivateKey,
            host: host ?? this.host,
            apiToken: apiToken ?? this.apiToken,
            useBiometric: useBiometric ?? this.useBiometric,
            pwLength: pwLength ?? this.pwLength,
            pwSpecialChars: pwSpecialChars ?? this.pwSpecialChars,
            pwAvoidIlO0: pwAvoidIlO0 ?? this.pwAvoidIlO0,
            categoryPlaceholder: categoryPlaceholder ?? this.categoryPlaceholder,
            lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        );
    }
}
