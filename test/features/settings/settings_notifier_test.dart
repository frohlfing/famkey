import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:famkey/core/env.dart';
import 'package:famkey/core/logger.dart';
import 'package:famkey/core/service_locator.dart';
import 'package:famkey/database/database.dart';
import 'package:famkey/features/settings/delete_vault/delete_vault_notifier.dart';
import 'package:famkey/features/settings/delete_vault/delete_vault_state.dart';
import 'package:famkey/features/settings/settings_notifier.dart';
import 'package:famkey/features/settings/settings_state.dart';
import 'package:famkey/services/autofill_service.dart';
import 'package:famkey/services/autotype_service.dart';
import 'package:famkey/services/biometric_service.dart';
import 'package:famkey/services/clipboard_service.dart';
import 'package:famkey/services/config_service.dart';
import 'package:famkey/services/crypto_service.dart';
import 'package:famkey/services/database_service.dart';
import 'package:famkey/services/info_service.dart';
import 'package:famkey/services/session_service.dart';
import 'package:famkey/services/web_service.dart';

import 'settings_notifier_test.mocks.dart';

@GenerateMocks([
  AutofillService,
  AutotypeService,
  BiometricService,
  ClipboardService,
  ConfigService,
  CryptoService,
  DatabaseService,
  InfoService,
  SessionService,
  WebService,
])
void main() {
  late ProviderContainer container;
  late MockAutofillService mockAutofill;
  late MockAutotypeService mockAutotype;
  late MockBiometricService mockBio;
  late MockClipboardService mockClipboard;
  late MockConfigService mockConfig;
  late MockCryptoService mockCrypto;
  late MockDatabaseService mockDb;
  late MockInfoService mockInfo;
  late MockSessionService mockSession;
  late MockWebService mockWeb;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => Directory.systemTemp.path,
    );
    await env.init();
  });

  setUp(() async {
    mockAutofill = MockAutofillService();
    mockAutotype = MockAutotypeService();
    mockBio = MockBiometricService();
    mockClipboard = MockClipboardService();
    mockConfig = MockConfigService();
    mockCrypto = MockCryptoService();
    mockDb = MockDatabaseService();
    mockInfo = MockInfoService();
    mockSession = MockSessionService();
    mockWeb = MockWebService();

    await getIt.reset();
    getIt.registerSingleton<AutofillService>(mockAutofill);
    getIt.registerSingleton<AutotypeService>(mockAutotype);
    getIt.registerSingleton<BiometricService>(mockBio);
    getIt.registerSingleton<ClipboardService>(mockClipboard);
    getIt.registerSingleton<ConfigService>(mockConfig);
    getIt.registerSingleton<CryptoService>(mockCrypto);
    getIt.registerSingleton<DatabaseService>(mockDb);
    getIt.registerSingleton<InfoService>(mockInfo);
    getIt.registerSingleton<SessionService>(mockSession);
    getIt.registerSingleton<WebService>(mockWeb);

    // Standard-Stubs für load(), damit es in jedem Test funktioniert
    when(mockDb.getNotHiddenFriends()).thenAnswer((_) async => []);
    when(mockDb.getUserIdsWithEmptyEntryKeys()).thenAnswer((_) async => []);
    when(mockSession.vaultName).thenReturn('MyVault');
    when(mockSession.user).thenReturn(null);
    // Stubs für SettingsNotifier.build()
    when(mockBio.canOpenSettings).thenReturn(false);
    when(mockAutofill.isSupported).thenReturn(false);
    when(mockAutotype.isSupported).thenReturn(false);
    when(mockInfo.canOpenSettings).thenReturn(false);
    when(mockInfo.syncProtocolVersion).thenReturn(1);
    when(mockInfo.schemaVersion).thenReturn(1);
    when(mockInfo.version).thenAnswer((_) async => '1.0.0');
    // ConfigService-Stubs (werden in build(), load() und setThemeMode() benötigt)
    when(mockConfig.themeMode).thenReturn(ThemeMode.system);
    when(mockConfig.logLevel).thenReturn(LogLevel.info);
    when(mockConfig.logDays).thenReturn(7);
    when(mockConfig.logSize).thenReturn(0);
    when(mockConfig.autoLockSeconds).thenReturn(null);
    when(mockConfig.clipboardClearSeconds).thenReturn(null);
    when(mockConfig.isAutotypeEnabled).thenReturn(false);
    when(mockConfig.autotypeHotkey).thenReturn('');
    when(mockConfig.lastVaultName).thenReturn('MyVault');
    // AutofillService-Stubs für load()
    when(mockAutofill.isAutofillEnabled()).thenAnswer((_) async => false);

    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('SettingsNotifier Tests', () {

    test('1.1.1 load: Lädt Einstellungen und Freunde korrekt', () async {
      final settings = SettingsEntity(
          id: 1, salt: 's', encryptedPrivateKey: 'e', masterKeyTimestamp: DateTime.now(),
          host: 'https://host', apiToken: 't', lastSyncAt: DateTime(2024),
          useBiometric: true, pwLength: 16, pwSpecialChars: '!', pwAvoidIlO0: true,
          categoryPlaceholder: 'Work'
      );
      final friends = [
        UserEntity(id: 2, uuid: 'f1', name: 'Bob', publicKey: 'pub', isVerified: false, isHidden: false,
            syncedName: '', updatedAt: DateTime.now())
      ];

      when(mockDb.getSettings()).thenAnswer((_) async => settings);
      when(mockDb.getNotHiddenFriends()).thenAnswer((_) async => friends);
      when(mockCrypto.fingerprint('pub')).thenReturn('AA:BB:CC');

      final notifier = container.read(settingsProvider.notifier);
      await notifier.load();

      final state = container.read(settingsProvider);
      expect(state.status, equals(SettingsActionStatus.loaded));
      expect(state.vaultName, equals('MyVault'));
      expect(state.friends.length, equals(1));

      // Fingerprint-Check: Berücksichtigt den Zero Width Space (\u200B) nach den Doppelpunkten
      expect(state.fingerprints[2], equals('AA:\u200BBB:\u200BCC'));
      verify(mockCrypto.fingerprint('pub')).called(1);
    });

    test('2.1.1 saveBiometricSettings: Deaktivierung löscht Secure-Store Key', () async {
      final settings = SettingsEntity(
          id: 1, salt: 's', encryptedPrivateKey: 'e', masterKeyTimestamp: DateTime.now(),
          host: 'h', apiToken: 't', lastSyncAt: DateTime.now(),
          useBiometric: true, pwLength: 16, pwSpecialChars: '!', pwAvoidIlO0: true,
          categoryPlaceholder: ''
      );

      when(mockDb.getSettings()).thenAnswer((_) async => settings);
      when(mockDb.saveSettings(any)).thenAnswer((inv) async => inv.positionalArguments[0]);
      when(mockBio.removeMasterKey(any)).thenAnswer((_) async => {});

      final notifier = container.read(settingsProvider.notifier);
      await notifier.load();

      await notifier.saveBiometricSettings(false);

      expect(container.read(settingsProvider).useBiometric, isFalse);
      verify(mockBio.removeMasterKey('MyVault')).called(1);
      verify(mockDb.saveSettings(argThat(predicate<SettingsEntity>((s) => s.useBiometric == false)))).called(1);
    });

    test('3.1.1 setThemeMode: Persistiert Auswahl im ConfigService', () {
      final notifier = container.read(settingsProvider.notifier);

      notifier.setThemeMode(ThemeMode.dark);

      expect(container.read(settingsProvider).themeMode, equals(ThemeMode.dark));
    });

    test('4.1.1 toggleVerification: Rekeying bei Verifizierung', () async {
      final friend = UserEntity(id: 2, uuid: 'f1', name: 'Bob', publicKey: 'friend-pub', isVerified: false, isHidden: false,
          syncedName: '', updatedAt: DateTime.now());
      final myPerm = PermissionEntity(id: 1, entryId: 10, userId: 1, encryptedKey: 'my-enc-key', accessLevel: 3);
      final friendPerm = PermissionEntity(id: 2, entryId: 10, userId: 2, encryptedKey: '', accessLevel: 1);

      when(mockSession.privateKey).thenReturn(Uint8List(32));
      when(mockDb.getPermissionsWithoutKeyByUserId(2)).thenAnswer((_) async => [friendPerm]);
      when(mockDb.getPermissionByEntryIdAndUserId(10, 1)).thenAnswer((_) async => myPerm);
      when(mockDb.savePermission(any)).thenAnswer((inv) async => inv.positionalArguments[0]);
      when(mockDb.saveUser(any)).thenAnswer((inv) async => inv.positionalArguments[0]);

      when(mockCrypto.decryptRsa(any, any)).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
      when(mockCrypto.encryptRsa(any, any)).thenAnswer((_) async => 'new-friend-enc-key');

      final notifier = container.read(settingsProvider.notifier);

      await notifier.toggleVerification(friend);

      verify(mockDb.savePermission(argThat(predicate<PermissionEntity>((p) => p.encryptedKey == 'new-friend-enc-key')))).called(1);
      verify(mockDb.saveUser(argThat(predicate<UserEntity>((u) => u.isVerified == true)))).called(1);
    });

    test('5.1.1 deleteVaultLocal: Bereinigt alle lokalen Daten', () async {
      final settings = SettingsEntity(
        id: 1, salt: base64Encode(Uint8List(16)), encryptedPrivateKey: 'e', masterKeyTimestamp: DateTime.now(),
        host: '', apiToken: '', lastSyncAt: DateTime(0),
        useBiometric: false, pwLength: 16, pwSpecialChars: '!', pwAvoidIlO0: true,
        categoryPlaceholder: '',
      );
      when(mockSession.settings).thenReturn(settings);
      when(mockCrypto.deriveKey(any, any)).thenAnswer((_) async => Uint8List(32));
      when(mockCrypto.decrypt(any, any)).thenAnswer((_) async => Uint8List(32));
      when(mockDb.deleteCurrentDatabaseAndSaltFile()).thenAnswer((_) async => {});
      when(mockBio.removeMasterKey('MyVault')).thenAnswer((_) async => {});

      final notifier = container.read(deleteVaultProvider.notifier);
      notifier.setDeleteLocal(true);
      notifier.setPassword('password');
      await notifier.confirm();

      expect(container.read(deleteVaultProvider).status, equals(DeleteVaultActionStatus.deleted));
      verify(mockDb.deleteCurrentDatabaseAndSaltFile()).called(1);
      verify(mockBio.removeMasterKey('MyVault')).called(1);
      verify(mockSession.clearSession()).called(1);
    });

    test('5.2.1 deleteVaultServer: Löscht Tresor auf dem Server und setzt lastSyncAt zurück', () async {
      final settings = SettingsEntity(
        id: 1, salt: base64Encode(Uint8List(16)), encryptedPrivateKey: 'e', masterKeyTimestamp: DateTime.now(),
        host: 'https://host', apiToken: 't', lastSyncAt: DateTime(2024),
        useBiometric: false, pwLength: 16, pwSpecialChars: '!', pwAvoidIlO0: true,
        categoryPlaceholder: '',
      );
      final user = UserEntity(
        id: 1, uuid: 'u1', name: 'Alice', publicKey: 'pub',
        isVerified: true, isHidden: false, syncedName: 'Alice', updatedAt: DateTime.now(),
      );

      when(mockDb.getSettings()).thenAnswer((_) async => settings);
      when(mockSession.user).thenReturn(user);
      when(mockSession.settings).thenReturn(settings);
      when(mockSession.privateKey).thenReturn(Uint8List(32));
      when(mockCrypto.deriveKey(any, any)).thenAnswer((_) async => Uint8List(32));
      when(mockCrypto.decrypt(any, any)).thenAnswer((_) async => Uint8List(32));
      when(mockWeb.deleteVault('u1')).thenAnswer((_) async => {});
      when(mockDb.saveSettings(any)).thenAnswer((inv) async => inv.positionalArguments[0]);

      final notifier = container.read(deleteVaultProvider.notifier);
      await notifier.load(); // setzt _settings
      notifier.setDeleteServer(true);
      notifier.setPassword('password');
      await notifier.confirm();

      verify(mockWeb.deleteVault('u1')).called(1);
      // lastSyncAt muss auf Epoch zurückgesetzt worden sein
      verify(mockDb.saveSettings(argThat(predicate<SettingsEntity>(
              (s) => s.lastSyncAt.millisecondsSinceEpoch == 0)))).called(1);
      expect(container.read(deleteVaultProvider).isRegistered, isFalse);
      expect(container.read(deleteVaultProvider).status, equals(DeleteVaultActionStatus.saved));
    });

    test('5.3.1 deleteVaultBoth: Löscht Server und Gerät', () async {
      final settings = SettingsEntity(
        id: 1, salt: base64Encode(Uint8List(16)), encryptedPrivateKey: 'e', masterKeyTimestamp: DateTime.now(),
        host: 'https://host', apiToken: 't', lastSyncAt: DateTime(2024),
        useBiometric: false, pwLength: 16, pwSpecialChars: '!', pwAvoidIlO0: true,
        categoryPlaceholder: '',
      );
      final user = UserEntity(
        id: 1, uuid: 'u1', name: 'Alice', publicKey: 'pub',
        isVerified: true, isHidden: false, syncedName: 'Alice', updatedAt: DateTime.now(),
      );

      when(mockDb.getSettings()).thenAnswer((_) async => settings);
      when(mockSession.user).thenReturn(user);
      when(mockSession.settings).thenReturn(settings);
      when(mockSession.privateKey).thenReturn(Uint8List(32));
      when(mockCrypto.deriveKey(any, any)).thenAnswer((_) async => Uint8List(32));
      when(mockCrypto.decrypt(any, any)).thenAnswer((_) async => Uint8List(32));
      when(mockWeb.deleteVault('u1')).thenAnswer((_) async => {});
      when(mockDb.deleteCurrentDatabaseAndSaltFile()).thenAnswer((_) async => {});
      when(mockBio.removeMasterKey('MyVault')).thenAnswer((_) async => {});

      final notifier = container.read(deleteVaultProvider.notifier);
      await notifier.load();
      notifier.setDeleteServer(true);
      notifier.setDeleteLocal(true);
      notifier.setPassword('password');
      await notifier.confirm();

      verify(mockWeb.deleteVault('u1')).called(1);
      verify(mockDb.deleteCurrentDatabaseAndSaltFile()).called(1);
      verify(mockBio.removeMasterKey('MyVault')).called(1);
      verify(mockSession.clearSession()).called(1);
      expect(container.read(deleteVaultProvider).status, equals(DeleteVaultActionStatus.deleted));
    });

    test('6.1.1 deleteFriend: Löscht Freund physisch, wenn keine Verknüpfungen existieren', () async {
      final friend = UserEntity(id: 2, uuid: 'f1', name: 'Bob', publicKey: 'pub', isVerified: true, isHidden: false,
          syncedName: '', updatedAt: DateTime.now());

      // Keine Berechtigungen für diesen Freund gefunden
      when(mockDb.getPermissionsByUserId(2)).thenAnswer((_) async => []);
      when(mockDb.deleteUser(2)).thenAnswer((_) async => {});

      final notifier = container.read(settingsProvider.notifier);
      await notifier.deleteFriend(friend);

      verify(mockDb.deleteUser(2)).called(1);
      verifyNever(mockDb.hideUser(any));
      expect(container.read(settingsProvider).status, equals(SettingsActionStatus.friendDeleted));
    });

    test('6.1.2 deleteFriend: Versteckt Freund nur, wenn noch Verknüpfungen existieren', () async {
      final friend = UserEntity(id: 2, uuid: 'f1', name: 'Bob', publicKey: 'pub', isVerified: true, isHidden: false,
          syncedName: '', updatedAt: DateTime.now());
      final perm = PermissionEntity(id: 5, entryId: 10, userId: 2, encryptedKey: 'k', accessLevel: 1);

      // Berechtigung existiert -> darf nicht physisch gelöscht werden
      when(mockDb.getPermissionsByUserId(2)).thenAnswer((_) async => [perm]);
      when(mockDb.hideUser(2)).thenAnswer((_) async => {});

      final notifier = container.read(settingsProvider.notifier);
      await notifier.deleteFriend(friend);

      verify(mockDb.hideUser(2)).called(1);
      verifyNever(mockDb.deleteUser(any));
    });
  });
}
