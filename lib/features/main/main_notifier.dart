import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/app_version.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/main/main_state.dart';
import 'package:privault/features/main/sync_statistics.dart';
import 'package:privault/models/dtos/sync_dtos.dart';
import 'package:privault/models/dtos/user_response.dart';
import 'package:privault/models/payloads/entry_payload.dart';
import 'package:privault/models/payloads/friend_payload.dart';
import 'package:privault/services/biometric_service.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';
import 'package:privault/services/web_service.dart';

final mainProvider = NotifierProvider<MainNotifier, MainState>(
  MainNotifier.new,
);

class MainNotifier extends Notifier<MainState> {

  // ------------------------------------------------------------------------
  // --- Verwendete Dienste ---
  // ------------------------------------------------------------------------

  late final BiometricService _biometricService;
  late final CryptoService _cryptoService;
  late final DatabaseService _databaseService;
  late final SessionService _sessionService;
  late final WebService _webService;

  // ------------------------------------------------------------------------
  // --- Interne Variablen (nicht reaktiv, nicht UI‑relevant) ---
  // ------------------------------------------------------------------------

  /// Antwort des Servers mit der neuen Benutzer-Identität, die adoptiert werden muss.
  UserResponse? _userResponse;

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert einen Notifier.
  ///
  /// Die Verwendung von `Ref.watch` oder `Ref.listen` innerhalb dieser Methode ist unbedenklich.
  /// Ändert sich eine Abhängigkeit dieses Notifiers (bei Verwendung von `Ref.watch`), wird der Build-Prozess erneut ausgeführt. Der Notifier selbst wird jedoch nicht neu erstellt. Seine Instanz bleibt zwischen den Build-Ausführungen erhalten.
  @override
  MainState build() {
    // Dienste aus getIt holen
    _biometricService = getIt();
    _cryptoService = getIt();
    _databaseService = getIt();
    _sessionService = getIt();
    _webService = getIt();

    // Initialer State
    return const MainState();
  }

