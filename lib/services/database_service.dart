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

/// Dienst für die Interaktion mit der lokalen SQLCipher-Datenbank.
/// Beinhaltet grundlegende CRUD-Operationen und Transaktionen für komplexe Vorgänge.
class DatabaseService {
  final ConfigService _configService;
  AppDatabase? _db;
  String? _currentDbPath;

  /// Initialisiert eine neue Instanz des [DatabaseService].
  DatabaseService(this._configService);

  bool get isInitialized => _db != null;

  /// Baut die Verbindung zur Datenbank auf.
  Future<void> initialize(String vaultName, String password) async {
    if (_db != null) return; // Bereits verbunden

    // 1. Pfad bestimmen
    _currentDbPath = getDatabasePath(vaultName);

    _db = AppDatabase(vaultName, password);
  }

  /// Erstellt einen sicheren Dateipfad basierend auf dem Tresornamen.
  /// Bereinigt den Namen von ungültigen Dateisystemzeichen.
  String getDatabasePath(String vaultName) {
    final storagePath = _configService.vaultStoragePath;

    // Bereinigung: Alle Zeichen außer Buchstaben, Zahlen, Unterstrichen und Bindestrichen durch '_' ersetzen.
    // Das entspricht der MAUI-Logik (InvalidFileNameChars).
    final safeName = vaultName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();

    return p.join(storagePath, '$safeName.db3');
  }

  // ------------------------------------------------------------------------
  // --- Datenbankdatei / System ---
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

  /// Schließt die aktuelle Datenbankverbindung.
  Future<void> close() async {
    if (_db != null) {
      await _db?.close();
      _db = null;
    }
  }

  /// Prüft, ob eine Datenbankdatei für den angegebenen Tresornamen bereits existiert.
  Future<bool> databaseExists(String vaultName) async {
    final path = getDatabasePath(vaultName);
    return await File(path).exists();
  }

  /// Erstellt eine Sicherheitskopie der aktuellen Datenbankdatei.
  /// Wird z.B. vor kritischen Operationen wie `rekey` aufgerufen.
  Future<void> createBackup() async {
    if (_currentDbPath == null || _currentDbPath!.isEmpty) return;
    final file = File(_currentDbPath!);
    if (await file.exists()) {
      await file.copy('$_currentDbPath.bak');
    }
  }

