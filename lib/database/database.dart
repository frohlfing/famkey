import 'dart:ffi';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/services/config_service.dart';
import 'package:flutter/foundation.dart';

part 'database.g.dart';

/// Definition des Datenbank-Schemas
///
/// WICHTIG:
/// Wenn hier etwas geändert wird, muss `database.g.dart` mit diesem Befehl neu generiert werden:
/// ```shell
/// flutter pub run build_runner build --delete-conflicting-outputs
/// ```

/// Repräsentiert eine Benutzeridentität innerhalb eines Tresors.
///
/// Diese Klasse verwaltet sowohl den Benutzer der App als auch alle hinzugefügten
/// Freunde, mit denen Einträge geteilt werden können.
///
/// **Rollenverteilung:**
/// * **Besitzer:** Der Hauptbenutzer der App hat lokal stets die `id = 1`.
/// * **Freunde:** Weitere Benutzer, mit denen Einträge geteilt werden können.
@DataClassName('UserEntity')
class Users extends Table {
  /// Die interne ID (Auto-Increment in der Datenbank).
  /// Der Benutzer der App wird systemintern stets mit der ID 1 identifiziert.
  /// Nullable für neue Einträge, bevor sie in die Datenbank geschrieben werden.
  IntColumn get id => integer().autoIncrement()();

  /// Die globale eindeutige ID des Benutzers (Universally Unique Identifier v4).
  TextColumn get uuid => text().unique()();

  /// Der Name des Benutzers (eindeutig pro Tresor auf dem Server).
  /// Ist im Normalfall UNVERÄNDERLICH nach der Registrierung.
  TextColumn get name => text().unique()();

  /// Der öffentliche RSA-Schlüssel des Benutzers (Base64-kodierter SPKI-String).
  TextColumn get publicKey => text()();

  /// Gibt an, ob die Identität dieses Benutzers (per Fingerprint-Vergleich) manuell verifiziert wurde.
  BoolColumn get isVerified => boolean().withDefault(const Constant(false))();

  /// Gibt an, ob der Benutzer in der UI ausgeblendet ist (z.B. gelöschte Freunde, die wegen Sync noch erhalten bleiben müssen).
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();

  /// Zeitpunkt der letzten Änderung (UTC).
  DateTimeColumn get updatedAt => dateTime()();
}

/// Repräsentiert einen Tresoreintrag in der SQLite-Datenbank.
@DataClassName('EntryEntity')
class Entries extends Table {
  /// Die interne ID (Auto-Increment in der Datenbank).
  /// Nullable für neue Einträge, bevor sie in die Datenbank geschrieben werden.
  IntColumn get id => integer().autoIncrement()();

  /// Die globale eindeutige ID des Eintrags (Universally Unique Identifier v4).
  TextColumn get uuid => text().unique()();

  /// Die Kategorie des Eintrags.
  TextColumn get category => text().withDefault(const Constant(''))();

  /// Der Anzeigename des Eintrags.
  TextColumn get title => text().withDefault(const Constant(''))();

  /// Die zugehörige Adresse der Webseite oder des Dienstes.
  TextColumn get url => text().withDefault(const Constant(''))();

  /// Ergänzende Notizen.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Der binäre Dateninhalt des Website-Icons, gespeichert als Base64-kodierter String.
  /// Ermöglicht die visuelle Identifikation in der Liste ohne zusätzliche Netzwerkanfragen.
  TextColumn get favicon => text().withDefault(const Constant(''))();

  /// Der AES-256-GCM verschlüsselte Daten-Container (Ciphertext + Nonce + Auth-Tag).
  /// Enthält das serialisierte JSON-Objekt der Klasse [EntryPayload].
  TextColumn get encryptedData => text()();

  /// Die lokale ID des Benutzers, der diesen Eintrag erstellt hat.
  IntColumn get creatorId => integer()();

  /// Die lokale ID des Benutzers, der den Eintrag zuletzt aktualisiert hat.
  IntColumn get updaterId => integer()();

  /// Zeitpunkt der letzten Änderung (UTC).
  DateTimeColumn get updatedAt => dateTime()();
}

/// Repräsentiert die Zugriffsberechtigung eines Benutzers für einen spezifischen Tresoreintrag.
@DataClassName('PermissionEntity')
class Permissions extends Table {
  /// Die interne ID (Auto-Increment in der Datenbank).
  /// Nullable für neue Einträge, bevor sie in die Datenbank geschrieben werden.
  IntColumn get id => integer().autoIncrement()();