  /// Lädt die Daten für die Anzeige.
  Future<void> load() async {
    state = state.copyWith(isBusy: true, error: FormError.none());
    try {
      final entries = await _databaseService.getEntries();
      state = state.copyWith(allEntries: entries);
    } catch (e, st) {
      Logger().fatal("Fehler beim Laden: $e", stack: st);
      state = state.copyWith(error: FormError(ErrorCode.unknown));
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  /// Meldet den Benutzer ab und bereinigt die Sitzungsdaten im RAM.
  void logout() {
    _databaseService.close(); // Datenbankverbindung kappen
    _sessionService.clearSession(); // Schlüssel aus dem RAM löschen
    state = const MainState();
  }

  // ------------------------------------------------------------------------
  // --- Suche, Filter und Gruppierung ---
  // ------------------------------------------------------------------------

  /// Setter für Suchbegriff
  void setSearchQuery(String value) {
    state = state.copyWith(searchQuery: value.toLowerCase());
  }

  /// Setter für "Nur-Meine"-Filter
  void setOnlyMyEntries(bool value) {
    state = state.copyWith(onlyMyEntries: value);
  }

  /// Gruppiert die gefilterten Einträge nach Kategorien für die Darstellung in der UI.
  Map<String, List<EntryEntity>> getEntriesGroupedByCategory() {
    final Map<String, List<EntryEntity>> groups = {};
    final placeholder = _sessionService.settings?.categoryPlaceholder ?? 'Allgemein';
    final q = state.searchQuery;

    // Filter anwenden
    final filtered = state.allEntries.where((entry) {
      final matchesSearch = entry.title.toLowerCase().contains(q) || entry.url.toLowerCase().contains(q) || entry.notes.toLowerCase().contains(q);
      final matchesUser = !state.onlyMyEntries || entry.creatorId == _sessionService.user?.id;
      return matchesSearch && matchesUser;
    });

    // Gruppieren
    for (final entry in filtered) {
      final category = entry.category.isEmpty ? placeholder : entry.category;
      if (!groups.containsKey(category)) {
        groups[category] = [];
      }
      groups[category]!.add(entry);
    }
    return groups;
  }

  /// Klappt eine Kategorie auf/zu.
  void toggleCategory(String category) {
    final collapsed = Set<String>.from(state.collapsedCategories);
    if (collapsed.contains(category)) {
      collapsed.remove(category);
    } else {
      collapsed.add(category);
    }
    state = state.copyWith(collapsedCategories: collapsed);
  }

  // ------------------------------------------------------------------------
  // --- Synchronisation ---
  // ------------------------------------------------------------------------

  /// Startet den Synchronisationsprozess mit dem konfigurierten Server.
  /// Behandelt Spezialfälle wie Passwortänderungen auf anderen Geräten (Adoption).
  Future<bool> sync() async {
    // Stats-Zähler anlegen
    final stats = SyncStatistics();

    // Letzte Serverantwort mit der Benutzer-Identität verwerfen
    _userResponse = null;

    // Busy setzen, Fehler zurücksetzen
    state = state.copyWith(isBusy: true, error: FormError.none());
    try {
      if (_sessionService.settings == null) throw Exception("Settings liegt nicht in der Session.");
      if (_sessionService.user == null) throw Exception("Der Benutzer liegt nicht in der Session.");

      // 1. WebService konfigurieren
      _configWebService();

      // 2. Server-Version prüfen
      await _checkVersion();

      // 3. Benutzer registrieren, falls noch nicht geschehen
      _userResponse = await _registerUserIfNeeded();

      // 4. Sicherstellen, dass die UUID des Benutzers und das Salt übereinstimmen
      // Wenn nicht, wird zum ersten mal ein Zweitgerät synchronisiert oder es wurde auf einem anderen Gerät das Passwort geändert.
      if (_sessionService.user!.uuid != _userResponse!.userUuid ||
          _sessionService.settings!.salt != _userResponse!.salt) {
        state = state.copyWith(error: FormError(ErrorCode.syncSaltMismatch));
        return false;
      }

      // 5. Freundesliste vom Server herunterladen und lokale Liste aktualisieren.
      // Falls ein Freund einen neuen Fingerprint hat, werden seine Entry-Keys gelöscht und das Vertrauen entzogen.
      await _pullFriends();

      // 6. Sync abbrechen, wenn die Umschlüsselung eines Entry-Keys noch aussteht.
      final needsRekeying = await _databaseService.hasPermissionsWithoutKey();
      if (needsRekeying) {
        state = state.copyWith(error: FormError(ErrorCode.syncEmptyEntryKey));
        return false;
      }

      // 7. Einträge vom Server herunterladen und lokale Einträge aktualisieren
      final serverTime = await _pullEntries(stats);

      // 8. Veränderte Einträge hochladen
      await _pushEntries(stats);

      // 9. Aktualisierte Freundesliste an den Server hochladen ---
      await _pushFriends();

      // 10. Zeitstempel setzen
      final updatedSettings = _sessionService.settings!.copyWith(lastSyncAt: serverTime);
      await _databaseService.saveSettings(updatedSettings);

      // 11. Einträge aktualisieren und Statistik im State ablegen
      final entries = await _databaseService.getEntries();
      state = state.copyWith(allEntries: entries, lastSyncStats: stats);
      return true;

    } catch (e, st) {
      Logger().fatal("Fehler beim Sync: $e", stack: st);
      state = state.copyWith(error: FormError(ErrorCode.unknown));
      return false;

    } finally {
      // Busy zurücksetzen
      state = state.copyWith(isBusy: false);
    }
  }

  /// Übernimmt eine neue Identität vom Server.
  ///
  /// Führt eine Umschlüsselung aller vorhandenen Berechtigungen durch, verschlüsselt die sqLite-Datei mit dem
  /// neuen Master-Schlüssel und aktualisiert die Salt-Datei.
  Future<bool> adoptIdentity(String password) async {
    Uint8List? masterKey;
    Uint8List? newMasterKey;

    state = state.copyWith(isBusy: true, error: FormError.none());

    try {
      if (_userResponse == null) throw Exception("Der Server hat noch keine Benutzerdaten geliefert.");
      if (_sessionService.settings == null) throw Exception("Settings liegt nicht in der Session.");
      if (_sessionService.user == null) throw Exception("Der Benutzer liegt nicht in der Session.");
      if (_sessionService.settings!.encryptedPrivateKey.isEmpty) throw Exception("`encryptedPrivateKey` ist in der Session leer.");
      if (_sessionService.settings!.salt.isEmpty) throw Exception("Das Salt liegt nicht in der Session.");
      if (_sessionService.privateKey == null) throw Exception("Der privater Schlüssel ist nicht entpackt.");

      // Kurze Pause für Lade-Indikator, bevor Argon2 blockiert
      await Future.delayed(const Duration(milliseconds: 50));

      // 1. MasterKey ableiten (Argon2id)
      final salt = base64Decode(_sessionService.settings!.salt);
      masterKey = await _cryptoService.deriveKey(password, salt);

      // 2. Passwort validieren
      try {
        await _cryptoService.decrypt(_sessionService.settings!.encryptedPrivateKey, masterKey);
      } catch (_) {
        state = state.copyWith(error: FormError(ErrorCode.wrongPassword, field: 'password'));
        return false;
      }

      // 3. Physisches Datenbank-Backup erstellen
      await _databaseService.createBackup();

      try {
        // --- Start Kritische Logik ---

        // 4. Neuen Master-Key mit dem Salt der neuen Identität berechnen
        final newSalt = base64Decode(_userResponse!.salt);
        newMasterKey = await _cryptoService.deriveKey(password, newSalt);

        // 5. Private-Key der neune Identität entschlüsseln
        final newPrivateKey = await _cryptoService.decrypt(_userResponse!.encryptedPrivateKey, newMasterKey);

        // 6. Falls sich das RSA-Schlüsselpaar geändert hat: Alle Permissions umschlüsseln
        final rsaKeyChanged = !const ListEquality().equals(_sessionService.privateKey, newPrivateKey);
        if (rsaKeyChanged) {
          final allPermissions = await _databaseService.getPermissions();
          final updatedPermissions = <PermissionEntity>[];
          for (var perm in allPermissions) {
            if (perm.encryptedKey.isNotEmpty && _sessionService.privateKey != null) {
              try {
                // Entschlüsseln mit altem (aktuellem) Private-Key, verschlüsseln mit dem Public-Key der neuen Identität
                final entryKey = await _cryptoService.decryptRsa(perm.encryptedKey, utf8.decode(_sessionService.privateKey!));
                final newEncryptedKey = await _cryptoService.encryptRsa(entryKey, _userResponse!.publicKey);
                updatedPermissions.add(perm.copyWith(encryptedKey: newEncryptedKey));
              } catch (e) {
                throw Exception("Fehler beim Umschlüsseln der Permission ${perm.id}: $e");
              }
            }
          }
          if (updatedPermissions.isNotEmpty) {
            await _databaseService.updatePermissions(updatedPermissions);
          }
        }

        // 7. Datenbankdatei mit dem neuen Master-Key verschlüsseln
        await _databaseService.rekey(newMasterKey);

        // 8. Salt-Datei aktualisieren
        await _databaseService.saveSalt(_sessionService.vaultName, newSalt);

        // 9. Master-Key im SecureStore aktualisieren
        if (_sessionService.settings!.useBiometric) {
          await _biometricService.saveMasterKey(_sessionService.vaultName, newMasterKey);
        }

        // 10. User-UUID übernehmen, falls geändert
        UserEntity user = _sessionService.user!;
        if (user.uuid != _userResponse!.userUuid) {
          // Wenn ein Zweitgerät das erste mal synchronisiert wird, muss auch die UUID des Benutzers übernommen werden.
          user = user.copyWith(uuid: _userResponse!.userUuid);
          user = await _databaseService.saveUser(user);
        }

        // 11. Settings aktualisieren
        final settings = _sessionService.settings!.copyWith(
          salt: base64Encode(newSalt),
          encryptedPrivateKey: _userResponse!.encryptedPrivateKey,
        );
        await _databaseService.saveSettings(settings);

        // 12. Session aktualisieren
        _sessionService.setSession(
          user: user,
          privateKey: newPrivateKey,
          vaultName: _sessionService.vaultName,
          settings: settings,
        );

        // --- Ende Kritische Logik ---

        // 13. Backup löschen
        await _databaseService.removeBackup();
        return true;
      } catch (e) {
        // Fehler während der Operation -> Rollback
        try {
          await _databaseService.close();
          await _databaseService.restoreBackup();
          await _databaseService.initialize(_sessionService.vaultName, masterKey);
        } catch (_) {}
        rethrow;
      }

    } catch (e, st) {
      Logger().fatal("Fehler bei der Identitätsübernahme: $e", stack: st);
      state = state.copyWith(error: FormError(ErrorCode.unknown));
      return false;

    } finally {
      if (masterKey != null) _cryptoService.wipeKey(masterKey);
      if (newMasterKey != null) _cryptoService.wipeKey(newMasterKey);
      state = state.copyWith(isBusy: false);
    }
  }

  /// Konfiguriert den WebService mit den aktuellen Session-Daten.
  void _configWebService() {
    if (_sessionService.settings!.host.isEmpty) {
      throw Exception("Für die Synchronisation muss eine gültige Host-URL hinterlegt sein. Bitte trage sie in den Einstellungen ein.");
    }

    if (_sessionService.settings!.apiToken.isEmpty) {
      throw Exception("Für die Synchronisation muss ein gültiger API-Token hinterlegt sein. Bitte trage ihn in den Einstellungen ein.");
    }

    _webService.updateConfig(host: _sessionService.settings!.host, apiToken: _sessionService.settings!.apiToken);

    _webService.setSignatureData(userUuid: _sessionService.user!.uuid, privateKey: _sessionService.privateKey!, publicKey: _sessionService.user!.publicKey);
  }

  /// Stellt sicher, dass die Server-Version zur App passt.
  ///
  /// Wenn die Version nicht kompatibel ist, wird eine Exception geworfen.
  Future<void> _checkVersion() async {
    final serverVersion = await _webService.getServerVersion();
    if (AppVersion.syncProtocolVersion < serverVersion.minSyncProtocolVersion) {
      // App zu alt
      throw Exception("Bitte aktualisiere die App und starte danach nochmal die Synchronisation.");
    }
    if (AppVersion.syncProtocolVersion > serverVersion.syncProtocolVersion) {
      // Server zu alt
      throw Exception("Der Server ist noch nicht auf dem aktuellen Stand. Versuche es später noch einmal.");
    }
  }

  // Registriert den Benutzer, wenn noch nicht geschehen.
  Future<UserResponse> _registerUserIfNeeded() async {
    final vaultName = _sessionService.vaultName;
    var user = _sessionService.user!;
    var settings = _sessionService.settings!;
    if (settings.encryptedPrivateKey.isEmpty) throw Exception("Privater Schlüssel fehlt");
    if (settings.salt.isEmpty) throw Exception("Salt fehlt");

    // Benutzer suchen
    var userResponse = await _webService.findUser(vaultName, user.name);

    // Benutzer registrieren, wenn noch nicht vorhanden
    if (userResponse == null) {
      userResponse = await _webService.registerUser(
        vaultName: vaultName,
        userName: user.name,
        userUuid: user.uuid,
        salt: settings.salt,
        publicKey: user.publicKey,
        encryptedPrivateKey: settings.encryptedPrivateKey,
      );

      // Die vom Server erhaltene UUID speichern
      user = user.copyWith(uuid: userResponse.userUuid);
      user = await _databaseService.saveUser(user);

      // Session aktualisieren
      _sessionService.setSession(
        user: user,
        privateKey: _sessionService.privateKey!,
        vaultName: _sessionService.vaultName,
        settings: settings,
      );
    }
    else {
      if (userResponse.salt != settings.salt || userResponse.encryptedPrivateKey != settings.encryptedPrivateKey) {
        /// Überträgt eine Passwortänderung (neues Salt und verschlüsselter Private Key) zum Server.
        await _webService.changePassword(_sessionService.user!.uuid, settings.salt, settings.encryptedPrivateKey);
      }
    }

    return userResponse;
  }

  /// Lädt die Freundesliste vom Server und verarbeitet Namensänderungen, Key-Wechsel und gelöschte Freunde.
  Future<void> _pullFriends() async {
    if (_sessionService.privateKey == null) throw Exception("RSA PrivateKey nicht gefunden");

    // 1. Clientseitig gespeicherte Benutzer holen
    final localUsers = await _databaseService.getUsers();

    // 2. Öffentliche Schlüssel aller Benutzer vom Server holen
    final publicKeys = await _webService.getPublicKeys(_userResponse!.userUuid);

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
    final encryptedFriends = _userResponse!.encryptedFriends;
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
  /// Zurückgegeben wird der aktuelle Zeitstempel des Servers zum Zeitpunkt der Anfrage.
  Future<DateTime> _pullEntries(SyncStatistics stats) async {
    // 1. Neue und geänderte Einträge vom Server herunterladen
    final pullResponse = await _webService.pullSync(_userResponse!.userUuid, _sessionService.settings!.lastSyncAt);

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
        stats.pullDeleted++;
      }
    }

    // 3. Fremde Einträge löschen, bei denen mir das Recht entzogen wurde (AccessLevel == 0)
    for (var entryDto in pullResponse.updates.where((u) => u.accessLevel == 0)) {
      final entry = await _databaseService.getEntryByUuid(entryDto.entryUuid);
      if (entry != null) {
        // Hier kein lokaler Tombstone, da der Eintrag im Tresor auf dem Gerät des Freundes ja noch existiert (nur für mich unsichtbar).
        await _databaseService.deleteEntry(entry.id);
        stats.pullDeleted++;
      }
    }

    // 4. Vorbereitung: Alle lokalen User laden, um UUIDs in IDs aufzulösen
    final localUsers = await _databaseService.getUsers();
    final userUuidMap = {for (var u in localUsers) u.uuid: u.id};

    // 5. Updates einspielen
    for (var entryDto in pullResponse.updates.where((u) => u.accessLevel > 0)) {
      // 5.1 Suchfelder aus dem verschlüsselten Payload extrahieren
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
          throw Exception("Eintrag ${entryDto.entryUuid} konnte nicht extrahiert werden: $e");
        }
      }

      // 5.2 Statistik aktualisieren
      final existing = await _databaseService.getEntryByUuid(entryDto.entryUuid);
      if (existing == null) {
        stats.pullAdded++;
      } else {
        stats.pullUpdated++;
      }

      // 5.3 Eintrag speichern
      final savedEntry = await _databaseService.saveEntry(EntryEntity(
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
      ));

      // 5.4 Eigene Permission (UserId 1) speichern
      if (entryDto.encryptedKey != null && entryDto.encryptedKey!.isNotEmpty) {
        await _databaseService.savePermission(PermissionEntity(
          id: 0,
          entryId: savedEntry.id,
          userId: 1,
          encryptedKey: entryDto.encryptedKey!,
          accessLevel: entryDto.accessLevel,
        ));
      }

      // 5.5 Freunde verarbeiten
      for (var remoteFriends in entryDto.friends) {
        // Wir speichern die Permission nur, wenn wir den User lokal kennen (aus dem Settings-Pull)
        final friendUserId = userUuidMap[remoteFriends.userUuid];
        if (friendUserId != null) {
          await _databaseService.savePermission(PermissionEntity(
            id: 0,
            entryId: savedEntry.id,
            userId: friendUserId,
            encryptedKey: remoteFriends.encryptedKey ?? '',
            accessLevel: remoteFriends.accessLevel,
          ));
        }
      }

      // 5.6 Anhänge verarbeiten
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

      // 5.7 Lokale Anhänge löschen, die auf dem Server nicht mehr existieren
      final remoteUuidsSet = remoteAttachmentUuids.toSet();
      for (var l in localAttachments) {
        if (!remoteUuidsSet.contains(l.uuid)) {
          await _databaseService.deleteAttachment(l.id);
        }
      }
    }

