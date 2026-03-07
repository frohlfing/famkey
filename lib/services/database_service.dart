import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart'; // Hinzugefügt für debugPrint
import 'package:path/path.dart' as p;
import 'package:privault/database/database.dart';
import 'package:privault/services/config_service.dart';
import 'package:privault/models/entities/user_entity.dart';
import 'package:privault/models/entities/entry_entity.dart';
import 'package:privault/models/entities/settings_entity.dart';
import 'package:privault/models/entities/permission_entity.dart';
import 'package:privault/models/entities/tombstone_entity.dart';
import 'package:privault/models/entities/attachment_entity.dart';
import '../core/app_version.dart';
import '../models/entities/version_entity.dart';

/// Dienst für die Interaktion mit der lokalen SQLCipher-Datenbank.
class DatabaseService {
  // ------------------------------------------------------------------------
  // --- Verwendete Dienste (Abhängigkeiten) ---
  // ------------------------------------------------------------------------

  final ConfigService _configService;

  // ------------------------------------------------------------------------
  // --- Interne Variablen & Konstanten ---
  // ------------------------------------------------------------------------

  /// Die Datenbankverbindung
  AppDatabase? _db;

  /// Pfad zur Datenbankdatei
  String? _currentDbPath;

  // ------------------------------------------------------------------------
  // --- Initialisierung / Lifecycle ---
  // ------------------------------------------------------------------------

  /// Konstruktor
  DatabaseService(this._configService);

  /// Gibt zurück, ob die Datenbankverbindung initialisiert ist.
  bool get isInitialized => _db != null;

  /// Baut die Verbindung zur Datenbank auf.
  Future<void> initialize(String vaultName, Uint8List masterKey) async {
    if (_db != null) return; // Bereits verbunden

    // 1. Pfad bestimmen
    _currentDbPath = getDatabasePath(vaultName);

    // 2. Verbindung herstellen
    _db = AppDatabase(vaultName, _bytesToHex(masterKey));

    // 3. Migrationen
    //await _runMigrations();
  }

  /// Wirft ein Exception, falls die Datenbankverbindung nicht initialisiert wurde.
  void _ensureDbInitialized() {
    if (_db == null) throw Exception("Datenbank ist nicht initialisiert!");
  }

  /// Wirft ein Exception, falls das DB-Verzeichnis nicht initialisiert wurde.
  void _ensureDbPathInitialized() {
    if (_currentDbPath == null || _currentDbPath!.isEmpty) throw Exception("DB-Verzeichnis ist nicht initialisiert!");
  }

  /// Schließt die aktuelle Datenbankverbindung.
  Future<void> close() async {
    if (_db != null) {
      await _db?.close();
      _db = null;
    }
  }

  // ------------------------------------------------------------------------
  // --- Migration ---
  // ------------------------------------------------------------------------

  Future<VersionEntity> getVersion() async {
    _ensureDbInitialized();

    // todo per ORM bauen

    final versionResult = await _db!.customSelect('SELECT major, minor, patch, updated_at FROM versions WHERE id = 1;').getSingleOrNull();
    if (versionResult == null) return VersionEntity(major: 0, minor: 0, patch: 0, updatedAt: DateTime.now().toUtc());

    return VersionEntity(
      major: versionResult.data['major'] as int,
      minor: versionResult.data['minor'] as int,
      patch: versionResult.data['patch'] as int,
      updatedAt: DateTime.parse(versionResult.data['updated_at'] as String).toUtc(),
    );
  }

  /// Das Drift-Framework kümmert sich automatisch um Schema-Änderungen (wie das Hinzufügen von Spalten), wenn die @UseRowClass
  /// Annotationen in den Tabellendefinitionen in database.dart aktualisiert und die Build-Runner-Codegenerierung ausgeführt wird.
  /// Diese Methode konzentriert sich auf die Versionsprüfung des Tresors und das Auslösen von manuellen Datenmigrationen.
  Future<void> _runMigrations() async {
    // 1. Version vergleichen
    final dbVersion = await getVersion();
    if (dbVersion.major > 0 || dbVersion.minor > 0) {
      // Prüfung auf zu NEUE Version
      if (dbVersion.major > AppVersion.major || (dbVersion.major == AppVersion.major && dbVersion.minor > AppVersion.minor)) {
        // Patch-Nummer ist egal
        // Die Version des Tresors ist größer als die der App!
        throw Exception(
          'Der Tresor wurde zuletzt mit der neueren Version priVault v${dbVersion.major}.${dbVersion.minor} bearbeitet.\n'
          'Installiere diese Version oder höher, um den Tresor öffnen zu können.',
        );
      }

      // Prüfung auf zu ALTE Version (Breaking Changes bei Major Update)
      if (dbVersion.major < AppVersion.major) {
        // Die Major-Version des Tresors ist kleiner als die der App!
        throw Exception(
          'Der Tresor wurde zuletzt mit der älteren Version priVault v${dbVersion.major}.${dbVersion.minor} bearbeitet.\n'
          'Du kannst den Tresor importieren, indem du einen neuen Tresor anlegst und die Importfunktion aufrufst.',
        );
      }
    }

    // 2. Migrationen ausführen (Drift übernimmt das Schema)
    if (dbVersion.major < AppVersion.major || dbVersion.minor < AppVersion.minor || dbVersion.patch < AppVersion.patch) {
      return await _db!.transaction(() async {
        // Hier könnten in Zukunft manuelle Daten-Transformationen stattfinden,
        // die nicht von Drifts Schema-Migrationen abgedeckt werden.

        // Versionsnummer im Tresor speichern
        await _saveVersion(AppVersion.major, AppVersion.minor, AppVersion.patch);
      });
    }
  }

