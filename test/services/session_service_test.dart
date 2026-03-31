import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:privault/database/database.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/session_service.dart';

@GenerateMocks([CryptoService])
import 'session_service_test.mocks.dart';

void main() {
  group('SessionService Tests', () {
    late SessionService sut;
    late MockCryptoService mockCryptoService;

    setUp(() {
      mockCryptoService = MockCryptoService();
      sut = SessionService(mockCryptoService);
    });

    test('1.1.1 isLoggedIn (implizit): Ist true, wenn User und Key gesetzt sind', () {
      sut.setUser(UserEntity(id: '1', name: 'Frank', publicKey: 'pub', encryptedPrivateKey: 'priv', salt: 'salt', createdAt: DateTime.now(), updatedAt: DateTime.now()));
      sut.setPrivateKey(Uint8List.fromList([1, 2, 3]));
      
      // In Dart gibt es keine explizite isLoggedIn Property im SessionService, 
      // aber wir prüfen die Logik:
      expect(sut.user, isNotNull);
      expect(sut.privateKey, isNotNull);
      expect(sut.privateKey!.isNotEmpty, isTrue);
    });

    test('2.1.1 clearSession: Sensible Daten werden beim Logout physisch aus dem RAM gelöscht', () {
      final secret = Uint8List.fromList([0xAA, 0xBB, 0xCC]);
      sut.setPrivateKey(secret);
      
      sut.clearSession();
      
      // Verifiziert, dass wipeKey auf dem Secret aufgerufen wurde
      verify(mockCryptoService.wipeKey(secret)).called(1);
      expect(sut.privateKey, isNull);
    });

    test('2.1.2 clearSession: Sitzung wird vollständig zurückgesetzt', () {
      sut.setUser(UserEntity(id: '1', name: 'Frank', publicKey: 'pub', encryptedPrivateKey: 'priv', salt: 'salt', createdAt: DateTime.now(), updatedAt: DateTime.now()));
      sut.setPrivateKey(Uint8List.fromList([1, 2, 3]));
      sut.setVaultName('MyVault');
      
      sut.clearSession();
      
      expect(sut.user, isNull);
      expect(sut.privateKey, isNull);
      expect(sut.vaultName, isEmpty);
      expect(sut.settings, isNull);
    });

    test('2.2.1 setSession: Alle Felder werden korrekt gesetzt', () {
      final user = UserEntity(id: '1', name: 'Frank', publicKey: 'pub', encryptedPrivateKey: 'priv', salt: 'salt', createdAt: DateTime.now(), updatedAt: DateTime.now());
      final key = Uint8List.fromList([1, 2, 3]);
      final settings = SettingsEntity(id: 1, userId: '1', theme: 'dark', language: 'de', createdAt: DateTime.now(), updatedAt: DateTime.now());
      
      sut.setSession(
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
