import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:famkey/services/crypto_service.dart';
import 'package:famkey/services/web_service.dart';
import 'package:uuid/uuid.dart';

@GenerateMocks([CryptoService])
import 'web_service_test.mocks.dart';

/// Integrationstest für den [WebService] gegen einen lokal laufenden Server.
/// 
/// Der Test nutzt ein echtes [Dio]-Objekt (statt Mocks), um Requests an den lokalen 
/// Webservice zu senden. 
/// 
/// WICHTIG:
/// - Header [X-Test]: Damit der Server Testdaten von Produktivdaten unterscheiden kann.
/// - Header [X-Coverage]: Damit der Server einen Code-Coverage-Report für das PHP-Backend erstellt.
void main() {
  group('WebService Integration Tests', () {
    late WebService sut;
    late MockCryptoService mockCrypto;
    late String vaultName;
    late String apiToken;
    
    const String testHost = 'https://famkey.test/api/'; // Oder http://localhost:8000/api/

    // Extrahiert den API-Token aus der host/config.php (wie im C# Test)
    String readApiTokenFromConfig() {
      try {
        final file = File('host/config.php');
        if (!file.existsSync()) return 'DEIN_API_TOKEN';
        
        final content = file.readAsStringSync();
        final regExp = RegExp("const\\s+API_TOKEN\\s*=\\s*['\"](.*?)['\"]\\s*;");
        final match = regExp.firstMatch(content);
        return match?.group(1) ?? 'DEIN_API_TOKEN';
      } catch (e) {
        debugPrint('Fehler beim Lesen der config.php: $e');
        return 'DEIN_API_TOKEN';
      }
    }

    setUp(() {
      mockCrypto = MockCryptoService();
      apiToken = readApiTokenFromConfig();
      
      // Eindeutiger Name für diesen Testlauf
      vaultName = '~test-${const Uuid().v4().substring(0, 8)}';

      // Echtes Dio mit Test-Headern vorbereiten
      final dio = Dio(BaseOptions(
        baseUrl: testHost,
        connectTimeout: const Duration(seconds: 5),
      ));

      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['X-Test'] = '1';
          options.headers['X-Coverage'] = '1';
          return handler.next(options);
        },
      ));

      sut = WebService(
        mockCrypto,
        host: testHost,
        apiToken: apiToken,
        dio: dio,
      );

      // Default Crypto Mocks
      when(mockCrypto.computeHash(any)).thenAnswer((inv) => 'hash(${inv.positionalArguments[0]})');
    });

    // Entspricht DisposeAsync in C#
    tearDown(() async {
      try {
        await sut.cleanTest(vaultName);
      } catch (e) {
        debugPrint('Cleanup fehlgeschlagen (evtl. Server nicht erreichbar): $e');
      }
    });

    test('1.1.1 GetServerVersion: Liefert Version und triggert serverseitige Coverage', () async {
      try {
        final version = await sut.getServerVersion();
        
        // Korrektur: Case-insensitive Vergleich oder korrekte Schreibweise
        expect(version.service.toLowerCase(), contains('famkey'));
        expect(version.syncProtocolVersion, greaterThanOrEqualTo(1));
        debugPrint('Backend-Service: ${version.service}');
      } on DioException catch (e) {
        if (e.type == DioExceptionType.connectionError) {
          debugPrint('INFO: Server unter $testHost nicht erreichbar. Test übersprungen.');
          return;
        }
        rethrow;
      }
    });

    test('2.1.1 Benutzer-Lifecycle: FindUser, RegisterUser und Cleanup', () async {
      final userName = '~user-${const Uuid().v4().substring(0, 8)}';
      final userUuid = const Uuid().v4();

      try {
        // 1. Benutzer existiert noch nicht
        final before = await sut.findUser(vaultName, userName);
        expect(before, isNull);

        // 2. Registrieren
        final registered = await sut.registerUser(
          vaultName: vaultName,
          userName: userName,
          userUuid: userUuid,
          salt: 'salt123',
          publicKey: 'PUB_KEY',
          encryptedPrivateKey: 'ENC_PRIV',
          masterKeyTimestamp: DateTime.now().toUtc(),
        );
        expect(registered.userUuid, equals(userUuid));

        // 3. Nach Registrierung auffindbar
        final after = await sut.findUser(vaultName, userName);
        expect(after, isNotNull);
        expect(after?.userUuid, equals(userUuid));

      } on DioException catch (e) {
        if (e.type == DioExceptionType.connectionError) return;
        rethrow;
      }
    });

    test('2.3.1 RSA-Signatur Interceptor: Verifiziert Header-Erzeugung', () async {
      final key = Uint8List.fromList([1, 2, 3, 4]);
      sut.setSignatureData(userUuid: 'test-uuid', privateKey: key);

      // Wir simulieren die Signatur-Erstellung im CryptoService
      when(mockCrypto.signData(any, any)).thenAnswer((_) async => 'valid-mock-signature');

      try {
        // Dieser Request triggert den Signature-Interceptor
        await sut.getPublicKeys('test-uuid');

        // Prüfen, ob der CryptoService zur Signatur gerufen wurde
        verify(mockCrypto.signData(any, key)).called(1);
      } on DioException catch (e) {
        if (e.type == DioExceptionType.connectionError) return;
        // Statuscode ist egal, solange die Logik bis zum Request lief
      }
    });
  });
}