    return pullResponse.serverTime;
  }

  /// Updatet die Einträge auf dem Server.
  Future<void> _pushEntries(SyncStatistics stats) async {
    var userUuid = _userResponse!.userUuid;

    // Veränderungen seit dem letzten Push ermitteln
    final lastSyncAt = _sessionService.settings!.lastSyncAt;
    final localUpdates = await _databaseService.getEntriesSince(lastSyncAt);
    final localDeletes = await _databaseService.getTombstonesSince(lastSyncAt);
    final unsyncedAttachments = await _databaseService.getAttachmentsUnsynced();

    if (localUpdates.isNotEmpty || localDeletes.isNotEmpty || unsyncedAttachments.isNotEmpty) {
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
        final friends = perms
            .where((p) => p.userId > 1)
            .map((p) {
          final uUuid = userMap[p.userId];
          if (uUuid == null || uUuid.isEmpty) return null;
          return FriendPermissionDto(
            userUuid: uUuid,
            encryptedKey: p.encryptedKey,
            accessLevel: p.accessLevel,
          );
        }).nonNulls // Nur bekannte UUIDs, nulls filtern
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

      // 2. Zu pushende Deletes ermitteln
      final pushDeletes = localDeletes
          .map(
            (d) => SyncDeleteDto(
          entryUuid: d.entryUuid,
          deletedAt: d.deletedAt,
        ),
      )
          .toList();

      // 3. Updates und Deletes an den Server pushen
      if (pushUpdates.isNotEmpty || pushDeletes.isNotEmpty) {
        await _webService.pushSync(userUuid, SyncPushRequest(updates: pushUpdates, deletes: pushDeletes));
        stats.pushSent = pushUpdates.length + pushDeletes.length;
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
    }
  }

  /// Verschlüsselt die Freunde und lädt sie auf den Server hoch.
  Future<void> _pushFriends() async {
    if (_sessionService.privateKey == null) throw Exception("RSA PrivateKey nicht gefunden");

    // Wir nutzen HKDF, um aus dem RSA-Private-Key einen stabilen AES-Key für die Freundesliste abzuleiten.
    final aesKey = _cryptoService.deriveKeyFromKey(_sessionService.privateKey!, null, 'friends-list-encryption');
    try {
      // 1. Alle lokal hinzugefügten Freunde laden
      final users = await _databaseService.getUsers();
      final friends = users
          .where((u) => u.id > 1)
          .map(
            (u) => FriendPayload(
          uuid: u.uuid,
          name: u.name,
          isVerified: u.isVerified,
          isHidden: u.isHidden,
          updatedAt: u.updatedAt,
        ),
      )
          .toList();

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

  // ------------------------------------------------------------------------
  // --- Convenience Getter ---
  // ------------------------------------------------------------------------

  /// Gibt den Name des aktuell geöffneten Tresors zurück.
  String getVaultName() {
    return _sessionService.vaultName;
  }

  /// Gibt im Falle eines `syncSaltMismatch`-Errors an, ob ein Zweitgerät zum
  /// ersten mal mit dem Tresor auf dem Server synchronisiert werden soll.
  ///
  /// Dies trifft zu, wenn die vom Server gelieferte Benutzer-UUID nicht mit
  /// der lokalen übereinstimmt. Andernfalls wurde auf dem anderen Gerät das
  /// Passwort geändert.
  bool isOnboarding() {
    final myUuid = _sessionService.user != null ? _sessionService.user!.uuid : '';
    final otherUuid = _userResponse != null ? _userResponse!.userUuid : '';
    return otherUuid != myUuid;
  }
}