  /// Speichert die Schema-Version.
  Future<void> _saveVersion(int major, int minor, int patch) async {
    final companion = VersionsCompanion(
      id: const Value(1),
      major: Value(major),
      minor: Value(minor),
      patch: Value(patch),
      updatedAt: Value(DateTime.now().toUtc()),
    );
    await _db!.into(_db!.versions).insertOnConflictUpdate(companion);
  }

  // ------------------------------------------------------------------------
  // --- Methoden bzgl. Salt ---
  // ------------------------------------------------------------------------

  /// Gibt den Pfad zur Salt-Datei des aktuellen Tresors zurück.
  String _getSaltPath(String vaultName) => '${getDatabasePath(vaultName)}.salt';

  /// Liest das Salt für einen bestimmten Tresor aus dem Dateisystem.
  Future<Uint8List?> getSalt(String vaultName) async {
    final saltFile = File(_getSaltPath(vaultName));
    if (await saltFile.exists()) {
      return await saltFile.readAsBytes();
    }
    return null;
  }

  /// Speichert ein neues Salt für einen bestimmten Tresor im Dateisystem.
  Future<void> saveSalt(String vaultName, Uint8List saltBytes) async {
    final saltFile = File(_getSaltPath(vaultName));
    await saltFile.writeAsBytes(saltBytes);
  }

  // ------------------------------------------------------------------------
  // --- Methoden bzgl. Datenbankdatei ---
  // ------------------------------------------------------------------------

  /// Erstellt einen sicheren Dateipfad basierend auf dem Tresornamen.
  /// Bereinigt den Namen von ungültigen Dateisystemzeichen.
  String getDatabasePath(String vaultName) {
    final storagePath = _configService.vaultStoragePath;

    // Bereinigung: Alle Zeichen außer Buchstaben, Zahlen, Unterstrichen und Bindestrichen durch '_' ersetzen.
    final safeName = vaultName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();

    return p.join(storagePath, '$safeName.db3');
  }

  /// Prüft, ob eine Datenbankdatei für den angegebenen Tresornamen bereits existiert.
  Future<bool> databaseExists(String vaultName) async {
    final path = getDatabasePath(vaultName);
    return await File(path).exists();
  }

  /// Ändert das Verschlüsselungspasswort (bzw. den Key) der Datenbankdatei.
  Future<void> rekey(Uint8List newMasterKey) async {
    _ensureDbInitialized();
    final hexKey = newMasterKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _db!.customStatement("PRAGMA hexrekey = '$hexKey';");
  }

  // --- Backup & Restore ---

  /// Erstellt eine Sicherheitskopie der aktuellen Datenbankdatei.
  /// Wird z.B. vor kritischen Operationen wie `rekey` aufgerufen.
  Future<void> createBackup() async {
    _ensureDbPathInitialized();
    final file = File(_currentDbPath!);
    if (await file.exists()) {
      await file.copy('$_currentDbPath.bak');
    }
  }

  /// Entfernt eine zuvor erstellte Sicherheitskopie (bei erfolgreicher Operation).
  Future<void> removeBackup() async {
    _ensureDbPathInitialized();
    final backupPath = '$_currentDbPath.bak';
    final backupFile = File(backupPath);
    if (await backupFile.exists()) {
      try {
        await backupFile.delete();
      } catch (_) {
        debugPrint("Backup-File konnte nicht gelöscht werden.");
      }
    }
  }

  /// Stellt die Sicherheitskopie wieder her (bei fehlgeschlagener Operation).
  /// Die Datenbank muss geschlossen sein.
  Future<void> restoreBackup() async {
    _ensureDbPathInitialized();
    final backupPath = '$_currentDbPath.bak';
    final backupFile = File(backupPath);
    if (!await backupFile.exists()) {
      debugPrint("Es konnte keine Backup-Datei gefunden werden.");
      return;
    }
    await backupFile.copy(_currentDbPath!);
    try {
      await backupFile.delete();
    } catch (_) {
      debugPrint("Backup-File konnte kopiert, aber nicht gelöscht werden.");
    }
  }

