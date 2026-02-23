import 'dart:convert';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:privault/core/app_version.dart';
import 'package:privault/models/entities/entry_entity.dart';
import 'package:privault/models/entities/permission_entity.dart';
import 'package:privault/models/entities/tombstone_entity.dart';
import 'package:privault/models/entities/user_entity.dart';
import 'package:privault/models/entities/attachment_entity.dart';
import 'package:privault/models/dtos/sync_dtos.dart';
import 'package:privault/models/dtos/user_response.dart';
import 'package:privault/models/payloads/entry_payload.dart';
import 'package:privault/models/payloads/friend_payload.dart';
import 'package:privault/models/exceptions/salt_mismatch_exception.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';
import 'package:privault/services/web_service.dart';
import 'package:privault/services/config_service.dart';

class SyncStatistics {
  int pullAdded = 0;
  int pullUpdated = 0;
  int pullDeleted = 0;
  int pushSent = 0;

  bool get hasChanges => pullAdded > 0 || pullUpdated > 0 || pullDeleted > 0 || pushSent > 0;

  @override
  String toString() => 
    '✳️ Hinzugefügt: $pullAdded\n'
    '✏️ Aktualisiert: $pullUpdated\n'
    '❌ Gelöscht: $pullDeleted\n'
    '💾 Gesichert: $pushSent';
}

class SyncService {
  final CryptoService _cryptoService;
  final DatabaseService _databaseService;
  final SessionService _sessionService;
  final WebService _webService;
  final ConfigService _configService;

  SyncService(this._cryptoService, this._databaseService, this._sessionService, this._webService, this._configService);