  /// Die interne ID des zugehörigen Eintrags.
  IntColumn get entryId => integer().references(Entries, #id)();

  /// Die lokale ID des Benutzers, dem dieser Zugriff gewährt wurde.
  IntColumn get userId => integer().references(Users, #id)();

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

  @override
  List<Set<Column>> get uniqueKeys => [
    {entryId, userId},
  ];
}

/// Repräsentiert einen Dateianhang zu einem Tresoreintrag in der lokalen SQLite-Datenbank.
/// Der gesamte Inhalt wird verschlüsselt gespeichert, um die Privatsphäre zu gewährleisten.
@DataClassName('AttachmentEntity')
class Attachments extends Table {
  /// Die interne ID (Auto-Increment in der Datenbank).
  /// Nullable für neue Einträge, bevor sie in die Datenbank geschrieben werden.
  IntColumn get id => integer().autoIncrement()();

  /// Die globale eindeutige ID des Anhangs (Universally Unique Identifier v4).
  TextColumn get uuid => text().unique()();

  /// Die interne ID des zugehörigen Eintrags.
  IntColumn get entryId => integer().references(Entries, #id)();

  /// Der AES-256-GCM verschlüsselte Metadaten-Container (Ciphertext + Nonce + Auth-Tag).
  /// Enthält das serialisierte JSON-Objekt der Klasse [AttachmentMetaPayload].
  TextColumn get encryptedMeta => text()();

  /// Der AES-256-GCM verschlüsselte Binärdaten-Container (Ciphertext + Nonce + Auth-Tag).
  /// Enthält den binären Dateninhalt des Anhangs.
  TextColumn get encryptedContent => text()();

  /// `true`, wenn der Anhang erfolgreich zum Server synchronisiert wurde, sonst `false`.
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}

/// Repräsentiert einen Löschmarker ("Tombstone") für Tresoreinträge.
/// Diese Entität speichert die UUIDs von gelöschten Objekten, um die Synchronisation
/// von Löschvorgängen über mehrere Geräte hinweg zu ermöglichen.
///
/// **Funktionsweise:**
/// Wenn ein Eintrag lokal gelöscht wird, wird hier ein Grabstein hinterlassen.
/// Beim nächsten Synchronisationsvorgang meldet der Client dem Server:
/// "Eintrag mit UUID X wurde gelöscht".
@DataClassName('TombstoneEntity')
class Tombstones extends Table {
  /// Die interne ID (Auto-Increment in der Datenbank).
  /// Nullable für neue Einträge, bevor sie in die Datenbank geschrieben werden.
  IntColumn get id => integer().autoIncrement()();

  /// Die globale ID des gelöschten Eintrags (Universally Unique Identifier v4).
  TextColumn get entryUuid => text().unique()();

  /// Zeitpunkt (UTC) der Löschung.
  DateTimeColumn get deletedAt => dateTime()();
}

/// Repräsentiert die privaten Konfigurationseinstellungen des aktuell geöffneten Tresors.
/// Diese Entität speichert sensible Synchronisationsparameter und kryptografische Basiselemente.
///
/// **Besonderheit:**
/// Diese Tabelle fungiert als Singleton-Speicher und enthält systembedingt exakt einen Datensatz,
/// welcher die Konfiguration für die aktuelle Tresor-Instanz beschreibt.
@DataClassName('SettingEntity')
class Settings extends Table {
  /// Die interne ID (Primärschlüssel).
  /// Da es sich um einen Singleton-Datensatz handelt, ist der Wert hierbei stets 1.
  IntColumn get id => integer().withDefault(const Constant(1))();

  // --- Kryptografie ---

  /// Das Salt, welches zur Ableitung des Master-Keys (Argon2id) verwendet wird.
  TextColumn get salt => text()();

  /// Der private RSA-Schlüssel des Benutzers - verschlüsselt mit dem Master-Key (AES-256-GCM).
  TextColumn get encryptedPrivateKey => text()();

  // --- Sync-Einstellungen ---

  /// Die URL des Sync-Servers (Host).
  TextColumn get host => text().nullable()();

  /// Das API-Token zur Authentifizierung gegenüber dem Sync-Server.
  TextColumn get apiToken => text().nullable()();

  // --- Biometrie ---

  /// Gibt an, ob Fingerabdruck bzw. Gesichtserkennung als Anmeldeoption zur Verfügung steht.
  BoolColumn get useBiometric => boolean().withDefault(const Constant(true))();

  // --- Passwort-Generator ---

  /// Die vom Passwortgenerator verwendete Passwortlänge.
  IntColumn get pwLength => integer().withDefault(const Constant(16))();

  /// Die vom Passwortgenerator verwendeten Sonderzeichen.
  TextColumn get pwSpecialChars => text().nullable()();

  /// Gibt an, ob der Passwortgenerator verwechselbare Zeichen (I, l, O, 0) ausschließen soll.
  BoolColumn get pwAvoidIlO0 => boolean().withDefault(const Constant(true))();

  // --- Aussehen ---

  /// Der Name, der in der UI als Platzhalter für Einträge ohne explizite Kategorie verwendet wird.
  TextColumn get categoryPlaceholder => text().nullable()();

  // --- Synchronisation ---

  /// Zeitpunkt der letzten erfolgreichen Synchronisation (UTC, Serverzeit).
  DateTimeColumn get lastSyncAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Repräsentiert die Schema-Version der lokalen SQLite-Datenbank.
/// Diese Entität wird genutzt, um automatische Migrationen bei App-Updates durchzuführen.
///
/// **Besonderheit:**
/// Diese Tabelle fungiert als Singleton-Speicher und enthält systembedingt exakt einen Datensatz,
/// welcher den aktuellen Zustand der lokalen Datenbankstruktur beschreibt.
///
/// **Versioning-Schema (SemVer):**
/// * **Major:** Inkompatible Änderungen am Datenformat.
/// * **Minor:** Neue Tabellen oder Spalten (abwärtskompatibel).
/// * **Patch:** Fehlerkorrekturen am Schema ohne Strukturänderung.
@DataClassName('VersionEntity')
class Versions extends Table {
  /// Die interne ID (Auto-Increment in der Datenbank).
  /// Da es sich um einen Singleton-Datensatz handelt, ist der Wert hierbei stets 1.
  IntColumn get id => integer().withDefault(const Constant(1))();

  /// Die Haupt-Versionsnummer.
  /// Wird erhöht bei Schema-Änderungen, die nicht abwärtskompatibel sind.
  IntColumn get major => integer()();

  /// Die Neben-Versionsnummer.
  /// Wird erhöht, wenn das Schema abwärtskompatibel verändert wurde (z.B. neue optionale Felder).
  IntColumn get minor => integer()();

  /// Die Revisionsnummer.
  /// Wird erhöht, wenn das Schema optimiert wurde (z.B. Index hinzugefügt/verändert).
  IntColumn get patch => integer()();

  /// Zeitstempel der letzten lokalen Schema-Änderung (UTC).
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Users, Entries, Permissions, Attachments, Tombstones, Versions, Settings])
class AppDatabase extends _$AppDatabase {
  final String password;
  final String dbName;

  AppDatabase(this.dbName, this.password) : super(_openConnection(dbName, password));

  // Bei einer Änderung muss die Version erhöht werden, damit Drift weiß, dass es die Änderung ausführen muss.
  @override
  int get schemaVersion => 1;

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
      await customStatement('PRAGMA foreign_keys = ON');

      if (kDebugMode) {
        // Hier könntest du Prüfungen durchführen oder Testdaten einfügen
        print('Datenbank geöffnet. Schema Version: ${details.versionNow}');
      }
    },
  );

  static QueryExecutor _openConnection(String name, String password) {
    return LazyDatabase(() async {
      // WICHTIG: Nutze den zentralen Speicherpfad aus dem ConfigService
      final config = getIt<ConfigService>();
      final storagePath = config.vaultStoragePath;
      final file = File(p.join(storagePath, '$name.db3'));

      // DLL-Bindung für SQLCipher
      if (!kIsWeb && Platform.isWindows) {
        final dllPath = p.join(Directory.current.path, 'sqlite3mc_x64.dll');
        if (File(dllPath).existsSync()) {
          open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open(dllPath));
          debugPrint('✅ SQLiteMC DLL registriert');
        }
      }

      if (kDebugMode) {
        // Brauchen wir, um die DB per Database Navigator öffnen zu können
        debugPrint("🔑 DB-Passwort: $password");
      }

      // Datenbank öffnen
      final rawDb = sqlite3.open(file.path);

      // Datenbank entsperren
      rawDb.execute("PRAGMA cipher = 'sqlcipher';");
      rawDb.execute("PRAGMA hexkey = '$password';");

      // Ab hier übernimmt Drift und prüft, ob die Tabellen aktualisiert werden müssen.
      return NativeDatabase.opened(rawDb);
    });
  }
}
