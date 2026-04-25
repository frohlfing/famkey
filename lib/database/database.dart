import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'connection.dart';

part 'database.g.dart';

/// Definition des Datenbank-Schemas
///
/// WICHTIG:
/// Wenn hier etwas geändert wird, muss `database.g.dart` mit diesem Befehl neu generiert werden:
/// ```shell
/// dart run build_runner build --delete-conflicting-outputs
/// ```

/// Repräsentiert eine Benutzeridentität innerhalb eines Tresors.
///
/// Diese Klasse verwaltet sowohl den Benutzer der App als auch alle hinzugefügten
/// Freunde, mit denen Einträge geteilt werden können.
///
/// **Rollenverteilung:**
/// * **Besitzer:** Der Hauptbenutzer der App hat lokal stets die `id = 1`.
/// * **Freunde:** Weitere Benutzer, mit denen Einträge geteilt werden können.
@TableIndex(name: 'uk_users_uuid', columns: {#uuid}, unique: true)
@TableIndex(name: 'uk_users_name', columns: {#name}, unique: true)
@TableIndex(name: 'idx_users_is_hidden', columns: {#isHidden})
@TableIndex(name: 'idx_users_updated_at', columns: {#updatedAt})
@DataClassName('UserEntity')
class Users extends Table {
  /// Die interne ID (Auto-Increment in der Datenbank).
  /// Der Benutzer der App wird systemintern stets mit der ID 1 identifiziert.
  /// Nullable für neue Einträge, bevor sie in die Datenbank geschrieben werden.
  IntColumn get id => integer().autoIncrement()();

  /// Die globale eindeutige ID des Benutzers (Universally Unique Identifier v4).
  TextColumn get uuid => text()();

  /// Der Name des Benutzers (eindeutig pro Tresor).
  TextColumn get name => text()();

  /// Der Benutzername, unter dem diese Person auf dem Sync-Server aktuell bekannt ist.
  ///
  /// Leer = noch nie gesynct.
  ///
  /// Verwendung je nach Rolle:
  /// - **Besitzer (id = 1):** Wird beim ersten Sync gesetzt und nach jedem erfolgreichen
  ///   Rename auf den neuen Namen aktualisiert. Dient zur Erkennung ausstehender Umbenennungen:
  ///   `name != syncedName` → `patchUserName` beim nächsten Sync aufrufen.
  /// - **Freunde (id > 1):** Wird beim Hinzufügen gesetzt und danach nicht mehr verändert.
  ///   Dient zur Anzeige von Umbenennungen in der Freundesliste:
  ///   `name != syncedName` → Hinweis "Bobby (ehemals Bob)".
  TextColumn get syncedName => text().withDefault(const Constant(''))();

  /// Der öffentliche RSA-Schlüssel des Benutzers (Base64-kodierter SPKI-String).
  TextColumn get publicKey => text()();

  /// Gibt an, ob die Identität dieses Benutzers (per Fingerprint-Vergleich) manuell verifiziert wurde.
  BoolColumn get isVerified => boolean()();

  /// Gibt an, ob der Benutzer in der UI ausgeblendet ist (z.B. gelöschte Freunde, die wegen Sync noch erhalten bleiben müssen).
  BoolColumn get isHidden => boolean()();

  /// Zeitpunkt der letzten Änderung (UTC).
  DateTimeColumn get updatedAt => dateTime()();
}

/// Repräsentiert einen Tresoreintrag in der SQLite-Datenbank.
@TableIndex(name: 'uk_entries_uuid', columns: {#uuid}, unique: true)
@TableIndex(name: 'idx_entries_updated_at', columns: {#updatedAt})
@DataClassName('EntryEntity')
class Entries extends Table {
  /// Die interne ID (Auto-Increment in der Datenbank).
  /// Nullable für neue Einträge, bevor sie in die Datenbank geschrieben werden.
  IntColumn get id => integer().autoIncrement()();

  /// Die globale eindeutige ID des Eintrags (Universally Unique Identifier v4).
  TextColumn get uuid => text()();

  /// Der AES-256-GCM verschlüsselte Daten-Container.
  /// Enthält das serialisierte JSON-Objekt der Klasse [EntryPayload].
  TextColumn get encryptedData => text()();

  /// Der AES-256-GCM verschlüsselte Index-Container.
  /// Enthält das serialisierte JSON-Objekt der Klasse [IndexPayload].
  TextColumn get encryptedIndex => text()();

  /// Die lokale ID des Benutzers, der diesen Eintrag erstellt hat.
  IntColumn get creatorId => integer()();

  /// Die lokale ID des Benutzers, der den Eintrag zuletzt aktualisiert hat.
  IntColumn get updaterId => integer()();

  /// Zeitpunkt der letzten Änderung (UTC).
  DateTimeColumn get updatedAt => dateTime()();
}

/// Repräsentiert die Zugriffsberechtigung eines Benutzers für einen spezifischen Tresoreintrag.
@TableIndex(name: 'uk_permissions_entry_id_user_id', columns: {#entryId, #userId}, unique: true) // für Detailansicht
@TableIndex(name: 'idx_permissions_user', columns: {#userId})
@DataClassName('PermissionEntity')
class Permissions extends Table {
  /// Die interne ID (Auto-Increment in der Datenbank).
  /// Nullable für neue Einträge, bevor sie in die Datenbank geschrieben werden.
  IntColumn get id => integer().autoIncrement()();

  /// Die interne ID des zugehörigen Eintrags.
  IntColumn get entryId => integer()();

  /// Die lokale ID des Benutzers, dem dieser Zugriff gewährt wurde.
  IntColumn get userId => integer()();

  /// Der AES-Entry-Key für den Eintrag (32 Bytes), verschlüsselt mit dem öffentlichen RSA-Key des Benutzers.
  ///
  /// Wenn beim Synchronisieren festgestellt wird, dass der RSA-Schlüssel des Benutzers veraltet ist,
  /// wird dieser Wert geleert, da der Schlüssel nicht mehr entschlüsselt werden kann.
  TextColumn get encryptedKey => text()();

  /// Definiert die Berechtigungsstufe des Benutzers für diesen Eintrag.
  /// * **0:** Kein Zugriff
  /// * **1:** Nur Lesen
  /// * **2:** Lesen und Schreiben
  /// * **3:** Vollzugriff/Besitzerrecht (inkl. Löschen und Berechtigungen verwalten)
  IntColumn get accessLevel => integer()();
}

/// Repräsentiert einen Dateianhang zu einem Tresoreintrag in der lokalen SQLite-Datenbank.
/// Der gesamte Inhalt wird verschlüsselt gespeichert, um die Privatsphäre zu gewährleisten.
@TableIndex(name: 'uk_attachments_uuid', columns: {#uuid}, unique: true)
@TableIndex(name: 'idx_attachments_entry_id', columns: {#entryId})
@TableIndex(name: 'idx_attachments_is_synced', columns: {#isSynced})
@DataClassName('AttachmentEntity')
class Attachments extends Table {
  /// Die interne ID (Auto-Increment in der Datenbank).
  /// Nullable für neue Einträge, bevor sie in die Datenbank geschrieben werden.
  IntColumn get id => integer().autoIncrement()();

  /// Die globale eindeutige ID des Anhangs (Universally Unique Identifier v4).
  TextColumn get uuid => text()();

  /// Die interne ID des zugehörigen Eintrags.
  IntColumn get entryId => integer()();

  /// Der AES-256-GCM verschlüsselte Metadaten-Container (Ciphertext + Nonce + Auth-Tag).
  /// Enthält das serialisierte JSON-Objekt der Klasse [AttachmentMetaPayload].
  TextColumn get encryptedMeta => text()();

  /// Der AES-256-GCM verschlüsselte Binärdaten-Container (Ciphertext + Nonce + Auth-Tag).
  /// Enthält den binären Dateninhalt des Anhangs.
  TextColumn get encryptedContent => text()();

  /// `true`, wenn der Anhang erfolgreich zum Server synchronisiert wurde, sonst `false`.
  BoolColumn get isSynced => boolean()();
}

/// Repräsentiert einen Löschmarker ("Tombstone") für Tresoreinträge.
/// Diese Entität speichert die UUIDs von gelöschten Objekten, um die Synchronisation
/// von Löschvorgängen über mehrere Geräte hinweg zu ermöglichen.
///
/// **Funktionsweise:**
/// Wenn ein Eintrag lokal gelöscht wird, wird hier ein Grabstein hinterlassen.
/// Beim nächsten Synchronisationsvorgang meldet der Client dem Server:
/// "Eintrag mit UUID X wurde gelöscht".
@TableIndex(name: 'uk_tombstones_entry_uuid', columns: {#entryUuid}, unique: true)
@TableIndex(name: 'idx_tombstones_deleted_at', columns: {#deletedAt})
@DataClassName('TombstoneEntity')
class Tombstones extends Table {
  /// Die interne ID (Auto-Increment in der Datenbank).
  /// Nullable für neue Einträge, bevor sie in die Datenbank geschrieben werden.
  IntColumn get id => integer().autoIncrement()();

  /// Die globale ID des gelöschten Eintrags (Universally Unique Identifier v4).
  TextColumn get entryUuid => text()();

  /// Zeitpunkt (UTC) der Löschung.
  DateTimeColumn get deletedAt => dateTime()();
}

/// Repräsentiert die privaten Konfigurationseinstellungen des aktuell geöffneten Tresors.
/// Diese Entität speichert sensible Synchronisationsparameter und kryptografische Basiselemente.
///
/// **Besonderheit:**
/// Diese Tabelle fungiert als Singleton-Speicher und enthält systembedingt exakt einen Datensatz,
/// welcher die Konfiguration für die aktuelle Tresor-Instanz beschreibt.
@DataClassName('SettingsEntity')
class Settings extends Table {
  /// Die interne ID (Primärschlüssel).
  /// Da es sich um einen Singleton-Datensatz handelt, ist der Wert hierbei stets 1.
  IntColumn get id => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};

  // --- Kryptografie ---

  /// Das Salt, welches zur Ableitung des Master-Keys (Argon2id) verwendet wird.
  TextColumn get salt => text()();

  /// Der private RSA-Schlüssel des Benutzers - verschlüsselt mit dem Master-Key (AES-256-GCM).
  TextColumn get encryptedPrivateKey => text()();

  /// Zeitstempel des Master-Keys (UTC).
  DateTimeColumn get masterKeyTimestamp => dateTime()();

  // --- Sync-Einstellungen ---

  /// Die URL des Sync-Servers (Host).
  TextColumn get host => text()();

  /// Das API-Token zur Authentifizierung gegenüber dem Sync-Server.
  TextColumn get apiToken => text()();

  /// Zeitpunkt der letzten erfolgreichen Synchronisation (UTC, Serverzeit).
  DateTimeColumn get lastSyncAt => dateTime()();

  // --- Biometrie ---

  /// Gibt an, ob Fingerabdruck bzw. Gesichtserkennung als Anmeldeoption zur Verfügung steht.
  BoolColumn get useBiometric => boolean()();

  // --- Passwortgenerator ---

  /// Die vom Passwortgenerator verwendete Passwortlänge.
  IntColumn get pwLength => integer()();

  /// Die vom Passwortgenerator verwendeten Sonderzeichen.
  TextColumn get pwSpecialChars => text()();

  /// Gibt an, ob der Passwortgenerator verwechselbare Zeichen (I, l, O, 0) ausschließen soll.
  BoolColumn get pwAvoidIlO0 => boolean().named('pw_avoid_ilo0')();

  // --- Aussehen ---

  /// Der Name, der in der UI als Platzhalter für Einträge ohne explizite Kategorie verwendet wird.
  TextColumn get categoryPlaceholder => text()(); // todo umbenennen in unnamedCategory
}

@DriftDatabase(tables: [Users, Entries, Permissions, Attachments, Tombstones, Settings])
class AppDatabase extends _$AppDatabase {
  final String password;
  final String dbName;

  AppDatabase(this.dbName, this.password) : super(openConnection(dbName, password));

  // Bei einer Änderung muss die Version erhöht werden, damit Drift weiß, dass es die Änderung ausführen muss.
  static const int version = 1;

  @override
  int get schemaVersion => version;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // Wird aufgerufen, wenn die DB zum allerersten Mal erstellt wird
    onCreate: (m) async {
      await m.createAll();
    },

    // Wird aufgerufen, wenn schemaVersion im Code höher ist als in der DB-Datei
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Beispiel: Wenn du UserEntity hinzufügst und die Version auf 2 erhöhst:
        // await m.createTable(userEntities);
      }
    },

    // Wird jedes Mal aufgerufen, wenn die DB geöffnet wird
    beforeOpen: (details) async {
      // Aktiviert Foreign Key Support in SQLite
      //await customStatement('PRAGMA foreign_keys = ON');

      if (kDebugMode) {
        // Hier könntest du Prüfungen durchführen oder Testdaten einfügen
        //print('Datenbank geöffnet. Schema Version: ${details.versionNow}');
      }
    },
  );
}