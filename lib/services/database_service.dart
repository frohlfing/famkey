import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:privault/database/database.dart';
import 'package:privault/models/entities/user_entity.dart';
import 'package:privault/models/entities/entry_entity.dart';
import 'package:privault/models/entities/settings_entity.dart';
import 'package:privault/models/entities/permission_entity.dart';
import 'package:privault/models/entities/tombstone_entity.dart';
import 'package:privault/models/entities/attachment_entity.dart';

class DatabaseService {
  AppDatabase? _db;
  String? _currentDbPath;

  bool get isInitialized => _db != null;

  Future<void> initialize(String vaultName, String password) async {
    if (_db != null) return;
    
    final dbFolder = await getApplicationDocumentsDirectory();
    _currentDbPath = p.join(dbFolder.path, '$vaultName.db3');
    
    _db = AppDatabase(vaultName, password);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> deleteCurrentDatabase() async {
    final path = _currentDbPath;
    await close();
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  // --- User Operations ---

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
    return list.map((u) => UserEntity(
      id: u.id,
      uuid: u.uuid,
      name: u.name,
      publicKey: u.publicKey,
      isVerified: u.isVerified,
      isHidden: u.isHidden,
      updatedAt: u.updatedAt,
    )).toList();
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

  // --- Entry Operations ---

  Future<List<EntryEntity>> getAllEntries() async {
    if (_db == null) return [];
    final list = await _db!.select(_db!.entries).get();
    return list.map((e) => EntryEntity(
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
    )).toList();
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
    return list.map((e) => EntryEntity(
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
    )).toList();
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

  Future<void> deleteEntry(int id) async {
    if (_db == null) return;
    await _db!.transaction(() async {
      await (_db!.delete(_db!.attachments)..where((a) => a.entryId.equals(id))).go();
      await (_db!.delete(_db!.permissions)..where((p) => p.entryId.equals(id))).go();
      await (_db!.delete(_db!.entries)..where((e) => e.id.equals(id))).go();
    });
  }

  // --- Attachment Operations ---

  Future<List<AttachmentEntity>> getAttachmentsByEntryId(int entryId) async {
    if (_db == null) return [];
    final list = await (_db!.select(_db!.attachments)..where((a) => a.entryId.equals(entryId))).get();
    return list.map((a) => AttachmentEntity(
      id: a.id,
      uuid: a.uuid,
      entryId: a.entryId,
      encryptedMeta: a.encryptedMeta,
      encryptedContent: a.encryptedContent,
      isSynced: a.isSynced,
    )).toList();
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

  // --- Combined Operation (Matching MAUI logic) ---

  Future<void> saveEntryWithPermissions(EntryEntity entry, int userId, String encryptedKey, {int accessLevel = 3}) async {
    if (_db == null) return;

    await _db!.transaction(() async {
      int actualEntryId;
      final entryCompanion = _entryToCompanion(entry);
      
      final existing = await (_db!.select(_db!.entries)..where((e) => e.uuid.equals(entry.uuid))).getSingleOrNull();
      if (existing != null) {
        await (_db!.update(_db!.entries)..where((e) => e.uuid.equals(entry.uuid))).write(entryCompanion);
        actualEntryId = existing.id;
      } else {
        actualEntryId = await _db!.into(_db!.entries).insert(entryCompanion);
      }

      final permCompanion = PermissionsCompanion(
        entryId: Value(actualEntryId),
        userId: Value(userId),
        encryptedKey: Value(encryptedKey),
        accessLevel: Value(accessLevel),
      );

      await _db!.into(_db!.permissions).insertOnConflictUpdate(permCompanion);
    });
  }

  // --- Permission Operations ---

  Future<List<PermissionEntity>> getPermissionsByEntryId(int entryId) async {
    if (_db == null) return [];
    final list = await (_db!.select(_db!.permissions)..where((p) => p.entryId.equals(entryId))).get();
    return list.map((p) => PermissionEntity(
      id: p.id,
      entryId: p.entryId,
      userId: p.userId,
      encryptedKey: p.encryptedKey,
      accessLevel: p.accessLevel,
    )).toList();
  }

  Future<PermissionEntity?> getPermissionByEntryAndUser(int entryId, int userId) async {
    if (_db == null) return null;
    final row = await (_db!.select(_db!.permissions)
      ..where((p) => p.entryId.equals(entryId) & p.userId.equals(userId)))
      .getSingleOrNull();
    
    if (row == null) return null;
    return PermissionEntity(
      id: row.id,
      entryId: row.entryId,
      userId: row.userId,
      encryptedKey: row.encryptedKey,
      accessLevel: row.accessLevel,
    );
  }

  // --- Tombstone Operations ---

  Future<List<TombstoneEntity>> getTombstonesSince(DateTime since) async {
    if (_db == null) return [];
    final list = await (_db!.select(_db!.tombstones)..where((t) => t.deletedAt.isBiggerThanValue(since))).get();
    return list.map((t) => TombstoneEntity(
      id: t.id,
      entryUuid: t.entryUuid,
      deletedAt: t.deletedAt,
    )).toList();
  }

  Future<void> saveTombstone(TombstoneEntity t) async {
    if (_db == null) return;
    await _db!.into(_db!.tombstones).insertOnConflictUpdate(TombstonesCompanion(
      entryUuid: Value(t.entryUuid),
      deletedAt: Value(t.deletedAt),
    ));
  }

  // --- Settings Operations ---

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