  /// Benennt die Datenbankdatei eines Tresors (inklusive Salt) physisch auf dem Dateisystem um.
  /// Die Datenbankverbindung muss geschlossen sein.
  Future<void> renameDatabase(String oldName, String newName) async {
    if (_db != null) throw Exception("Erst Verbindung schließen!");

    final oldPath = getDatabasePath(oldName);
    final newPath = getDatabasePath(newName);

    // DB umbenennen
    final oldFile = File(oldPath);
    if (await oldFile.exists()) await oldFile.rename(newPath);

    // Salt umbenennen
    final oldSalt = File('$oldPath.salt');
    if (await oldSalt.exists()) await oldSalt.rename('$newPath.salt');

    // Backup der Datei umbenennen
    final oldBak = File('$oldPath.bak');
    if (await oldBak.exists()) await oldBak.rename('$newPath.bak');

    _currentDbPath = newPath;
  }

  /// Schließt die DB und löscht physisch die DB- und Salt-Datei.
  Future<void> deleteCurrentDatabase() async {
    _ensureDbPathInitialized();
    final path = _currentDbPath;
    await close();

    if (path != null) {
      final dbFile = File(path);
      if (await dbFile.exists()) await dbFile.delete();

      final saltFile = File('$path.salt');
      if (await saltFile.exists()) await saltFile.delete();
    }
  }

  // ------------------------------------------------------------------------
  // --- Methoden bzgl. User ---
  // ------------------------------------------------------------------------

  /// Lädt alle registrierten Benutzerdatensätze.
  Future<List<UserEntity>> getUsers() async {
    _ensureDbInitialized();

    final list = await _db!.select(_db!.users).get();
    return list
        .map(
          (u) => UserEntity(
            id: u.id,
            uuid: u.uuid,
            name: u.name,
            publicKey: u.publicKey,
            isVerified: u.isVerified,
            isHidden: u.isHidden,
            updatedAt: u.updatedAt,
          ),
        )
        .toList();
  }

  /// Lädt einen Benutzer anhand seiner internen ID.
  Future<UserEntity?> getUser(int userId) async {
    _ensureDbInitialized();

    final query = _db!.select(_db!.users)..where((u) => u.id.equals(userId));
    final user = await query.getSingleOrNull();
    if (user == null) return null;

    return UserEntity(
      id: user.id,
      uuid: user.uuid,
      name: user.name,
      publicKey: user.publicKey,
      isVerified: user.isVerified,
      isHidden: user.isHidden,
      updatedAt: user.updatedAt,
    );
  }

  /// Lädt einen Benutzer anhand seiner globalen UUID.
  Future<UserEntity?> getUserByUuid(String userUuid) async {
    _ensureDbInitialized();

    final row = await (_db!.select(_db!.users)..where((u) => u.uuid.equals(userUuid))).getSingleOrNull();
    if (row == null) return null;
    return UserEntity(
      id: row.id,
      uuid: row.uuid,
      name: row.name,
      publicKey: row.publicKey,
      isVerified: row.isVerified,
      isHidden: row.isHidden,
      updatedAt: row.updatedAt,
    );
  }

  /// Prüft, ob es mindestens einen (sichtbaren) Benutzer gibt, der noch nicht verifiziert ist.
  ///
  /// Der Benutzer der App ist immer verifiziert. Es werden also ausschließlich die Freunde betrachtet.
  Future<bool> hasUnverifiedUser() async {
    _ensureDbInitialized();

    final countExp = _db!.users.id.count();
    final query = _db!.selectOnly(_db!.users)
      ..addColumns([countExp])
      ..where(_db!.users.isVerified.equals(false) & _db!.users.isHidden.equals(false));
    final result = await query.map((row) => row.read(countExp)).getSingleOrNull();
    return (result ?? 0) > 0;
  }

  /// Speichert einen neuen Benutzer oder aktualisiert einen bestehenden Datensatz.
  /// Zurückgegeben wird die Entität mit der aktualisierten ID.
  Future<UserEntity> saveUser(UserEntity user) async {
    _ensureDbInitialized();

    // Existierenden Datensatz suchen (id ODER uuid)
    final existing =
        await (_db!.select(_db!.users)
          ..where((u) => (user.id != null ? u.id.equals(user.id!) : const Constant(false)) | u.uuid.equals(user.uuid)))
          .getSingleOrNull();

    var companion = UsersCompanion(
      uuid: Value(user.uuid),
      name: Value(user.name),
      publicKey: Value(user.publicKey),
      isVerified: Value(user.isVerified),
      isHidden: Value(user.isHidden),
      updatedAt: Value(user.updatedAt),
    );

    // Falls nicht vorhanden → Insert
    if (existing == null) {
      final newId = await _db!.into(_db!.users).insert(companion);
      return user.copyWith(id: newId);
    }

    // Falls vorhanden → Id übernehmen und Update
    companion = companion.copyWith(id: Value(existing.id));
    await (_db!.update(_db!.users)..where((u) => u.id.equals(existing.id))).write(companion);
    return user.copyWith(id: existing.id);
  }

