import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/edit/edit_notifier.dart';
import 'package:privault/features/edit/edit_state.dart';
import 'package:privault/models/payloads/entry_payload.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/password_service.dart';
import 'package:privault/services/session_service.dart';

import 'edit_notifier_test.mocks.dart';

@GenerateMocks([CryptoService, DatabaseService, PasswordService, SessionService])
void main() {
  late ProviderContainer container;
  late MockCryptoService mockCrypto;
  late MockDatabaseService mockDb;
  late MockPasswordService mockPw;
  late MockSessionService mockSession;

  setUp(() {
    mockCrypto = MockCryptoService();
    mockDb = MockDatabaseService();
    mockPw = MockPasswordService();
    mockSession = MockSessionService();

    getIt.reset();
    getIt.registerSingleton<CryptoService>(mockCrypto);
    getIt.registerSingleton<DatabaseService>(mockDb);
    getIt.registerSingleton<PasswordService>(mockPw);
    getIt.registerSingleton<SessionService>(mockSession);

    // Standard-Stub für Passwortstärke hinzufügen
    when(mockPw.estimateStrength(any)).thenReturn(0);

    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  EntryPayload createTestPayload({String password = 'p'}) {
    return EntryPayload(
      category: 'C', title: 'T', username: 'u', password: password,
      url: 'u', notes: 'n', passwordTimestamp: DateTime(2024), favicon: ''
    );
  }

  group('EditNotifier Tests', () {
    
    test('1.1.1 load (New): Initialisiert leeres Formular', () async {
      when(mockSession.privateKey).thenReturn(Uint8List(32));
      when(mockDb.getCategories()).thenAnswer((_) async => ['Work', 'Social']);

      final notifier = container.read(editProvider.notifier);
      await notifier.load(null);

      final state = container.read(editProvider);
      expect(state.status, equals(EditActionStatus.loaded));
      expect(state.entryId, equals(0));
      expect(state.formData.title, isEmpty);
      expect(state.existingCategories, contains('Work'));
    });

    test('1.2.1 load (Edit): Lädt und entschlüsselt vorhandenen Eintrag', () async {
      final entry = EntryEntity(id: 10, uuid: 'e1', category: 'C', title: 'T', url: 'u', notes: 'n', favicon: 'f', creatorId: 1, updaterId: 1, updatedAt: DateTime.now(), encryptedData: 'ENC_DATA');
      final payloadJson = json.encode(createTestPayload().toJson());

      when(mockSession.privateKey).thenReturn(Uint8List(32));
      when(mockDb.getCategories()).thenAnswer((_) async => []);
      when(mockDb.getEntry(10)).thenAnswer((_) async => entry);
      when(mockDb.getPermissionByEntryIdAndUserId(10, 1)).thenAnswer((_) async => PermissionEntity(id: 1, entryId: 10, userId: 1, encryptedKey: 'K', accessLevel: 3));
      when(mockCrypto.decryptRsa(any, any)).thenAnswer((_) async => Uint8List(32));
      when(mockCrypto.decrypt(any, any)).thenAnswer((_) async => Uint8List.fromList(utf8.encode(payloadJson)));
      when(mockPw.estimateStrength(any)).thenReturn(3);

      final notifier = container.read(editProvider.notifier);
      await notifier.load(10);

      final state = container.read(editProvider);
      expect(state.entryId, equals(10));
      expect(state.formData.title, equals('T'));
      expect(state.passwordStrength, equals(3));
    });

    test('2.1.1 save: Validiert Pflichtfelder', () async {
      final notifier = container.read(editProvider.notifier);
      await notifier.load(null);
      
      // Titel leer lassen
      notifier.setTitle('  '); 
      await notifier.save();

      expect(container.read(editProvider).error.code, equals(ErrorCode.valueRequired));
      verifyNever(mockDb.saveEntryWithPermissions(any, any, any));
    });

    test('2.2.1 save (Create): Verschlüsselt und speichert neuen Eintrag', () async {
      final user = UserEntity(id: 1, uuid: 'u', name: 'A', publicKey: 'PUB', isVerified: true, isHidden: false, updatedAt: DateTime.now());
      when(mockSession.privateKey).thenReturn(Uint8List(32));
      when(mockSession.user).thenReturn(user);
      when(mockDb.getCategories()).thenAnswer((_) async => []);
      
      final notifier = container.read(editProvider.notifier);
      await notifier.load(null);

      notifier.setTitle('New Entry');
      notifier.setPassword('Secret123');

      when(mockCrypto.encrypt(any, any)).thenAnswer((_) async => 'ENC_DATA');
      when(mockCrypto.encryptRsa(any, 'PUB')).thenAnswer((_) async => 'ENC_KEY');
      when(mockDb.saveEntryWithPermissions(any, 1, 'ENC_KEY')).thenAnswer((inv) async => (inv.positionalArguments[0] as EntryEntity).copyWith(id: 100));

      await notifier.save();

      expect(container.read(editProvider).status, equals(EditActionStatus.saved));
      expect(container.read(editProvider).entryId, equals(100));
      verify(mockDb.saveEntryWithPermissions(any, 1, 'ENC_KEY')).called(1);
    });

    test('3.1.1 deleteEntry: Löscht den Eintrag aus der DB', () async {
      // Setup: Bestehender Eintrag geladen
      final entry = EntryEntity(id: 10, uuid: 'e1', category: 'C', title: 'T', url: 'u', notes: 'n', favicon: 'f', creatorId: 1, updaterId: 1, updatedAt: DateTime.now(), encryptedData: 'D');
      when(mockSession.privateKey).thenReturn(Uint8List(32));
      when(mockDb.getCategories()).thenAnswer((_) async => []);
      when(mockDb.getEntry(10)).thenAnswer((_) async => entry);
      when(mockDb.getPermissionByEntryIdAndUserId(10, 1)).thenAnswer((_) async => PermissionEntity(id: 1, entryId: 10, userId: 1, encryptedKey: 'K', accessLevel: 3));
      when(mockCrypto.decryptRsa(any, any)).thenAnswer((_) async => Uint8List(32));
      when(mockCrypto.decrypt(any, any)).thenAnswer((_) async => Uint8List.fromList(utf8.encode(json.encode(createTestPayload().toJson()))));

      final notifier = container.read(editProvider.notifier);
      await notifier.load(10);

      when(mockDb.deleteEntry(10)).thenAnswer((_) async => {});

      await notifier.deleteEntry();

      expect(container.read(editProvider).status, equals(EditActionStatus.deleted));
      verify(mockDb.deleteEntry(10)).called(1);
    });

    test('4.1.1 generatePassword: Nutzt Einstellungen aus der Session', () {
      final settings = SettingsEntity(
        id: 1, salt: 's', encryptedPrivateKey: 'e', masterKeyTimestamp: DateTime.now(),
        host: 'h', apiToken: 't', lastSyncAt: DateTime.now(), useBiometric: false,
        pwLength: 25, pwSpecialChars: '?!', pwAvoidIlO0: true, categoryPlaceholder: ''
      );
      when(mockSession.settings).thenReturn(settings);
      when(mockPw.generatePassword(length: 25, specialChars: '?!', withUmlauts: true, avoidIlO0: true)).thenReturn('GENERATED_PW');

      final notifier = container.read(editProvider.notifier);
      notifier.generatePassword();

      expect(container.read(editProvider).formData.password, equals('GENERATED_PW'));
    });
  });
}
