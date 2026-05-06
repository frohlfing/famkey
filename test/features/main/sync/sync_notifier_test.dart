import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:famkey/core/service_locator.dart';
import 'package:famkey/database/database.dart';
import 'package:famkey/features/main/sync/sync_notifier.dart';
import 'package:famkey/features/main/sync/sync_state.dart';
import 'package:famkey/models/dtos/sync_dtos.dart';
import 'package:famkey/models/dtos/user_response.dart';
import 'package:famkey/models/dtos/version_response.dart';
import 'package:famkey/services/config_service.dart';
import 'package:famkey/services/crypto_service.dart';
import 'package:famkey/services/database_service.dart';
import 'package:famkey/services/info_service.dart';
import 'package:famkey/services/session_service.dart';
import 'package:famkey/services/web_service.dart';

import 'sync_notifier_test.mocks.dart';

@GenerateMocks([
  CryptoService,
  DatabaseService,
  SessionService,
  WebService,
  ConfigService,
])
void main() {
  late ProviderContainer container;
  late MockCryptoService mockCrypto;
  late MockDatabaseService mockDb;
  late MockSessionService mockSession;
  late MockWebService mockWeb;

  setUp(() {
    mockCrypto = MockCryptoService();
    mockDb = MockDatabaseService();
    mockSession = MockSessionService();
    mockWeb = MockWebService();

    getIt.reset();
    getIt.registerSingleton<CryptoService>(mockCrypto);
    getIt.registerSingleton<DatabaseService>(mockDb);
    getIt.registerSingleton<InfoService>(InfoService());
    getIt.registerSingleton<SessionService>(mockSession);
    getIt.registerSingleton<WebService>(mockWeb);

    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('SyncNotifier Tests', () {

    void arrangeLoggedIn() {
      final user = UserEntity(
          id: 1,
          uuid: 'local-uuid',
          name: 'Alice',
          publicKey: 'PUB',
          isVerified: true,
          isHidden: false,
          syncedName: '',
          updatedAt: DateTime.now()
      );

      final settings = SettingsEntity(
        id: 1,
        salt: 'salt',
        encryptedPrivateKey: 'ENC',
        masterKeyTimestamp: DateTime.now(),
        host: 'http://localhost',
        apiToken: 'token',
        lastSyncAt: DateTime.now(),
        useBiometric: false,
        pwLength: 20,
        pwSpecialChars: r'!@#$',
        pwAvoidIlO0: true,
        categoryPlaceholder: 'General',
      );

      when(mockSession.user).thenReturn(user);
      when(mockSession.settings).thenReturn(settings);
      when(mockSession.privateKey).thenReturn(Uint8List(32));
      when(mockSession.vaultName).thenReturn('VaultX');
    }

    test('1.1.1 sync: Bricht ab, wenn Session-Daten fehlen', () async {
      when(mockSession.settings).thenReturn(null);

      final notifier = container.read(syncProvider.notifier);
      await notifier.sync();

      expect(container.read(syncProvider).status, equals(SyncStatus.failure));
    });

    test('1.1.2 sync: Erkennt veraltete Server-Version', () async {
      arrangeLoggedIn();

      when(mockWeb.getServerVersion()).thenAnswer((_) async => VersionResponse(
        service: 'FamKey',
        syncProtocolVersion: 1 - 1,
        minSyncProtocolVersion: 1,
      ));

      final notifier = container.read(syncProvider.notifier);
      await notifier.sync();

      expect(container.read(syncProvider).status, equals(SyncStatus.failure));
      verify(mockWeb.getServerVersion()).called(1);
    });

    test('1.1.3 sync: Registriert neuen Benutzer, wenn auf Server nicht vorhanden', () async {
      arrangeLoggedIn();

      when(mockWeb.getServerVersion()).thenAnswer((_) async => VersionResponse(
        service: 'FamKey v1 REST-API',
        syncProtocolVersion: 1,
        minSyncProtocolVersion: 1,
      ));

      when(mockWeb.findUser(any, any)).thenAnswer((_) async => null);

      final userResponse = UserResponse(
          userUuid: 'local-uuid',
          vaultUuid: 'vault-uuid',
          userHash: 'hash',
          salt: 'salt',
          publicKey: 'PUB',
          encryptedPrivateKey: 'ENC',
          masterKeyTimestamp: DateTime.now(),
          encryptedFriends: ''
      );

      when(mockWeb.registerUser(
        vaultName: anyNamed('vaultName'),
        userName: anyNamed('userName'),
        userUuid: anyNamed('userUuid'),
        salt: anyNamed('salt'),
        publicKey: anyNamed('publicKey'),
        encryptedPrivateKey: anyNamed('encryptedPrivateKey'),
        masterKeyTimestamp: anyNamed('masterKeyTimestamp'),
      )).thenAnswer((_) async => userResponse);

      when(mockWeb.getPublicKeys(any)).thenAnswer((_) async => []);
      when(mockDb.getUsers()).thenAnswer((_) async => []);
      when(mockCrypto.deriveKeyFromKey(any, any, any)).thenAnswer((_) async => Uint8List(32));

      when(mockDb.hasPermissionsWithoutKey()).thenAnswer((_) async => false);
      when(mockWeb.pullSync(any, any)).thenAnswer((_) async => SyncPullResponse(
          updates: [], deletes: [], serverTime: DateTime.now()
      ));
      when(mockDb.getEntriesSince(any)).thenAnswer((_) async => []);
      when(mockDb.getTombstonesSince(any)).thenAnswer((_) async => []);
      when(mockDb.getAttachmentsUnsynced()).thenAnswer((_) async => []);
      when(mockDb.saveUser(any)).thenAnswer((inv) async => inv.positionalArguments[0] as UserEntity);
      when(mockDb.saveSettings(any)).thenAnswer((inv) async => inv.positionalArguments[0]);

      final notifier = container.read(syncProvider.notifier);
      await notifier.sync();

      expect(container.read(syncProvider).status, equals(SyncStatus.success));
    });

    test('1.1.4 sync: Stoppt bei Adoption-Bedarf (UUID Mismatch)', () async {
      arrangeLoggedIn();

      when(mockWeb.getServerVersion()).thenAnswer((_) async => VersionResponse(
        service: 'FamKey v1 REST-API',
        syncProtocolVersion: 1,
        minSyncProtocolVersion: 1,
      ));

      final remoteUser = UserResponse(
          userUuid: 'other-uuid',
          vaultUuid: 'vault-uuid',
          userHash: 'hash',
          salt: 'salt',
          publicKey: 'PUB',
          encryptedPrivateKey: 'ENC',
          masterKeyTimestamp: DateTime.now(),
          encryptedFriends: ''
      );
      when(mockWeb.findUser(any, any)).thenAnswer((_) async => remoteUser);

      final notifier = container.read(syncProvider.notifier);
      await notifier.sync();

      expect(container.read(syncProvider).status, equals(SyncStatus.askForAdoption));
      expect(container.read(syncProvider).adoptionUserIdentity.userUuid, equals('other-uuid'));
    });

    test('1.1.5 sync: Propagiert Benutzernamen-Umbenennung an den Server', () async {
      // User hat local name='Alice-Neu', syncedName='Alice' (= alter Servername)
      when(mockSession.user).thenReturn(UserEntity(
        id: 1, uuid: 'local-uuid', name: 'Alice-Neu',
        publicKey: 'PUB', isVerified: true, isHidden: false,
        syncedName: 'Alice', // abweichend → Rename muss propagiert werden
        updatedAt: DateTime.now(),
      ));
      final settings = SettingsEntity(
        id: 1, salt: 'salt', encryptedPrivateKey: 'ENC',
        masterKeyTimestamp: DateTime.now(), host: 'http://localhost',
        apiToken: 'token', lastSyncAt: DateTime.now(),
        useBiometric: false, pwLength: 20, pwSpecialChars: r'!@#$',
        pwAvoidIlO0: true, categoryPlaceholder: 'General',
      );
      when(mockSession.settings).thenReturn(settings);
      when(mockSession.privateKey).thenReturn(Uint8List(32));
      when(mockSession.vaultName).thenReturn('VaultX');

      when(mockWeb.getServerVersion()).thenAnswer((_) async => VersionResponse(
        service: 'FamKey v1 REST-API',
        syncProtocolVersion: 1,
        minSyncProtocolVersion: 1,
      ));

      // Server kennt 'Alice' (den syncedName), UUID stimmt überein → kein Onboarding
      final sameUuidResponse = UserResponse(
        userUuid: 'local-uuid', vaultUuid: 'vault-uuid', userHash: 'hash',
        salt: 'salt', publicKey: 'PUB', encryptedPrivateKey: 'ENC',
        masterKeyTimestamp: settings.masterKeyTimestamp, encryptedFriends: '',
      );
      when(mockWeb.findUser(any, 'Alice')).thenAnswer((_) async => sameUuidResponse);
      when(mockWeb.patchUserName('local-uuid', 'Alice-Neu')).thenAnswer((_) async => {});

      when(mockDb.saveUser(any)).thenAnswer((inv) async => inv.positionalArguments[0] as UserEntity);
      when(mockWeb.getPublicKeys(any)).thenAnswer((_) async => []);
      when(mockDb.getUsers()).thenAnswer((_) async => []);
      when(mockCrypto.deriveKeyFromKey(any, any, any)).thenAnswer((_) async => Uint8List(32));
      when(mockDb.hasPermissionsWithoutKey()).thenAnswer((_) async => false);
      when(mockWeb.pullSync(any, any)).thenAnswer((_) async =>
          SyncPullResponse(updates: [], deletes: [], serverTime: DateTime.now()));
      when(mockDb.getEntriesSince(any)).thenAnswer((_) async => []);
      when(mockDb.getTombstonesSince(any)).thenAnswer((_) async => []);
      when(mockDb.getAttachmentsUnsynced()).thenAnswer((_) async => []);
      when(mockDb.saveSettings(any)).thenAnswer((inv) async => inv.positionalArguments[0]);

      final notifier = container.read(syncProvider.notifier);
      await notifier.sync();

      // patchUserName muss mit neuem Namen aufgerufen worden sein
      verify(mockWeb.patchUserName('local-uuid', 'Alice-Neu')).called(1);
      // syncedName muss auf neuen Namen aktualisiert worden sein
      verify(mockDb.saveUser(argThat(predicate<UserEntity>(
              (u) => u.syncedName == 'Alice-Neu')))).called(1);
      expect(container.read(syncProvider).status, equals(SyncStatus.success));
    });

    test('1.1.6 sync: Registriert neuen Tresor-Mandanten nach Umbenennung', () async {
      // Nach lokaler Umbenennung kennt der Server den neuen Namen nicht →
      // findUser liefert null → frische Registrierung unter neuem Namen.
      arrangeLoggedIn(); // vaultName = 'VaultX', user.syncedName = ''

      when(mockWeb.getServerVersion()).thenAnswer((_) async => VersionResponse(
        service: 'FamKey v1 REST-API',
        syncProtocolVersion: 1,
        minSyncProtocolVersion: 1,
      ));

      // Server kennt 'VaultX' noch nicht
      when(mockWeb.findUser('VaultX', any)).thenAnswer((_) async => null);

      final newVaultResponse = UserResponse(
        userUuid: 'local-uuid', vaultUuid: 'new-vault-uuid', userHash: 'hash',
        salt: 'salt', publicKey: 'PUB', encryptedPrivateKey: 'ENC',
        masterKeyTimestamp: DateTime.now(), encryptedFriends: '',
      );
      when(mockWeb.registerUser(
        vaultName: 'VaultX',
        userName: anyNamed('userName'),
        userUuid: anyNamed('userUuid'),
        salt: anyNamed('salt'),
        publicKey: anyNamed('publicKey'),
        encryptedPrivateKey: anyNamed('encryptedPrivateKey'),
        masterKeyTimestamp: anyNamed('masterKeyTimestamp'),
      )).thenAnswer((_) async => newVaultResponse);

      when(mockDb.saveUser(any)).thenAnswer((inv) async => inv.positionalArguments[0] as UserEntity);
      when(mockWeb.getPublicKeys(any)).thenAnswer((_) async => []);
      when(mockDb.getUsers()).thenAnswer((_) async => []);
      when(mockCrypto.deriveKeyFromKey(any, any, any)).thenAnswer((_) async => Uint8List(32));
      when(mockDb.hasPermissionsWithoutKey()).thenAnswer((_) async => false);
      when(mockWeb.pullSync(any, any)).thenAnswer((_) async =>
          SyncPullResponse(updates: [], deletes: [], serverTime: DateTime.now()));
      when(mockDb.getEntriesSince(any)).thenAnswer((_) async => []);
      when(mockDb.getTombstonesSince(any)).thenAnswer((_) async => []);
      when(mockDb.getAttachmentsUnsynced()).thenAnswer((_) async => []);
      when(mockDb.saveSettings(any)).thenAnswer((inv) async => inv.positionalArguments[0]);

      final notifier = container.read(syncProvider.notifier);
      await notifier.sync();

      verify(mockWeb.registerUser(
        vaultName: 'VaultX',
        userName: anyNamed('userName'),
        userUuid: anyNamed('userUuid'),
        salt: anyNamed('salt'),
        publicKey: anyNamed('publicKey'),
        encryptedPrivateKey: anyNamed('encryptedPrivateKey'),
        masterKeyTimestamp: anyNamed('masterKeyTimestamp'),
      )).called(1);
      expect(container.read(syncProvider).status, equals(SyncStatus.success));
    });
  });
}