  /// Verbirgt einen Benutzer und entwertet seine Schlüssel (Vertrauensentzug).
  Future<void> hideUser(int userId) async {
    _ensureDbInitialized();

    final now = DateTime.now().toUtc();
    await _db!.transaction(() async {
      // 1. Alle Permissions des Users entwerten.
      await _db!.customStatement(
        """
        UPDATE permissions 
        SET access_level = 0, encrypted_key = '' 
        WHERE user_id = ? AND (access_level > 0 OR encrypted_key != '')
        """,
        [userId],
      );

      // 2. Zeitstempel aller betroffenen Einträge aktualisieren
      await _db!.customStatement(
        """
        UPDATE entries 
        SET updated_at = ? 
        WHERE id IN (SELECT entry_id FROM permissions WHERE user_id = ?)
        """,
        [now.millisecondsSinceEpoch, userId],
      );

      // 3. Benutzer-Status aktualisieren
      await _db!.customStatement(
        """
        UPDATE users 
        SET is_verified = 0, is_hidden = 1, updated_at = ? 
        WHERE id = ?
        """,
        [now.millisecondsSinceEpoch, userId],
      );
    });
  }

  /// Löscht einen Benutzer und alle damit verbundenen Daten (Einträge, Permissions, Anhänge).
  Future<void> deleteUser(int userId) async {
    _ensureDbInitialized();

    await _db!.transaction(() async {
      // 1. Lösche alle Permissions, die der Benutzer selbst hat
      await (_db!.delete(_db!.permissions)..where((p) => p.userId.equals(userId))).go();

      // 2. Lösche ALLE Permissions für ALLE Einträge, die dieser Benutzer erstellt hat
      // (Wenn der Besitzer gelöscht wird, haben auch Freunde keinen Zugriff mehr)
      await _db!.customStatement("DELETE FROM permissions WHERE entry_id IN (SELECT id FROM entries WHERE creator_id = ?)", [userId]);

      // 3. Lösche alle Anhänge von Einträgen, die dieser Benutzer erstellt hat
      await _db!.customStatement("DELETE FROM attachments WHERE entry_id IN (SELECT id FROM entries WHERE creator_id = ?)", [userId]);

      // 4. Lösche die Einträge des Benutzers
      await (_db!.delete(_db!.entries)..where((e) => e.creatorId.equals(userId))).go();

      // 5. UpdaterId bei verbliebenen Einträgen nullen
      await _db!.customStatement("UPDATE entries SET updater_id = 0 WHERE updater_id = ?", [userId]);

      // 6. Den Benutzer selbst löschen
      await (_db!.delete(_db!.users)..where((u) => u.id.equals(userId))).go();
    });
  }

  // ------------------------------------------------------------------------
  // --- Methoden bzgl. Entry ---
  // ------------------------------------------------------------------------

  /// Lädt alle nicht gelöschten Einträge aus dem Tresor.
  Future<List<EntryEntity>> getEntries() async {
    _ensureDbInitialized();

    final list = await _db!.select(_db!.entries).get();
    return list
        .map(
          (e) => EntryEntity(
            id: e.id,
            uuid: e.uuid,
            category: e.category,
            title: e.title,
            url: e.url,
            notes: e.notes,
            favicon: e.favicon,
            encryptedData: e.encryptedData,
            creatorId: e.creatorId,
            updaterId: e.updaterId,
            updatedAt: e.updatedAt,
          ),
        )
        .toList();
  }

  /// Lädt alle Einträge, die nach einem bestimmten Zeitpunkt aktualisiert wurden (inkrementeller Sync).
  Future<List<EntryEntity>> getEntriesSince(DateTime since) async {
    _ensureDbInitialized();

    final list = await (_db!.select(_db!.entries)..where((e) => e.updatedAt.isBiggerThanValue(since))).get();
    return list
        .map(
          (e) => EntryEntity(
            id: e.id,
            uuid: e.uuid,
            category: e.category,
            title: e.title,
            url: e.url,
            notes: e.notes,
            favicon: e.favicon,
            encryptedData: e.encryptedData,
            creatorId: e.creatorId,
            updaterId: e.updaterId,
            updatedAt: e.updatedAt,
          ),
        )
        .toList();
  }

  /// Liefert die Liste der bereits gespeicherten Kategorien.
  Future<List<String>> getCategories() async {
    _ensureDbInitialized();

    final query = _db!.selectOnly(_db!.entries, distinct: true)
      ..addColumns([_db!.entries.category]) // Nur die Spalte 'category' selektieren
      ..where(_db!.entries.category.isNotValue('')); // Filtert leere Strings aus

    final rows = await query.get();

    // Die Ergebnisse mappen und sortieren
    final categories = rows.map((row) => row.read(_db!.entries.category)!).toList();

    return categories..sort();
  }

