import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto_hash;
import 'package:dargon2_flutter/dargon2_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:webcrypto/webcrypto.dart';

/// Kryptografische Dienste für die App.
///
/// Verwendet:
/// - [dargon2_flutter] für Argon2id (C-Referenzimplementierung nativ, hash-wasm auf Web)
/// - [webcrypto] für RSA-OAEP, AES-256-GCM, HKDF, RSASSA-PKCS1-v1_5
///   (BoringSSL nativ, SubtleCrypto auf Web – hardware-beschleunigt auf allen Plattformen)
class CryptoService {

  // ------------------------------------------------------------------------
  // --- Konstanten ---
  // ------------------------------------------------------------------------

  // Argon2id Parameter (BSI-konform)
  static const int _argonMemory      = 64 * 1024; // 64 MB RAM
  static const int _argonIterations  = 4;
  static const int _argonParallelism = 4;
  static const int _argonKeyLength   = 32;

  // MethodChannel für Argon2 auf Android (BouncyCastle-Implementierung)
  static const MethodChannel _argonChannel = MethodChannel('de.frohlfing.privault/argon2');

  // AES-GCM Konstanten
  static const int _nonceSize = 12; // 96 Bit IV (Standard für GCM)
  static const int _tagSize   = 16; // 128 Bit Authentication Tag

  // RSA Konstanten
  static const int _rsaModulusLength = 4096;
  static final BigInt _rsaPublicExponent = BigInt.from(65537);

  // ------------------------------------------------------------------------
  // --- AES ---
  // ------------------------------------------------------------------------

  /// Generiert einen kryptografisch sicheren 32-Byte AES-Schlüssel.
  Uint8List generateAesKey() {
    final random = Random.secure();
    return Uint8List.fromList(List<int>.generate(32, (_) => random.nextInt(256)));
  }

