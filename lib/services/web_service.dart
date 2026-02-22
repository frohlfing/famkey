import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:privault/models/dtos/sync_dtos.dart';
import 'package:privault/models/dtos/user_response.dart';
import 'package:privault/models/dtos/version_response.dart';
import 'package:privault/services/crypto_service.dart';

class WebService {
  final Dio _dio;
  final CryptoService _cryptoService;

  WebService(this._cryptoService, {required String baseUrl, required String apiToken})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
          headers: {
            'Authorization': 'Bearer $apiToken',
            'X-API-Token': apiToken,
            'Content-Type': 'application/json',
          },
        ));

  /// Erlaubt das Testen der Verbindung mit beliebigen Parametern (für Settings)
  Future<VersionResponse> getServerVersion({String? host, String? apiToken}) async {
    final testDio = Dio(BaseOptions(
      baseUrl: host != null ? (host.endsWith('/') ? host : '$host/') : _dio.options.baseUrl,
      headers: {
        'Authorization': 'Bearer ${apiToken ?? _dio.options.headers['X-API-Token']}',
        'X-API-Token': apiToken ?? _dio.options.headers['X-API-Token'],
      },
      connectTimeout: const Duration(seconds: 5),
    ));

    final response = await testDio.get('version');
    return VersionResponse.fromJson(response.data);
  }

  void addSignatureInterceptor(String userUuid, String privateKeyPem) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final timestamp = (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000).toString();
        final payload = '$userUuid:$timestamp';
        final signature = await _cryptoService.signData(utf8.encode(payload) as Uint8List, privateKeyPem);
        options.headers['X-User-Uuid'] = userUuid;
        options.headers['X-Timestamp'] = timestamp;
        options.headers['X-Signature'] = signature.replaceAll('\r', '').replaceAll('\n', '').trim();
        return handler.next(options);
      },
    ));
  }

  // --- Endpoints ---

  Future<UserResponse?> findUser(String vaultName, String userName) async {
    final vaultHash = _cryptoService.computeHash(vaultName);
    final userHash = _cryptoService.computeHash(userName);
    final response = await _dio.get('users', queryParameters: {'vault_hash': vaultHash, 'user_hash': userHash});
    if (response.data == null) return null;
    return UserResponse.fromJson(response.data);
  }

  Future<SyncPullResponse> pullSync(String userUuid, DateTime since) async {
    final response = await _dio.get('users/$userUuid/entries/sync', queryParameters: {'since': since.toUtc().toIso8601String()});
    return SyncPullResponse.fromJson(response.data);
  }

  Future<void> pushSync(String userUuid, SyncPushRequest request) async {
    await _dio.post('users/$userUuid/entries/sync', data: request.toJson());
  }

  Future<UserResponse> registerUser({
    required String vaultName, required String userName, required String userUuid,
    required String salt, required String publicKey, required String encryptedPrivateKey,
  }) async {
    final body = {
      'user_uuid': userUuid, 'vault_hash': _cryptoService.computeHash(vaultName),
      'user_hash': _cryptoService.computeHash(userName), 'salt': salt,
      'public_key': publicKey, 'encrypted_private_key': encryptedPrivateKey,
    };
    final response = await _dio.post('users', data: body);
    return UserResponse.fromJson(response.data);
  }
}
