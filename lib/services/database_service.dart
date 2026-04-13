import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart'; // Hinzugefügt für debugPrint
import 'package:path/path.dart' as p;
import 'package:privault/core/app_file_factory.dart';
import 'package:privault/database/database.dart';
import '../core/env.dart';

/// Daten für `import()`
typedef ImportBatch = List<({EntryEntity entry, String encryptedEntryKey, List<({String uuid, String encryptedMeta, String encryptedContent})> attachments})>;

/// Dienst für die Interaktion mit der lokalen SQLCipher-Datenbank.
class DatabaseService {

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
  DatabaseService();

  /// Gibt zurück, ob die Datenbankverbindung initialisiert ist.
  bool get isInitialized => _db != null;

  /// Baut die Verbindung zur Datenbank auf.
  Future<void> initialize(String vaultName, Uint8List masterKey) async {
    if (_db != null) return; // Bereits verbunden
    _currentDbPath = getDatabasePath(vaultName);
    _db = AppDatabase(vaultName, _bytesToHex(masterKey));
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
  // --- Methoden bzgl. Salt ---
  // ------------------------------------------------------------------------

  /// Gibt den Pfad zur Salt-Datei des aktuellen Tresors zurück.
  String _getSaltPath(String vaultName) => '${getDatabasePath(vaultName)}.salt';

  /// Liest das Salt aus der Salt-Datei.
  Future<Uint8List?> getSalt(String vaultName) async {
    final saltFile = createAppFile(_getSaltPath(vaultName));
    if (await saltFile.exists()) {
      return saltFile.readAsBytes();
    }
    return null;
  }

  /// Speichert das Salt in die Salt-Datei.
  Future<void> saveSalt(String vaultName, Uint8List saltBytes) {
    final saltFile = createAppFile(_getSaltPath(vaultName));
    return saltFile.writeAsBytes(saltBytes);
  }

  // /// Löscht eine Salt-Datei.
  // Future<void> deleteSaltFile(String vaultName, Uint8List saltBytes) async {
  //   final saltFile = File(_getSaltPath(vaultName));
  //   if (await saltFile.exists()) await saltFile.delete();
  // }

  // ------------------------------------------------------------------------
  // --- Methoden bzgl. Datenbankdatei ---
  // ------------------------------------------------------------------------

  /// Erstellt einen sicheren Dateipfad basierend auf dem Tresornamen.
  /// Bereinigt den Namen von ungültigen Dateisystemzeichen.
  String getDatabasePath(String vaultName) {
    // Bereinigung: Alle Zeichen außer Buchstaben, Zahlen, Unterstrichen und Bindestrichen durch '_' ersetzen.
    final safeName = vaultName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    return p.join(env.vaultStoragePath, '$safeName.db3');
  }

  /// Prüft, ob eine Datenbankdatei für den angegebenen Tresornamen bereits existiert.
  Future<bool> databaseExists(String vaultName) {
    final path = getDatabasePath(vaultName);
    return createAppFile(path).exists();
  }

  /// Listet existierende Tresore auf.
  Future<List<String>> getExistingVaults() async {
    final path = env.vaultStoragePath;
    if (path.isEmpty) return [];

    final dir = createAppDirectory(path);
    if (!await dir.exists()) return [];
    final files = await dir.list(recursive: true);

    if (env.isWeb) {
      // Drift legt /drift_db/<name>/database an
      return files
          .where((f) => f.name == 'database')
          .map((f) => f.path.split('/').reversed.skip(1).first) // Verzeichnis direkt über "database"
          .toList();
    }

    // Nativ: vaults/<name>.db3
    final vaults = files
        .where((f) => f.name.endsWith('.db3'))
        .map((f) => f.name.replaceAll('.db3', ''))
        .toList();

    debugPrint("Vaults: $vaults");
    return vaults;
  }

  /// Ändert das Verschlüsselungspasswort (bzw. den Key) der Datenbankdatei.
  Future<void> rekey(Uint8List newMasterKey) {
    _ensureDbInitialized();
    final hexKey = newMasterKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return _db!.customStatement("PRAGMA hexrekey = '$hexKey';");
  }

  // --- Backup & Restore ---

  /// Erstellt eine Sicherheitskopie der aktuellen Datenbankdatei.
  /// Wird z.B. vor kritischen Operationen wie `rekey` aufgerufen.
  Future<void> createBackup() async {
    _ensureDbPathInitialized();
    final file = createAppFile(_currentDbPath!);
    if (await file.exists()) {
      await file.copy('$_currentDbPath.bak');
    }
  }

  /// Entfernt eine zuvor erstellte Sicherheitskopie (bei erfolgreicher Operation).
  Future<void> removeBackup() async {
    _ensureDbPathInitialized();
    final backupPath = '$_currentDbPath.bak';
    final backupFile = createAppFile(backupPath);
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
    final backupFile = createAppFile(backupPath);
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
  Future<void> renameDatabaseAndSaltFile(String oldName, String newName) async {
    if (_db != null) throw Exception("Erst Verbindung schließen!");

    final oldPath = getDatabasePath(oldName);
    final newPath = getDatabasePath(newName);

    // DB umbenennen
    final oldFile = createAppFile(oldPath);
    if (await oldFile.exists()) await oldFile.rename(newPath);

    // Salt umbenennen
    final oldSalt = createAppFile('$oldPath.salt');
    if (await oldSalt.exists()) await oldSalt.rename('$newPath.salt');

    // Backup der Datei umbenennen
    final oldBak = createAppFile('$oldPath.bak');
    if (await oldBak.exists()) await oldBak.rename('$newPath.bak');

    _currentDbPath = newPath;
  }

  /// Schließt die DB und löscht physisch die DB- und Salt-Datei.
  Future<void> deleteCurrentDatabaseAndSaltFile() async {
    _ensureDbPathInitialized();
    final path = _currentDbPath;
    await close();

    if (path != null) {
      final dbFile = createAppFile(path);
      if (await dbFile.exists()) await dbFile.delete();

      final saltFile = createAppFile('$path.salt');
      if (await saltFile.exists()) await saltFile.delete();
    }
  }

  // ------------------------------------------------------------------------
  // --- Methoden bzgl. User ---
  // ------------------------------------------------------------------------

  /// Lädt alle registrierten Benutzerdatensätze.
  Future<List<UserEntity>> getUsers() {
    _ensureDbInitialized();
    return _db!.select(_db!.users).get();
  }

  /// Lädt alle Freunde, die nicht ausgeblendet sind.
  Future<List<UserEntity>> getNotHiddenFriends() {
    _ensureDbInitialized();
    return (_db!.select(_db!.users)..where((u) => u.id.isBiggerThanValue(1) & u.isHidden.equals(false))).get();
  }

  /// Lädt alle Freunde, die nicht ausgeblendet sind zusammen mit den Zugriffsrechten auf den gegebenen Eintrag.
  Future<List<({UserEntity user, int accessLevel})>> getNotHiddenFriendsWithAccessLevel(int entryId) async {
    _ensureDbInitialized();
    final allFriends = await getNotHiddenFriends();
    final permissions = await getPermissionsByEntryId(entryId);
    return allFriends.map((user) {
      final perm = permissions.firstWhere((p) => p.userId == user.id, orElse: () => PermissionEntity(id: 0, entryId: 0, userId: 0, accessLevel: 0, encryptedKey: ''));
      return (user: user, accessLevel: perm.accessLevel);
    }).toList();
  }

  /// Lädt einen Benutzer anhand seiner internen ID.
  Future<UserEntity?> getUser(int userId) {
    _ensureDbInitialized();
    return (_db!.select(_db!.users)..where((u) => u.id.equals(userId))).getSingleOrNull();
  }

  /// Lädt einen Benutzer anhand seiner globalen UUID.
  Future<UserEntity?> getUserByUuid(String userUuid) {
    _ensureDbInitialized();
    return (_db!.select(_db!.users)..where((u) => u.uuid.equals(userUuid))).getSingleOrNull();
  }

  /// Lädt einen Benutzer anhand seines Namens (case-insensitive).
  Future<UserEntity?> getUserByName(String userName) {
    _ensureDbInitialized();
    final lowerName = userName.toLowerCase();
    return (_db!.select(_db!.users)..where((u) => u.name.lower().equals(lowerName))).getSingleOrNull();
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

    var companion = UsersCompanion(
      uuid: Value(user.uuid),
      name: Value(user.name),
      publicKey: Value(user.publicKey),
      isVerified: Value(user.isVerified),
      isHidden: Value(user.isHidden),
      updatedAt: Value(user.updatedAt),
    );

    // Existierenden Datensatz suchen (id ODER uuid)
    final existing = await (_db!.select(_db!.users)..where((u) => u.id.equals(user.id) | u.uuid.equals(user.uuid))).getSingleOrNull();

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
  Future<List<EntryEntity>> getEntries() {
    _ensureDbInitialized();
    return _db!.select(_db!.entries).get();
  }

  /// Lädt alle Einträge, die nach einem bestimmten Zeitpunkt aktualisiert wurden (inkrementeller Sync).
  Future<List<EntryEntity>> getEntriesSince(DateTime since) {
    _ensureDbInitialized();
    return (_db!.select(_db!.entries)..where((e) => e.updatedAt.isBiggerThanValue(since))).get();
  }

  /// Lädt einen Eintrag anhand seiner internen ID.
  Future<EntryEntity?> getEntry(int entryId) {
    _ensureDbInitialized();
    return (_db!.select(_db!.entries)..where((e) => e.id.equals(entryId))).getSingleOrNull();
  }

  /// Lädt einen Eintrag anhand seiner globalen UUID.
  Future<EntryEntity?> getEntryByUuid(String entryUuid) {
    _ensureDbInitialized();
    return (_db!.select(_db!.entries)..where((e) => e.uuid.equals(entryUuid))).getSingleOrNull();
  }

  /// Speichert einen Tresor-Eintrag und aktualisiert automatisch den Zeitstempel.
  Future<EntryEntity> saveEntry(EntryEntity entry) async {
    _ensureDbInitialized();

    var companion = EntriesCompanion(
      uuid: Value(entry.uuid),
      encryptedData: Value(entry.encryptedData),
      encryptedIndex: Value(entry.encryptedIndex),
      creatorId: Value(entry.creatorId),
      updaterId: Value(entry.updaterId),
      updatedAt: Value(entry.updatedAt),
    );

    // Existierenden Datensatz suchen (id ODER uuid)
    final existing = await (_db!.select(_db!.entries)..where((e) => e.id.equals(entry.id) | e.uuid.equals(entry.uuid))).getSingleOrNull();

    // Falls nicht vorhanden → Insert
    if (existing == null) {
      return _db!.transaction(() async {
        // Tombstone löschen, falls dieser existiert (Wiederauferstehung)
        await (_db!.delete(_db!.tombstones)..where((t) => t.entryUuid.equals(entry.uuid))).go();
        // Eintrag einfügen
        final newId = await _db!.into(_db!.entries).insert(companion);
        return entry.copyWith(id: newId);
      });
    }

    // Falls vorhanden → Id übernehmen und Update
    companion = companion.copyWith(id: Value(existing.id));
    await (_db!.update(_db!.entries)..where((u) => u.id.equals(existing.id))).write(companion);
    return entry.copyWith(id: existing.id);
  }

  /// Speichert einen Tresor-Eintrag und die Berechtigung auf diesen Eintrag für den angegebenen Benutzer.
  /// `encryptedKey` ist der verschlüsselte Entry-Key des Benutzers für diesen Eintrag.
  Future<EntryEntity> saveEntryWithPermissions(EntryEntity entry, int userId, String encryptedKey, {int accessLevel = 3}) async {
    _ensureDbInitialized();

    return _db!.transaction(() async {

      // 1. Eintrag speichern (wie saveEntry)

      var companion = EntriesCompanion(
        uuid: Value(entry.uuid),
        encryptedData: Value(entry.encryptedData),
        encryptedIndex: Value(entry.encryptedIndex),
        creatorId: Value(entry.creatorId),
        updaterId: Value(entry.updaterId),
        updatedAt: Value(entry.updatedAt),
      );

      // Existierenden Datensatz suchen (id ODER uuid)
      final existing = await (_db!.select(_db!.entries)..where((e) => e.id.equals(entry.id) | e.uuid.equals(entry.uuid))).getSingleOrNull();

      // Insert bzw. Update
      if (existing == null) {
        // Tombstone löschen, falls dieser existiert (Wiederauferstehung)
        await (_db!.delete(_db!.tombstones)..where((t) => t.entryUuid.equals(entry.uuid))).go();
        // Eintrag einfügen
        final newId = await _db!.into(_db!.entries).insert(companion);
        entry = entry.copyWith(id: newId);
      }
      else {
        // Eintrag aktualisieren
        companion = companion.copyWith(id: Value(existing.id));
        await (_db!.update(_db!.entries)..where((e) => e.id.equals(existing.id))).write(companion);
        entry = entry.copyWith(id: existing.id);
      }

      // 2. Berechtigung für den Benutzer speichern (wie SavePermission)

      var permCompanion = PermissionsCompanion(
        entryId: Value(entry.id),
        userId: Value(userId),
        encryptedKey: Value(encryptedKey),
        accessLevel: Value(accessLevel),
      );

      // Existierenden Datensatz suchen (über entryId UND userId)
      final existingPerm = await (_db!.select(_db!.permissions)..where((p) => p.entryId.equals(entry.id) & p.userId.equals(userId))).getSingleOrNull();

      // Insert bzw. Update
      if (existingPerm == null) {
        await _db!.into(_db!.permissions).insert(permCompanion);
      }
      else {
        permCompanion = permCompanion.copyWith(id: Value(existingPerm.id));
        await (_db!.update(_db!.permissions)..where((p) => p.id.equals(existingPerm.id))).write(permCompanion);
      }

      return entry;
    });
  }

  /// Löscht einen Eintrag mit allen zugehörigen Berechtigungen und Anhängen, ohne ein Grabstein zu setzen.
  Future<void> deleteEntryAndForget(int entryId) async {
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

  /// Löscht einen Eintrag mit allen zugehörigen Berechtigungen und Anhängen und setzt ein Grabstein.
  Future<void> deleteEntry(int entryId, {DateTime? deletedAt}) async {
    _ensureDbInitialized();
    final entry = await (_db!.select(_db!.entries)..where((e) => e.id.equals(entryId))).getSingleOrNull();
    if (entry == null) return;
    final entryUuid = entry.uuid;

    await _db!.transaction(() async {
      // 1. Alle Berechtigungen für diesen Eintrag löschen

      await (_db!.delete(_db!.permissions)..where((p) => p.entryId.equals(entryId))).go();

      // 2. Alle Anhänge (Metadaten und physische Blobs) dieses Eintrags löschen
      await (_db!.delete(_db!.attachments)..where((a) => a.entryId.equals(entryId))).go();

      // 3. Den Eintrag selbst physisch löschen
      await (_db!.delete(_db!.entries)..where((e) => e.id.equals(entryId))).go();

      // 4. Grabstein setzen (wie saveTombstone)
      var companion = TombstonesCompanion(entryUuid: Value(entryUuid), deletedAt: Value(deletedAt ?? DateTime.now().toUtc()));
      final existing = await (_db!.select(_db!.tombstones)..where((t) => t.entryUuid.equals(entryUuid))).getSingleOrNull();
      if (existing == null) {
        await _db!.into(_db!.tombstones).insert(companion);
      }
      else {
        companion = companion.copyWith(id: Value(existing.id));
        await (_db!.update(_db!.tombstones)..where((t) => t.id.equals(existing.id))).write(companion);
      }
    });
  }

  // ------------------------------------------------------------------------
  // --- Methoden bzgl. Permission ---
  // ------------------------------------------------------------------------

  /// Lädt alle Berechtigungen.
  Future<List<PermissionEntity>> getPermissions() {
    _ensureDbInitialized();
    return _db!.select(_db!.permissions).get();
  }

  /// Lädt alle Berechtigungen auf einen bestimmten Eintrag.
  Future<List<PermissionEntity>> getPermissionsByEntryId(int entryId) {
    _ensureDbInitialized();
    return (_db!.select(_db!.permissions)..where((p) => p.entryId.equals(entryId))).get();
  }

  /// Lädt alle Berechtigungen eines bestimmten Benutzers.
  Future<List<PermissionEntity>> getPermissionsByUserId(int userId) {
    _ensureDbInitialized();
    return (_db!.select(_db!.permissions)..where((p) => p.userId.equals(userId))).get();
  }

  /// Lädt alle Berechtigungen mit leeren Entry-Key eines bestimmten Benutzers.
  Future<List<PermissionEntity>> getPermissionsWithoutKeyByUserId(int userId) {
    _ensureDbInitialized();
    return (_db!.select(_db!.permissions)..where((p) => p.userId.equals(userId) & p.encryptedKey.equals(''))).get();
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
    return rows.map((row) => row.read(_db!.permissions.userId)).whereType<int>().toList();
  }

  /// Lädt eine Berechtigung anhand seiner internen ID.
  Future<PermissionEntity?> getPermission(int permissionId) {
    _ensureDbInitialized();
    return (_db!.select(_db!.permissions)..where((p) => p.id.equals(permissionId))).getSingleOrNull();
  }

  /// Lädt die Berechtigung eines Benutzers für einen Eintrag.
  Future<PermissionEntity?> getPermissionByEntryIdAndUserId(int entryId, int userId) {
    _ensureDbInitialized();
    return (_db!.select(_db!.permissions)..where((p) => p.entryId.equals(entryId) & p.userId.equals(userId))).getSingleOrNull();
  }

  /// Speichert eine neue oder aktualisierte Berechtigung.
  Future<PermissionEntity> savePermission(PermissionEntity permission) async {
    _ensureDbInitialized();

    var companion = PermissionsCompanion(
      entryId: Value(permission.entryId),
      userId: Value(permission.userId),
      encryptedKey: Value(permission.encryptedKey),
      accessLevel: Value(permission.accessLevel),
    );

    // Existierenden Datensatz suchen (id ODER (entryId UND userId))
    final existing = await (_db!.select(_db!.permissions)
      ..where((p) => p.id.equals(permission.id) | (p.entryId.equals(permission.entryId) & p.userId.equals(permission.userId))))
        .getSingleOrNull();

    // Falls nicht vorhanden → Insert
    if (existing == null) {
      final newId = await _db!.into(_db!.permissions).insert(companion);
      return permission.copyWith(id: newId);
    }

    // Falls vorhanden → Id übernehmen und Update
    companion = companion.copyWith(id: Value(existing.id));
    await (_db!.update(_db!.permissions)..where((p) => p.id.equals(existing.id))).write(companion);
    return permission.copyWith(id: existing.id);
  }

  /// Aktualisiert eine Liste von Berechtigungen.
  Future<void> updatePermissions(List<PermissionEntity> permissions) async {
    _ensureDbInitialized();
    await _db!.transaction(() async {
      for (final p in permissions) {
        final companion = PermissionsCompanion(
            encryptedKey: Value(p.encryptedKey),
            accessLevel: Value(p.accessLevel),
        );
        await (_db!.update(_db!.permissions)..where((perm) => perm.id.equals(p.id))).write(companion);
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
      //await _db!.customStatement(
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
  Future<List<TombstoneEntity>> getTombstonesSince(DateTime since) {
    _ensureDbInitialized();
    return (_db!.select(_db!.tombstones)..where((t) => t.deletedAt.isBiggerThanValue(since))).get();
  }

  // /// Speichert einen Löschmarker, um die Entfernung eines Eintrags synchronisieren zu können.
  // Future<TombstoneEntity> saveTombstone(TombstoneEntity tombstone) async {
  //   _ensureDbInitialized();
  //
  //   var companion = TombstonesCompanion(
  //       entryUuid: Value(tombstone.entryUuid),
  //       deletedAt: Value(tombstone.deletedAt),
  //   );
  //
  //   // Existierenden Datensatz suchen (id ODER entryUuid)
  //   final existing = await (_db!.select(_db!.tombstones)..where((t) => t.id.equals(tombstone.id) | t.entryUuid.equals(tombstone.entryUuid))).getSingleOrNull();
  //
  //   // Falls nicht vorhanden → Insert
  //   if (existing == null) {
  //     final newId = await _db!.into(_db!.tombstones).insert(companion);
  //     return tombstone.copyWith(id: newId);
  //   }
  //
  //   // Falls vorhanden → Id übernehmen und Update
  //   companion = companion.copyWith(id: Value(existing.id));
  //   await (_db!.update(_db!.tombstones)..where((t) => t.id.equals(existing.id))).write(companion);
  //   return tombstone.copyWith(id: existing.id);
  // }

  // /// Löscht einen Löschmarker.
  // Future<void> deleteTombstone(int tombstoneId) async {
  //   _ensureDbInitialized();
  //   await (_db!.delete(_db!.tombstones)..where((t) => t.id.equals(tombstoneId))).go();
  // }

  // ------------------------------------------------------------------------
  // --- Methoden bzgl. Attachment ---
  // ------------------------------------------------------------------------

  /// Lädt alle Anhänge eines bestimmten Eintrags.
  Future<List<AttachmentEntity>> getAttachmentsByEntryId(int entryId) {
    _ensureDbInitialized();
    return (_db!.select(_db!.attachments)..where((a) => a.entryId.equals(entryId))).get();
  }

  /// Lädt alle Anhänge, die noch nicht erfolgreich mit dem Server synchronisiert wurden.
  Future<List<AttachmentEntity>> getAttachmentsUnsynced() {
    _ensureDbInitialized();
    return (_db!.select(_db!.attachments)..where((a) => a.isSynced.equals(false))).get();
  }

  /// Lädt einen Anhang anhand seiner internen ID.
  Future<AttachmentEntity?> getAttachment(int attachmentId) {
    _ensureDbInitialized();
    return (_db!.select(_db!.attachments)..where((a) => a.id.equals(attachmentId))).getSingleOrNull();
  }

  /// Lädt einen Anhang anhand seiner UUID.
  Future<AttachmentEntity?> getAttachmentByUuid(String attachmentUuid) {
    _ensureDbInitialized();
    return (_db!.select(_db!.attachments)..where((a) => a.uuid.equals(attachmentUuid))).getSingleOrNull();
  }

  /// Speichert einen Anhang oder aktualisiert einen bestehenden.
  Future<AttachmentEntity> saveAttachment(AttachmentEntity attachment) async {
    _ensureDbInitialized();

    var companion = AttachmentsCompanion(
      uuid: Value(attachment.uuid),
      entryId: Value(attachment.entryId),
      encryptedMeta: Value(attachment.encryptedMeta),
      encryptedContent: Value(attachment.encryptedContent),
      isSynced: Value(attachment.isSynced),
    );

    // Existierenden Datensatz suchen (id ODER uuid)
    final existing = await (_db!.select(_db!.attachments)..where((a) => a.id.equals(attachment.id) | a.uuid.equals(attachment.uuid))).getSingleOrNull();

    // Falls nicht vorhanden → Insert
    if (existing == null) {
      final newId = await _db!.into(_db!.attachments).insert(companion);
      return attachment.copyWith(id: newId);
    }

    // Falls vorhanden → Id übernehmen und Update
    companion = companion.copyWith(id: Value(existing.id));
    await (_db!.update(_db!.attachments)..where((a) => a.id.equals(existing.id))).write(companion);
    return attachment.copyWith(id: existing.id);
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
  Future<SettingsEntity?> getSettings() {
    _ensureDbInitialized();
    return (_db!.select(_db!.settings)..where((s) => s.id.equals(1))).getSingleOrNull();
  }

  /// Speichert oder ersetzt die globalen Tresor-Einstellungen.
  Future<SettingsEntity> saveSettings(SettingsEntity settings) async {
    _ensureDbInitialized();

    final companion = SettingsCompanion(
      id: const Value(1),
      salt: Value(settings.salt),
      encryptedPrivateKey: Value(settings.encryptedPrivateKey),
      masterKeyTimestamp: Value(settings.masterKeyTimestamp),
      host: Value(settings.host),
      apiToken: Value(settings.apiToken),
      lastSyncAt: Value(settings.lastSyncAt),
      useBiometric: Value(settings.useBiometric),
      pwLength: Value(settings.pwLength),
      pwSpecialChars: Value(settings.pwSpecialChars),
      pwAvoidIlO0: Value(settings.pwAvoidIlO0),
      categoryPlaceholder: Value(settings.categoryPlaceholder),
    );

    await _db!.into(_db!.settings).insertOnConflictUpdate(companion);
    return settings;
  }

  /// Importiert die Daten
  ///
  /// Es wird nur hinzugefügt, nicht überschrieben. Die Einträge dürfen noch nicht existieren.
  /// Zurückgegeben wird die Anzahl der neuen Einträge.
  Future<void> import(ImportBatch items) async {
    _ensureDbInitialized();
    await _db!.transaction(() async {
      for (final item in items) {

        // 1. Eintrag speichern
        final entry = item.entry;
        final companion = EntriesCompanion(
          uuid: Value(entry.uuid),
          encryptedData: Value(entry.encryptedData),
          encryptedIndex: Value(entry.encryptedIndex),
          creatorId: Value(entry.creatorId),
          updaterId: Value(entry.updaterId),
          updatedAt: Value(entry.updatedAt),
        );
        final entryId = await _db!.into(_db!.entries).insert(companion);

        // 2. Permission speichern (mit korrekter entryId)
        final permCompanion = PermissionsCompanion(
          entryId: Value(entryId),
          userId: Value(1),
          encryptedKey: Value(item.encryptedEntryKey),
          accessLevel: Value(3), // Besitzer
        );
        await _db!.into(_db!.permissions).insert(permCompanion);

        // 3. Anhänge speichern
        for (final att in item.attachments) {
          final attCompanion = AttachmentsCompanion(
            uuid: Value(att.uuid),
            entryId: Value(entryId),
            encryptedMeta: Value(att.encryptedMeta),
            encryptedContent: Value(att.encryptedContent),
            isSynced: Value(false),
          );
          await _db!.into(_db!.attachments).insert(attCompanion);
        }
      }
    });
  }

  // ------------------------------------------------------------------------
  // --- Interne Methoden / Helper ---
  // ------------------------------------------------------------------------

  /// Konvertiert einen Byte-Array in einen Hex-String.
  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
