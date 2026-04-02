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
  // ------------------------------------------------------------------------
  // --- Interne Variablen & Konstanten ---
  // ------------------------------------------------------------------------

  // Argon2id Parameter (BSI-konform)
  static const int argonMemorySize = 64 * 1024; // 64 MB RAM
  static const int argonIterations = 4;
  static const int argonParallelism = 4;

  // AES-GCM Konstanten
  static const int nonceSize = 12; // 96 Bit IV (Standard für GCM)
  static const int tagSize = 16; // 128 Bit Authentication Tag

  final _aesGcm = crypto_auth.AesGcm.with256bits();

  // ------------------------------------------------------------------------
  // --- Methoden ---
  // ------------------------------------------------------------------------

  // --- AES ---

  /// Generiert ein kryptografisch sicheres 32 Byte langen AES-Schlüssel.
  Uint8List generateAesKey() {
    final random = Random.secure();
    return Uint8List.fromList(List<int>.generate(32, (_) => random.nextInt(256)));
  }

  /// Leitet einen 32-Byte (256 Bit) AES-Schlüssel aus einem Passwort und Salt mittels Argon2id ab (PBKDF).
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

    try {
      argon2.deriveKey(passwordBytes, 0, result, 0);
      return result;
    } finally {
      wipeKey(passwordBytes);
    }
  }

  /// Verschlüsselt Daten mit AES-256-GCM.
  ///
  /// Generiert eine zufällige Nonce für jede Verschlüsselung.
  /// Das Ergebnis wird als Base64-String im Format `[Nonce] + [Tag] + [Ciphertext]` zurückgegeben.
  Future<String> encrypt(Uint8List data, Uint8List key) async {
    if (key.length != 32) {
      throw Exception("Key muss exakt 32 Bytes lang sein (AES-256).");
    }

    final secretKey = crypto_auth.SecretKey(key);
    final nonce = _aesGcm.newNonce();

    final secretBox = await _aesGcm.encrypt(data, secretKey: secretKey, nonce: nonce);

    final combined = Uint8List(nonceSize + tagSize + secretBox.cipherText.length);
    combined.setRange(0, nonceSize, secretBox.nonce);
    combined.setRange(nonceSize, nonceSize + tagSize, secretBox.mac.bytes);
    combined.setRange(nonceSize + tagSize, combined.length, secretBox.cipherText);

    return base64.encode(combined);
  }

  /// Entschlüsselt Daten, die mit `Encrypt"` erstellt wurden, und prüft deren Integrität (Auth-Tag).
  Future<Uint8List> decrypt(String encryptedDataBase64, Uint8List key) async {
    if (key.length != 32) {
      throw Exception("Key muss exakt 32 Bytes lang sein (AES-256).");
    }

    final blob = base64.decode(encryptedDataBase64);
    if (blob.length < nonceSize + tagSize) {
      throw Exception("Datenformat ungültig.");
    }

    final nonce = blob.sublist(0, nonceSize);
    final tag = blob.sublist(nonceSize, nonceSize + tagSize);
    final cipherText = blob.sublist(nonceSize + tagSize);

    final secretKey = crypto_auth.SecretKey(key);
    final secretBox = crypto_auth.SecretBox(cipherText, nonce: nonce, mac: crypto_auth.Mac(tag));

    final clearText = await _aesGcm.decrypt(secretBox, secretKey: secretKey);

    return Uint8List.fromList(clearText);
  }

  // --- RSA ---

  /// Generiert ein RSA-4096 Schlüsselpaar.
  ///
  /// Der Public-Key wird im SPKI/X.509 Format (Base64), der Private-Key als PKCS#8 Byte-Array zurückgegeben.
  Future<(String, Uint8List)> generateRsaKeyPair() async {
    final result = await frsa.RSA.generate(4096);
    // Wir wandeln den Public Key in das X.509 Format (736 Zeichen) um
    final x509PubKey = _ensureX509Format(result.publicKey);
    return (x509PubKey, utf8.encode(result.privateKey));
  }

  /// Verschlüsselt kleine Datenmengen mit einem RSA Public-Key (OAEP mit SHA-256 Padding).
  Future<String> encryptRsa(Uint8List data, String publicKeyPem) async {
    final pem = _ensurePemHeader(publicKeyPem, "PUBLIC KEY");
    return await frsa.RSA.encryptOAEP(base64.encode(data), "", frsa.Hash.SHA256, pem);
  }

  /// Entschlüsselt Daten mit einem RSA Private Key (OAEP mit SHA-256 Padding).
  Future<Uint8List> decryptRsa(String encryptedDataBase64, String privateKeyPem) async {
    final pem = _ensurePemHeader(privateKeyPem, "PRIVATE KEY");
    final decrypted = await frsa.RSA.decryptOAEP(encryptedDataBase64, "", frsa.Hash.SHA256, pem);
    return base64.decode(decrypted);
  }

  /// Erzeugt einen SHA-256 Fingerprint eines (Base64-kodierten) Public-Keys.
  /// Format: HH:HH:HH:...
  String fingerprint(String publicKey) {
    if (publicKey.trim().isEmpty) return "";
    final hash = crypto_hash.sha256.convert(base64.decode(publicKey));
    return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
  }

  // --- Sonstiges ---

  /// Leitet mittels HKDF-SHA256 einen neuen symmetrischen Schlüssel ab.
  ///
  /// Wir nutzen HKDF-SHA256, um aus einem inputKey (z.B. RSA Private-Key) einen symmetrischen Key abzuleiten.
  /// Das Ergebnis ist ein pseudozufälliger 32-Byte (256 Bit) Schlüssel.
  /// `salt` ist optional, aber empfohlen. `info` ist Kontext (z.B. "friends-list-encryption").
  Uint8List deriveKeyFromKey(Uint8List keyMaterial, Uint8List? salt, String info) {
    final hkdf = pc.HKDFKeyDerivator(pc.SHA256Digest());
    final params = pc.HkdfParameters(keyMaterial, 32, salt, Uint8List.fromList(utf8.encode(info)));
    hkdf.init(params);
    final derivedKey = Uint8List(32);
    // Das IKM wurde bereits über params/init gesetzt, daher hier null.
    hkdf.deriveKey(null, 0, derivedKey, 0);
    return derivedKey;
  }

  /// Berechnet einen einfachen SHA-256 Hash eines Strings (Rückgabe als Hex-String).
  String computeHash(String input) {
    final bytes = utf8.encode(input);
    final digest = crypto_hash.sha256.convert(bytes);
    return digest.toString();
  }

  /// Generiert ein kryptografisch sicheres, 16 Byte langes Salt.
  Uint8List generateSalt() {
    final random = Random.secure();
    return Uint8List.fromList(List<int>.generate(16, (_) => random.nextInt(256)));
  }

  /// Signiert Daten mit dem RSA Private Key.
  /// Nutzt PKCS#1 v1.5 (für maximale Kompatibilität mit dem PHP-Backend).
  Future<String> signData(Uint8List data, Uint8List privateKeyBytes) async {
    final privateKey = _parsePrivateKeyBytes(privateKeyBytes);
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    signer.init(true, pc.PrivateKeyParameter<RSAPrivateKey>(privateKey));
    final sig = signer.generateSignature(data);
    return base64.encode(sig.bytes);
  }

  /// Überschreibt sensitive Daten im Arbeitsspeicher mit Nullen, um die Verweildauer von Schlüsseln zu minimieren.
  void wipeKey(Uint8List? key) {
    if (key == null) return;
    for (int i = 0; i < key.length; i++) {
      key[i] = 0;
    }
  }

  // ------------------------------------------------------------------------
  // --- Interne Methoden / Helper ---
  // ------------------------------------------------------------------------

  /// Parst den Private-Key aus dem PKCS#8 Format.
  RSAPrivateKey _parsePrivateKeyBytes(Uint8List bytes) {
    var workingBytes = bytes;
    if (workingBytes.isNotEmpty && workingBytes[0] == 45) {
      final pem = utf8.decode(workingBytes);
      workingBytes = base64.decode(_stripPem(pem));
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

  /// Stellt sicher, dass der Public-Key im X.509 Format (736 Zeichen) vorliegt.
  String _ensureX509Format(String keyPem) {
    final rawBase64 = _stripPem(keyPem);
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

  /// Entfernt den Header und Footer aus dem PEM-String.
  String _stripPem(String pem) {
    return pem
        .replaceAll(RegExp(r'-----BEGIN [A-Z ]+-----'), '') //
        .replaceAll(RegExp(r'-----END [A-Z ]+-----'), '')
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .trim();
  }

  /// Stellt sicher, dass der Private-Key im PKCS#8 Format (Base64) vorliegt.
  String _ensurePemHeader(String key, String type) {
    if (key.startsWith('-----')) return key;
    return "-----BEGIN RSA $type-----\n$key\n-----END RSA $type-----";
  }
}
