import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart'; // Hinzugefügt für debugPrint
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

/// Repräsentiert die Zusammenfassung eines Synchronisationsvorgangs.
/// Enthält Zähler für heruntergeladene und hochgeladene Änderungen zur Benutzerinformation.
class SyncStatistics {
  /// Anzahl der vom Server neu hinzugefügten Einträge.
  int pullAdded = 0;

  /// Anzahl der vom Server aktualisierten Einträge.
  int pullUpdated = 0;

  /// Anzahl der lokal gelöschten Einträge aufgrund von Server-Tombstones.
  int pullDeleted = 0;

  /// Anzahl der erfolgreich zum Server übertragenen Änderungen (Updates und Deletes).
  int pushSent = 0;

  /// Gibt an, ob während des Sync-Vorgangs überhaupt Daten bewegt wurden.
  bool get hasChanges => pullAdded > 0 || pullUpdated > 0 || pullDeleted > 0 || pushSent > 0;

  /// Erzeugt eine benutzerfreundliche Zusammenfassung der Statistik.
  @override
  String toString() =>
      '✳️ Hinzugefügt: $pullAdded\n'
      '✏️ Aktualisiert: $pullUpdated\n'
      '❌ Gelöscht: $pullDeleted\n'
      '💾 Gesichert: $pushSent';
}

/// Dienst für die Synchronisation zwischen der lokalen SQLite-Datenbank und dem Remote-Server.
/// Beinhaltet Pull (Herunterladen), Push (Hochladen) und Konfliktauflösung (Adoption).
class SyncService {
  final CryptoService _cryptoService;
  final DatabaseService _databaseService;
  final SessionService _sessionService;
  final WebService _webService;

  /// Initialisiert eine neue Instanz des [SyncService] und injiziert die benötigten Dienste.
  SyncService(this._cryptoService, this._databaseService, this._sessionService, this._webService);

