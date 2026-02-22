import 'dart:convert';
import 'dart:typed_data';
import 'package:privault/models/entities/entry_entity.dart';
import 'package:privault/models/entities/permission_entity.dart';
import 'package:privault/models/entities/tombstone_entity.dart';
import 'package:privault/models/entities/user_entity.dart';
import 'package:privault/models/dtos/sync_dtos.dart';
import 'package:privault/models/payloads/entry_payload.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';
import 'package:privault/services/web_service.dart';

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

  SyncService(this._cryptoService, this._databaseService, this._sessionService, this._webService);

  Future<SyncStatistics> sync() async {
    final stats = SyncStatistics();
    if (!_sessionService.isLoggedIn) return stats;

    final user = _sessionService.user!;
    final settingsMap = _sessionService.settings;
    if (settingsMap == null) return stats;

    final lastSyncAt = DateTime.tryParse(settingsMap['last_sync_at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0).toUtc();

    try {
      // 1. User auf dem Server prüfen/registrieren
      var userResponse = await _webService.findUser(_sessionService.vaultName, user.name);
      if (userResponse == null) {
        // Neu registrieren (implizit bei erstem Sync)
        userResponse = await _webService.registerUser(
          vaultName: _sessionService.vaultName,
          userName: user.name,
          userUuid: user.uuid,
          salt: settingsMap['salt'],
          publicKey: user.publicKey,
          encryptedPrivateKey: settingsMap['encrypted_private_key'],
        );
      }

      // 2. PULL: Änderungen vom Server holen
      final pullResponse = await _webService.pullSync(userResponse.userUuid, lastSyncAt);

      // 3. Deletes verarbeiten
      for (var tombstoneDto in pullResponse.deletes) {
        final entry = await _databaseService.getEntryByUuid(tombstoneDto.entryUuid);
        if (entry != null) {
          await _databaseService.saveTombstone(TombstoneEntity(
            entryUuid: tombstoneDto.entryUuid,
            deletedAt: tombstoneDto.deletedAt,
          ));
          await _databaseService.deleteEntry(entry.id!);
          stats.pullDeleted++;
        }
      }

      // 4. Updates verarbeiten
      final localUsers = await _databaseService.getUsers();
      final userUuidMap = { for (var u in localUsers) u.uuid : u.id };

      for (var entryDto in pullResponse.updates) {
        if (entryDto.accessLevel == 0) {
          // Zugriff entzogen
          final entry = await _databaseService.getEntryByUuid(entryDto.entryUuid);
          if (entry != null) await _databaseService.deleteEntry(entry.id!);
          continue;
        }

        // Metadaten für Suche entschlüsseln
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
        stats.pullUpdated++;
      }

      // 5. PUSH: Lokale Änderungen hochladen
      final localUpdates = await _databaseService.getEntriesSince(lastSyncAt);
      final localDeletes = await _databaseService.getTombstonesSince(lastSyncAt);

      if (localUpdates.isNotEmpty || localDeletes.isNotEmpty) {
        final pushUpdates = <SyncEntryDto>[];
        for (var entry in localUpdates) {
          final myPerm = await _databaseService.getPermissionByEntryAndUser(entry.id!, 1);
          if (myPerm != null && myPerm.accessLevel >= 2) {
            pushUpdates.add(SyncEntryDto(
              entryUuid: entry.uuid,
              encryptedData: entry.encryptedData,
              encryptedKey: myPerm.encryptedKey,
              accessLevel: myPerm.accessLevel,
              attachmentUuids: [], // simplified for now
              creatorUuid: user.uuid, // simplified mapping
              updaterUuid: user.uuid,
              updatedAt: entry.updatedAt,
            ));
          }
        }

        final pushDeletes = localDeletes.map((d) => SyncDeleteDto(entryUuid: d.entryUuid, deletedAt: d.deletedAt)).toList();
        
        if (pushUpdates.isNotEmpty || pushDeletes.isNotEmpty) {
          await _webService.pushSync(user.uuid, SyncPushRequest(updates: pushUpdates, deletes: pushDeletes));
          stats.pushSent = pushUpdates.length + pushDeletes.length;
        }
      }

      // 6. FINALIZE: Zeitstempel aktualisieren
      final updatedSettings = settingsMap;
      updatedSettings['last_sync_at'] = pullResponse.serverTime.toIso8601String();
      // await _databaseService.saveSettings(SettingsEntity.fromMap(updatedSettings));

      return stats;
    } catch (e) {
      rethrow;
    }
  }
}
