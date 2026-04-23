import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/database/database.dart';
import 'package:privault/features/main/main_notifier.dart';
import 'package:privault/features/main/main_state.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';
import 'main_notifier_test.mocks.dart';

Uint8List indexBytes(String category, String title, String url, String notes) {
  final map = {'category': category, 'title': title, 'url': url, 'notes': notes, 'favicon': ''};
  return Uint8List.fromList(utf8.encode(json.encode(map)));
}

@GenerateMocks([DatabaseService, SessionService, CryptoService])
void main() {
  late ProviderContainer container;
  late MockCryptoService mockCrypto;
  late MockDatabaseService mockDb;
  late MockSessionService mockSession;

  setUp(() {
    mockCrypto = MockCryptoService();
    mockDb = MockDatabaseService();
    mockSession = MockSessionService();

    getIt.reset();
    getIt.registerSingleton<CryptoService>(mockCrypto);
    getIt.registerSingleton<DatabaseService>(mockDb);
    getIt.registerSingleton<SessionService>(mockSession);

    // Standard-Stubs für SessionService (behebt MissingStubError)
    when(mockSession.indexKey).thenReturn(Uint8List(32));
    when(mockSession.indexKey).thenReturn(Uint8List(32));
    when(mockSession.settings).thenReturn(null);
    when(mockSession.vaultName).thenReturn('TestVault');
    when(mockSession.user).thenReturn(null);

    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('MainNotifier Tests', () {

    List<EntryEntity> createTestEntries() {
      return [
        EntryEntity(id: 1, uuid: 'e1', encryptedData: '', encryptedIndex: 'IDX_1', creatorId: 1, updaterId: 1, updatedAt: DateTime.now()),
        EntryEntity(id: 2, uuid: 'e2', encryptedData: '', encryptedIndex: 'IDX_2', creatorId: 1, updaterId: 1, updatedAt: DateTime.now()),
        EntryEntity(id: 3, uuid: 'e3', encryptedData: '', encryptedIndex: 'IDX_3', creatorId: 2, updaterId: 2, updatedAt: DateTime.now()),
      ];
    }

    test('1.1.1 load: Gruppiert Einträge korrekt nach Kategorie', () async {
      final entries = createTestEntries();
      when(mockDb.getEntries()).thenAnswer((_) async => entries);
      when(mockCrypto.decrypt('IDX_1', any)).thenAnswer((_) async => indexBytes('Work',  'Mail',    'm.de', ''));
      when(mockCrypto.decrypt('IDX_2', any)).thenAnswer((_) async => indexBytes('Work',  'Slack',   's.de', ''));
      when(mockCrypto.decrypt('IDX_3', any)).thenAnswer((_) async => indexBytes('',      'Private', 'p.de', 'Secret'));
      final notifier = container.read(mainProvider.notifier);
      await notifier.load();

      final state = container.read(mainProvider);
      expect(state.status, equals(MainActionStatus.loaded));
      expect(state.groupedEntries.keys, containsAll(['Work', 'Allgemein']));
      expect(state.groupedEntries['Work']!.length, equals(2));
      expect(state.groupedEntries['Allgemein']!.length, equals(1));
    });

    test('2.1.1 search: Filtert Einträge nach Titel oder URL', () async {
      final entries = createTestEntries();
      when(mockDb.getEntries()).thenAnswer((_) async => entries);

      when(mockCrypto.decrypt('IDX_1', any)).thenAnswer((_) async => indexBytes('Work',  'Mail',    'm.de', ''));
      when(mockCrypto.decrypt('IDX_2', any)).thenAnswer((_) async => indexBytes('Work',  'Slack',   's.de', ''));
      when(mockCrypto.decrypt('IDX_3', any)).thenAnswer((_) async => indexBytes('',      'Private', 'p.de', 'Secret'));
      final notifier = container.read(mainProvider.notifier);
      await notifier.load();

      // Suche nach "slack"
      notifier.setSearchQuery('slack');

      var state = container.read(mainProvider);
      expect(state.groupedEntries['Work']!.length, equals(1));
      expect(state.groupedEntries['Work']!.first.index.title, equals('Slack'));
      expect(state.groupedEntries.containsKey('Allgemein'), isFalse);

      // Suche nach "p.de" (URL)
      notifier.setSearchQuery('p.de');
      state = container.read(mainProvider);
      expect(state.groupedEntries.containsKey('Work'), isFalse);
      expect(state.groupedEntries['Allgemein']!.first.index.title, equals('Private'));
    });

    test('3.1.1 filter: "Nur Meine" zeigt nur eigene Einträge', () async {
      final entries = createTestEntries();
      when(mockDb.getEntries()).thenAnswer((_) async => entries);

      // Stub für den User (ID 1)
      final alice = UserEntity(id: 1, uuid: 'u1', name: 'Alice', publicKey: 'p', isVerified: true, isHidden: false,
          syncedName: '', updatedAt: DateTime.now());
      when(mockSession.user).thenReturn(alice);

      when(mockCrypto.decrypt('IDX_1', any)).thenAnswer((_) async => indexBytes('Work',  'Mail',    'm.de', ''));
      when(mockCrypto.decrypt('IDX_2', any)).thenAnswer((_) async => indexBytes('Work',  'Slack',   's.de', ''));
      when(mockCrypto.decrypt('IDX_3', any)).thenAnswer((_) async => indexBytes('',      'Private', 'p.de', 'Secret'));
      final notifier = container.read(mainProvider.notifier);
      await notifier.load();

      notifier.setOnlyMyEntries(true);

      final state = container.read(mainProvider);
      // Eintrag 3 (CreatorId 2) sollte verschwinden
      expect(state.groupedEntries.containsKey('Allgemein'), isFalse);
      expect(state.groupedEntries['Work']!.length, equals(2));
    });

    test('4.1.1 toggleCategory: Merkt sich eingeklappte Gruppen', () {
      final notifier = container.read(mainProvider.notifier);

      notifier.toggleCategory('Work');
      expect(container.read(mainProvider).collapsedCategories, contains('Work'));

      notifier.toggleCategory('Work');
      expect(container.read(mainProvider).collapsedCategories, isNot(contains('Work')));
    });

    test('5.1.1 logout: Bereinigt Session und schließt DB', () {
      final notifier = container.read(mainProvider.notifier);
      when(mockDb.close()).thenAnswer((_) async => {});

      notifier.logout();

      verify(mockDb.close()).called(1);
      verify(mockSession.clearSession()).called(1);
      expect(container.read(mainProvider).groupedEntries, isEmpty);
    });
  });
}