  /// Führt die vollständige Synchronisation durch.
  ///
  /// Ablauf:
  /// 1. Versionsprüfung
  /// 2. Benutzer validieren / Registrieren
  /// 3. STEP 0: Freunde synchronisieren (Settings Pull)
  /// 4. STEP A: Pull (Tombstones, Rechteentzug, neue/aktualisierte Einträge, Anhänge)
  /// 5. STEP B: Push (lokale Änderungen hochladen, nur wenn Schreibrecht Level >= 2 besteht)
  /// 6. STEP C: Finalize (Timestamps setzen)
  /// 7. STEP D: Freunde hochladen (Settings Push)
  Future<SyncStatistics> sync() async {
    final stats = SyncStatistics();
    if (!_sessionService.isLoggedIn) return stats;

    var user = _sessionService.user!;
    var settingsEntity = await _databaseService.getSettings();
    if (settingsEntity == null) return stats;

    final lastSyncAt = settingsEntity.lastSyncAt;

    try {
      // API-Konfiguration für die aktuelle Sitzung aktualisieren
      _webService.updateConfig(host: settingsEntity.host, apiToken: settingsEntity.apiToken);
      _webService.setSignatureData(userUuid: user.uuid, privateKey: _sessionService.privateKey!, publicKey: user.publicKey);

      // Versionsprüfung
      final serverVersion = await _webService.getServerVersion();
      if (serverVersion.major != AppVersion.major) {
        final v = AppVersion.major > 1 ? '${AppVersion.major}' : '';
        throw Exception(
          "Die Server-Version passt nicht zur App. Korrigiere die Host-URL in den Einstellungen: https://privault$v/api.frank-rohlfing.de",
        );
      }
      if (serverVersion.minor < AppVersion.requiredServerMinor) {
        throw Exception("Der Server ist noch nicht auf dem aktuellen Stand. Versuche es später nochmal.");
      }
      if (AppVersion.minor < serverVersion.requiredClientMinor) {
        throw Exception("Bitte aktualisiere die App und starte danach nochmal die Synchronisation.");
      }

      // 1. Prüfen: Gibt es mich auf dem Server?
      var userResponse = await _webService.findUser(_sessionService.vaultName, user.name);
      if (userResponse == null) {
        // FALL A: User (und evtl. Tresor) existieren noch nicht.
        // -> Wir legen beides implizit an!

        // Sicherstellen, dass der API-Token in den Einstellungen eingetragen ist
        if (settingsEntity.apiToken.isEmpty) {
          throw Exception("Kein API-Token hinterlegt. Kann Tresor nicht anlegen.");
        }

        // Benutzer registrieren
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
        // FALL B: User existiert
        if (user.uuid != userResponse.userUuid) {
          user = user.copyWith(uuid: userResponse.userUuid);
          await _databaseService.saveUser(user);
        }

        // Sicherheitscheck!
        // Ist das Salt auf dem Server identisch zu meinem lokalen?
        // Wenn nicht, hat jemand anderes (oder ich am PC) das Passwort geändert (Notfall-Reset),
        // oder ich synchronisiere ein Zweitgerät das erst mal.
        if (userResponse.salt != settingsEntity.salt) {
          throw SaltMismatchException(userResponse);
        }
      }

      final serverUserUuid = userResponse.userUuid;

      // --- STEP 0: SETTINGS PULL ---
      // Zuerst Freunde synchronisieren, damit Pull-Entries zugeordnet werden können.
      await _pullFriends(userResponse);

      // --- STEP A: PULL (Herunterladen) ---
      final pullResponse = await _webService.pullSync(serverUserUuid, lastSyncAt);

      // 1a. Gelöschte Einträge entfernen (Tombstones anwenden)
      for (var tombstoneDto in pullResponse.deletes) {
        final entry = await _databaseService.getEntryByUuid(tombstoneDto.entryUuid);
        if (entry != null && entry.id != null) {
          await _databaseService.saveTombstone(TombstoneEntity(entryUuid: tombstoneDto.entryUuid, deletedAt: tombstoneDto.deletedAt));
          await _databaseService.deleteEntry(entry.id!);
          stats.pullDeleted++;
        }
      }

      // 1b. Fremde Einträge löschen, bei denen mir das Recht entzogen wurde (AccessLevel == 0)
      for (var entryDto in pullResponse.updates.where((u) => u.accessLevel == 0)) {
        final entry = await _databaseService.getEntryByUuid(entryDto.entryUuid);
        if (entry != null && entry.id != null) {
          // Hier kein lokaler Tombstone, da der Eintrag im Tresor ja noch existiert (nur für mich unsichtbar).
          await _databaseService.deleteEntry(entry.id!);
          stats.pullDeleted++;
        }
      }

      // Vorbereitung: Alle lokalen User laden, um UUIDs in IDs aufzulösen
      final localUsers = await _databaseService.getUsers();
      final userUuidMap = {for (var u in localUsers) u.uuid: u.id};

      // 2. Updates einspielen
      for (var entryDto in pullResponse.updates.where((u) => u.accessLevel > 0)) {
        final existing = await _databaseService.getEntryByUuid(entryDto.entryUuid);
        if (existing == null) {
          stats.pullAdded++;
        } else {
          stats.pullUpdated++;
        }

        // Suchfelder aus dem verschlüsselten Payload extrahieren
        String category = '', title = '', url = '', notes = '', favicon = '';
        if (entryDto.encryptedKey != null && _sessionService.privateKey != null) {
          try {
            // Wir brauchen den EntryKey (AES), um an die Suchfelder zu kommen
            final entryKey = await _cryptoService.decryptRsa(entryDto.encryptedKey!, utf8.decode(_sessionService.privateKey!));
            final decryptedData = await _cryptoService.decrypt(entryDto.encryptedData, entryKey);
            final payload = EntryPayload.fromJson(json.decode(utf8.decode(decryptedData)));
            category = payload.category;
            title = payload.title;
            url = payload.url;
            notes = payload.notes;
            favicon = payload.favicon;
          } catch (e) {
            debugPrint("Fehler beim Extrahieren der Suchfelder für ${entryDto.entryUuid}: $e");
          }
        }

        // UUIDs der Benutzer in interne IDs aufzulösen (0 falls User lokal noch unbekannt)
        final entity = EntryEntity(
          uuid: entryDto.entryUuid,
          category: category,
          title: title,
          url: url,
          notes: notes,
          favicon: favicon,
          encryptedData: entryDto.encryptedData,
          creatorId: userUuidMap[entryDto.creatorUuid] ?? 0,
          updaterId: userUuidMap[entryDto.updaterUuid] ?? 0,
          updatedAt: entryDto.updatedAt,
        );

        // A: Eintrag & Eigene Permission (UserId 1) speichern
        await _databaseService.saveEntryWithPermissions(entity, 1, entryDto.encryptedKey ?? '', accessLevel: entryDto.accessLevel);

        final savedEntry = await _databaseService.getEntryByUuid(entryDto.entryUuid);
        if (savedEntry != null && savedEntry.id != null) {
          // B: Freunde verarbeiten
          for (var remoteFriends in entryDto.friends) {
            // Wir speichern die Permission nur, wenn wir den User lokal kennen (aus dem Settings-Pull)
            final friendUserId = userUuidMap[remoteFriends.userUuid];
            if (friendUserId != null) {
              await _databaseService.savePermission(
                PermissionEntity(
                  entryId: savedEntry.id!,
                  userId: friendUserId,
                  encryptedKey: remoteFriends.encryptedKey ?? '',
                  accessLevel: remoteFriends.accessLevel,
                ),
              );
            }
          }

          // Anhänge verarbeiten
          final remoteAttachmentUuids = entryDto.attachmentUuids;
          final localAttachments = await _databaseService.getAttachmentsByEntryId(savedEntry.id!);
          final localMap = {for (var a in localAttachments) a.uuid: a};

          for (var attUuid in remoteAttachmentUuids) {
            if (!localMap.containsKey(attUuid)) {
              // Hier laden wir nun das vollständige DTO mit Meta & Content
              try {
                final attResponse = await _webService.downloadAttachment(attUuid);

                // Typsichere Extraktion aus der Map
                final attachmentUuid = attResponse['attachment_uuid'] as String?;
                final encryptedContent = attResponse['encrypted_content'] as String?;
                final encryptedMeta = attResponse['encrypted_meta'] as String?;

                if (encryptedContent == null || encryptedContent.isEmpty) {
                  debugPrint("Warnung: Anhang $attUuid konnte nicht geladen werden.");
                  continue;
                }
                final att = AttachmentEntity(
                  uuid: attachmentUuid ?? attUuid,
                  entryId: savedEntry.id!,
                  encryptedMeta: encryptedMeta ?? '',
                  encryptedContent: encryptedContent,
                  isSynced: true,
                );
                await _databaseService.saveAttachment(att);
              } catch (e) {
                debugPrint("Fehler beim Download des Anhangs $attUuid: $e");
              }
            }
          }

          // Lokale Anhänge löschen, die auf dem Server nicht mehr existieren
          final remoteUuidsSet = remoteAttachmentUuids.toSet();
          for (var l in localAttachments) {
            if (!remoteUuidsSet.contains(l.uuid)) {
              await _databaseService.deleteAttachment(l.id!);
            }
          }
        }
      }

      // --- STEP B: PUSH (Hochladen) ---
      final localUpdates = await _databaseService.getEntriesSince(lastSyncAt);
      final localDeletes = await _databaseService.getTombstonesSince(lastSyncAt);

      // Zusätzlich unsynced Attachments ermitteln
      final unsyncedAttachments = await _databaseService.getAttachmentsUnsynced();

      if (localUpdates.isNotEmpty || localDeletes.isNotEmpty || unsyncedAttachments.isNotEmpty) {
        // Vorbereitung: UUID Map laden, um IDs aufzulösen
        final users2 = await _databaseService.getUsers();
        final userMap = {for (var u in users2) u.id: u.uuid};

        // Neue oder veränderte Einträge ermitteln
        final pushUpdates = <SyncEntryDto>[];

        for (var entry in localUpdates) {
          // Alle Berechtigungen für diesen Eintrag laden
          final perms = await _databaseService.getPermissionsByEntryId(entry.id!);

          // Meine eigene Permission (ID 1) holen
          final myPerm = perms.where((p) => p.userId == 1).firstOrNull;

          // WICHTIG: Nur pushen, wenn ich Schreibrechte (Level >= 2) habe!
          // Level 2 = Schreiben, Level 3 = Besitzer
          if (myPerm == null || myPerm.accessLevel < 2) continue;

          // Dateianhänge
          final localAttachmentsForEntry = await _databaseService.getAttachmentsByEntryId(entry.id!);
          final attachmentUuids = localAttachmentsForEntry.map((a) => a.uuid).where((u) => u.trim().isNotEmpty).toSet().toList();

          // Liste der Freunde (UserId > 1) für den Server bauen
          final friends = perms
              .where((p) => p.userId > 1)
              .map((p) {
                final uUuid = userMap[p.userId];
                if (uUuid == null || uUuid.isEmpty) return null;
                return FriendPermissionDto(userUuid: uUuid, encryptedKey: p.encryptedKey, accessLevel: p.accessLevel);
              })
              .nonNulls // Nur bekannte UUIDs, nulls filtern
              .toList();

          pushUpdates.add(
            SyncEntryDto(
              entryUuid: entry.uuid,
              encryptedData: entry.encryptedData,
              encryptedKey: myPerm.encryptedKey,
              accessLevel: myPerm.accessLevel,
              attachmentUuids: attachmentUuids,
              friends: friends,
              creatorUuid: userMap[entry.creatorId] ?? '',
              updaterUuid: userMap[entry.updaterId] ?? '',
              updatedAt: entry.updatedAt,
            ),
          );
        }

        // Gelöschte Einträge ermitteln
        final pushDeletes = localDeletes.map((d) => SyncDeleteDto(entryUuid: d.entryUuid, deletedAt: d.deletedAt)).toList();

        // Änderungen an den Server pushen
        if (pushUpdates.isNotEmpty || pushDeletes.isNotEmpty) {
          await _webService.pushSync(serverUserUuid, SyncPushRequest(updates: pushUpdates, deletes: pushDeletes));
          stats.pushSent = pushUpdates.length + pushDeletes.length;
        }

        // Unsynced Attachments hochladen (darf erst nach dem Push erfolgen, damit der Anhang an den Eintrag gehängt werden kann)
        for (var att in unsyncedAttachments) {
          final entry = await _databaseService.getEntryById(att.entryId);
          if (entry != null) {
            await _webService.uploadAttachment(entry.uuid, att.uuid, att.encryptedMeta, att.encryptedContent);
            att = att.copyWith(isSynced: true);
            await _databaseService.saveAttachment(att);
          }
        }
      }

      // --- STEP C: FINALIZE ---
      // Zeitstempel setzen
      // Wir nehmen die Zeit, die der Server uns beim Pull gegeben hat.
      settingsEntity = settingsEntity.copyWith(lastSyncAt: pullResponse.serverTime);
      await _databaseService.saveSettings(settingsEntity);

      // --- STEP D: SETTINGS PUSH ---
      // Wir laden die verschlüsselten Settings (inkl. Freunden) hoch
      await _pushFriends();

      return stats;
    } catch (e) {
      rethrow;
    }
  }