  /// Entfernt eine zuvor erstellte Sicherheitskopie (bei erfolgreicher Operation).
  Future<void> removeBackup() async {
    if (_currentDbPath == null || _currentDbPath!.isEmpty) return;
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
  Future<void> restoreBackup() async {
    if (_currentDbPath == null || _currentDbPath!.isEmpty) return;
    final backupPath = '$_currentDbPath.bak';
    final backupFile = File(backupPath);
    if (await backupFile.exists()) {
      await backupFile.copy(_currentDbPath!);
      try {
        await backupFile.delete();
      } catch (_) {
        debugPrint("Backup-File konnte kopiert, aber nicht gelöscht werden.");
      }
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
    final path = _currentDbPath;
    await close();

    if (path != null) {
      final dbFile = File(path);
      if (await dbFile.exists()) await dbFile.delete();

      final saltFile = File('$path.salt');
      if (await saltFile.exists()) await saltFile.delete();
    }
  }

  /// Ändert das Verschlüsselungspasswort (bzw. den Key) der Datenbankdatei.
  Future<void> rekey(Uint8List newMasterKey) async {
    if (_db == null) return;
    final hexKey = newMasterKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _db!.customStatement("PRAGMA hexrekey = '$hexKey';");
  }

  // ------------------------------------------------------------------------
  // --- User Operations ---
  // ------------------------------------------------------------------------

  Future<UserEntity?> getUserById(int id) async {
    if (_db == null) return null;
    final query = _db!.select(_db!.users)..where((u) => u.id.equals(id));
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

  Future<UserEntity?> getUserByUuid(String uuid) async {
    if (_db == null) return null;
    final row = await (_db!.select(_db!.users)..where((u) => u.uuid.equals(uuid))).getSingleOrNull();
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

  Future<List<UserEntity>> getUsers() async {
    if (_db == null) return [];
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

  Future<void> saveUser(UserEntity entity) async {
    if (_db == null) return;
    final companion = UsersCompanion(
      uuid: Value(entity.uuid),
      name: Value(entity.name),
      publicKey: Value(entity.publicKey),
      isVerified: Value(entity.isVerified),
      isHidden: Value(entity.isHidden),
      updatedAt: Value(entity.updatedAt),
    );

    if (entity.id != null) {
      await (_db!.update(_db!.users)..where((u) => u.id.equals(entity.id!))).write(companion);
    } else {
      await _db!.into(_db!.users).insert(companion);
    }
  }

  /// Löscht einen Benutzer und alle damit verbundenen Daten (Einträge, Permissions, Anhänge).
  Future<void> deleteUser(int id) async {
    if (_db == null) return;
    await _db!.transaction(() async {
      // 1. Lösche alle Permissions, die der Benutzer selbst hat
      await (_db!.delete(_db!.permissions)..where((p) => p.userId.equals(id))).go();

      // 2. Lösche ALLE Permissions für ALLE Einträge, die dieser Benutzer erstellt hat
      // (Wenn der Besitzer gelöscht wird, haben auch Freunde keinen Zugriff mehr)
      await _db!.customStatement("DELETE FROM permissions WHERE entry_id IN (SELECT id FROM entries WHERE creator_id = ?)", [id]);

      // 3. Lösche alle Anhänge von Einträgen, die dieser Benutzer erstellt hat
      await _db!.customStatement("DELETE FROM attachments WHERE entry_id IN (SELECT id FROM entries WHERE creator_id = ?)", [id]);

      // 4. Lösche die Einträge des Benutzers
      await (_db!.delete(_db!.entries)..where((e) => e.creatorId.equals(id))).go();

      // 5. UpdaterId bei verbliebenen Einträgen nullen
      await _db!.customStatement("UPDATE entries SET updater_id = 0 WHERE updater_id = ?", [id]);

      // 6. Den Benutzer selbst löschen
      await (_db!.delete(_db!.users)..where((u) => u.id.equals(id))).go();
    });
  }

  /// Verbirgt einen Benutzer und entwertet seine Schlüssel (Vertrauensentzug).
  Future<void> hideUser(int userId) async {
    if (_db == null) return;
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
        [now.toIso8601String(), userId],
      );

      // 3. Benutzer-Status aktualisieren
      await _db!.customStatement(
        """
          UPDATE users 
          SET is_verified = 0, is_hidden = 1, updated_at = ? 
          WHERE id = ?
      """,
        [now.toIso8601String(), userId],
      );
    });
  }

  /// Löscht alle Entry-Keys eines Benutzers (z.B. bei Identitätswechsel).
  Future<void> removeEntryKeysForUser(int userId) async {
    if (_db == null) return;
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
        [now.toIso8601String(), userId],
      );
    });
  }

  /// Prüft, ob ein Benutzer Zugriff auf Einträge hat, aber sein Schlüssel fehlt.
  Future<bool> hasAccessWithoutKey(int userId) async {
    if (_db == null) return false;
    final countExp = _db!.permissions.id.count();
    final query = _db!.selectOnly(_db!.permissions)
      ..addColumns([countExp])
      ..where(_db!.permissions.userId.equals(userId) & _db!.permissions.encryptedKey.equals(''));
    final result = await query.map((row) => row.read(countExp)).getSingle();
    return (result ?? 0) > 0;
  }

  // ------------------------------------------------------------------------
  // --- Entry Operations ---
  // ------------------------------------------------------------------------

  Future<List<EntryEntity>> getAllEntries() async {
    if (_db == null) return [];
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

  Future<EntryEntity?> getEntryById(int id) async {
    if (_db == null) return null;
    final row = await (_db!.select(_db!.entries)..where((e) => e.id.equals(id))).getSingleOrNull();
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

  Future<EntryEntity?> getEntryByUuid(String uuid) async {
    if (_db == null) return null;
    final row = await (_db!.select(_db!.entries)..where((e) => e.uuid.equals(uuid))).getSingleOrNull();
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

  Future<List<EntryEntity>> getEntriesSince(DateTime since) async {
    if (_db == null) return [];
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

  Future<void> saveEntry(EntryEntity entity) async {
    if (_db == null) return;
    final companion = _entryToCompanion(entity);

    if (entity.id != null) {
      await (_db!.update(_db!.entries)..where((e) => e.id.equals(entity.id!))).write(companion);
    } else {
      await _db!.into(_db!.entries).insert(companion);
    }
  }

  /// Löscht einen Eintrag mit allen zugehörigen Berechtigungen und Anhängen.
  Future<void> deleteEntry(int id) async {
    if (_db == null) return;
    await _db!.transaction(() async {
      // 1. Alle Berechtigungen für diesen Eintrag löschen
      await (_db!.delete(_db!.permissions)..where((p) => p.entryId.equals(id))).go();

      // 2. Alle Anhänge (Metadaten und physische Blobs) dieses Eintrags löschen
      await (_db!.delete(_db!.attachments)..where((a) => a.entryId.equals(id))).go();

      // 3. Den Eintrag selbst physisch löschen
      await (_db!.delete(_db!.entries)..where((e) => e.id.equals(id))).go();
    });
  }

  // --- Combined Operation (Matching MAUI logic) ---

  /// Speichert einen Eintrag zusammen mit einer initialen Berechtigung in einer Transaktion.
  Future<int> saveEntryWithPermissions(EntryEntity entry, int userId, String encryptedKey, {int accessLevel = 3}) async {
    if (_db == null) throw Exception("Datenbank nicht initialisiert");

    return await _db!.transaction(() async {
      int actualEntryId;
      final entryCompanion = _entryToCompanion(entry);

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

  // ------------------------------------------------------------------------
  // --- Attachment Operations ---
  // ------------------------------------------------------------------------

  Future<List<AttachmentEntity>> getAttachmentsByEntryId(int entryId) async {
    if (_db == null) return [];
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

  Future<List<AttachmentEntity>> getAttachmentsUnsynced() async {
    if (_db == null) return [];
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

  Future<void> saveAttachment(AttachmentEntity entity) async {
    if (_db == null) return;
    final companion = AttachmentsCompanion(
      uuid: Value(entity.uuid),
      entryId: Value(entity.entryId),
      encryptedMeta: Value(entity.encryptedMeta),
      encryptedContent: Value(entity.encryptedContent),
      isSynced: Value(entity.isSynced),
    );

    if (entity.id != null) {
      await (_db!.update(_db!.attachments)..where((a) => a.id.equals(entity.id!))).write(companion);
    } else {
      await _db!.into(_db!.attachments).insert(companion);
    }
  }

  Future<void> deleteAttachment(int id) async {
    if (_db == null) return;
    await (_db!.delete(_db!.attachments)..where((a) => a.id.equals(id))).go();
  }

  // ------------------------------------------------------------------------
  // --- Permission Operations ---
  // ------------------------------------------------------------------------

  Future<List<PermissionEntity>> getPermissionsByEntryId(int entryId) async {
    if (_db == null) return [];
    final list = await (_db!.select(_db!.permissions)..where((p) => p.entryId.equals(entryId))).get();
    return list
        .map(
          (p) => PermissionEntity(id: p.id, entryId: p.entryId, userId: p.userId, encryptedKey: p.encryptedKey, accessLevel: p.accessLevel),
        )
        .toList();
  }

  Future<List<PermissionEntity>> getPermissions() async {
    if (_db == null) return [];
    final list = await _db!.select(_db!.permissions).get();
    return list
        .map(
          (p) => PermissionEntity(id: p.id, entryId: p.entryId, userId: p.userId, encryptedKey: p.encryptedKey, accessLevel: p.accessLevel),
        )
        .toList();
  }

  Future<PermissionEntity?> getPermissionByEntryAndUser(int entryId, int userId) async {
    if (_db == null) return null;
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

  Future<void> savePermission(PermissionEntity entity) async {
    if (_db == null) return;
    final companion = PermissionsCompanion(
      entryId: Value(entity.entryId),
      userId: Value(entity.userId),
      encryptedKey: Value(entity.encryptedKey),
      accessLevel: Value(entity.accessLevel),
    );

    if (entity.id != null) {
      await (_db!.update(_db!.permissions)..where((p) => p.id.equals(entity.id!))).write(companion);
    } else {
      await _db!.into(_db!.permissions).insert(companion);
    }
  }

  Future<void> updatePermissions(List<PermissionEntity> permissions) async {
    if (_db == null) return;
    await _db!.transaction(() async {
      for (final p in permissions) {
        final companion = PermissionsCompanion(encryptedKey: Value(p.encryptedKey), accessLevel: Value(p.accessLevel));
        if (p.id != null) {
          await (_db!.update(_db!.permissions)..where((perm) => perm.id.equals(p.id!))).write(companion);
        }
      }
    });
  }

  // ------------------------------------------------------------------------
  // --- Tombstone Operations ---
  // ------------------------------------------------------------------------

  Future<List<TombstoneEntity>> getTombstonesSince(DateTime since) async {
    if (_db == null) return [];
    final list = await (_db!.select(_db!.tombstones)..where((t) => t.deletedAt.isBiggerThanValue(since))).get();
    return list.map((t) => TombstoneEntity(id: t.id, entryUuid: t.entryUuid, deletedAt: t.deletedAt)).toList();
  }

  Future<void> saveTombstone(TombstoneEntity t) async {
    if (_db == null) return;
    await _db!
        .into(_db!.tombstones)
        .insertOnConflictUpdate(TombstonesCompanion(entryUuid: Value(t.entryUuid), deletedAt: Value(t.deletedAt)));
  }

  // ------------------------------------------------------------------------
  // --- Settings Operations ---
  // ------------------------------------------------------------------------

  Future<SettingsEntity?> getSettings() async {
    if (_db == null) return null;
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

  Future<void> saveSettings(SettingsEntity s) async {
    if (_db == null) return;
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

  // Helper
  EntriesCompanion _entryToCompanion(EntryEntity entity) {
    return EntriesCompanion(
      uuid: Value(entity.uuid),
      category: Value(entity.category),
      title: Value(entity.title),
      url: Value(entity.url),
      notes: Value(entity.notes),
      favicon: Value(entity.favicon),
      encryptedData: Value(entity.encryptedData),
      creatorId: Value(entity.creatorId),
      updaterId: Value(entity.updaterId),
      updatedAt: Value(entity.updatedAt),
    );
  }
}

// ------------------------------------------------------------------------
// --- Private Methoden ---
// ------------------------------------------------------------------------
