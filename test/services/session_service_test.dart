import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:privault/database/database.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/session_service.dart';

import 'session_service_test.mocks.dart';

@GenerateMocks([CryptoService])
void main() {
  group('SessionService Tests', () {
    late SessionService sut;
    late MockCryptoService mockCryptoService;

    setUp(() {
      mockCryptoService = MockCryptoService();
      when(mockCryptoService.deriveKeyFromKey(any, any, any)).thenReturn(Uint8List(32));
      sut = SessionService(mockCryptoService);
    });

    // Hilfsmethode zum Erstellen eines Test-Users (passend zu Deiner database.dart)
    UserEntity createTestUser() {
      return UserEntity(
        id: 1,
        uuid: 'u-123',
        name: 'Frank',
        publicKey: 'pub-key',
        isVerified: true,
        isHidden: false,
        updatedAt: DateTime.now(),
      );
    }

    // Hilfsmethode zum Erstellen von Test-Settings (passend zu Deiner database.dart)
    SettingsEntity createTestSettings() {
      return SettingsEntity(
        id: 1,
        salt: 'salt',
        encryptedPrivateKey: 'enc-priv',
        masterKeyTimestamp: DateTime.now(),
        host: 'https://localhost',
        apiToken: 'token',
        lastSyncAt: DateTime.now(),
        useBiometric: false,
        pwLength: 20,
        pwSpecialChars: r'!@#$',
        pwAvoidIlO0: true,
        categoryPlaceholder: 'General',
      );
    }

    test('1.1.1 User and Key properties work correctly', () async {
      final user = createTestUser();
      sut.setUser(user);
      await sut.setPrivateKey(Uint8List.fromList([1, 2, 3]));
      
      expect(sut.user, equals(user));
      expect(sut.privateKey, isNotNull);
      expect(sut.privateKey!.length, equals(3));
    });

    test('2.1.1 clearSession: Sensible Daten werden beim Logout physisch aus dem RAM gelöscht', () async {
      final secret = Uint8List.fromList([0xAA, 0xBB, 0xCC]);
      await sut.setPrivateKey(secret);
      
      sut.clearSession();
      
      // Verifiziert, dass wipeKey auf dem Secret aufgerufen wurde
      verify(mockCryptoService.wipeKey(secret)).called(1);       // privateKey
      // Der indexKey wird ebenfalls gewipet, aber sein Wert ist Uint8List(32) aus dem Stub

      expect(sut.privateKey, isNull);
    });

    test('2.1.2 clearSession: Sitzung wird vollständig zurückgesetzt', () async {
      sut.setUser(createTestUser());
      await sut.setPrivateKey(Uint8List.fromList([1, 2, 3]));
      sut.setVaultName('MyVault');
      sut.setSettings(createTestSettings());
      
      sut.clearSession();
      
      expect(sut.user, isNull);
      expect(sut.privateKey, isNull);
      expect(sut.indexKey, isNull);
      expect(sut.vaultName, isEmpty);
      expect(sut.settings, isNull);
    });

    test('2.2.1 setSession: Alle Felder werden korrekt gesetzt', () async {
      final user = createTestUser();
      final key = Uint8List.fromList([1, 2, 3]);
      final settings = createTestSettings();
      
      await sut.setSession(
        user: user, 
        privateKey: key, 
        vaultName: 'TestVault', 
        settings: settings
      );
      
      expect(sut.user, equals(user));
      expect(sut.privateKey, equals(key));
      expect(sut.vaultName, equals('TestVault'));
      expect(sut.settings, equals(settings));
    });
  });
}