  /// Übernimmt eine neue Identität vom Server, falls das Master-Passwort auf einem anderen Gerät geändert wurde.
  /// Führt eine Umschlüsselung der lokalen Datenbank und aller vorhandenen Berechtigungen durch.
  ///
  /// Wird durch den [GuardService] (der das Masterpasswort über ein UI-Prompt abfragt) aufgerufen.
  Future<void> adoptRemoteIdentity(String password, UserResponse userResponse) async {
    // 1. Private-Key des Servers entschlüsseln
    final remoteMasterKey = await _cryptoService.deriveKey(password, base64Decode(userResponse.salt));
    final remotePrivKey = await _cryptoService.decrypt(userResponse.encryptedPrivateKey, remoteMasterKey);

    // 2. Falls sich das RSA-Schlüsselpaar geändert hat: Alle Permissions umschlüsseln
    final rsaKeyChanged = !const ListEquality().equals(_sessionService.privateKey, remotePrivKey);
    if (rsaKeyChanged) {
      final allPermissions = await _databaseService.getPermissions();
      final updatedPermissions = <PermissionEntity>[];
      for (var perm in allPermissions) {
        if (perm.encryptedKey.isNotEmpty && _sessionService.privateKey != null) {
          try {
            // Entschlüsseln mit altem (aktuellem) PrivateKey, verschlüsseln mit neuem PublicKey
            final entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, utf8.decode(_sessionService.privateKey!));
            final newEncryptedKey = await _cryptoService.encryptRsa(entryKey, userResponse.publicKey);
            updatedPermissions.add(perm.copyWith(encryptedKey: newEncryptedKey));
          } catch (e) {
            debugPrint("Fehler beim Umschlüsseln der Permission ${perm.id}: $e");
          }
        }
      }
      if (updatedPermissions.isNotEmpty) {
        await _databaseService.updatePermissions(updatedPermissions);
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
      settings = settings.copyWith(salt: userResponse.salt, encryptedPrivateKey: userResponse.encryptedPrivateKey);
      await _databaseService.saveSettings(settings);
    }

    // 5. Session aktualisieren (Wichtig, damit folgende Operationen den neuen Key nutzen)
    _sessionService.setSession(
      user: localUser,
      privateKey: remotePrivKey,
      vaultName: _sessionService.vaultName,
      settings: _sessionService.settings,
    );

    // Clean up memory
    _cryptoService.wipeKey(remoteMasterKey);
  }

