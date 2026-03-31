import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/app_version.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/main/sync/adopt_identity/user_identity.dart';
import 'package:privault/features/main/sync/sync_state.dart';
import 'package:privault/features/main/sync/sync_statistics.dart';
import 'package:privault/models/dtos/sync_dtos.dart';
import 'package:privault/models/dtos/user_response.dart';
import 'package:privault/models/payloads/entry_payload.dart';
import 'package:privault/models/payloads/friend_payload.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';
import 'package:privault/services/web_service.dart';

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(() {
  return SyncNotifier();
});

class SyncNotifier extends Notifier<SyncState> {

  // ------------------------------------------------------------------------
  // --- Services ---
  // ------------------------------------------------------------------------

  late final CryptoService _cryptoService;
  late final DatabaseService _databaseService;
  late final SessionService _sessionService;
  late final WebService _webService;

  // ------------------------------------------------------------------------
  // --- Interne Variablen (nicht reaktiv, nicht UI‑relevant) ---
  // ------------------------------------------------------------------------

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert einen Notifier.
  ///
  /// Die Verwendung von `Ref.watch` oder `Ref.listen` innerhalb dieser Methode ist unbedenklich.
  /// Ändert sich eine Abhängigkeit dieses Notifiers (bei Verwendung von `Ref.watch`), wird der Build-Prozess erneut ausgeführt. Der Notifier selbst wird jedoch nicht neu erstellt. Seine Instanz bleibt zwischen den Build-Ausführungen erhalten.
  @override
  SyncState build() {
    // Dienste aus getIt holen
    _cryptoService = getIt();
    _databaseService = getIt();
    _sessionService = getIt();
    _webService = getIt();

    // Initialer State
    return const SyncState();
  }
  
