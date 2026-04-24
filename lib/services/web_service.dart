import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/models/dtos/sync_dtos.dart';
import 'package:privault/models/dtos/user_response.dart';
import 'package:privault/models/dtos/version_response.dart';
import 'package:privault/services/crypto_service.dart';

/// Dienst für die Kommunikation mit der priVault-API (Backend).
/// Kümmert sich um Authentifizierung (API-Token) und Autorisierung (RSA-Signatur der Requests).
class WebService {

  // ------------------------------------------------------------------------
  // --- Verwendete Dienste (Abhängigkeiten) ---
  // ------------------------------------------------------------------------

  final CryptoService _cryptoService;

  // ------------------------------------------------------------------------
  // --- Interne Variablen ---
  // ------------------------------------------------------------------------

  final Dio _dio;
  String _apiToken = '';
  String? _userUuid;
  Uint8List? _privateKeyBytes;

  // ------------------------------------------------------------------------
  // --- Initialisierung / Lifecycle ---
  // ------------------------------------------------------------------------

  /// Konstruktor.
  ///
  /// [host] ist die Serveradresse ohne "/api".
  /// [dio] kann für Unit-Tests übergeben werden, um Header oder Mocks zu injizieren.
  WebService(this._cryptoService, {String? host, String? apiToken, Dio? dio})
      : _dio = dio ?? Dio() {

    _apiToken = apiToken ?? '';

    // Falls dio von außen kommt, stellen wir sicher, dass die BaseUrl passt
    if (host != null && host.isNotEmpty) {
      _dio.options.baseUrl = host.endsWith('/') ? '${host}api/' : '$host/api/';
    }

    // Default Headers (API Token & Debug Cookie)
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['Authorization'] = 'Bearer $_apiToken';
          options.headers['X-API-Token'] = _apiToken;
          options.headers['Content-Type'] = 'application/json';
          options.headers['Accept'] = 'application/json';
          if (kDebugMode) {
            options.headers['Cookie'] = 'XDEBUG_SESSION=PHPSTORM';
          }
          return handler.next(options);
        },
      ),
    );

    // Signature Interceptor
    // Erzeugt dynamisch für jeden Request eine frische RSA-Signatur
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_userUuid != null && _privateKeyBytes != null) {
            // Wir signieren die Kombination aus UUID und einem aktuellen Zeitstempel (gegen Replay-Attacks)
            final timestamp = (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000).toString();
            final payload = '$_userUuid:$timestamp';

            try {
              // Signatur erstellen (CryptoService nutzen)
              var signature = await _cryptoService.signData(Uint8List.fromList(utf8.encode(payload)), _privateKeyBytes!);

              // Sicherstellen, dass die Signatur für Header valide ist (keine Zeilenumbrüche)
              options.headers['X-User-Uuid'] = _userUuid;
              options.headers['X-Timestamp'] = timestamp;
              options.headers['X-Signature'] = signature.replaceAll('\r', '').replaceAll('\n', '').trim();
            } catch (e) {
              debugPrint("❌ [SIGN] FEHLER IM INTERCEPTOR: $e");
            }
          }
          return handler.next(options);
        },
      ),
    );

    // Log-Ausgabe für Debug-Zwecke
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: true,
          requestBody: true,
          responseHeader: true,
          responseBody: true,
          error: true,
          logPrint: (obj) => debugPrint(obj.toString()),
        ),
      );
    }
  }

  // --- Konfiguration ---

  /// Aktualisiert die Konfiguration des WebServices.
  /// [host] ist die Serveradresse ohne "/api".
  void updateConfig({required String host, required String apiToken}) {
    if (host.isNotEmpty) {
      _dio.options.baseUrl = host.endsWith('/') ? '${host}api/' : '$host/api/';
    }
    _apiToken = apiToken;
  }

  /// Aktualisiert die Signature-Daten des WebServices.
  void setSignatureData({required String userUuid, required Uint8List privateKey, String? publicKey}) {
    _userUuid = userUuid;
    _privateKeyBytes = privateKey;
  }

  /// Löscht die Signature-Daten des WebServices.
  void clearSignatureData() {
    _userUuid = null;
    _privateKeyBytes = null;
  }

  // ------------------------------------------------------------------------
  // --- Methoden bzgl. Resource Version ---
  // ------------------------------------------------------------------------

  /// Fragt die aktuelle API-Version des Servers ab.
  ///
  /// Falls die Serverantwort ein unerwartetes Format hat, wird
  /// `VersionResponse` mit leeren Werten zurückgegeben.
  Future<VersionResponse> getServerVersion() async {
    final response = await _dio.get('version');
    return VersionResponse.fromJson(response.data);
  }

  // ------------------------------------------------------------------------
  // --- Methoden bzgl. Resource User ---
  // ------------------------------------------------------------------------

  /// Sucht im angegebenen Tresor nach einem bestimmten Benutzer.
  Future<UserResponse?> findUser(String vaultName, String userName) async {
    final vaultHash = _cryptoService.computeHash(vaultName);
    final userHash = _cryptoService.computeHash(userName);
    final response = await _dio.get(
      'users',
      queryParameters: {
        'vault_hash': vaultHash,
        'user_hash': userHash,
      },
    );
    if (response.data == null || response.data.toString().isEmpty) return null;
    return UserResponse.fromJson(response.data);
  }

  /// Registriert einen neuen Benutzer auf dem Server.
  Future<UserResponse> registerUser({required String vaultName, required String userName, required String userUuid, required String salt, required String publicKey, required String encryptedPrivateKey, required DateTime masterKeyTimestamp}) async {
    final response = await _dio.post(
      'users',
      data: {
        'user_uuid': userUuid,
        'vault_hash': _cryptoService.computeHash(vaultName),
        'user_hash': _cryptoService.computeHash(userName),
        'salt': salt,
        'public_key': publicKey,
        'encrypted_private_key': encryptedPrivateKey,
        'master_key_timestamp': masterKeyTimestamp.toUtc().toIso8601String(),
      },
    );
    return UserResponse.fromJson(response.data);
  }

  /// Überträgt eine Passwortänderung (neues Salt und verschlüsselter Private Key) zum Server.
  Future<void> changePassword(String userUuid, String salt, String encryptedPrivateKey, DateTime masterKeyTimestamp) async {
    await _dio.put(
      'users/$userUuid/password',
      data: {
        'salt': salt,
        'encrypted_private_key': encryptedPrivateKey,
        'master_key_timestamp': masterKeyTimestamp.toUtc().toIso8601String(),
      },
    );
  }

  /// Ruft die öffentlichen RSA-Schlüssel aller Benutzer des Tresors ab.
  Future<List<Map<String, dynamic>>> getPublicKeys(String userUuid) async {
    final response = await _dio.get('users/$userUuid/public_keys');
    return List<Map<String, dynamic>>.from(response.data);
  }

  /// Speichert die verschlüsselte Freundesliste des Benutzers auf dem Server.
  Future<void> saveFriends(String userUuid, String encryptedFriends) async {
    await _dio.put('users/$userUuid/friends', data: {'encrypted_friends': encryptedFriends});
  }

  /// Ändert den Benutzernamen auf dem Server.
  ///
  /// Wird beim Sync aufgerufen, wenn [user.name] != [user.syncedName].
  Future<void> patchUserName(String userUuid, String userName) async {
    await _dio.patch(
      'users/$userUuid/name',
      data: {
        'user_hash': _cryptoService.computeHash(userName),
      },
    );
  }

  // ------------------------------------------------------------------------
  // --- Methoden bzgl. Bulk-Aktion Sync ---
  // ------------------------------------------------------------------------

  /// Ruft alle Änderungen seit der letzten Synchronisation ab.
  ///
  /// `since` ist Zeitpunkt des letzten erfolgreichen Abgleichs (UTC).
  Future<SyncPullResponse> pullSync(String userUuid, DateTime since) async {
    // ":O" in C# erzeugt einen ISO-8601 String. Das Äquivalent in Dart ist toIso8601String().
    final response = await _dio.get('users/$userUuid/entries/sync', queryParameters: {'since': since.toUtc().toIso8601String()});
    return SyncPullResponse.fromJson(response.data);
  }

  /// Überträgt lokale Änderungen zum Server.
  ///
  /// `request` ist das Payload mit den zu synchronisierenden Daten.
  Future<void> pushSync(String userUuid, SyncPushRequest request) async {
    await _dio.post('users/$userUuid/entries/sync', data: request.toJson());
  }

  // ------------------------------------------------------------------------
  // --- Methoden bzgl. Resource Attachment ---
  // ------------------------------------------------------------------------

  /// Lädt die verschlüsselten Daten eines Dateianhangs vom Server herunter.
  Future<Map<String, dynamic>> downloadAttachment(String attachmentUuid) async {
    final response = await _dio.get('attachments/$attachmentUuid');
    return response.data as Map<String, dynamic>;
  }

  /// Lädt einen neuen oder geänderten Anhang zum Server hoch.
  ///
  /// `encryptedContent` ist Base64-kodiert.
  Future<void> uploadAttachment(String entryUuid, String attachmentUuid, String encryptedMeta, String encryptedContent) async {
    await _dio.put(
      'attachments/$attachmentUuid',
      data: {
        'entry_uuid': entryUuid,
        'encrypted_meta': encryptedMeta,
        'encrypted_content': encryptedContent,
      },
    );
  }

  // ------------------------------------------------------------------------
  // --- Methoden bzgl. Resource Vault ---
  // ------------------------------------------------------------------------

  /// Räumt den Test-Tresor serverseitig auf (DELETE /test?vault_hash=...).
  ///
  /// Wird typischerweise von Integrationstests verwendet.
  Future<void> cleanTest(String vaultName) async {
    final vaultHash = _cryptoService.computeHash(vaultName);
    await _dio.delete('vaults', queryParameters: {'vault_hash': vaultHash});
  }

  /// Löscht den Tresor des Benutzers serverseitig (RSA-geschützt).
  ///
  /// Entspricht der Option "Nur auf dem Server löschen" im Einstellungen-Dialog.
  Future<void> deleteVault(String userUuid) async {
    await _dio.delete('users/$userUuid/vault');
  }

  // ------------------------------------------------------------------------
  // --- Fehlerauswertung ---
  // ------------------------------------------------------------------------

  /// Wandelt den Verbindungsfehler in ein FormError um.
  static AppError convertDioError(DioException de) {
    String message;
    ErrorCode code = ErrorCode.networkError;
    final host = de.requestOptions.baseUrl;

    switch (de.type) {
      case DioExceptionType.connectionError:
        message = 'Service auf $host nicht erreicht. Prüfe deine Internetverbindung und die Serveradresse.';
        break;

      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Server $host antwortet nicht rechtzeitig. Ist er online?';
        break;

      case DioExceptionType.badCertificate:
        message = 'Das Sicherheitszertifikat des Servers $host ist ungültig oder abgelaufen.';
        break;

      case DioExceptionType.badResponse: // z.B. kein JSON
        final status = de.response?.statusCode;
        if (status == 404) {
          code = ErrorCode.noSyncService;
          message = 'Auf dem Server $host läuft kein PriVault Sync-Service. Überprüfe die Serveradresse.';
        } else if (status == 401) {
          code = ErrorCode.unauthorized;
          message = 'Der API-Token wurde vom Server abgelehnt.';
        } else if (status == 503) {
          message = 'Der Server $host kann vorübergehend keine Anfrage bearbeiten.';
        } else { // Fallback
          final msg = de.response?.statusMessage ?? (de.message ?? 'Serverfehler');
          message = status != null ? '$msg (Code $status)' : msg;
        }
        break;

      default:
        // Fallback
        final msg = de.response?.statusMessage ?? (de.message ?? 'Netzwerkfehler');
        message = de.response?.statusCode != null ? '$msg (Code ${de.response?.statusCode})' : msg;
    }

    return AppError(code, text: message);
  }
}