  /// Lädt die Freundesliste vom Server und verarbeitet Namensänderungen, Key-Wechsel und gelöschte Freunde.
  Future<void> _pullFriends(UserResponse userResponse) async {
    // Clientseitig gespeicherte Benutzer holen
    final localUsers = await _databaseService.getUsers();

    // Öffentliche Schlüssel aller Benutzer vom Server holen
    final publicKeys = await _webService.getPublicKeys(userResponse.userUuid);

    // Freundesliste vom Server holen
    final encryptedFriends = userResponse.encryptedFriends;
    if (encryptedFriends == null || encryptedFriends.isEmpty) return;

    // Freundesliste entschlüsseln
    // Wir nutzen HKDF, um aus dem RSA-Private-Key einen stabilen AES-Key für die Freundesliste abzuleiten.
    // Info-String "friends" sorgt für Kontextbindung.
    final syncKeyMaterial = _sessionService.privateKey;
    if (syncKeyMaterial == null) throw Exception("RSA PrivateKey nicht gefunden");

    final aesKey = _cryptoService.deriveKeyFromKey(syncKeyMaterial, null, 'friends-list-encryption');
    List<FriendPayload> friends;
    try {
      final decrypted = await _cryptoService.decrypt(encryptedFriends, aesKey);
      final List<dynamic> jsonList = jsonDecode(utf8.decode(decrypted));
      friends = jsonList.map((e) => FriendPayload.fromJson(e)).toList();
    } catch (e) {
      throw Exception("Die Freundesliste auf dem Server ist fehlerhaft.");
    } finally {
      _cryptoService.wipeKey(aesKey);
    }

    // Vom Server geholte Freundesliste durchlaufen
    var needsRekeying = false;
    for (var remoteFriend in friends) {
      // Den öffentlichen Schlüssel des Freundes holen
      final pkEntry = publicKeys.where((pk) => pk['user_uuid'] == remoteFriend.uuid).firstOrNull;
      final publicKey = pkEntry?['public_key'] as String?;
      if (publicKey == null) continue; // der Freund existiert auf dem Server nicht mehr

      // Den vom Server geladenen Freund lokal suchen
      var localMatch = localUsers.where((u) => u.uuid == remoteFriend.uuid).firstOrNull;
      if (localMatch == null) {
        // Freund lokal hinzufügen
        await _databaseService.saveUser(
          UserEntity(
            uuid: remoteFriend.uuid,
            name: remoteFriend.name,
            publicKey: publicKey,
            isVerified: remoteFriend.isVerified,
            isHidden: remoteFriend.isHidden,
            updatedAt: remoteFriend.updatedAt,
          ),
        );
      } else {
        // Freund lokal aktualisieren

        // Fingerprint-Check (Sicherheitsveto)
        if (localMatch.publicKey != publicKey) {
          // Der lokal gespeicherte RSA-Key ist veraltet.

          // Alle verschlüsselten Entry-Keys des Freundes werden geleert, da sie unbrauchbar geworden sind.
          await _databaseService.removeEntryKeysForUser(localMatch.id!);

          // Neuen Key übernehmen, aber Vertrauen entziehen
          localMatch = localMatch.copyWith(publicKey: publicKey, isVerified: false, updatedAt: DateTime.now().toUtc());
          await _databaseService.saveUser(localMatch);

          // Hat der Freund Zugriffsrecht auf mindestens einen Eintrag?
          // Dann muss der Entry-Key neu generiert werden, bevor die Synchronization fortgesetzt werden kann.
          if (!needsRekeying) {
            if (await _databaseService.hasAccessWithoutKey(localMatch.id!)) {
              needsRekeying = true;
            }
          }
        }

        // Metadaten Abgleich
        if (remoteFriend.updatedAt.isAfter(localMatch.updatedAt)) {
          localMatch = localMatch.copyWith(
            name: remoteFriend.name,
            isHidden: remoteFriend.isHidden,
            isVerified: remoteFriend.isVerified,
            updatedAt: remoteFriend.updatedAt,
          );
          await _databaseService.saveUser(localMatch);
        }
      }
    }

    // 2. Freunde lokal löschen, die auf dem Server nicht mehr existieren.
    for (var localFriend in localUsers.where((u) => (u.id ?? 0) > 1)) {
      final existsOnServer = publicKeys.any((pk) => pk['user_uuid'] == localFriend.uuid);
      if (!existsOnServer) {
        await _databaseService.deleteUser(localFriend.id!);
      }
    }

    // Sync abbrechen, wenn die Umschlüsselung eines Entry-Keys noch aussteht.
    if (needsRekeying) {
      throw Exception(
        "Sicherheitsstopp: Die Identität eines Freundes hat sich geändert. "
        "Bitte verifiziere den neuen Fingerprint in den Einstellungen, bevor du synchronisierst.",
      );
    }
  }