  /// Lädt einen Eintrag anhand seiner internen ID.
  Future<EntryEntity?> getEntry(int entryId) async {
    _ensureDbInitialized();

    final row = await (_db!.select(_db!.entries)..where((e) => e.id.equals(entryId))).getSingleOrNull();
    if (row == null) return null;
    return EntryEntity(
      id: row.id,
      uuid: row.uuid,
      category: row.category,
      title: row.title,
      url: row.url,
      notes: row.notes,
      favicon: row.favicon,
      encryptedData: row.encryptedData,
      creatorId: row.creatorId,
      updaterId: row.updaterId,
      updatedAt: row.updatedAt,
    );
  }

  /// Lädt einen Eintrag anhand seiner globalen UUID.
  Future<EntryEntity?> getEntryByUuid(String entryUuid) async {
    _ensureDbInitialized();

    final row = await (_db!.select(_db!.entries)..where((e) => e.uuid.equals(entryUuid))).getSingleOrNull();
    if (row == null) return null;

    return EntryEntity(
      id: row.id,
      uuid: row.uuid,
      category: row.category,
      title: row.title,
      url: row.url,
      notes: row.notes,
      favicon: row.favicon,
      encryptedData: row.encryptedData,
      creatorId: row.creatorId,
      updaterId: row.updaterId,
      updatedAt: row.updatedAt,
    );
  }

  /// Speichert einen Tresor-Eintrag und aktualisiert automatisch den Zeitstempel.
  Future<void> saveEntry(EntryEntity entry) async {
    _ensureDbInitialized();

    final companion = EntriesCompanion(
      uuid: Value(entry.uuid),
      category: Value(entry.category),
      title: Value(entry.title),
      url: Value(entry.url),
      notes: Value(entry.notes),
      favicon: Value(entry.favicon),
      encryptedData: Value(entry.encryptedData),
      creatorId: Value(entry.creatorId),
      updaterId: Value(entry.updaterId),
      updatedAt: Value(entry.updatedAt),
    );

    if (entry.id != null) {
      await (_db!.update(_db!.entries)..where((e) => e.id.equals(entry.id!))).write(companion);
    } else {
      await _db!.into(_db!.entries).insert(companion);
    }
  }

  /// Speichert einen Tresor-Eintrag und die Berechtigung auf diesen Eintrag für den angegebenen Benutzer.
  /// `encryptedKey` ist der verschlüsselte Entry-Key des Benutzers für diesen Eintrag.
  Future<int> saveEntryWithPermissions(EntryEntity entry, int userId, String encryptedKey, {int accessLevel = 3}) async {
    _ensureDbInitialized();

    return await _db!.transaction(() async {
      int actualEntryId;
      final entryCompanion = EntriesCompanion(
        uuid: Value(entry.uuid),
        category: Value(entry.category),
        title: Value(entry.title),
        url: Value(entry.url),
        notes: Value(entry.notes),
        favicon: Value(entry.favicon),
        encryptedData: Value(entry.encryptedData),
        creatorId: Value(entry.creatorId),
        updaterId: Value(entry.updaterId),
        updatedAt: Value(entry.updatedAt),
      );

      // 1. Eintrag speichern (wie MAUI: erst suchen ob Id oder Uuid existiert)
      final existingEntry = await (_db!.select(
        _db!.entries,
      )..where((e) => e.id.equals(entry.id ?? -1) | e.uuid.equals(entry.uuid))).getSingleOrNull();
      if (existingEntry != null) {
        await (_db!.update(_db!.entries)..where((e) => e.id.equals(existingEntry.id))).write(entryCompanion);
        actualEntryId = existingEntry.id;
      } else {
        actualEntryId = await _db!.into(_db!.entries).insert(entryCompanion);
      }

      // 2. Berechtigung für den Benutzer speichern
      final permCompanion = PermissionsCompanion(
        entryId: Value(actualEntryId),
        userId: Value(userId),
        encryptedKey: Value(encryptedKey),
        accessLevel: Value(accessLevel),
      );

      final existingPerm = await (_db!.select(
        _db!.permissions,
      )..where((p) => p.entryId.equals(actualEntryId) & p.userId.equals(userId))).getSingleOrNull();
      if (existingPerm != null) {
        await (_db!.update(_db!.permissions)..where((p) => p.id.equals(existingPerm.id))).write(permCompanion);
      } else {
        await _db!.into(_db!.permissions).insert(permCompanion);
      }

      return actualEntryId;
    });
  }

