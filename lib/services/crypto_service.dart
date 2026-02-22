import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart' as crypto_auth;
import 'package:pointycastle/export.dart' as pc;
import 'package:fast_rsa/fast_rsa.dart' as frsa;
import 'package:crypto/crypto.dart' as crypto_hash;

class CryptoService {
  // Argon2id Parameter (Matching C#)
  static const int argonMemorySize = 64 * 1024; // 64 MB
  static const int argonIterations = 4;
  static const int argonParallelism = 4;

  // AES-GCM Constants
  static const int nonceSize = 12;
  static const int tagSize = 16;

  final _aesGcm = crypto_auth.AesGcm.with256bits();

  /// Derive a 32-byte key from a password and salt using Argon2id with PointyCastle.
  Future<Uint8List> deriveKey(String password, Uint8List salt) async {
    final params = pc.Argon2Parameters(
      pc.Argon2Parameters.ARGON2_id,
      salt,
      desiredKeyLength: 32,
      iterations: argonIterations,
      memory: argonMemorySize,
      lanes: argonParallelism,
    );

    final argon2 = pc.Argon2BytesGenerator();
    argon2.init(params);

    final result = Uint8List(32);
    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    argon2.deriveKey(passwordBytes, 0, result, 0);

    return result;
  }

  /// Encrypt data using AES-256-GCM.
  Future<String> encrypt(Uint8List data, Uint8List key) async {
    final secretKey = crypto_auth.SecretKey(key);
    final nonce = _aesGcm.newNonce();

    final secretBox = await _aesGcm.encrypt(
      data,
      secretKey: secretKey,
      nonce: nonce,
    );

    final combined = Uint8List(nonceSize + tagSize + secretBox.cipherText.length);
    combined.setRange(0, nonceSize, secretBox.nonce);
    combined.setRange(nonceSize, nonceSize + tagSize, secretBox.mac.bytes);
    combined.setRange(nonceSize + tagSize, combined.length, secretBox.cipherText);

    return base64.encode(combined);
  }

  /// Decrypt data using AES-256-GCM.
  Future<Uint8List> decrypt(String encryptedDataBase64, Uint8List key) async {
    final blob = base64.decode(encryptedDataBase64);
    if (blob.length < nonceSize + tagSize) {
      throw Exception("Invalid data format");
    }

    final nonce = blob.sublist(0, nonceSize);
    final tag = blob.sublist(nonceSize, nonceSize + tagSize);
    final cipherText = blob.sublist(nonceSize + tagSize);

    final secretKey = crypto_auth.SecretKey(key);
    final secretBox = crypto_auth.SecretBox(
      cipherText,
      nonce: nonce,
      mac: crypto_auth.Mac(tag),
    );

    final clearText = await _aesGcm.decrypt(
      secretBox,
      secretKey: secretKey,
    );

    return Uint8List.fromList(clearText);
  }

  // --- RSA Section ---

  Future<(String, Uint8List)> generateRsaKeyPair() async {
    final result = await frsa.RSA.generate(4096);
    return (result.publicKey, utf8.encode(result.privateKey));
  }

  Future<String> encryptRsa(Uint8List data, String publicKeyPem) async {
    return await frsa.RSA.encryptOAEP(
      base64.encode(data),
      "",
      frsa.Hash.SHA256,
      publicKeyPem,
    );
  }

  Future<Uint8List> decryptRsa(String encryptedDataBase64, String privateKeyPem) async {
    final decrypted = await frsa.RSA.decryptOAEP(
      encryptedDataBase64,
      "",
      frsa.Hash.SHA256,
      privateKeyPem,
    );
    return base64.decode(decrypted);
  }

  Future<String> signData(Uint8List data, String privateKeyPem) async {
    return await frsa.RSA.signPKCS1v15(
      base64.encode(data),
      frsa.Hash.SHA256,
      privateKeyPem,
    );
  }

  /// Sicherer Cleanup von sensiblen Daten im RAM.
  void wipeKey(Uint8List? key) {
    if (key == null) return;
    for (int i = 0; i < key.length; i++) {
      key[i] = 0;
    }
  }

  // --- Helpers ---

  String computeHash(String input) {
    final bytes = utf8.encode(input);
    final digest = crypto_hash.sha256.convert(bytes);
    return digest.toString();
  }

  Uint8List generateSalt() {
    final random = Random.secure();
    return Uint8List.fromList(List<int>.generate(16, (i) => random.nextInt(256)));
  }
}