  /// Verschlüsselt die Freunde und lädt sie auf den Server hoch.
  /// Nutzt eine hybride Verschlüsselung basierend auf dem privaten RSA-Schlüssel des Benutzers.
  Future<void> _pushFriends() async {
    final localUser = _sessionService.user!;

    // Wir nutzen HKDF, um aus dem RSA-Private-Key einen stabilen AES-Key für die Freundesliste abzuleiten.
    final syncKeyMaterial = _sessionService.privateKey;
    if (syncKeyMaterial == null) throw Exception("RSA PrivateKey nicht gefunden");

    final aesKey = _cryptoService.deriveKeyFromKey(syncKeyMaterial, null, 'friends-list-encryption');
    try {
      // 1. Alle lokal hinzugefügten Freunde laden
      final users = await _databaseService.getUsers();
      final friends = users
          .where((u) => (u.id ?? 0) > 1)
          .map((u) => FriendPayload(uuid: u.uuid, name: u.name, isVerified: u.isVerified, isHidden: u.isHidden, updatedAt: u.updatedAt))
          .toList();

      // Wenn es keine Freunde gibt, ist kein Push erforderlich.
      if (friends.isEmpty) return;

      // 2. Payload bauen
      final json = jsonEncode(friends.map((f) => f.toJson()).toList());
      final plainBytes = utf8.encode(json);
      final encryptedBlob = await _cryptoService.encrypt(plainBytes, aesKey);

      // 3. Hochladen
      await _webService.saveFriends(localUser.uuid, encryptedBlob);
    } finally {
      _cryptoService.wipeKey(aesKey);
    }
  }
}