  /// Löscht einen Eintrag mit allen zugehörigen Berechtigungen und Anhängen.
  Future<void> deleteEntry(int entryId) async {
    _ensureDbInitialized();

    await _db!.transaction(() async {
      // 1. Alle Berechtigungen für diesen Eintrag löschen
      await (_db!.delete(_db!.permissions)..where((p) => p.entryId.equals(entryId))).go();

      // 2. Alle Anhänge (Metadaten und physische Blobs) dieses Eintrags löschen
      await (_db!.delete(_db!.attachments)..where((a) => a.entryId.equals(entryId))).go();

      // 3. Den Eintrag selbst physisch löschen
      await (_db!.delete(_db!.entries)..where((e) => e.id.equals(entryId))).go();
    });
  }

  // ------------------------------------------------------------------------
  // --- Methoden bzgl. Permission ---
  // ------------------------------------------------------------------------

  /// Lädt alle Berechtigungen.
  Future<List<PermissionEntity>> getPermissions() async {
    _ensureDbInitialized();

    final list = await _db!.select(_db!.permissions).get();
    return list
        .map(
          (p) => PermissionEntity(id: p.id, entryId: p.entryId, userId: p.userId, encryptedKey: p.encryptedKey, accessLevel: p.accessLevel),
        )
        .toList();
  }

  /// Lädt alle Berechtigungen auf einen bestimmten Eintrag.
  Future<List<PermissionEntity>> getPermissionsByEntryId(int entryId) async {
    _ensureDbInitialized();

    final list = await (_db!.select(_db!.permissions)..where((p) => p.entryId.equals(entryId))).get();
    return list
        .map(
          (p) => PermissionEntity(id: p.id, entryId: p.entryId, userId: p.userId, encryptedKey: p.encryptedKey, accessLevel: p.accessLevel),
        )
        .toList();
  }

  /// Lädt alle Berechtigungen eines bestimmten Benutzers.
  Future<List<PermissionEntity>> getPermissionsByUserId(int userId) async {
    _ensureDbInitialized();

    final list = await (_db!.select(_db!.permissions)..where((p) => p.userId.equals(userId))).get();
    return list
        .map(
          (p) => PermissionEntity(id: p.id, entryId: p.entryId, userId: p.userId, encryptedKey: p.encryptedKey, accessLevel: p.accessLevel),
        )
        .toList();
  }

  /// Lädt alle Berechtigungen mit leeren Entry-Key eines bestimmten Benutzers.
  Future<List<PermissionEntity>> getPermissionsWithoutKeyByUserId(int userId) async {
    _ensureDbInitialized();

    final list = await (_db!.select(_db!.permissions)..where((p) => p.userId.equals(userId) & p.encryptedKey.equals(''))).get();
    return list
        .map(
          (p) => PermissionEntity(
            id: p.id,
            entryId: p.entryId,
            userId: p.userId,
            encryptedKey: p.encryptedKey,
            accessLevel: p.accessLevel,
          ),
        )
        .toList();
  }

  /// Prüft, ob es Berechtigungen mit geleerten Entry-Keys gibt (durch `removeEntryKeysForUser`).
  /// In diesem Fall darf keine Synchronisation durchgeführt werden (da der betroffene Freund den Eintrag nicht öffnen könnte).
  Future<bool> hasPermissionsWithoutKey() async {
    _ensureDbInitialized();

    final countExp = _db!.permissions.id.count();
    final query = _db!.selectOnly(_db!.permissions)
      ..addColumns([countExp])
      ..where(_db!.permissions.encryptedKey.equals('') & _db!.permissions.accessLevel.isNotValue(0));
    final result = await query.map((row) => row.read(countExp)).getSingle();
    return (result ?? 0) > 0;
  }

  /// Liefert eine Liste aller IDs von Benutzern, die Zugriff auf Einträge mit geleerten Entry-Key haben.
  Future<List<int>> getUserIdsWithEmptyEntryKeys() async {
    _ensureDbInitialized();

    final query = _db!.selectOnly(_db!.permissions, distinct: true)
      ..addColumns([_db!.permissions.userId])
      ..where(_db!.permissions.encryptedKey.equals('') & _db!.permissions.accessLevel.isNotValue(0));
    final rows = await query.get();
    return rows //
        .map((row) => row.read(_db!.permissions.userId))
        .whereType<int>()
        .toList();
  }

  /// Lädt eine Berechtigung anhand seiner internen ID.
  Future<PermissionEntity?> getPermission(int permissionId) async {
    _ensureDbInitialized();

    final row = await (_db!.select(_db!.permissions)..where((p) => p.id.equals(permissionId))).getSingleOrNull();
    if (row == null) return null;
    return PermissionEntity(
      id: row.id,
      entryId: row.entryId,
      userId: row.userId,
      encryptedKey: row.encryptedKey,
      accessLevel: row.accessLevel,
    );
  }

  /// Lädt die Berechtigung eines Benutzers für einen Eintrag.
  Future<PermissionEntity?> getPermissionByEntryIdAndUserId(int entryId, int userId) async {
    _ensureDbInitialized();

    final row = await (_db!.select(_db!.permissions)..where((p) => p.entryId.equals(entryId) & p.userId.equals(userId))).getSingleOrNull();
    if (row == null) return null;
    return PermissionEntity(
      id: row.id,
      entryId: row.entryId,
      userId: row.userId,
      encryptedKey: row.encryptedKey,
      accessLevel: row.accessLevel,
    );
  }

