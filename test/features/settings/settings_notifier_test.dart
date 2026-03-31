import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/settings/settings_notifier.dart';
import 'package:privault/features/settings/settings_state.dart';
import 'package:privault/services/autofill_service.dart';
import 'package:privault/services/biometric_service.dart';
import 'package:privault/services/config_service.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';

import 'settings_notifier_test.mocks.dart';

@GenerateMocks([
  AutofillService,
  BiometricService,
  ConfigService,
  CryptoService,
  DatabaseService,
  SessionService,
])
void main() {
  late ProviderContainer container;
  late MockAutofillService mockAutofill;
  late MockBiometricService mockBio;
  late MockConfigService mockConfig;
  late MockCryptoService mockCrypto;
  late MockDatabaseService mockDb;
  late MockSessionService mockSession;

  setUp(() {
    mockAutofill = MockAutofillService();
    mockBio = MockBiometricService();
    mockConfig = MockConfigService();
    mockCrypto = MockCryptoService();
    mockDb = MockDatabaseService();
    mockSession = MockSessionService();

    getIt.reset();
    getIt.registerSingleton<AutofillService>(mockAutofill);
    getIt.registerSingleton<BiometricService>(mockBio);
    getIt.registerSingleton<ConfigService>(mockConfig);
    getIt.registerSingleton<CryptoService>(mockCrypto);
    getIt.registerSingleton<DatabaseService>(mockDb);
    getIt.registerSingleton<SessionService>(mockSession);

    // Standard-Stubs für load(), damit es in jedem Test funktioniert
    when(mockDb.getNotHiddenFriends()).thenAnswer((_) async => []);
    when(mockDb.getUserIdsWithEmptyEntryKeys()).thenAnswer((_) async => []);
    when(mockConfig.vaultStoragePath).thenReturn('/mock/path');
    when(mockConfig.themeMode).thenReturn(ThemeMode.system);
    when(mockSession.vaultName).thenReturn('MyVault');
    when(mockSession.user).thenReturn(null);

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
        UserEntity(id: 2, uuid: 'f1', name: 'Bob', publicKey: 'pub', isVerified: false, isHidden: false, updatedAt: DateTime.now())
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
      verify(mockConfig.themeMode = ThemeMode.dark).called(1);
    });

    test('4.1.1 toggleVerification: Rekeying bei Verifizierung', () async {
      final friend = UserEntity(id: 2, uuid: 'f1', name: 'Bob', publicKey: 'friend-pub', isVerified: false, isHidden: false, updatedAt: DateTime.now());
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

    test('5.1.1 deleteVault: Bereinigt alle lokalen Daten', () async {
      when(mockDb.deleteCurrentDatabaseAndSaltFile()).thenAnswer((_) async => {});
      when(mockBio.removeMasterKey('MyVault')).thenAnswer((_) async => {});
      when(mockConfig.lastVaultName).thenReturn('MyVault');

      final notifier = container.read(settingsProvider.notifier);
      await notifier.deleteVault();

      expect(container.read(settingsProvider).status, equals(SettingsActionStatus.deleted));
      verify(mockDb.deleteCurrentDatabaseAndSaltFile()).called(1);
      verify(mockBio.removeMasterKey('MyVault')).called(1);
      verify(mockConfig.lastVaultName = '').called(1);
      verify(mockSession.clearSession()).called(1);
    });

    test('6.1.1 deleteFriend: Löscht Freund physisch, wenn keine Verknüpfungen existieren', () async {
      final friend = UserEntity(id: 2, uuid: 'f1', name: 'Bob', publicKey: 'pub', isVerified: true, isHidden: false, updatedAt: DateTime.now());
      
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
      final friend = UserEntity(id: 2, uuid: 'f1', name: 'Bob', publicKey: 'pub', isVerified: true, isHidden: false, updatedAt: DateTime.now());
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