  /// Startet den Synchronisationsprozess.
  Future<void> sync() async {
    if (state.isBusy) return;

    // UI-State zurücksetzen
    state = const SyncState(status: SyncStatus.progress);
    
    try {

      if (_sessionService.settings == null) throw Exception("Settings liegt nicht in der Session.");
      final settings = _sessionService.settings!;
      if (settings.encryptedPrivateKey.isEmpty) throw Exception("Der private RSA-Schlüssel liegt nicht in der Datenbank.");
      if (settings.salt.isEmpty) throw Exception("Das Salt liegt nicht in der Datenbank.");

      if (_sessionService.user == null) throw Exception("Der Benutzer liegt nicht in der Session.");
      final user = _sessionService.user!;
      if (_sessionService.privateKey == null) throw Exception("Der privater Schlüssel ist nicht entpackt.");

      // 1. WebService konfigurieren
      if (settings.host.isEmpty || settings.apiToken.isEmpty) {
        state = state.copyWith(status: SyncStatus.failure, error: AppError(ErrorCode.valueRequired, text: 'Der Sync-Server ist noch nicht eingerichtet.'));
        return;
      }
      _webService.updateConfig(host: settings.host, apiToken: settings.apiToken);
      _webService.setSignatureData(userUuid: user.uuid, privateKey: _sessionService.privateKey!, publicKey: user.publicKey);

      // 2. Server-Version prüfen
      final serverVersion = await _webService.getServerVersion();
      if (!serverVersion.service.contains("PriVault")) {
        state = state.copyWith(status: SyncStatus.failure, error: AppError(ErrorCode.noSyncService));
        return;
      }
      if (AppVersion.syncProtocolVersion < serverVersion.minSyncProtocolVersion) {
        state = state.copyWith(status: SyncStatus.failure, error: AppError(ErrorCode.appIsOutdated));
        return;
      }
      if (AppVersion.syncProtocolVersion > serverVersion.syncProtocolVersion) {
        state = state.copyWith(status: SyncStatus.failure, error: AppError(ErrorCode.serverIsOutdated));
        return;
      }

      // 3. Benutzer über den Namen im angegebenen Tresor suchen.
      var userResponse = await _webService.findUser(_sessionService.vaultName, user.name);

      // 4. Wenn der Benutzer nicht gefunden wurde, registrieren. Ansonsten sicherstellen, dass die UUID und die Schlüssel des Benutzers passen.
      if (userResponse == null) {
        // Benutzer existiert noch nicht

        // Jetzt registrieren.
        userResponse = await _webService.registerUser(
          vaultName: _sessionService.vaultName,
          userName: user.name,
          userUuid: user.uuid,
          salt: settings.salt,
          publicKey: user.publicKey,
          encryptedPrivateKey: settings.encryptedPrivateKey,
          masterKeyTimestamp: settings.masterKeyTimestamp,
        );

        // Die UUID des Benutzers muss gleich sein!
        if (userResponse.userUuid != user.uuid) throw Exception("Die vom Server erhaltene UUID entspricht nicht dem lokalen Benutzer.");

      } else {
        // Der Name des Benutzers existiert auf dem Server.

        // Fall ein anderes Gerät den Benutzer registriert hat und dieses Gerät noch nicht mit dem Server synchronisiert wurde, stimmt die UUID des Benutzers nicht.
        // In diesem Fall wird die UUID des Benutzers, das Salt und das RSA-Schlüsselpaar des anderen Gerätes übernommen.
        final isOnboarding = userResponse.userUuid != user.uuid;

        // Falls das Master-Passwort geändert wurde, ist der private RSA-Schlüssel anders verpackt (und Salt wurde neu generiert). todo ist ein neuer Salt notwendig?
        // In diesem Fall entscheidet der Zeitstempel des Master-Keys, ob die Schlüssel auf dem Server oder auf dem lokalen Gerät aktualisiert werden.
        final isKeyConflict = userResponse.encryptedPrivateKey != settings.encryptedPrivateKey || userResponse.salt != settings.salt;
        final isServerNewer = userResponse.masterKeyTimestamp.isAfter(settings.masterKeyTimestamp); // der Server ist aktueller

        if (isOnboarding || (isKeyConflict && isServerNewer)) {
          // Der Server ist aktueller -> Dialog für die Identitätsübernahme öffnen
          Logger().info(isOnboarding ? 'Erste Synchronisation. Starte Adoption.' : 'Das lokale Master-Passwort ist veraltet. Starte Adoption.');
          state = state.copyWith(
            status: SyncStatus.askForAdoption,
            adoptionUserIdentity: UserIdentity(
              userUuid: userResponse.userUuid,
              salt: userResponse.salt,
              publicKey: userResponse.publicKey,
              encryptedPrivateKey: userResponse.encryptedPrivateKey,
            ),
          );
          return; // Sync-Prozess hier abbrechen; nach der Adoption wird die Synchronisation erneut gestartet
        }
        
        // Das lokale Master-Passwort ist aktueller -> Server aktualisieren
        Logger().info('Das Master-Passwort wurde lokal geändert. Aktualisiere Server.');
        await _webService.changePassword(user.uuid, settings.salt, settings.encryptedPrivateKey, settings.masterKeyTimestamp);
      }

      // 5. Freundesliste vom Server herunterladen und lokale Liste aktualisieren.
      // Falls ein Freund einen neuen Fingerprint hat, werden seine Entry-Keys gelöscht und das Vertrauen entzogen.
      await _pullFriends(userResponse);

      // 6. Sync abbrechen, wenn die Umschlüsselung eines Entry-Keys noch aussteht.
      final needsRekeying = await _databaseService.hasPermissionsWithoutKey();
      if (needsRekeying) {
        final text = "Der Fingerprint eines Freundes hat sich geändert.\n"
          "Bitte verifiziere diesen in den Einstellungen, und starte danach die Synchronisation erneut.";
        state = state.copyWith(status: SyncStatus.askForRekeying, error: AppError(ErrorCode.syncEmptyEntryKey, text: text));
        return;
      }

      // 7. Einträge vom Server herunterladen
      final serverTime = await _pullEntries(userResponse.userUuid);

      // 8. Veränderte Einträge hochladen
      await _pushEntries(userResponse.userUuid);

      // 9. Aktualisierte Freundesliste an den Server hochladen
      await _pushFriends();

      // 10. Zeitstempel setzen
      final updatedSettings = settings.copyWith(lastSyncAt: serverTime);
      await _databaseService.saveSettings(updatedSettings);

      // 11. UI-State aktualisieren
      state = state.copyWith(status: SyncStatus.success);

    } on DioException catch (de) { // Exception des HTTP-Clients
      //final msg = de.response?.statusMessage ?? (de.message ?? 'Netzwerkfehler');
      //final text = de.response?.statusCode != null ? '$msg (Code ${de.response?.statusCode})' : msg;
      //Logger().error(text);
      //state = state.copyWith(status: SyncStatus.failure, error: AppError(ErrorCode.networkError, text: text));
      final error = WebService.convertDioError(de);
      Logger().error(error.text);
      state = state.copyWith(status: SyncStatus.failure, error: error);
      
    } catch (e, st) {
      Logger().fatal("Fehler beim Synchronisieren: $e", stack: st);
      state = state.copyWith(status: SyncStatus.failure, error: AppError(ErrorCode.unknown));
    }
  }