  /// Leitet einen 32-Byte (256 Bit) AES-Schlüssel aus einem Passwort und Salt
  /// mittels Argon2id ab.
  ///
  /// Android: BouncyCastle via MethodChannel (umgeht defekte FFI-Library).
  /// Nativ (andere Plattformen): C-Referenzimplementierung via FFI (schnell).
  /// Web: hash-wasm WebAssembly-Implementierung (schnell).
  Future<Uint8List> deriveKey(String password, Uint8List salt) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final hash = await _argonChannel.invokeMethod<Uint8List>('hashPassword', {
        'password': Uint8List.fromList(utf8.encode(password)),
        'salt': salt,
        'memory': _argonMemory,
        'iterations': _argonIterations,
        'parallelism': _argonParallelism,
        'keyLength': _argonKeyLength,
      });
      return hash!;
    }
    final result = await argon2.hashPasswordString(
      password,
      salt: Salt(salt),
      type: Argon2Type.id,
      version: Argon2Version.V13,
      memory: _argonMemory,
      iterations: _argonIterations,
      parallelism: _argonParallelism,
      length: _argonKeyLength,
    );
    return Uint8List.fromList(result.rawBytes);
  }

  /// Verschlüsselt Daten mit AES-256-GCM.
  ///
  /// Generiert eine zufällige Nonce für jede Verschlüsselung.
  /// Das Ergebnis wird als Base64-String im Format `[Nonce(12)] + [Tag(16)] + [Ciphertext]`
  /// zurückgegeben – kompatibel mit dem bisherigen Format.
  Future<String> encrypt(Uint8List data, Uint8List key) async {
    if (key.length != 32) throw Exception('Key muss exakt 32 Bytes lang sein (AES-256).');

    final nonce = Uint8List(_nonceSize);
    fillRandomBytes(nonce);

    final secretKey = await AesGcmSecretKey.importRawKey(key);

    // webcrypto liefert: ciphertext + tag (tag ist die letzten 16 Bytes)
    final output = await secretKey.encryptBytes(data, nonce);
    final cipherText = output.sublist(0, output.length - _tagSize);
    final tag        = output.sublist(output.length - _tagSize);

    // Speicherformat: nonce + tag + ciphertext
    final combined = Uint8List(_nonceSize + _tagSize + cipherText.length);
    combined.setRange(0,                              _nonceSize,               nonce);
    combined.setRange(_nonceSize,                     _nonceSize + _tagSize,    tag);
    combined.setRange(_nonceSize + _tagSize,          combined.length,          cipherText);

    return base64.encode(combined);
  }

  /// Entschlüsselt Daten, die mit [encrypt] erstellt wurden,
  /// und prüft deren Integrität (Auth-Tag).
  Future<Uint8List> decrypt(String encryptedDataBase64, Uint8List key) async {
    if (key.length != 32) throw Exception('Key muss exakt 32 Bytes lang sein (AES-256).');

    final blob = base64.decode(encryptedDataBase64);
    if (blob.length < _nonceSize + _tagSize) throw Exception('Datenformat ungültig.');

    final nonce      = blob.sublist(0,             _nonceSize);
    final tag        = blob.sublist(_nonceSize,    _nonceSize + _tagSize);
    final cipherText = blob.sublist(_nonceSize + _tagSize);

    // webcrypto erwartet: ciphertext + tag
    final combined = Uint8List(cipherText.length + _tagSize);
    combined.setRange(0,                combined.length - _tagSize, cipherText);
    combined.setRange(combined.length - _tagSize, combined.length,  tag);

    final secretKey = await AesGcmSecretKey.importRawKey(key);
    final clearText = await secretKey.decryptBytes(combined, nonce);
    return Uint8List.fromList(clearText);
  }

  // ------------------------------------------------------------------------
  // --- RSA ---
  // ------------------------------------------------------------------------

  /// Generiert ein RSA-4096 Schlüsselpaar.
  ///
  /// Rückgabe:
  /// - Public Key: Base64-kodierter SPKI-String (identisches Format wie bisher)
  /// - Private Key: PKCS#8 DER-Bytes (Uint8List)
  ///
  /// Nativ: BoringSSL (~1-2 Sekunden).
  /// Web: SubtleCrypto (~1-2 Sekunden).
  Future<(String publicKey, Uint8List privateKey)> generateRsaKeyPair() async {
    final keyPair = await RsaOaepPrivateKey.generateKey(
      _rsaModulusLength,
      _rsaPublicExponent,
      Hash.sha256,
    );

    final spkiBytes  = await keyPair.publicKey.exportSpkiKey();
    final pkcs8Bytes = await keyPair.privateKey.exportPkcs8Key();

    return (base64.encode(spkiBytes), Uint8List.fromList(pkcs8Bytes));
  }

  /// Verschlüsselt kleine Datenmengen mit einem RSA Public-Key (OAEP mit SHA-256).
  Future<String> encryptRsa(Uint8List data, String publicKeyBase64) async {
    final spkiBytes = base64.decode(publicKeyBase64);
    final publicKey = await RsaOaepPublicKey.importSpkiKey(spkiBytes, Hash.sha256);
    final encrypted = await publicKey.encryptBytes(data);
    return base64.encode(encrypted);
  }

  /// Entschlüsselt Daten mit einem RSA Private Key (OAEP mit SHA-256).
  ///
  /// [privateKeyBytes] sind PKCS#8 DER-Bytes (wie von [generateRsaKeyPair] geliefert).
  Future<Uint8List> decryptRsa(String encryptedDataBase64, Uint8List privateKeyBytes) async {
    final privateKey = await RsaOaepPrivateKey.importPkcs8Key(privateKeyBytes, Hash.sha256);
    final decrypted  = await privateKey.decryptBytes(base64.decode(encryptedDataBase64));
    return Uint8List.fromList(decrypted);
  }

  /// Signiert Daten mit dem RSA Private Key.
  ///
  /// Nutzt RSASSA-PKCS1-v1_5 mit SHA-256 (für Kompatibilität mit dem PHP-Backend).
  /// [privateKeyBytes] sind PKCS#8 DER-Bytes.
  Future<String> signData(Uint8List data, Uint8List privateKeyBytes) async {
    //final privateKey = _parsePrivateKeyBytes(privateKeyBytes);
    final privateKey = await RsassaPkcs1V15PrivateKey.importPkcs8Key(
      privateKeyBytes,
      Hash.sha256,
    );
    final signature = await privateKey.signBytes(data);
    return base64.encode(signature);
  }

  // ------------------------------------------------------------------------
  // --- Sonstiges ---
  // ------------------------------------------------------------------------

  /// Erzeugt einen SHA-256 Fingerprint eines (Base64-kodierten) Public-Keys.
  /// Format: HH:HH:HH:...
  String fingerprint(String publicKey) {
    if (publicKey.trim().isEmpty) return '';
    final hash = crypto_hash.sha256.convert(base64.decode(publicKey));
    return hash.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }

  /// Leitet mittels HKDF-SHA256 einen neuen symmetrischen Schlüssel ab.
  ///
  /// Deterministisch: gleiche Eingaben → gleicher Schlüssel.
  /// [info] beschreibt den Verwendungszweck (z.B. "friends-list-encryption").
  Future<Uint8List> deriveKeyFromKey(
    Uint8List keyMaterial,
    Uint8List? salt,
    String info,
  ) async {
    final hkdfKey = await HkdfSecretKey.importRawKey(keyMaterial);
    final derived = await hkdfKey.deriveBits(
      256,
      Hash.sha256,
      utf8.encode(info),
      salt ?? Uint8List(0),
    );
    return Uint8List.fromList(derived);
  }

  /// Berechnet einen SHA-256 Hash eines Strings (Rückgabe als Hex-String).
  String computeHash(String input) {
    final digest = crypto_hash.sha256.convert(utf8.encode(input));
    return digest.toString();
  }

  /// Generiert ein kryptografisch sicheres, 16-Byte langes Salt.
  Uint8List generateSalt() {
    final random = Random.secure();
    return Uint8List.fromList(List<int>.generate(16, (_) => random.nextInt(256)));
  }

  /// Überschreibt sensitive Daten im Arbeitsspeicher mit Nullen, um die Verweildauer von Schlüsseln zu minimieren.
  void wipeKey(Uint8List? key) {
    if (key == null) return;
    for (int i = 0; i < key.length; i++) {
      key[i] = 0;
    }
  }

  // // ------------------------------------------------------------------------
  // // --- Interne Methoden / Helper ---
  // // ------------------------------------------------------------------------
  //
  // /// Parst den Private-Key aus dem PKCS#8 Format.
  // RSAPrivateKey _parsePrivateKeyBytes(Uint8List bytes) {
  //   var workingBytes = bytes;
  //   if (workingBytes.isNotEmpty && workingBytes[0] == 45) {
  //     final pem = utf8.decode(workingBytes);
  //     workingBytes = base64.decode(_stripPem(pem));
  //   }
  //
  //   final asn1Parser = pc_asn1.ASN1Parser(workingBytes);
  //   final topLevelSeq = asn1Parser.nextObject() as pc_asn1.ASN1Sequence;
  //   pc_asn1.ASN1Sequence rsaSeq;
  //
  //   if (topLevelSeq.elements!.length >= 3 && topLevelSeq.elements![2] is pc_asn1.ASN1OctetString) {
  //     final privKeyOctet = topLevelSeq.elements![2] as pc_asn1.ASN1OctetString;
  //     final rsaParser = pc_asn1.ASN1Parser(privKeyOctet.valueBytes!);
  //     rsaSeq = rsaParser.nextObject() as pc_asn1.ASN1Sequence;
  //   } else {
  //     rsaSeq = topLevelSeq;
  //   }
  //
  //   BigInt getInt(int index) {
  //     final el = rsaSeq.elements![index];
  //     return (el as dynamic).integer ?? (el as dynamic).valueAsBigInteger;
  //   }
  //
  //   return RSAPrivateKey(getInt(1), getInt(3), getInt(4), getInt(5));
  // }
  //
  // /// Stellt sicher, dass der Public-Key im X.509 Format (736 Zeichen) vorliegt.
  // String _ensureX509Format(String keyPem) {
  //   final rawBase64 = _stripPem(keyPem);
  //   if (rawBase64.length == 736) return rawBase64;
  //
  //   if (rawBase64.length == 704) {
  //     // Umwandlung von PKCS#1 zu X.509
  //     final pkcs1Bytes = base64.decode(rawBase64);
  //
  //     final algorithmSeq = pc_asn1.ASN1Sequence();
  //     algorithmSeq.add(pc_asn1.ASN1ObjectIdentifier.fromIdentifierString('1.2.840.113549.1.1.1'));
  //     algorithmSeq.add(pc_asn1.ASN1Null());
  //
  //     // Bei ASN1BitString heißt der Parameter stringValues
  //     final publicKeyBitString = pc_asn1.ASN1BitString(stringValues: pkcs1Bytes);
  //
  //     final spkiSeq = pc_asn1.ASN1Sequence();
  //     spkiSeq.add(algorithmSeq);
  //     spkiSeq.add(publicKeyBitString);
  //
  //     return base64.encode(spkiSeq.encode());
  //   }
  //
  //   return rawBase64;
  // }
  //
  // /// Entfernt den Header und Footer aus dem PEM-String.
  // String _stripPem(String pem) {
  //   return pem
  //       .replaceAll(RegExp(r'-----BEGIN [A-Z ]+-----'), '') //
  //       .replaceAll(RegExp(r'-----END [A-Z ]+-----'), '')
  //       .replaceAll('\n', '')
  //       .replaceAll('\r', '')
  //       .trim();
  // }
  //
  // /// Stellt sicher, dass der Private-Key im PKCS#8 Format (Base64) vorliegt.
  // String _ensurePemHeader(String key, String type) {
  //   if (key.startsWith('-----')) return key;
  //   return "-----BEGIN RSA $type-----\n$key\n-----END RSA $type-----";
  // }
}