  /// Speichert eine neue oder aktualisierte Berechtigung.
  Future<void> savePermission(PermissionEntity permission) async {
    _ensureDbInitialized();

    final companion = PermissionsCompanion(
      entryId: Value(permission.entryId),
      userId: Value(permission.userId),
      encryptedKey: Value(permission.encryptedKey),
      accessLevel: Value(permission.accessLevel),
    );

    if (permission.id != null) {
      await (_db!.update(_db!.permissions)..where((p) => p.id.equals(permission.id!))).write(companion);
    } else {
      await _db!.into(_db!.permissions).insert(companion);
    }
  }

  /// Aktualisiert eine Liste von Berechtigungen.
  Future<void> updatePermissions(List<PermissionEntity> permissions) async {
    _ensureDbInitialized();

    await _db!.transaction(() async {
      for (final p in permissions) {
        final companion = PermissionsCompanion(encryptedKey: Value(p.encryptedKey), accessLevel: Value(p.accessLevel));
        if (p.id != null) {
          await (_db!.update(_db!.permissions)..where((perm) => perm.id.equals(p.id!))).write(companion);
        }
      }
    });
  }

  /// Löscht eine Berechtigung.
  Future<void> deletePermission(int permissionId) async {
    _ensureDbInitialized();

    await (_db!.delete(_db!.permissions)..where((p) => p.id.equals(permissionId))).go();
  }

  /// Leert alle Entry-Keys eines Benutzers.
  ///
  /// Während der Synchronisation wird überprüft, ob der Fingerprint des Freundes geändert wurde.
  /// Wenn ja, wird der Entry-Key durch diese Methode, da er unbrauchbar geworden ist. Der Fingerprint
  /// des Freundes muss in dem Fall erneut verifiziert werden, wodurch der Entry-Key wieder gesetzt wird.
  Future<void> removeEntryKeysForUser(int userId) async {
    _ensureDbInitialized();

    final now = DateTime.now().toUtc();

    await _db!.transaction(() async {
      // 1. Alle Entry-Keys des Users in einem Rutsch entfernen.
      // Wir prüfen manuell, ob Zeilen betroffen waren (in Drift über custom Update oder Select)
      final affectedRows = await _db!.customUpdate(
        """
        UPDATE permissions 
        SET encrypted_key = '' 
        WHERE user_id = ? AND encrypted_key != ''
        """,
        variables: [Variable.withInt(userId)],
      );

      // Wenn keine Keys entfernt wurden, müssen wir auch keine Zeitstempel aktualisieren.
      if (affectedRows == 0) return;

      // 2. Zeitstempel der betroffenen Einträge aktualisieren.
      await _db!.customStatement(
        """
        UPDATE entries 
        SET updated_at = ? 
        WHERE id IN (SELECT entry_id FROM permissions WHERE user_id = ?)
        """,
        [now.millisecondsSinceEpoch, userId],
      );
    });
  }

  // ------------------------------------------------------------------------
  // --- Methoden bzgl. Tombstone ---
  // ------------------------------------------------------------------------

  /// Lädt alle Löschmarker (Tombstones) seit dem angegebenen Zeitpunkt ab.
  Future<List<TombstoneEntity>> getTombstonesSince(DateTime since) async {
    _ensureDbInitialized();

    final list = await (_db!.select(_db!.tombstones)..where((t) => t.deletedAt.isBiggerThanValue(since))).get();
    return list.map((t) => TombstoneEntity(id: t.id, entryUuid: t.entryUuid, deletedAt: t.deletedAt)).toList();
  }

  /// Speichert einen Löschmarker, um die Entfernung eines Eintrags synchronisieren zu können.
  Future<void> saveTombstone(TombstoneEntity tombstone) async {
    _ensureDbInitialized();

    await _db!.into(_db!.tombstones).insertOnConflictUpdate(TombstonesCompanion(entryUuid: Value(tombstone.entryUuid), deletedAt: Value(tombstone.deletedAt)));
  }

  // ------------------------------------------------------------------------
  // --- Methoden bzgl. Attachment ---
  // ------------------------------------------------------------------------

  /// Lädt alle Anhänge eines bestimmten Eintrags.
  Future<List<AttachmentEntity>> getAttachmentsByEntryId(int entryId) async {
    _ensureDbInitialized();

    final list = await (_db!.select(_db!.attachments)..where((a) => a.entryId.equals(entryId))).get();
    return list
        .map(
          (a) => AttachmentEntity(
            id: a.id,
            uuid: a.uuid,
            entryId: a.entryId,
            encryptedMeta: a.encryptedMeta,
            encryptedContent: a.encryptedContent,
            isSynced: a.isSynced,
          ),
        )
        .toList();
  }

