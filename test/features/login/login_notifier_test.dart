import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:famkey/core/app_error.dart';
import 'package:famkey/core/service_locator.dart';
import 'package:famkey/database/database.dart';
import 'package:famkey/features/login/login_notifier.dart';
import 'package:famkey/features/login/login_state.dart';
import 'package:famkey/services/autolock_service.dart';
import 'package:famkey/services/biometric_service.dart';
import 'package:famkey/services/config_service.dart';
import 'package:famkey/services/crypto_service.dart';
import 'package:famkey/services/database_service.dart';
import 'package:famkey/services/password_service.dart';
import 'package:famkey/services/session_service.dart';

import 'login_notifier_test.mocks.dart';

@GenerateMocks([
  AutolockService,
  BiometricService,
  ConfigService,
  CryptoService,
  DatabaseService,
  PasswordService,
  SessionService,
])
void main() {
  late ProviderContainer container;
  late MockAutolockService mockAutolock;
  late MockBiometricService mockBio;
  late MockConfigService mockConfig;
  late MockCryptoService mockCrypto;
  late MockDatabaseService mockDb;
  late MockPasswordService mockPw;
  late MockSessionService mockSession;

  setUp(() async {
    mockAutolock = MockAutolockService();
    mockBio = MockBiometricService();
    mockConfig = MockConfigService();
    mockCrypto = MockCryptoService();
    mockDb = MockDatabaseService();
    mockPw = MockPasswordService();
    mockSession = MockSessionService();

    await getIt.reset();
    getIt.registerSingleton<AutolockService>(mockAutolock);
    getIt.registerSingleton<BiometricService>(mockBio);
    getIt.registerSingleton<ConfigService>(mockConfig);
    getIt.registerSingleton<CryptoService>(mockCrypto);
    getIt.registerSingleton<DatabaseService>(mockDb);
    getIt.registerSingleton<PasswordService>(mockPw);
    getIt.registerSingleton<SessionService>(mockSession);

    // Standard-Stubs für häufig aufgerufene Methoden
    when(mockPw.estimateStrength(any)).thenReturn(0);
    when(mockConfig.lastVaultName).thenReturn('');
    when(mockConfig.autoLockSeconds).thenReturn(null);
    // Behebt MissingStubError: Wird von setVaultName im Hintergrund gerufen
    when(mockBio.containsMasterKey(any)).thenAnswer((_) async => false);

    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('LoginNotifier Tests', () {

    test('1.1.1 setVaultName: Ungültige Zeichen im Tresornamen werden ersetzt', () {
      final notifier = container.read(loginProvider.notifier);

      notifier.setVaultName('Mein/Tresor?');

      expect(container.read(loginProvider).vaultName, equals('Mein_Tresor_'));
    });

    test('2.1.1 login: Login bei existierendem Tresor öffnet Datenbank', () async {
      final notifier = container.read(loginProvider.notifier);
      final masterKey = Uint8List(32);
      final privateKey = Uint8List(32);
      final salt = Uint8List(16);

      final user = UserEntity(id: 1, uuid: 'u', name: 'N', publicKey: 'p', isVerified: true, isHidden: false,
          syncedName: '', updatedAt: DateTime.now());
      final settings = SettingsEntity(
          id: 1, salt: 's', encryptedPrivateKey: 'enc', masterKeyTimestamp: DateTime.now(),
          host: 'h', apiToken: 't', lastSyncAt: DateTime.now(), useBiometric: false,
          pwLength: 20, pwSpecialChars: '!', pwAvoidIlO0: true, categoryPlaceholder: ''
      );

      // 1. Initialisieren (lädt vorhandene Tresore)
      when(mockDb.getExistingVaults()).thenAnswer((_) async => ['Safe']);
      await notifier.load();

      // 2. Benutzereingabe simulieren
      notifier.setVaultName('Safe');
      notifier.setPassword('Secret');

      // Mocks für den Login-Flow
      when(mockDb.close()).thenAnswer((_) async => {});
      when(mockDb.getSalt('Safe')).thenAnswer((_) async => salt);
      when(mockCrypto.deriveKey('Secret', salt)).thenAnswer((_) async => masterKey);
      when(mockDb.initialize('Safe', masterKey)).thenAnswer((_) async => {});
      when(mockDb.getUser(1)).thenAnswer((_) async => user);
      when(mockDb.getSettings()).thenAnswer((_) async => settings);
      when(mockCrypto.decrypt('enc', masterKey)).thenAnswer((_) async => privateKey);

      // 3. Login ausführen
      await notifier.login();

      expect(container.read(loginProvider).status, equals(LoginActionStatus.success));
      verify(mockDb.initialize('Safe', masterKey)).called(1);
      (await verify(mockSession.setSession(
          user: user,
          privateKey: privateKey,
          vaultName: 'Safe',
          settings: settings,
      ))).called(1);
    });

    test('2.2.1 login: Falsches Passwort führt zu Fehlermeldung', () async {
      final notifier = container.read(loginProvider.notifier);
      final salt = Uint8List(16);
      final masterKey = Uint8List(32);

      // 1. Initialisieren
      when(mockDb.getExistingVaults()).thenAnswer((_) async => ['Safe']);
      when(mockBio.containsMasterKey('Safe')).thenAnswer((_) async => false);
      await notifier.load();

      // 2. Benutzereingabe simulieren
      notifier.setVaultName('Safe');
      notifier.setPassword('Wrong');

      // Mocks vorbereiten
      when(mockDb.close()).thenAnswer((_) async => {});
      when(mockDb.getSalt('Safe')).thenAnswer((_) async => salt);
      when(mockCrypto.deriveKey('Wrong', salt)).thenAnswer((_) async => masterKey);

      // SQLite Fehler simulieren
      when(mockDb.initialize('Safe', masterKey)).thenThrow(Exception('authentication failed'));

      // 3. Login ausführen
      await notifier.login();

      expect(container.read(loginProvider).status, equals(LoginActionStatus.failure));
      expect(container.read(loginProvider).error.code, equals(ErrorCode.wrongPassword));
    });

    test('2.3.1 login: Nicht existierender Tresor fragt nach Neuanlage', () async {
      final notifier = container.read(loginProvider.notifier);

      // 1. Initialisieren (Liste ist leer)
      when(mockDb.getExistingVaults()).thenAnswer((_) async => []);
      await notifier.load();

      // 2. Namen eingeben, der nicht existiert
      notifier.setVaultName('NewVault');
      notifier.setPassword('Pass');

      // 3. Login versuchen
      await notifier.login();

      // Sollte im Status "askToCreateVault" landen
      expect(container.read(loginProvider).status, equals(LoginActionStatus.askToCreateVault));
      verifyNever(mockDb.initialize(any, any));
    });
  });
}