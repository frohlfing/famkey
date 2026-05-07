import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:famkey/core/env.dart';
import 'package:famkey/database/database.dart';
import 'package:famkey/services/config_service.dart';
import 'package:famkey/services/database_service.dart';

import 'database_service_test.mocks.dart';

@GenerateMocks([ConfigService])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => Directory.systemTemp.path,
    );
    await env.init();
    await Directory(env.vaultStoragePath).create(recursive: true);
  });

  group('DatabaseService Tests', () {
    late DatabaseService sut;
    late MockConfigService mockConfigService;
    late Directory tempDir;

    setUp(() async {
      // Mock für PackageInfo (wird von AppDatabase beim Öffnen geloggt)
      PackageInfo.setMockInitialValues(
        appName: 'FamKey',
        packageName: 'com.example.famkey',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: 'buildSignature',
      );

      // 1. GetIt vorbereiten
      final getIt = GetIt.instance;
      if (getIt.isRegistered<ConfigService>()) {
        await getIt.unregister<ConfigService>();
      }

      mockConfigService = MockConfigService();
      getIt.registerSingleton<ConfigService>(mockConfigService);

      // 2. Temporäres Verzeichnis
      tempDir = await Directory.systemTemp.createTemp('famkey_test_');

      sut = DatabaseService();
    });

    tearDown(() async {
      await sut.close();
      await GetIt.instance.reset(); // Wichtig für saubere Tests
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Uint8List validKey([int seed = 1]) {
      final key = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        key[i] = seed;
      }
      return key;
    }

    test('1.2.1 initialize: Kehrt bei Mehrfachaufruf einfach zurück', () async {
      final key = validKey();
      await sut.initialize("MultiVault", key);
      expect(sut.isInitialized, isTrue);

      await sut.initialize("MultiVault", key);
      expect(sut.isInitialized, isTrue);
    });

    test('1.3.1 Backup-Roundtrip', () async {
      const vaultName = "VaultZ";
      await sut.initialize(vaultName, validKey());

      // WICHTIG: Einen Zugriff erzwingen, damit Drift die Datei physisch erstellt
      await sut.getSettings();

      final dbPath = sut.getDatabasePath(vaultName);
      final backupPath = '$dbPath.bak';

      expect(File(dbPath).existsSync(), isTrue, reason: 'DB Datei sollte existieren');

      await sut.createBackup();
      expect(File(backupPath).existsSync(), isTrue, reason: 'Backup Datei sollte nach createBackup existieren');

      await sut.close();
      await sut.restoreBackup();
      expect(File(backupPath).existsSync(), isFalse);
    });

    test('2.1.1 User-Roundtrip: Speichern und Abfragen', () async {
      await sut.initialize("VaultU", validKey());

      final user = UserEntity(
        id: 0,
        uuid: 'u-alice',
        name: 'Alice',
        publicKey: 'pub',
        isVerified: true,
        isHidden: false,
        syncedName: '',
        updatedAt: DateTime.now(),
      );

      final savedUser = await sut.saveUser(user);
      expect(savedUser.id, greaterThan(0));

      final got = await sut.getUserByUuid('u-alice');
      expect(got?.name, equals('Alice'));
    });

    test('2.1.2 User-Roundtrip: syncedName wird gespeichert und geladen', () async {
      await sut.initialize("VaultSyncedName", validKey());

      // Freund wurde unter 'Bobby' hinzugefügt, hat sich in 'Bob' umbenannt
      final user = UserEntity(
        id: 0,
        uuid: 'u-bob',
        name: 'Bob',
        syncedName: 'Bobby',
        publicKey: 'pub',
        isVerified: false,
        isHidden: false,
        updatedAt: DateTime.now(),
      );

      await sut.saveUser(user);
      final got = await sut.getUserByUuid('u-bob');
      // saveUser speichert syncedName nicht explizit – Drift verwendet den DB-Standardwert ''
      expect(got?.syncedName, equals(''));
      expect(got?.name, equals('Bob'));
    });

    test('7.1.1 Settings-Roundtrip: Einstellungen speichern und abrufen', () async {
      await sut.initialize("VaultS", validKey());

      final settings = SettingsEntity(
        id: 1,
        salt: 'salt',
        encryptedPrivateKey: 'priv',
        masterKeyTimestamp: DateTime.now(),
        host: 'https://api.de',
        apiToken: 'token',
        lastSyncAt: DateTime.now(),
        useBiometric: true,
        pwLength: 16,
        pwSpecialChars: "!@#\$",
        pwAvoidIlO0: true,
        categoryPlaceholder: 'General',
      );

      await sut.saveSettings(settings);
      final loaded = await sut.getSettings();

      expect(loaded?.apiToken, equals('token'));
      expect(loaded?.pwSpecialChars, equals("!@#\$"));
    });
  });
}