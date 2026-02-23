import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart' as crypto_auth;
import 'package:pointycastle/export.dart' as pc;
import 'package:pointycastle/asn1.dart' as pc_asn1;
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/signers/rsa_signer.dart';
import 'package:pointycastle/digests/sha256.dart';
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
    // Wir wandeln den Public Key in das X.509 Format (736 Zeichen) um
    final x509PubKey = _ensureX509Format(result.publicKey);
    return (x509PubKey, utf8.encode(result.privateKey));
  }

  Future<String> encryptRsa(Uint8List data, String publicKeyPem) async {
    final pem = _ensurePemHeader(publicKeyPem, "PUBLIC KEY");
    return await frsa.RSA.encryptOAEP(
      base64.encode(data),
      "",
      frsa.Hash.SHA256,
      pem,
    );
  }

  Future<Uint8List> decryptRsa(String encryptedDataBase64, String privateKeyPem) async {
    final pem = _ensurePemHeader(privateKeyPem, "PRIVATE KEY");
    final decrypted = await frsa.RSA.decryptOAEP(
      encryptedDataBase64,
      "",
      frsa.Hash.SHA256,
      pem,
    );
    return base64.decode(decrypted);
  }

  Future<String> signData(Uint8List data, Uint8List privateKeyBytes) async {
    final privateKey = _parsePrivateKeyBytes(privateKeyBytes);
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    signer.init(true, pc.PrivateKeyParameter<RSAPrivateKey>(privateKey));
    final sig = signer.generateSignature(data);
    return base64.encode(sig.bytes);
  }

  RSAPrivateKey _parsePrivateKeyBytes(Uint8List bytes) {
    var workingBytes = bytes;
    if (workingBytes.isNotEmpty && workingBytes[0] == 45) {
      final pem = utf8.decode(workingBytes);
      workingBytes = base64.decode(stripPem(pem));
    }

    final asn1Parser = pc_asn1.ASN1Parser(workingBytes);
    final topLevelSeq = asn1Parser.nextObject() as pc_asn1.ASN1Sequence;
    pc_asn1.ASN1Sequence rsaSeq;
    
    if (topLevelSeq.elements!.length >= 3 && topLevelSeq.elements![2] is pc_asn1.ASN1OctetString) {
      final privKeyOctet = topLevelSeq.elements![2] as pc_asn1.ASN1OctetString;
      final rsaParser = pc_asn1.ASN1Parser(privKeyOctet.valueBytes!);
      rsaSeq = rsaParser.nextObject() as pc_asn1.ASN1Sequence;
    } else {
      rsaSeq = topLevelSeq;
    }
    
    BigInt getInt(int index) {
      final el = rsaSeq.elements![index];
      return (el as dynamic).integer ?? (el as dynamic).valueAsBigInteger;
    }

    return RSAPrivateKey(getInt(1), getInt(3), getInt(4), getInt(5));
  }

  /// Stellt sicher, dass der Public Key im X.509 Format (736 Zeichen) vorliegt.
  String _ensureX509Format(String keyPem) {
    final rawBase64 = stripPem(keyPem);
    if (rawBase64.length == 736) return rawBase64;

    if (rawBase64.length == 704) {
      // Umwandlung von PKCS#1 zu X.509
      final pkcs1Bytes = base64.decode(rawBase64);
      
      final algorithmSeq = pc_asn1.ASN1Sequence();
      algorithmSeq.add(pc_asn1.ASN1ObjectIdentifier.fromIdentifierString('1.2.840.113549.1.1.1'));
      algorithmSeq.add(pc_asn1.ASN1Null());
      
      // Bei ASN1BitString heißt der Parameter stringValues
      final publicKeyBitString = pc_asn1.ASN1BitString(stringValues: pkcs1Bytes);
      
      final spkiSeq = pc_asn1.ASN1Sequence();
      spkiSeq.add(algorithmSeq);
      spkiSeq.add(publicKeyBitString);
      
      return base64.encode(spkiSeq.encode());
    }
    
    return rawBase64;
  }

  String stripPem(String pem) {
    return pem
        .replaceAll(RegExp(r'-----BEGIN [A-Z ]+-----'), '')
        .replaceAll(RegExp(r'-----END [A-Z ]+-----'), '')
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .trim();
  }

  String _ensurePemHeader(String key, String type) {
    if (key.startsWith('-----')) return key;
    return "-----BEGIN RSA $type-----\n$key\n-----END RSA $type-----";
  }

  void wipeKey(Uint8List? key) {
    if (key == null) return;
    for (int i = 0; i < key.length; i++) {
      key[i] = 0;
    }
  }

  String computeHash(String input) {
    final bytes = utf8.encode(input);
    final digest = crypto_hash.sha256.convert(bytes);
    return digest.toString();
  }

  Uint8List generateSalt() {
    final random = Random.secure();
    return Uint8List.fromList(List<int>.generate(16, (i) => random.nextInt(256)));
  }

  Uint8List deriveKeyFromKey(Uint8List keyMaterial, Uint8List? salt, String info) {
    final hkdf = pc.HKDFKeyDerivator(pc.SHA256Digest());
    final params = pc.HkdfParameters(keyMaterial, 32, salt, Uint8List.fromList(utf8.encode(info)));
    hkdf.init(params);
    final derivedKey = Uint8List(32);
    // Das IKM wurde bereits über params/init gesetzt, daher hier null.
    hkdf.deriveKey(null, 0, derivedKey, 0);
    return derivedKey;
  }
}
