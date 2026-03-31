import 'dart:io';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;
import 'package:privault/database/database.dart';
import 'package:privault/services/config_service.dart';
import 'package:privault/services/database_service.dart';

@GenerateMocks([ConfigService])
import 'database_service_test.mocks.dart';

void main() {
  group('DatabaseService Tests', () {
    late DatabaseService sut;
    late MockConfigService mockConfigService;
    late Directory tempDir;

    setUp(() async {
      mockConfigService = MockConfigService();
      tempDir = await Directory.systemTemp.createTemp('privault_test_');
      
      when(mockConfigService.vaultStoragePath).thenReturn(tempDir.path);
      
      sut = DatabaseService(mockConfigService);
    });

    tearDown(() async {
      await sut.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Uint8List validKey([int seed = 1]) {
      return Uint8List(32)..fillRange(0, 32, seed);
    }

    test('1.2.1 initialize: Kehrt bei Mehrfachaufruf einfach zurück', () async {
      final key = validKey();
      await sut.initialize("MultiVault", key);
      expect(sut.isInitialized, isTrue);

      // Zweiter Aufruf sollte nichts tun (keine Exception)
      await sut.initialize("MultiVault", key);
      expect(sut.isInitialized, isTrue);
    });

    test('1.3.1 Backup-Roundtrip (CreateBackup, RestoreBackup, RemoveBackup)', () async {
      const vaultName = "VaultZ";
      await sut.initialize(vaultName, validKey());
      
      final dbPath = sut.getDatabasePath(vaultName);
      final backupPath = '$dbPath.bak';
      
      expect(File(backupPath).existsSync(), isFalse);
      
      await sut.createBackup();
      expect(File(backupPath).existsSync(), isTrue);
      
      await sut.close(); // Verbindung schließen für Restore
      await sut.restoreBackup();
      expect(File(backupPath).existsSync(), isFalse);

      await sut.initialize(vaultName, validKey());
      await sut.createBackup();
      expect(File(backupPath).existsSync(), isTrue);
      
      await sut.removeBackup();
      expect(File(backupPath).existsSync(), isFalse);
    });

    test('1.5.1 deleteCurrentDatabase: Dateien werden physisch gelöscht', () async {
      const vaultName = "VaultDel";
      final key = validKey();
      await sut.initialize(vaultName, key);
      
      // Salt speichern, um Löschung zu testen
      await sut.saveSalt(vaultName, Uint8List.fromList([1, 2, 3]));
      
      expect(await sut.databaseExists(vaultName), isTrue);
      expect(File('${sut.getDatabasePath(vaultName)}.salt').existsSync(), isTrue);
      
      await sut.deleteCurrentDatabaseAndSaltFile();
      
      expect(await sut.databaseExists(vaultName), isFalse);
      expect(File('${sut.getDatabasePath(vaultName)}.salt').existsSync(), isFalse);
      expect(sut.isInitialized, isFalse);
    });

    test('2.1.1 User-Roundtrip: Speichern, Abfragen, Löschen eines Benutzers', () async {
      await sut.initialize("VaultU", validKey());
      
      final user = UserEntity(
        id: 0,
        uuid: 'u-alice',
        name: 'Alice',
        publicKey: 'pub',
        isVerified: true,
        isHidden: false,
        updatedAt: DateTime.now(),
      );
      
      final savedUser = await sut.saveUser(user);
      expect(savedUser.id, greaterThan(0));
      
      final got = await sut.getUserByUuid('u-alice');
      expect(got?.name, equals('Alice'));
      
      // Update
      final updatedUser = savedUser.copyWith(name: 'Alice Updated');
      await sut.saveUser(updatedUser);
      expect((await sut.getUser(savedUser.id))?.name, equals('Alice Updated'));
      
      // Delete
      await sut.deleteUser(savedUser.id);
      expect(await sut.getUserByUuid('u-alice'), isNull);
    });

    test('3.1.1 Entry-Roundtrip: Speichern, Abfragen, Löschen von Einträgen', () async {
      await sut.initialize("VaultE", validKey());
      
      final entry = EntryEntity(
        id: 0,
        uuid: 'e-1',
        category: 'Work',
        title: 'Secret',
        url: 'https://test.de',
        notes: 'Notes',
        favicon: '',
        encryptedData: 'DATA',
        creatorId: 1,
        updaterId: 1,
        updatedAt: DateTime.now(),
      );
      
      final savedEntry = await sut.saveEntry(entry);
      expect(savedEntry.id, greaterThan(0));
      
      final list = await sut.getEntries();
      expect(list.length, equals(1));
      expect(list.first.uuid, equals('e-1'));
      
      final categories = await sut.getCategories();
      expect(categories, contains('Work'));
      
      await sut.deleteEntry(savedEntry.id);
      expect(await sut.getEntries(), isEmpty);
    });

    test('4.1.1 Attachment-Roundtrip: Speichern und Löschen', () async {
      await sut.initialize("VaultA", validKey());
      
      final attachment = AttachmentEntity(
        id: 0,
        uuid: 'a-1',
        entryId: 1,
        encryptedMeta: 'M1',
        encryptedContent: 'C1',
        isSynced: false,
      );
      
      final saved = await sut.saveAttachment(attachment);
      expect(saved.id, greaterThan(0));
      
      final unsynced = await sut.getAttachmentsUnsynced();
      expect(unsynced.length, equals(1));
      
      await sut.deleteAttachment(saved.id);
      expect(await sut.getAttachment(saved.id), isNull);
    });

    test('7.1.1 Settings-Roundtrip: Einstellungen speichern und abrufen', () async {
      await sut.initialize("VaultS", validKey());
      
      final settings = SettingsEntity(
        id: 1,
        salt: 'salt',
        encryptedPrivateKey: 'priv',
        masterKeyTimestamp: 123,
        host: 'https://api.de',
        apiToken: 'token',
        lastSyncAt: DateTime.now(),
        useBiometric: true,
        pwLength: 16,
        pwSpecialChars: true,
        pwAvoidIlO0: true,
        categoryPlaceholder: 'General',
      );
      
      await sut.saveSettings(settings);
      final loaded = await sut.getSettings();
      
      expect(loaded?.apiToken, equals('token'));
      expect(loaded?.useBiometric, isTrue);
    });
  });
}
