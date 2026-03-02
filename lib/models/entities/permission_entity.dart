/// Repräsentiert die Zugriffsberechtigung eines Benutzers für einen spezifischen Tresoreintrag.
class PermissionEntity {

    /// Die interne ID (Auto-Increment in der Datenbank).
    /// Nullable für neue Einträge, bevor sie in die Datenbank geschrieben werden.
    final int? id;

    /// Die interne ID des zugehörigen Eintrags.
    final int entryId;

    /// Die lokale ID des Benutzers, dem dieser Zugriff gewährt wurde.
    final int userId;

    /// Der AES-Entry-Key für den Eintrag (32 Bytes), verschlüsselt mit dem öffentlichen RSA-Key des Benutzers.
    ///
    /// Wenn beim Synchronisieren festgestellt wird, dass der RSA-Schlüssel des Benutzers veraltet ist,
    /// wird dieser Wert geleert, da der Schlüssel nicht mehr entschlüsselt werden kann.
    final String encryptedKey;

    /// Definiert die Berechtigungsstufe des Benutzers für diesen Eintrag.
    /// * **0:** Kein Zugriff
    /// * **1:** Nur Lesen
    /// * **2:** Lesen und Schreiben
    /// * **3:** Vollzugriff/Besitzerrecht (inkl. Löschen und Berechtigungen verwalten)
    final int accessLevel;

    /// Konstruktor
    PermissionEntity({
        this.id, 
        required this.entryId, 
        required this.userId, 
        required this.encryptedKey, 
        required this.accessLevel
    });

    /// Konvertiert eine [PermissionEntity] in eine Map (z.B. für SQLite oder JSON).
    Map<String, dynamic> toMap() {
        return {'id': id, 'entry_id': entryId, 'user_id': userId, 'encrypted_key': encryptedKey, 'access_level': accessLevel};
    }

    /// Erstellt ein [PermissionEntity] Objekt aus einer Map.
    factory PermissionEntity.fromMap(Map<String, dynamic> map) {
        return PermissionEntity(
            id: map['id'] as int?,
            entryId: map['entry_id'] as int,
            userId: map['user_id'] as int,
            encryptedKey: map['encrypted_key'] as String,
            accessLevel: map['access_level'] as int,
        );
    }

    /// Erzeugt eine Kopie des Objekts mit modifizierten Eigenschaften.
    PermissionEntity copyWith({int? id, int? entryId, int? userId, String? encryptedKey, int? accessLevel}) {
        return PermissionEntity(
            id: id ?? this.id,
            entryId: entryId ?? this.entryId,
            userId: userId ?? this.userId,
            encryptedKey: encryptedKey ?? this.encryptedKey,
            accessLevel: accessLevel ?? this.accessLevel,
        );
    }
}