  Future<SyncStatistics> sync() async {
    final stats = SyncStatistics();
    if (!_sessionService.isLoggedIn) return stats;

    var user = _sessionService.user!;
    var settingsEntity = await _databaseService.getSettings();
    if (settingsEntity == null) return stats;

    final lastSyncAt = settingsEntity.lastSyncAt;

    try {
      _webService.updateConfig(host: settingsEntity.host, apiToken: settingsEntity.apiToken);
      _webService.setSignatureData(
        userUuid: user.uuid,
        privateKey: _sessionService.privateKey!,
        publicKey: user.publicKey,
      );

      final serverVersion = await _webService.getServerVersion();
      if (serverVersion.major != AppVersion.major) {
        throw Exception("Server Version Mismatch");
      }

      var userResponse = await _webService.findUser(_sessionService.vaultName, user.name);
      if (userResponse == null) {
        userResponse = await _webService.registerUser(
          vaultName: _sessionService.vaultName,
          userName: user.name,
          userUuid: user.uuid,
          salt: settingsEntity.salt,
          publicKey: user.publicKey,
          encryptedPrivateKey: settingsEntity.encryptedPrivateKey,
        );
        user = user.copyWith(uuid: userResponse.userUuid);
        await _databaseService.saveUser(user);
      } else {
        if (userResponse.salt != settingsEntity.salt) {
          throw SaltMismatchException(userResponse);
        }
      }

      final serverUserUuid = userResponse.userUuid;
      await _pullFriends(userResponse);

      final pullResponse = await _webService.pullSync(serverUserUuid, lastSyncAt);

      // 1a. Gelöschte Einträge entfernen
      for (var tombstoneDto in pullResponse.deletes) {
        final entry = await _databaseService.getEntryByUuid(tombstoneDto.entryUuid);
        if (entry != null && entry.id != null) {
          await _databaseService.saveTombstone(TombstoneEntity(
            entryUuid: tombstoneDto.entryUuid,
            deletedAt: tombstoneDto.deletedAt,
          ));
          await _databaseService.deleteEntry(entry.id!);
          stats.pullDeleted++;
        }
      }

      // 1b. Berechtigung entzogen
      for (var entryDto in pullResponse.updates.where((u) => u.accessLevel == 0)) {
        final entry = await _databaseService.getEntryByUuid(entryDto.entryUuid);
        if (entry != null && entry.id != null) {
          await _databaseService.deleteEntry(entry.id!);
          stats.pullDeleted++;
        }
      }

      final localUsers = await _databaseService.getUsers();
      final userUuidMap = { for (var u in localUsers) u.uuid : u.id };

      // 2. Updates einspielen
      for (var entryDto in pullResponse.updates.where((u) => u.accessLevel > 0)) {
        final existing = await _databaseService.getEntryByUuid(entryDto.entryUuid);
        if (existing == null) {
          stats.pullAdded++;
        } else {
          stats.pullUpdated++;
        }

        String category = '', title = '', url = '', notes = '', favicon = '';
        if (entryDto.encryptedKey != null && _sessionService.privateKey != null) {
          try {
            final entryKey = await _cryptoService.decryptRsa(entryDto.encryptedKey!, utf8.decode(_sessionService.privateKey!));
            final decryptedData = await _cryptoService.decrypt(entryDto.encryptedData, entryKey);
            final payload = EntryPayload.fromJson(json.decode(utf8.decode(decryptedData)));
            category = payload.category; title = payload.title; url = payload.url; notes = payload.notes; favicon = payload.favicon;
          } catch (_) {}
        }

        final entity = EntryEntity(
          uuid: entryDto.entryUuid,
          category: category, title: title, url: url, notes: notes, favicon: favicon,
          encryptedData: entryDto.encryptedData,
          creatorId: userUuidMap[entryDto.creatorUuid] ?? 0,
          updaterId: userUuidMap[entryDto.updaterUuid] ?? 0,
          updatedAt: entryDto.updatedAt,
        );

        await _databaseService.saveEntryWithPermissions(entity, 1, entryDto.encryptedKey ?? '', accessLevel: entryDto.accessLevel);
        
        final savedEntry = await _databaseService.getEntryByUuid(entryDto.entryUuid);
        if (savedEntry != null && savedEntry.id != null) {
          for (var remoteFriends in entryDto.friends) {
            final friendUserId = userUuidMap[remoteFriends.userUuid];
            if (friendUserId != null) {
              await _databaseService.savePermission(PermissionEntity(
                entryId: savedEntry.id!,
                userId: friendUserId,
                encryptedKey: remoteFriends.encryptedKey ?? '',
                accessLevel: remoteFriends.accessLevel
              ));
            }
          }
        }
      }

      // 3. PUSH (Hochladen)
      final localUpdates = await _databaseService.getEntriesSince(lastSyncAt);
      final localDeletes = await _databaseService.getTombstonesSince(lastSyncAt);

      if (localUpdates.isNotEmpty || localDeletes.isNotEmpty) {
        final users2 = await _databaseService.getUsers();
        final userMap = { for (var u in users2) u.id : u.uuid };
        final pushUpdates = <SyncEntryDto>[];

        for (var entry in localUpdates) {
          final perms = await _databaseService.getPermissionsByEntryId(entry.id!);
          final myPerm = perms.where((p) => p.userId == 1).firstOrNull;
          if (myPerm == null || myPerm.accessLevel < 2) continue;

          pushUpdates.add(SyncEntryDto(
            entryUuid: entry.uuid,
            encryptedData: entry.encryptedData,
            encryptedKey: myPerm.encryptedKey,
            accessLevel: myPerm.accessLevel,
            attachmentUuids: [], 
            friends: [],
            creatorUuid: userMap[entry.creatorId] ?? '',
            updaterUuid: userMap[entry.updaterId] ?? '',
            updatedAt: entry.updatedAt,
          ));
        }

        final pushDeletes = localDeletes.map((d) => SyncDeleteDto(entryUuid: d.entryUuid, deletedAt: d.deletedAt)).toList();
        
        if (pushUpdates.isNotEmpty || pushDeletes.isNotEmpty) {
          await _webService.pushSync(serverUserUuid, SyncPushRequest(updates: pushUpdates, deletes: pushDeletes));
          stats.pushSent = pushUpdates.length + pushDeletes.length;
        }
      }

      settingsEntity = settingsEntity.copyWith(lastSyncAt: pullResponse.serverTime);
      await _databaseService.saveSettings(settingsEntity);
      await _pushFriends();

      return stats;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> adoptRemoteIdentity(String password, UserResponse userResponse) async {
    final remoteMasterKey = await _cryptoService.deriveKey(password, base64Decode(userResponse.salt));
    final remotePrivKey = await _cryptoService.decrypt(userResponse.encryptedPrivateKey, remoteMasterKey);
    await _databaseService.rekey(remoteMasterKey);

    var localUser = _sessionService.user!;
    localUser = localUser.copyWith(uuid: userResponse.userUuid, publicKey: userResponse.publicKey);
    await _databaseService.saveUser(localUser);

    var settings = await _databaseService.getSettings();
    if (settings != null) {
      settings = settings.copyWith(salt: userResponse.salt, encryptedPrivateKey: userResponse.encryptedPrivateKey);
      await _databaseService.saveSettings(settings);
    }

    _sessionService.setSession(user: localUser, privateKey: remotePrivKey, vaultName: _sessionService.vaultName, settings: _sessionService.settings);
    _cryptoService.wipeKey(remoteMasterKey);
  }

  Future<void> _pullFriends(UserResponse userResponse) async {
    final localUsers = await _databaseService.getUsers();
    final publicKeys = await _webService.getPublicKeys(userResponse.userUuid);
    final encryptedFriends = userResponse.encryptedFriends;
    if (encryptedFriends == null || encryptedFriends.isEmpty) return;

    final syncKeyMaterial = _sessionService.privateKey;
    final aesKey = _cryptoService.deriveKeyFromKey(syncKeyMaterial!, null, 'friends-list-encryption');
    final decrypted = await _cryptoService.decrypt(encryptedFriends, aesKey);
    final List<dynamic> jsonList = jsonDecode(utf8.decode(decrypted));
    final friends = jsonList.map((e) => FriendPayload.fromJson(e)).toList();

    for (var remoteFriend in friends) {
      final pkEntry = publicKeys.where((pk) => pk['user_uuid'] == remoteFriend.uuid).firstOrNull;
      final publicKey = pkEntry?['public_key'] as String?;
      if (publicKey == null) continue;

      var localMatch = localUsers.where((u) => u.uuid == remoteFriend.uuid).firstOrNull;
      if (localMatch == null) {
        await _databaseService.saveUser(UserEntity(uuid: remoteFriend.uuid, name: remoteFriend.name, publicKey: publicKey, isVerified: remoteFriend.isVerified, isHidden: remoteFriend.isHidden, updatedAt: remoteFriend.updatedAt));
      } else {
        localMatch = localMatch.copyWith(name: remoteFriend.name, publicKey: publicKey, isVerified: remoteFriend.isVerified, isHidden: remoteFriend.isHidden, updatedAt: remoteFriend.updatedAt);
        await _databaseService.saveUser(localMatch);
      }
    }
  }

  Future<void> _pushFriends() async {
    final syncKeyMaterial = _sessionService.privateKey;
    final aesKey = _cryptoService.deriveKeyFromKey(syncKeyMaterial!, null, 'friends-list-encryption');
    final users = await _databaseService.getUsers();
    final friends = users.where((u) => (u.id ?? 0) > 1).map((u) => FriendPayload(uuid: u.uuid, name: u.name, isVerified: u.isVerified, isHidden: u.isHidden, updatedAt: u.updatedAt)).toList();
    if (friends.isEmpty) return;
    final encryptedBlob = await _cryptoService.encrypt(utf8.encode(jsonEncode(friends.map((f) => f.toJson()).toList())) as Uint8List, aesKey);
    await _webService.saveFriends(_sessionService.user!.uuid, encryptedBlob);
  }
}