  /// Lädt alle Anhänge, die noch nicht erfolgreich mit dem Server synchronisiert wurden.
  Future<List<AttachmentEntity>> getAttachmentsUnsynced() async {
    _ensureDbInitialized();

    final list = await (_db!.select(_db!.attachments)..where((a) => a.isSynced.equals(false))).get();
    return list
        .map(
          (a) => AttachmentEntity(
            id: a.id,
            uuid: a.uuid,
            entryId: a.entryId,
            encryptedMeta: a.encryptedMeta,
            encryptedContent: a.encryptedContent,
            isSynced: a.isSynced,
          ),
        )
        .toList();
  }

  /// Lädt einen Anhang anhand seiner internen ID.
  Future<AttachmentEntity?> getAttachment(int attachmentId) async {
    _ensureDbInitialized();

    final row = await (_db!.select(_db!.attachments)..where((a) => a.id.equals(attachmentId))).getSingleOrNull();
    if (row == null) return null;

    return AttachmentEntity(
      id: row.id,
      uuid: row.uuid,
      entryId: row.entryId,
      encryptedMeta: row.encryptedMeta,
      encryptedContent: row.encryptedContent,
      isSynced: row.isSynced,
    );
  }

  /// Lädt einen Anhang anhand seiner UUID.
  Future<AttachmentEntity?> getAttachmentByUuid(String attachmentUuid) async {
    _ensureDbInitialized();

    final row = await (_db!.select(_db!.attachments)..where((a) => a.uuid.equals(attachmentUuid))).getSingleOrNull();
    if (row == null) return null;

    return AttachmentEntity(
      id: row.id,
      uuid: row.uuid,
      entryId: row.entryId,
      encryptedMeta: row.encryptedMeta,
      encryptedContent: row.encryptedContent,
      isSynced: row.isSynced,
    );
  }

  /// Speichert einen Anhang oder aktualisiert einen bestehenden.
  Future<void> saveAttachment(AttachmentEntity attachment) async {
    _ensureDbInitialized();

    final companion = AttachmentsCompanion(
      uuid: Value(attachment.uuid),
      entryId: Value(attachment.entryId),
      encryptedMeta: Value(attachment.encryptedMeta),
      encryptedContent: Value(attachment.encryptedContent),
      isSynced: Value(attachment.isSynced),
    );

    if (attachment.id != null) {
      await (_db!.update(_db!.attachments)..where((a) => a.id.equals(attachment.id!))).write(companion);
    } else {
      await _db!.into(_db!.attachments).insert(companion);
    }
  }

  /// Löscht einen Anhang anhand seiner internen ID.
  Future<void> deleteAttachment(int attachmentId) async {
    _ensureDbInitialized();

    await (_db!.delete(_db!.attachments)..where((a) => a.id.equals(attachmentId))).go();
  }

  // ------------------------------------------------------------------------
  // --- Methoden bzgl. Settings ---
  // ------------------------------------------------------------------------

  /// Lädt die globalen Einstellungen für den aktuellen Tresor.
  Future<SettingsEntity?> getSettings() async {
    _ensureDbInitialized();

    final query = _db!.select(_db!.settings)..where((s) => s.id.equals(1));
    final s = await query.getSingleOrNull();
    if (s == null) return null;

    return SettingsEntity(
      id: s.id,
      salt: s.salt,
      encryptedPrivateKey: s.encryptedPrivateKey,
      host: s.host ?? '',
      apiToken: s.apiToken ?? '',
      useBiometric: s.useBiometric,
      pwLength: s.pwLength,
      pwSpecialChars: s.pwSpecialChars ?? '',
      pwAvoidIlO0: s.pwAvoidIlO0,
      categoryPlaceholder: s.categoryPlaceholder ?? '',
      lastSyncAt: s.lastSyncAt,
    );
  }

  /// Speichert oder ersetzt die globalen Tresor-Einstellungen.
  Future<void> saveSettings(SettingsEntity s) async {
    _ensureDbInitialized();

    final companion = SettingsCompanion(
      id: const Value(1),
      salt: Value(s.salt),
      encryptedPrivateKey: Value(s.encryptedPrivateKey),
      host: Value(s.host),
      apiToken: Value(s.apiToken),
      useBiometric: Value(s.useBiometric),
      pwLength: Value(s.pwLength),
      pwSpecialChars: Value(s.pwSpecialChars),
      pwAvoidIlO0: Value(s.pwAvoidIlO0),
      categoryPlaceholder: Value(s.categoryPlaceholder),
      lastSyncAt: Value(s.lastSyncAt),
    );
    await _db!.into(_db!.settings).insertOnConflictUpdate(companion);
  }

  // ------------------------------------------------------------------------
  // --- Interne Methoden / Helper ---
  // ------------------------------------------------------------------------

  /// Konvertiert einen Byte-Array in einen Hex-String.
  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
