import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/services/config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

void main() {
  // Notwendig für SharedPreferences und PathProvider Mocks
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConfigService Tests', () {
    late SharedPreferences prefs;
    const String mockPath = '/mock/storage';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      // Moderner Mock für path_provider (getApplicationSupportDirectory)
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getApplicationSupportDirectory') {
            return mockPath;
          }
          return null;
        },
      );
    });

    test('1.1.1 Defaults: Liefert Defaultwerte, wenn noch nichts gespeichert ist', () {
      final sut = ConfigService(prefs);

      expect(sut.lastVaultName, equals(''));
      expect(sut.showOnlyMine, isFalse);
      expect(sut.themeMode, equals(ThemeMode.system));
      expect(sut.vaultStoragePath, equals(''));
      expect(sut.logMinLevel, equals(LogLevel.info));
      expect(sut.logMaxDays, equals(7));
    });

    test('1.1.2 Roundtrip: Properties werden korrekt persistiert und wieder geladen', () async {
      final sut1 = ConfigService(prefs);
      sut1.lastVaultName = 'VaultX';
      sut1.showOnlyMine = true;
      sut1.themeMode = ThemeMode.dark;
      sut1.vaultStoragePath = '/tmp/vaults';
      sut1.logMinLevel = LogLevel.debug;
      sut1.logMaxDays = 14;

      final sut2 = ConfigService(prefs);

      expect(sut2.lastVaultName, equals('VaultX'));
      expect(sut2.showOnlyMine, isTrue);
      expect(sut2.themeMode, equals(ThemeMode.dark));
      expect(sut2.vaultStoragePath, equals('/tmp/vaults'));
      expect(sut2.logMinLevel, equals(LogLevel.debug));
      expect(sut2.logMaxDays, equals(14));
    });

    test('1.1.3 Init: Setzt Standardpfad, wenn noch kein Pfad gespeichert ist', () async {
      final sut = ConfigService(prefs);
      expect(sut.vaultStoragePath, isEmpty);

      await sut.init();

      final expectedPath = p.join(mockPath, 'vaults');
      expect(sut.vaultStoragePath, equals(expectedPath));
    });

    test('1.1.4 Init: Überschreibt vorhandenen Pfad nicht', () async {
      final sut = ConfigService(prefs);
      sut.vaultStoragePath = '/existing/path';

      await sut.init();

      expect(sut.vaultStoragePath, equals('/existing/path'));
    });
  });
}
