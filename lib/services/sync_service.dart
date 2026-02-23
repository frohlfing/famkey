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
      // Vor jedem Sync die aktuellen Config-Daten in WebService übernehmen
      _webService.updateConfig(host: settingsEntity.host, apiToken: settingsEntity.apiToken);
      _webService.setSignatureData(
        userUuid: user.uuid,
        privateKey: _sessionService.privateKey!,
        publicKey: user.publicKey, // Für Debug-Logging
      );

      // 0. Versionsprüfung
      final serverVersion = await _webService.getServerVersion();
      if (serverVersion.major != AppVersion.major) {
        final v = AppVersion.major > 1 ? '${AppVersion.major}' : '';
        throw Exception("Die Server-Version passt nicht zur App. Korrigiere die Host-URL in den Einstellungen: https://privault$v/api.frank-rohlfing.de");
      }
      if (serverVersion.minor < AppVersion.requiredServerMinor) {
        throw Exception("Der Server ist noch nicht auf dem aktuellen Stand. Versuche es später nochmal.");
      }
      if (AppVersion.minor < serverVersion.requiredClientMinor) {
        throw Exception("Bitte aktualisiere die App und starte danach nochmal die Synchronisation.");
      }

      // 1. User auf dem Server prüfen/registrieren
      var userResponse = await _webService.findUser(_sessionService.vaultName, user.name);
      if (userResponse == null) {
        // Neu registrieren (implizit bei erstem Sync)
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
        
        // Update user uuid for signature validation now that user is registered
        _webService.setSignatureData(
          userUuid: user.uuid,
          privateKey: _sessionService.privateKey!,
          publicKey: user.publicKey,
        );
      } else {
        if (user.uuid != userResponse.userUuid) {
          user = user.copyWith(uuid: userResponse.userUuid);
          await _databaseService.saveUser(user);
          
          _webService.setSignatureData(
            userUuid: user.uuid,
            privateKey: _sessionService.privateKey!,
            publicKey: user.publicKey,
          );
        }

        if (userResponse.salt != settingsEntity.salt) {
          throw SaltMismatchException(userResponse);
        }
      }

      final serverUserUuid = userResponse.userUuid;

      // --- STEP 0: SETTINGS PULL ---
      await _pullFriends(userResponse);

      // --- STEP A: PULL (Herunterladen) ---
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

      // 1b. Fremde Einträge löschen, bei denen mir das Recht entzogen wurde
      for (var entryDto in pullResponse.updates.where((u) => u.accessLevel == 0)) {
        final entry = await _databaseService.getEntryByUuid(entryDto.entryUuid);
        if (entry != null && entry.id != null) {
          await _databaseService.deleteEntry(entry.id!);
        }
      }

      final localUsers = await _databaseService.getUsers();
      final userUuidMap = { for (var u in localUsers) u.uuid : u.id };

      // 2. Updates einspielen
      for (var entryDto in pullResponse.updates.where((u) => u.accessLevel > 0)) {
        
        final creatorId = userUuidMap[entryDto.creatorUuid] ?? 0;
        final updaterId = userUuidMap[entryDto.updaterUuid] ?? 0;

        String category = '', title = '', url = '', notes = '', favicon = '';
        if (entryDto.encryptedKey != null && _sessionService.privateKey != null) {
          try {
            final entryKey = await _cryptoService.decryptRsa(entryDto.encryptedKey!, utf8.decode(_sessionService.privateKey!));
            final decryptedData = await _cryptoService.decrypt(entryDto.encryptedData, entryKey);
            final payload = EntryPayload.fromJson(json.decode(utf8.decode(decryptedData)));
            category = payload.category; title = payload.title; url = payload.url; notes = payload.notes; favicon = payload.favicon;
          } catch (ex) {
            print('Fehler beim Extrahieren der Suchfelder für ${entryDto.entryUuid}: $ex');
          }
        }

        final entity = EntryEntity(
          uuid: entryDto.entryUuid,
          category: category, title: title, url: url, notes: notes, favicon: favicon,
          encryptedData: entryDto.encryptedData,
          creatorId: creatorId,
          updaterId: updaterId,
          updatedAt: entryDto.updatedAt,
        );

        if (await _databaseService.getEntryByUuid(entity.uuid) == null) {
          stats.pullAdded++;
        } else {
          stats.pullUpdated++;
        }

        await _databaseService.saveEntryWithPermissions(entity, 1, entryDto.encryptedKey ?? '', accessLevel: entryDto.accessLevel);
        
        final savedEntry = await _databaseService.getEntryByUuid(entryDto.entryUuid);
        if (savedEntry == null || savedEntry.id == null) continue;

        // B: Freunde verarbeiten
        for (var remoteFriends in entryDto.friends) {
          if (userUuidMap.containsKey(remoteFriends.userUuid)) {
             final friendUserId = userUuidMap[remoteFriends.userUuid];
             if (friendUserId != null) {
               final friendPerm = PermissionEntity(
                 entryId: savedEntry.id!,
                 userId: friendUserId,
                 encryptedKey: remoteFriends.encryptedKey ?? '',
                 accessLevel: remoteFriends.accessLevel
               );
               await _databaseService.savePermission(friendPerm);
             }
          }
        }

        // Anhänge verarbeiten
        final remoteAttachmentUuids = entryDto.attachmentUuids;
        final localAttachments = await _databaseService.getAttachmentsByEntryId(savedEntry.id!);
        final localMap = { for (var a in localAttachments) a.uuid : a };

        for (var attUuid in remoteAttachmentUuids) {
          if (!localMap.containsKey(attUuid)) {
            try {
              final response = await _webService.downloadAttachment(attUuid);
              final encryptedMeta = response['encrypted_meta'] as String?;
              final encryptedContent = response['encrypted_content'] as String?;
              if (encryptedMeta != null && encryptedContent != null) {
                final att = AttachmentEntity(
                  uuid: attUuid,
                  entryId: savedEntry.id!,
                  encryptedMeta: encryptedMeta,
                  encryptedContent: encryptedContent,
                  isSynced: true
                );
                await _databaseService.saveAttachment(att);
              }
            } catch (e) {
              print('Warnung: Anhang $attUuid konnte nicht geladen werden. $e');
            }
          }
        }

        final remoteUuidsSet = remoteAttachmentUuids.toSet();
        for (var l in localAttachments) {
          if (!remoteUuidsSet.contains(l.uuid) && l.id != null) {
            await _databaseService.deleteAttachment(l.id!);
          }
        }
      }

      // --- STEP B: PUSH (Hochladen) ---
      final localUpdates = await _databaseService.getEntriesSince(lastSyncAt);
      final localDeletes = await _databaseService.getTombstonesSince(lastSyncAt);
      final unsyncedAttachments = await _databaseService.getAttachmentsUnsynced();

      if (localUpdates.isNotEmpty || localDeletes.isNotEmpty || unsyncedAttachments.isNotEmpty) {
        final users2 = await _databaseService.getUsers();
        final userMap = { for (var u in users2) u.id : u.uuid };

        final pushUpdates = <SyncEntryDto>[];
        for (var entry in localUpdates) {
          if (entry.id == null) continue;
          final perms = await _databaseService.getPermissionsByEntryId(entry.id!);
          final myPerm = perms.where((p) => p.userId == 1).firstOrNull;
          
          if (myPerm == null || myPerm.accessLevel < 2) continue;

          final localAttachments = await _databaseService.getAttachmentsByEntryId(entry.id!);
          final attachmentUuids = localAttachments.map((a) => a.uuid).where((u) => u.isNotEmpty).toSet().toList();

          final friends = perms.where((p) => p.userId > 1).map((p) => FriendPermissionDto(
            userUuid: userMap[p.userId] ?? '',
            encryptedKey: p.encryptedKey.isEmpty ? null : p.encryptedKey,
            accessLevel: p.accessLevel
          )).where((p) => p.userUuid.isNotEmpty).toList();

          pushUpdates.add(SyncEntryDto(
            entryUuid: entry.uuid,
            encryptedData: entry.encryptedData,
            encryptedKey: myPerm.encryptedKey,
            accessLevel: myPerm.accessLevel,
            attachmentUuids: attachmentUuids,
            friends: friends,
            creatorUuid: userMap[entry.creatorId] ?? '',
            updaterUuid: userMap[entry.updaterId] ?? '',
            updatedAt: entry.updatedAt,
          ));
        }

        final pushDeletes = localDeletes.map((d) => SyncDeleteDto(entryUuid: d.entryUuid, deletedAt: d.deletedAt)).toList();
        
        final pushPayload = SyncPushRequest(updates: pushUpdates, deletes: pushDeletes);
        await _webService.pushSync(serverUserUuid, pushPayload);
        stats.pushSent = pushUpdates.length + pushDeletes.length;

        for (var att in unsyncedAttachments) {
          final entry = await _databaseService.getEntryById(att.entryId);
          if (entry != null) {
            await _webService.uploadAttachment(entry.uuid, att.uuid, att.encryptedMeta, att.encryptedContent);
            final updatedAtt = att.copyWith(isSynced: true);
            await _databaseService.saveAttachment(updatedAtt);
          }
        }
      }

      // --- STEP C: FINALIZE ---
      settingsEntity = settingsEntity.copyWith(lastSyncAt: pullResponse.serverTime);
      await _databaseService.saveSettings(settingsEntity);

      // --- STEP D: SETTINGS PUSH ---
      await _pushFriends();

      return stats;
    } catch (e) {
      rethrow;
    }
  }

  /// Übernimmt eine neue Identität vom Server, falls das Master-Passwort auf einem anderen Gerät geändert wurde.
  /// Führt eine Umschlüsselung der lokalen Datenbank und aller vorhandenen Berechtigungen durch.
  Future<void> adoptRemoteIdentity(String password, UserResponse userResponse) async {
    final remoteMasterKey = await _cryptoService.deriveKey(password, base64Decode(userResponse.salt));
    final currentPrivateKeyBytes = _sessionService.privateKey!;

    // 1. Private-Key des Servers entschlüsseln
    final remotePrivKey = await _cryptoService.decrypt(userResponse.encryptedPrivateKey, remoteMasterKey);

    // 2. Falls sich das RSA-Schlüsselpaar geändert hat: Alle Permissions umschlüsseln
    final rsaKeyChanged = !const ListEquality().equals(currentPrivateKeyBytes, remotePrivKey);
    if (rsaKeyChanged) {
      final allPermissions = await _databaseService.getPermissions();
      for (var perm in allPermissions) {
        if (perm.encryptedKey.isNotEmpty) {
          try {
            // Entschlüsseln mit altem (aktuellem) PrivateKey, verschlüsseln mit neuem PublicKey
            final entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, utf8.decode(currentPrivateKeyBytes));
            final newEncryptedKey = await _cryptoService.encryptRsa(entryKey, userResponse.publicKey);
            await _databaseService.savePermission(perm.copyWith(encryptedKey: newEncryptedKey));
          } catch (_) {
            // Fehler bei einem einzelnen Key ignorieren (sollte eigentlich nicht passieren)
          }
        }
      }
    }

    // 3. Datenbankdatei mit dem neuen MasterKey verschlüsseln
    await _databaseService.rekey(remoteMasterKey);

    // 4. Lokalen Benutzer und Settings aktualisieren
    var localUser = _sessionService.user!;
    localUser = localUser.copyWith(uuid: userResponse.userUuid, publicKey: userResponse.publicKey);
    await _databaseService.saveUser(localUser);

    var settings = await _databaseService.getSettings();
    if (settings != null) {
      settings = settings.copyWith(
        salt: userResponse.salt,
        encryptedPrivateKey: userResponse.encryptedPrivateKey,
      );
      await _databaseService.saveSettings(settings);
    }

    // 6. Session aktualisieren (Wichtig, damit folgende Operationen den neuen Key nutzen)
    _sessionService.setSession(
      user: localUser,
      privateKey: remotePrivKey,
      vaultName: _sessionService.vaultName,
      settings: _sessionService.settings,
    );

    _cryptoService.wipeKey(remoteMasterKey);
  }

  Future<void> _pullFriends(UserResponse userResponse) async {
    final localUsers = await _databaseService.getUsers();
    final publicKeys = await _webService.getPublicKeys(userResponse.userUuid);

    final encryptedFriends = userResponse.encryptedFriends;
    if (encryptedFriends == null || encryptedFriends.isEmpty) return;

    List<FriendPayload> friends = [];
    final syncKeyMaterial = _sessionService.privateKey;
    if (syncKeyMaterial == null) throw Exception('RSA PrivateKey nicht gefunden');

    final aesKey = _cryptoService.deriveKeyFromKey(syncKeyMaterial, null, 'friends-list-encryption');
    try {
      final decrypted = await _cryptoService.decrypt(encryptedFriends, aesKey);
      final jsonString = utf8.decode(decrypted);
      final List<dynamic> jsonList = jsonDecode(jsonString);
      friends = jsonList.map((e) => FriendPayload.fromJson(e)).toList();
    } finally {
      _cryptoService.wipeKey(aesKey);
    }

    bool needsRekeying = false;
    for (var remoteFriend in friends) {
      final pkEntry = publicKeys.where((pk) => pk['user_uuid'] == remoteFriend.uuid).firstOrNull;
      final publicKey = pkEntry?['public_key'] as String?;
      if (publicKey == null || publicKey.isEmpty) continue;

      var localMatch = localUsers.where((u) => u.uuid == remoteFriend.uuid).firstOrNull;
      if (localMatch == null) {
        final newUser = UserEntity(
          uuid: remoteFriend.uuid,
          name: remoteFriend.name,
          publicKey: publicKey,
          isVerified: remoteFriend.isVerified,
          isHidden: remoteFriend.isHidden,
          updatedAt: remoteFriend.updatedAt,
        );
        await _databaseService.saveUser(newUser);
      } else {
        if (localMatch.publicKey != publicKey) {
          if (localMatch.id != null) {
            await _databaseService.removeEntryKeysForUser(localMatch.id!);
          }
          localMatch = localMatch.copyWith(
            publicKey: publicKey,
            isVerified: false,
            updatedAt: DateTime.now().toUtc()
          );
          await _databaseService.saveUser(localMatch);

          if (!needsRekeying && localMatch.id != null) {
            if (await _databaseService.hasAccessWithoutKey(localMatch.id!)) {
              needsRekeying = true;
            }
          }
        }

        if (remoteFriend.updatedAt.isAfter(localMatch.updatedAt)) {
          localMatch = localMatch.copyWith(
            name: remoteFriend.name,
            isHidden: remoteFriend.isHidden,
            isVerified: remoteFriend.isVerified,
            updatedAt: remoteFriend.updatedAt
          );
          await _databaseService.saveUser(localMatch);
        }
      }
    }

    for (var localFriend in localUsers.where((u) => (u.id ?? 0) > 1)) {
      if (!publicKeys.any((pk) => pk['user_uuid'] == localFriend.uuid)) {
        if (localFriend.id != null) {
          await _databaseService.deleteUser(localFriend.id!);
        }
      }
    }

    if (needsRekeying) {
      throw Exception('Sicherheitsstopp: Die Identität eines Freundes hat sich geändert. Bitte verifiziere den neuen Fingerprint in den Einstellungen, bevor du synchronisierst.');
    }
  }

  Future<void> _pushFriends() async {
    final localUser = _sessionService.user!;
    
    final syncKeyMaterial = _sessionService.privateKey;
    if (syncKeyMaterial == null) throw Exception('RSA PrivateKey nicht gefunden');

    final aesKey = _cryptoService.deriveKeyFromKey(syncKeyMaterial, null, 'friends-list-encryption');
    try {
      final users = await _databaseService.getUsers();
      final friends = users.where((u) => (u.id ?? 0) > 1).map((u) => FriendPayload(
        uuid: u.uuid,
        name: u.name,
        isVerified: u.isVerified,
        isHidden: u.isHidden,
        updatedAt: u.updatedAt
      )).toList();

      if (friends.isEmpty) return;

      final jsonString = jsonEncode(friends.map((f) => f.toJson()).toList());
      final plainBytes = utf8.encode(jsonString) as Uint8List;
      final encryptedBlob = await _cryptoService.encrypt(plainBytes, aesKey);

      await _webService.saveFriends(localUser.uuid, encryptedBlob);
    } finally {
      _cryptoService.wipeKey(aesKey);
    }
  }

}
