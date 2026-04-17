import 'dart:convert';
import 'dart:typed_data';
import 'detail_notifier_test.mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/detail/detail_notifier.dart';
import 'package:privault/features/detail/detail_state.dart';
import 'package:privault/models/payloads/entry_payload.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/password_service.dart';
import 'package:privault/services/session_service.dart';


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

    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  EntryPayload createTestPayload({String password = 'pw'}) {
    return EntryPayload(
      category: 'C',
      title: 'T',
      username: 'user',
      password: password,
      url: 'u',
      notes: 'n',
      passwordTimestamp: DateTime.now(),
      favicon: '',
    );
  }

  group('DetailNotifier Tests', () {
    test('1.1.1 load: Entschlüsselt Daten und lädt Metadaten korrekt', () async {
      final entry = EntryEntity(
        id: 10,
        uuid: 'e1',
        creatorId: 1,
        updaterId: 1,
        updatedAt: DateTime.now(),
        encryptedData: 'ENC_DATA',
        encryptedIndex: '',
      );
      final myPerm = PermissionEntity(id: 1, entryId: 10, userId: 1, encryptedKey: 'ENC_KEY', accessLevel: 3);
      final entryKey = Uint8List(32);
      final privateKey = Uint8List(32);

      final payload = createTestPayload(password: 'pw');
      final payloadJson = json.encode(payload.toJson());

      // Stubs
      when(mockDb.getEntry(10)).thenAnswer((_) async => entry);
      when(mockDb.getPermissionByEntryIdAndUserId(10, 1)).thenAnswer((_) async => myPerm);
      when(mockSession.privateKey).thenReturn(privateKey);
      when(mockCrypto.decryptRsa('ENC_KEY', Uint8List(0))).thenAnswer((_) async => entryKey);
      when(mockCrypto.decrypt('ENC_DATA', entryKey)).thenAnswer((_) async => Uint8List.fromList(utf8.encode(payloadJson)));
      when(mockPw.estimateStrength('pw')).thenReturn(4);
      when(mockDb.getUser(1)).thenAnswer((_) async => UserEntity(
        id: 1,
        uuid: 'u',
        name: 'Alice',
        publicKey: 'p',
        isVerified: true,
        isHidden: false,
        updatedAt: DateTime.now()),
      );
      when(mockDb.getAttachmentsByEntryId(10)).thenAnswer((_) async => []);
      when(mockDb.getNotHiddenFriendsWithAccessLevel(10)).thenAnswer((_) async => []);

      final notifier = container.read(detailProvider.notifier);
      await notifier.load(10);

      final state = container.read(detailProvider);
      expect(state.status, equals(DetailActionStatus.loaded));
      expect(state.title, equals('T'));
      expect(state.password, equals('pw'));
      expect(state.passwordStrength, equals(4));
      expect(state.auditHint, contains('Alice'));
    });

    test('2.1.1 shareWith: Verschlüsselt Entry-Key für einen Freund neu', () async {
      // Voraussetzung: Eintrag muss geladen sein
      final entry = EntryEntity(
        id: 10,
        uuid: 'e1',
        creatorId: 1,
        updaterId: 1,
        updatedAt: DateTime.now(),
        encryptedData: 'D',
        encryptedIndex: '',
    );
      final friend = UserEntity(
        id: 2,
        uuid: 'f1',
        name: 'Bob',
        publicKey: 'FRIEND_PUB',
        isVerified: true,
        isHidden: false,
        updatedAt: DateTime.now(),
      );

      final entryKey = Uint8List(32);
      when(mockDb.getEntry(10)).thenAnswer((_) async => entry);
      when(mockDb.getPermissionByEntryIdAndUserId(10, 1))
          .thenAnswer((_) async => PermissionEntity(id: 1, entryId: 10, userId: 1, encryptedKey: 'K', accessLevel: 3));
      when(mockSession.privateKey).thenReturn(Uint8List(32));
      when(mockCrypto.decryptRsa(any, Uint8List(0))).thenAnswer((_) async => entryKey);
      when(mockCrypto.decrypt(any, any)).thenAnswer((_) async =>
          Uint8List.fromList(utf8.encode(json.encode(createTestPayload().toJson()))));
      when(mockPw.estimateStrength(any)).thenReturn(0);
      when(mockDb.getAttachmentsByEntryId(any)).thenAnswer((_) async => []);
      when(mockDb.getNotHiddenFriendsWithAccessLevel(any)).thenAnswer((_) async => []);
      when(mockDb.getUser(any)).thenAnswer((_) async => UserEntity(
        id: 1,
        uuid: 'u',
        name: 'A',
        publicKey: 'p',
        isVerified: true,
        isHidden: false,
        updatedAt: DateTime.now()),
      );

      final notifier = container.read(detailProvider.notifier);
      await notifier.load(10);

      // Jetzt das eigentliche Teilen testen
      when(mockDb.getPermissionByEntryIdAndUserId(10, 2)).thenAnswer((_) async => null); // Noch keine Permission
      when(mockCrypto.encryptRsa(entryKey, 'FRIEND_PUB')).thenAnswer((_) async => 'ENC_KEY_FOR_FRIEND');
      when(mockDb.savePermission(any)).thenAnswer((inv) async => inv.positionalArguments[0]);
      when(mockDb.saveEntry(any)).thenAnswer((inv) async => inv.positionalArguments[0]);

      await notifier.shareWith(friend);

      // Verifizieren, dass der Key für den Freund verschlüsselt wurde
      verify(mockCrypto.encryptRsa(entryKey, 'FRIEND_PUB')).called(1);
      verify(mockDb.savePermission(argThat(predicate<PermissionEntity>(
          (p) => p.userId == 2 && p.encryptedKey == 'ENC_KEY_FOR_FRIEND')))).called(1);
    });

    test('3.1.1 deleteAttachment: Löscht Anhang und aktualisiert UI', () async {
      // Setup: Geladener Eintrag
      final attachment =
          AttachmentEntity(id: 100, uuid: 'a1', entryId: 10, encryptedMeta: 'M', encryptedContent: 'C', isSynced: true);

      // Mocks für load() ...
      when(mockDb.getEntry(10)).thenAnswer((_) async => EntryEntity(
        id: 10,
        uuid: 'e1',
        creatorId: 1,
        updaterId: 1,
        updatedAt: DateTime.now(),
        encryptedData: 'D',
        encryptedIndex: '',
      ));
      when(mockDb.getPermissionByEntryIdAndUserId(10, 1))
          .thenAnswer((_) async => PermissionEntity(id: 1, entryId: 10, userId: 1, encryptedKey: 'K', accessLevel: 3));
      when(mockSession.privateKey).thenReturn(Uint8List(32));
      when(mockCrypto.decryptRsa(any, Uint8List(0))).thenAnswer((_) async => Uint8List(32));
      when(mockCrypto.decrypt(any, any)).thenAnswer((_) async =>
          Uint8List.fromList(utf8.encode(json.encode(createTestPayload().toJson()))));
      when(mockPw.estimateStrength(any)).thenReturn(0);
      when(mockDb.getUser(any)).thenAnswer((_) async => null);
      when(mockDb.getAttachmentsByEntryId(10)).thenAnswer((_) async => []);
      when(mockDb.getNotHiddenFriendsWithAccessLevel(10)).thenAnswer((_) async => []);

      final notifier = container.read(detailProvider.notifier);
      await notifier.load(10);

      // Löschvorgang
      when(mockDb.deleteAttachment(100)).thenAnswer((_) async => {});

      await notifier.deleteAttachment(attachment);

      verify(mockDb.deleteAttachment(100)).called(1);
      expect(container.read(detailProvider).status, equals(DetailActionStatus.attachmentDeleted));
    });
  });
}
