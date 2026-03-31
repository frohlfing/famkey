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
        service: 'PriVault',
        syncProtocolVersion: AppVersion.syncProtocolVersion - 1,
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
        service: 'PriVault v1 REST-API',
        syncProtocolVersion: AppVersion.syncProtocolVersion, 
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
      when(mockCrypto.deriveKeyFromKey(any, any, any)).thenReturn(Uint8List(32));
      when(mockDb.hasPermissionsWithoutKey()).thenAnswer((_) async => false);
      when(mockWeb.pullSync(any, any)).thenAnswer((_) async => SyncPullResponse(
        updates: [], deletes: [], serverTime: DateTime.now()
      ));
      when(mockDb.getEntriesSince(any)).thenAnswer((_) async => []);
      when(mockDb.getTombstonesSince(any)).thenAnswer((_) async => []);
      when(mockDb.getAttachmentsUnsynced()).thenAnswer((_) async => []);
      when(mockDb.saveSettings(any)).thenAnswer((inv) async => inv.positionalArguments[0]);

      final notifier = container.read(syncProvider.notifier);
      await notifier.sync();

      expect(container.read(syncProvider).status, equals(SyncStatus.success));
    });

    test('1.1.4 sync: Stoppt bei Adoption-Bedarf (UUID Mismatch)', () async {
      arrangeLoggedIn();
      
      when(mockWeb.getServerVersion()).thenAnswer((_) async => VersionResponse(
        service: 'PriVault v1 REST-API',
        syncProtocolVersion: AppVersion.syncProtocolVersion, 
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
  });
}
