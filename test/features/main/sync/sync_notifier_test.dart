import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:privault/core/app_version.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/main/sync/sync_notifier.dart';
import 'package:privault/features/main/sync/sync_state.dart';
import 'package:privault/models/dtos/sync_dtos.dart';
import 'package:privault/models/dtos/user_response.dart';
import 'package:privault/models/dtos/version_response.dart';
import 'package:privault/services/config_service.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';
import 'package:privault/services/web_service.dart';

@GenerateMocks([
  CryptoService,
  DatabaseService,
  SessionService,
  WebService,
  ConfigService,
])
import 'sync_notifier_test.mocks.dart';

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

    // GetIt zurücksetzen und Mocks registrieren, da der Notifier getIt() nutzt
    getIt.reset();
    getIt.registerSingleton<CryptoService>(mockCrypto);
    getIt.registerSingleton<DatabaseService>(mockDb);
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
        encryptedPrivateKey: 'ENC', 
        salt: 'salt', 
        createdAt: DateTime.now(), 
        updatedAt: DateTime.now()
      );
      final settings = SettingsEntity(
        id: 1, 
        userId: 'local-uuid', 
        theme: 'system', 
        language: 'de', 
        host: 'http://localhost', 
        apiToken: 'token', 
        salt: 'salt', 
        encryptedPrivateKey: 'ENC',
        masterKeyTimestamp: DateTime.now(),
        createdAt: DateTime.now(), 
        updatedAt: DateTime.now()
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
        service: 'PriVault',
        version: '0.1.0',
        syncProtocolVersion: AppVersion.syncProtocolVersion - 1,
        minSyncProtocolVersion: 1,
        major: 0, minor: 1, patch: 0
      ));

      final notifier = container.read(syncProvider.notifier);
      await notifier.sync();

      expect(container.read(syncProvider).status, equals(SyncStatus.failure));
      verify(mockWeb.getServerVersion()).called(1);
    });

    test('1.1.3 sync: Registriert neuen Benutzer, wenn auf Server nicht vorhanden', () async {
      arrangeLoggedIn();
      
      when(mockWeb.getServerVersion()).thenAnswer((_) async => VersionResponse(
        service: 'PriVault', version: '1.0.0', 
        syncProtocolVersion: AppVersion.syncProtocolVersion, 
        minSyncProtocolVersion: 1, major: 1, minor: 0, patch: 0
      ));
      
      // User auf Server nicht gefunden
      when(mockWeb.findUser(any, any)).thenAnswer((_) async => null);
      
      // Registrierung simulieren
      final userResponse = UserResponse(
        userUuid: 'local-uuid', 
        userName: 'Alice', 
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

      // Mocks für PullFriends, PullEntries, Push...
      when(mockWeb.getPublicKeys(any)).thenAnswer((_) async => []);
      when(mockDb.getUsers()).thenAnswer((_) async => []);
      when(mockCrypto.deriveKeyFromKey(any, any, any)).thenReturn(Uint8List(32));
      when(mockDb.hasPermissionsWithoutKey()).thenAnswer((_) async => false);
      when(mockWeb.pullSync(any, any)).thenAnswer((_) async => SyncPullResponse(
        updates: [], deletes: [], serverTime: DateTime.now()
      ));
      when(mockDb.getEntriesSince(any)).thenAnswer((_) async => []);
      when(mockDb.getTombstonesSince(any)).thenAnswer((_) async => []);
      when(mockDb.getAttachmentsUnsynced()).thenAnswer((_) async => []);

      final notifier = container.read(syncProvider.notifier);
      await notifier.sync();

      expect(container.read(syncProvider).status, equals(SyncStatus.success));
      verify(mockWeb.registerUser(
        vaultName: 'VaultX',
        userName: 'Alice',
        userUuid: 'local-uuid',
        salt: 'salt',
        publicKey: 'PUB',
        encryptedPrivateKey: 'ENC',
        masterKeyTimestamp: anyNamed('masterKeyTimestamp'),
      )).called(1);
    });

    test('1.1.4 sync: Stoppt bei Adoption-Bedarf (UUID Mismatch)', () async {
      arrangeLoggedIn();
      
      when(mockWeb.getServerVersion()).thenAnswer((_) async => VersionResponse(
        service: 'PriVault', version: '1.0.0', 
        syncProtocolVersion: AppVersion.syncProtocolVersion, 
        minSyncProtocolVersion: 1, major: 1, minor: 0, patch: 0
      ));

      // Server liefert andere UUID für den gleichen Namen -> Adoption nötig
      final remoteUser = UserResponse(
        userUuid: 'other-uuid', 
        userName: 'Alice', 
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
      expect(container.read(syncProvider).adoptionUserIdentity?.userUuid, equals('other-uuid'));
    });
  });
}
