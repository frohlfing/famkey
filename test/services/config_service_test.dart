import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/services/config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      expect(sut.logLevel, equals(LogLevel.info));
      expect(sut.logDays, equals(7));
    });

    test('1.1.2 Roundtrip: Properties werden korrekt persistiert und wieder geladen', () async {
      final sut1 = ConfigService(prefs);
      sut1.lastVaultName = 'VaultX';
      sut1.showOnlyMine = true;
      sut1.themeMode = ThemeMode.dark;
      sut1.logLevel = LogLevel.debug;
      sut1.logDays = 14;

      final sut2 = ConfigService(prefs);

      expect(sut2.lastVaultName, equals('VaultX'));
      expect(sut2.showOnlyMine, isTrue);
      expect(sut2.themeMode, equals(ThemeMode.dark));
      expect(sut2.logLevel, equals(LogLevel.debug));
      expect(sut2.logDays, equals(14));
    });
  });
}