  /// Lädt die Freundesliste vom Server und verarbeitet Namensänderungen, Key-Wechsel und gelöschte Freunde.
  Future<void> _pullFriends(UserResponse userResponse) async {
    // 1. Clientseitig gespeicherte Benutzer holen
    final localUsers = await _databaseService.getUsers();

    // 2. Öffentliche Schlüssel aller Benutzer vom Server holen
    final publicKeys = await _webService.getPublicKeys(userResponse.userUuid);

    // 3. Prüfen, ob der Öffentliche Schlüssel der lokalen Freunde aktuell ist.
    for (var localFriend in localUsers.where((u) => u.id > 1)) {
      // Den aktuellen öffentlichen Schlüssel holen
      final pkEntry = publicKeys.where((pk) => pk['user_uuid'] == localFriend.uuid).firstOrNull;
      final publicKey = pkEntry?['public_key'] as String?;

      if (publicKey == null) {
        // der Freund existiert auf dem Server nicht mehr
        await _databaseService.deleteUser(localFriend.id);
        continue;
      }

      // Fingerprint-Check (Sicherheitsveto)
      if (localFriend.publicKey != publicKey) {
        // Der lokal gespeicherte RSA-Key ist veraltet.

        // Alle verschlüsselten Entry-Keys des Freundes werden geleert, da sie unbrauchbar geworden sind.
        await _databaseService.removeEntryKeysForUser(localFriend.id);

        // Neuen Key übernehmen, aber Vertrauen entziehen
        localFriend = localFriend.copyWith(
          publicKey: publicKey,
          isVerified: false,
          updatedAt: DateTime.now().toUtc(),
        );
        localFriend = await _databaseService.saveUser(localFriend);
      }
    }

    // 4. Die auf dem Server gespeicherte Freundesliste entschlüsseln
    final encryptedFriends = userResponse.encryptedFriends;
    if (encryptedFriends == null || encryptedFriends.isEmpty) return;
    List<FriendPayload> friends;
    final aesKey = _cryptoService.deriveKeyFromKey(_sessionService.privateKey!, null, 'friends-list-encryption');
    try {
      final decrypted = await _cryptoService.decrypt(encryptedFriends, aesKey);
      final List<dynamic> jsonList = jsonDecode(utf8.decode(decrypted));
      friends = jsonList.map((e) => FriendPayload.fromJson(e)).toList();
    } catch (e) {
      throw Exception("Die Freundesliste auf dem Server ist fehlerhaft.");
    } finally {
      _cryptoService.wipeKey(aesKey);
    }

    // 5. Die entschlüsselte Freundesliste durchlaufen und lokale Liste abgleichen
    for (var remoteFriend in friends) {
      // Den öffentlichen Schlüssel des Freundes holen
      final pkEntry = publicKeys.where((pk) => pk['user_uuid'] == remoteFriend.uuid).firstOrNull;
      final publicKey = pkEntry?['public_key'] as String?;
      if (publicKey == null) continue; // der Freund existiert auf dem Server nicht mehr

      // Den vom Server geladenen Freund lokal suchen
      var localMatch = localUsers.where((u) => u.uuid == remoteFriend.uuid).firstOrNull;
      if (localMatch == null) {
        // Freund lokal hinzufügen
        await _databaseService.saveUser(UserEntity(
          id: 0,
          uuid: remoteFriend.uuid,
          name: remoteFriend.name,
          publicKey: publicKey,
          isVerified: remoteFriend.isVerified,
          isHidden: remoteFriend.isHidden,
          updatedAt: remoteFriend.updatedAt,
        ));
      } else {
        // Freund lokal aktualisieren, wenn der Eintrag auf dem Server aktueller ist
        if (remoteFriend.updatedAt.isAfter(localMatch.updatedAt)) {
          localMatch = localMatch.copyWith(
            name: remoteFriend.name,
            isVerified: remoteFriend.isVerified,
            isHidden: remoteFriend.isHidden,
            updatedAt: remoteFriend.updatedAt,
          );
          await _databaseService.saveUser(localMatch);
        }
      }
    }
  }

