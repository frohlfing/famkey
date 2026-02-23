import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:privault/models/dtos/sync_dtos.dart';
import 'package:privault/models/dtos/user_response.dart';
import 'package:privault/models/dtos/version_response.dart';
import 'package:privault/services/crypto_service.dart';

class WebService {
  final Dio _dio;
  final CryptoService _cryptoService;

  String _apiToken = '';
  String? _userUuid;
  Uint8List? _privateKeyBytes;
  String? _publicKey;

  /// Override deaktiviert für Live-Betrieb
  bool useSignatureTestOverride = false;

  WebService(this._cryptoService, {required String baseUrl, required String apiToken})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
        )) {
    _apiToken = apiToken;

    // Default Headers (API Token & Debug Cookie)
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['Authorization'] = 'Bearer $_apiToken';
        options.headers['X-API-Token'] = _apiToken;
        options.headers['Content-Type'] = 'application/json';
        if (kDebugMode) {
          options.headers['Cookie'] = 'XDEBUG_SESSION=PHPSTORM';
        }
        return handler.next(options);
      },
    ));

    // Signature Interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (useSignatureTestOverride) {
          debugPrint('🔧 WebService: [OVERRIDE] Sende MAUI-Test-Signatur');
          options.headers['X-User-Uuid'] = "01ed288a-b0a9-41a4-a40a-d616d0280999";
          options.headers['X-Timestamp'] = "1771835966";
          options.headers['X-Signature'] = "GoUtqfklIR0BT54CCV1Gr0W8q2x2Il5Awz1i5tzMABcfrmJoO6rhy0qgn4ymYnnIBE5MO6TPT3oSvD5WaQwgd/Z3J30fPdwbBRrQ0RlUCIvZfP5Nlmd0/v/ikpAYdUVTaKaNVPR6Wo8bJRy+GA+q8bHIYiGR9levPO2UT2EmqAgFWjRbvheM+cLiVTxtsEVw5AlYaHjWguezrQNPPPHyCp+l3UCywOlkvCgzLn/kTaiJYYbqld4ZzbWUZlk41CeUJdYoyVncPHP2l4/mSMYIOwRwTN84Xfu9IvnjdlklpwYIEj+5WEljhEDHDI69H/pmQK2zf1fSgdIJL3L8RGs0RadRj2iR8HqII+BhAzZBPiZdXVP3/npK2Axq6yLwXTXnXFs4RkrjfFGkCPOlBnFTk7tSNbE+FUeDRrQ5vPMZYBMHDcqu+2bz0fnViIEReATN1DqJFbqrOmi5BHZB91qv5TZB4VewVlzSXLdeXjzx1b5PMaO/9C42/TADWkvHznjuL/4Xv14qSbpKCEmN6GRhjA4x8VlnVc1BfYYGVNrVarzCSk6AcinTPPewpK5w1TIQ0S3DP1gmwV21c/UiYmm1gK+3VgkD/4s4V90Dv3gRUgI6Htdt332YSj3LLQoBXuPiCBMlfhCSoqUN0s2plq1q7Yo1fOcdx4deNghfdJU5yKg=";
          return handler.next(options);
        }

        if (_userUuid != null && _privateKeyBytes != null) {
          final timestamp = (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000).toString();
          final payload = '$_userUuid:$timestamp';
          
          try {
            final signature = await _cryptoService.signData(
              Uint8List.fromList(utf8.encode(payload)), 
              _privateKeyBytes!
            );
            
            options.headers['X-User-Uuid'] = _userUuid;
            options.headers['X-Timestamp'] = timestamp;
            options.headers['X-Signature'] = signature.replaceAll('\r', '').replaceAll('\n', '').trim();
            
            debugPrint('🔐 [SIGN] Payload:    $payload');
            if (kDebugMode) {
              debugPrint('🔐 [SIGN] PublicKey:  $_publicKey');
              debugPrint('🔐 [SIGN] Signature:  ${options.headers['X-Signature']}');
            }
          } catch (e) {
            debugPrint("❌ [SIGN] FEHLER IM INTERCEPTOR: $e");
          }
        }
        return handler.next(options);
      },
    ));

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ));
    }
  }

  void updateConfig({required String host, required String apiToken}) {
    if (host.isNotEmpty) {
      _dio.options.baseUrl = host.endsWith('/') ? host : '$host/';
    }
    _apiToken = apiToken;
  }

  void setSignatureData({required String userUuid, required Uint8List privateKey, String? publicKey}) {
    _userUuid = userUuid;
    _privateKeyBytes = privateKey;
    _publicKey = publicKey;
  }

  void clearSignatureData() {
    _userUuid = null;
    _privateKeyBytes = null;
    _publicKey = null;
  }

  Future<VersionResponse> getServerVersion({String? host, String? apiToken}) async {
    final testDio = Dio(BaseOptions(
      baseUrl: host != null ? (host.endsWith('/') ? host : '$host/') : _dio.options.baseUrl,
      headers: {
        'Authorization': 'Bearer ${apiToken ?? _apiToken}',
        'X-API-Token': apiToken ?? _apiToken,
      },
      connectTimeout: const Duration(seconds: 5),
    ));

    if (kDebugMode) {
      testDio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['Cookie'] = 'XDEBUG_SESSION=PHPSTORM';
          return handler.next(options);
        }
      ));

      testDio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: true,
        responseBody: true,
        error: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ));
    }

    final response = await testDio.get('version');
    return VersionResponse.fromJson(response.data);
  }

  // --- Endpoints ---

  Future<UserResponse?> findUser(String vaultName, String userName) async {
    final vaultHash = _cryptoService.computeHash(vaultName);
    final userHash = _cryptoService.computeHash(userName);
    final response = await _dio.get('users', queryParameters: {'vault_hash': vaultHash, 'user_hash': userHash});
    if (response.data == null || response.data.toString().isEmpty) return null;
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

  Future<List<Map<String, dynamic>>> getPublicKeys(String userUuid) async {
    final response = await _dio.get('users/$userUuid/public_keys');
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<void> saveFriends(String userUuid, String encryptedFriends) async {
    await _dio.put('users/$userUuid/friends', data: {'encrypted_friends': encryptedFriends});
  }

  Future<Map<String, dynamic>> downloadAttachment(String attachmentUuid) async {
    final response = await _dio.get('attachments/$attachmentUuid');
    return response.data as Map<String, dynamic>;
  }

  Future<void> uploadAttachment(String entryUuid, String attachmentUuid, String encryptedMeta, String encryptedContent) async {
    await _dio.put('attachments/$attachmentUuid', data: {
      'entry_uuid': entryUuid,
      'encrypted_meta': encryptedMeta,
      'encrypted_content': encryptedContent,
    });
  }
}