  /// Lädt neue und geänderte Einträge vom Server herunter und verarbeitet diese
  ///
  /// Zurückgegeben wird der aktuelle Zeitstempel des Servers zum Zeitpunkt der Anfrage.
  Future<DateTime> _pullEntries(String userUuid) async {
    int added = 0, updated = 0, deleted = 0;

    // 1. Neue und geänderte Einträge vom Server herunterladen
    final pullResponse = await _webService.pullSync(userUuid, _sessionService.settings!.lastSyncAt);

    // 2. Gelöschte Einträge entfernen
    for (var tombstoneDto in pullResponse.deletes) {
      final entry = await _databaseService.getEntryByUuid(tombstoneDto.entryUuid);
      if (entry != null) {
        await _databaseService.saveTombstone(TombstoneEntity(
          id: 0,
          entryUuid: tombstoneDto.entryUuid,
          deletedAt: tombstoneDto.deletedAt,
        ));
        await _databaseService.deleteEntry(entry.id);
        deleted++;
      }
    }

    // 3. Fremde Einträge löschen, bei denen mir das Recht entzogen wurde (AccessLevel == 0)
    for (var entryDto in pullResponse.updates.where((u) => u.accessLevel == 0)) {
      final entry = await _databaseService.getEntryByUuid(entryDto.entryUuid);
      if (entry != null) {
        // Hier kein lokaler Tombstone, da der Eintrag im Tresor auf dem Gerät des Freundes ja noch existiert (nur für mich unsichtbar).
        await _databaseService.deleteEntry(entry.id);
        deleted++;
      }
    }

    // 4. Vorbereitung: Alle lokalen User laden, um UUIDs in IDs aufzulösen
    final localUsers = await _databaseService.getUsers();
    final userUuidMap = {for (var u in localUsers) u.uuid: u.id};

    // 5. Updates einspielen
    for (var entryDto in pullResponse.updates.where((u) => u.accessLevel > 0)) {
      if (entryDto.encryptedKey.isEmpty) throw Exception("Heruntergeladenen Eintrag ${entryDto.entryUuid} hat kein Entry-Key.");

      // 5.1 Suchfelder aus dem verschlüsselten Payload extrahieren
      String category = '', title = '', url = '', notes = '', favicon = '';
      try {
        // Wir brauchen den EntryKey (AES), um an die Suchfelder zu kommen
        final entryKey = await _cryptoService.decryptRsa(entryDto.encryptedKey, utf8.decode(_sessionService.privateKey!));
        final decryptedData = await _cryptoService.decrypt(entryDto.encryptedData, entryKey);
        final payload = EntryPayload.fromJson(json.decode(utf8.decode(decryptedData)));
        category = payload.category;
        title = payload.title;
        url = payload.url;
        notes = payload.notes;
        favicon = payload.favicon;
      } catch (e) {
        throw Exception("Eintrag ${entryDto.entryUuid} konnte nicht extrahiert werden: $e");
      }

      // 5.2 Statistik aktualisieren
      final existing = await _databaseService.getEntryByUuid(entryDto.entryUuid);
      if (existing == null) {
        added++;
      } else {
        updated++;
      }

      // 5.3 Eintrag speichern
      final entity = EntryEntity(
        id: 0,
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
      final savedEntry = await _databaseService.saveEntryWithPermissions(
        entity,
        1, // userId
        entryDto.encryptedKey,
        accessLevel: entryDto.accessLevel,
      );

      // 5.4 Freunde verarbeiten
      for (var remoteFriends in entryDto.friends) {
        // Wir speichern die Permission nur, wenn wir den User lokal kennen.
        // (Die Benutzerliste wurde zuvor per pullFriends() abgeglichen.)
        final friendUserId = userUuidMap[remoteFriends.userUuid];
        if (friendUserId != null) {
          await _databaseService.savePermission(PermissionEntity(
            id: 0,
            entryId: savedEntry.id,
            userId: friendUserId,
            encryptedKey: remoteFriends.encryptedKey,
            accessLevel: remoteFriends.accessLevel,
          ));
        }
      }

      // 5.5 Anhänge verarbeiten
      final remoteAttachmentUuids = entryDto.attachmentUuids;
      final localAttachments = await _databaseService.getAttachmentsByEntryId(savedEntry.id);
      final localMap = {for (var a in localAttachments) a.uuid: a};
      for (var attUuid in remoteAttachmentUuids) {
        if (!localMap.containsKey(attUuid)) {
          // Hier laden wir nun das vollständige DTO mit Meta & Content
          final attResponse = await _webService.downloadAttachment(attUuid);

          final encryptedContent = attResponse['encrypted_content'] as String?;
          if (encryptedContent == null || encryptedContent.isEmpty) {
            throw Exception("Anhang $attUuid konnte nicht geladen werden.");
          }

          final attachmentUuid = attResponse['attachment_uuid'] as String?;
          final encryptedMeta = attResponse['encrypted_meta'] as String?;
          await _databaseService.saveAttachment(AttachmentEntity(
            id: 0,
            uuid: attachmentUuid ?? attUuid,
            entryId: savedEntry.id,
            encryptedMeta: encryptedMeta ?? '',
            encryptedContent: encryptedContent,
            isSynced: true,
          ));
        }
      }

      // 5.6 Lokale Anhänge löschen, die auf dem Server nicht mehr existieren
      final remoteUuidsSet = remoteAttachmentUuids.toSet();
      for (var attachment in localAttachments) {
        if (!remoteUuidsSet.contains(attachment.uuid)) {
          await _databaseService.deleteAttachment(attachment.id);
        }
      }
    }

    // 6. Sync-Statistik im State aktualisieren
    final stats = state.syncStatistics ?? const SyncStatistics();
    state = state.copyWith(
      syncStatistics: SyncStatistics(
        pullAdded: stats.pullAdded + added,
        pullUpdated: stats.pullUpdated + updated,
        pullDeleted: stats.pullDeleted + deleted,
        pushSent: stats.pushSent,
      ),
    );

    return pullResponse.serverTime;
  }

  /// Updatet die Einträge auf dem Server.
  Future<void> _pushEntries(String userUuid) async {
    // Veränderungen seit dem letzten Push ermitteln
    final lastSyncAt = _sessionService.settings!.lastSyncAt;
    final localUpdates = await _databaseService.getEntriesSince(lastSyncAt);
    final localDeletes = await _databaseService.getTombstonesSince(lastSyncAt);
    final unsyncedAttachments = await _databaseService.getAttachmentsUnsynced();
    if (localUpdates.isEmpty && localDeletes.isNotEmpty && unsyncedAttachments.isNotEmpty) {
      return; // nichts zu tun
    }

    // Vorbereitung: UUID Map laden, um IDs aufzulösen
    final users2 = await _databaseService.getUsers();
    final userMap = {for (var u in users2) u.id: u.uuid};

    // 1. Zu pushende Updates aufbauen
    final pushUpdates = <SyncEntryDto>[];
    for (var entry in localUpdates) {
      // Alle Berechtigungen für diesen Eintrag laden
      final perms = await _databaseService.getPermissionsByEntryId(entry.id);

      // Meine eigene Permission (ID 1) holen
      final myPerm = perms.where((p) => p.userId == 1).firstOrNull;

      // Nur pushen, wenn Schreibrechte (Level >= 2) gegeben sind
      // Level 2 = Schreiben, Level 3 = Besitzer
      if (myPerm == null || myPerm.accessLevel < 2) continue;

      // Dateianhänge
      final localAttachmentsForEntry = await _databaseService.getAttachmentsByEntryId(entry.id);
      final attachmentUuids = localAttachmentsForEntry.map((a) => a.uuid).where((u) => u.trim().isNotEmpty).toSet().toList();

      // Liste der Freunde (UserId > 1) für den Server bauen
      final friends = perms.where((p) => p.userId > 1).map((p) {
        final uUuid = userMap[p.userId];
        if (uUuid == null || uUuid.isEmpty) return null;
        return FriendPermissionDto(
          userUuid: uUuid,
          encryptedKey: p.encryptedKey,
          accessLevel: p.accessLevel,
        );
      }).nonNulls.toList(); // Nur bekannte UUIDs, nulls filtern

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

    // 2. Zu pushende Deletes ermitteln
    final pushDeletes = localDeletes.map((d) => SyncDeleteDto(entryUuid: d.entryUuid, deletedAt: d.deletedAt)).toList();

    // 3. Updates und Deletes an den Server pushen
    if (pushUpdates.isNotEmpty || pushDeletes.isNotEmpty) {
      await _webService.pushSync(userUuid, SyncPushRequest(updates: pushUpdates, deletes: pushDeletes));
    }

    // 4. Unsynced Attachments hochladen (darf erst nach dem Push erfolgen, damit der Anhang an den Eintrag gehängt werden kann)
    for (var att in unsyncedAttachments) {
      final entry = await _databaseService.getEntry(att.entryId);
      if (entry != null) {
        await _webService.uploadAttachment(entry.uuid, att.uuid, att.encryptedMeta, att.encryptedContent);
        att = att.copyWith(isSynced: true);
        await _databaseService.saveAttachment(att);
      }
    }

    // 5. Sync-Statistik im State aktualisieren
    if (pushUpdates.isNotEmpty || pushDeletes.isNotEmpty) {
      final stats = state.syncStatistics ?? const SyncStatistics();
      state = state.copyWith(
        syncStatistics: SyncStatistics(
          pullAdded: stats.pullAdded,
          pullUpdated: stats.pullUpdated,
          pullDeleted: stats.pullDeleted,
          pushSent: stats.pushSent + pushUpdates.length + pushDeletes.length,
        ),
      );
    }
  }

  /// Verschlüsselt die Freunde und lädt sie auf den Server hoch.
  Future<void> _pushFriends() async {
    // Wir nutzen HKDF, um aus dem RSA-Private-Key einen stabilen AES-Key für die Freundesliste abzuleiten.
    final aesKey = _cryptoService.deriveKeyFromKey(_sessionService.privateKey!, null, 'friends-list-encryption');
    try {
      // 1. Alle lokal hinzugefügten Freunde laden
      final users = await _databaseService.getUsers();
      final friends = users
        .where((u) => u.id > 1)
        .map((u) => FriendPayload(
          uuid: u.uuid,
          name: u.name,
          isVerified: u.isVerified,
          isHidden: u.isHidden,
          updatedAt: u.updatedAt,
        ),
      ).toList();

      // Wenn es keine Freunde gibt, ist kein Push erforderlich.
      if (friends.isEmpty) return;

      // 2. Payload bauen
      final json = jsonEncode(friends.map((f) => f.toJson()).toList());
      final plainBytes = utf8.encode(json);
      final encryptedBlob = await _cryptoService.encrypt(plainBytes, aesKey);

      // 3. Hochladen
      await _webService.saveFriends(_sessionService.user!.uuid, encryptedBlob);
    } finally {
      _cryptoService.wipeKey(aesKey);
    }
  }
}