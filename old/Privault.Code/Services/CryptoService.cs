#pragma warning disable CA1416 // unterdrückt Warning CA1416: "... nicht unterstützt für: ios ..." 

using Encoding = System.Text.Encoding;
using Konscious.Security.Cryptography;
using Privault.Core.Services.Contracts;
using System.Security.Cryptography;

namespace Privault.Core.Services;

/// <inheritdoc cref="ICryptoService" />
public class CryptoService : ICryptoService
{
    // ------------------------------------------------------------------------
    // --- Konstanten ---
    // ------------------------------------------------------------------------
    
    // Argon2id Parameter (BSI-konform)
    private const int ArgonMemorySize = 64 * 1024; // 64 MB RAM
    private const int ArgonIterations = 4;
    private const int ArgonParallelism = 4;

    // AES-GCM Konstanten
    private const int NonceSize = 12; // 96 Bit IV (Standard für GCM)
    private const int TagSize = 16; // 128 Bit Authentication Tag

    // ------------------------------------------------------------------------
    // --- Öffentliche Methoden ---
    // ------------------------------------------------------------------------
    
    // --- AES ---
    
    /// <inheritdoc />
    public async Task<byte[]> DeriveKeyAsync(string password, byte[] salt)
    {
        var passwordBytes = Encoding.UTF8.GetBytes(password);
        try
        {
            using var argon2 = new Argon2id(passwordBytes);
            argon2.Salt = salt;
            argon2.DegreeOfParallelism = ArgonParallelism;
            argon2.MemorySize = ArgonMemorySize;
            argon2.Iterations = ArgonIterations;

            // Erzeugt 32 Bytes (256 Bit) für AES
            return await argon2.GetBytesAsync(32);
        }
        finally
        {
            WipeKey(passwordBytes);
        }
    }
    
    /// <inheritdoc />
    public string Encrypt(byte[] data, byte[] key)
    {
        // Validierung
        if (key.Length != 32)
            throw new ArgumentException("Key muss exakt 32 Bytes lang sein (AES-256).", nameof(key));

        // Zufällige Nonce für jede Verschlüsselung generieren (Wichtig!)
        var nonce = new byte[NonceSize];
        RandomNumberGenerator.Fill(nonce);

        var cipherText = new byte[data.Length];
        var tag = new byte[TagSize];

        using (var aes = new AesGcm(key, TagSize))
        {
            // Führt Verschlüsselung durch und berechnet das Auth-Tag
            aes.Encrypt(nonce, data, cipherText, tag);
        }

        // Ergebnis zusammenbauen: [Nonce] + [Tag] + [Ciphertext]
        var blob = new byte[NonceSize + TagSize + cipherText.Length];
        Buffer.BlockCopy(nonce, 0, blob, 0, NonceSize);
        Buffer.BlockCopy(tag, 0, blob, NonceSize, TagSize);
        Buffer.BlockCopy(cipherText, 0, blob, NonceSize + TagSize, cipherText.Length);

        return Convert.ToBase64String(blob);
    }
    
    /// <inheritdoc />
    public byte[] Decrypt(string encryptedData, byte[] key)
    {
        if (key.Length != 32)
            throw new ArgumentException("Key muss 32 Bytes lang sein.", nameof(key));

        var blob = Convert.FromBase64String(encryptedData);
        if (blob.Length < NonceSize + TagSize)
            throw new ArgumentException("Datenformat ungültig.");

        // Arrays für die Extraktion vorbereiten
        var nonce = new byte[NonceSize];
        var tag = new byte[TagSize];
        var cipherTextSize = blob.Length - NonceSize - TagSize;
        var cipherText = new byte[cipherTextSize];
        var plainText = new byte[cipherTextSize];

        // Daten aus dem Blob extrahieren
        Buffer.BlockCopy(blob, 0, nonce, 0, NonceSize);
        Buffer.BlockCopy(blob, NonceSize, tag, 0, TagSize);
        Buffer.BlockCopy(blob, NonceSize + TagSize, cipherText, 0, cipherTextSize);

        // Entschlüsseln
        using var aes = new AesGcm(key, TagSize);
        aes.Decrypt(nonce, cipherText, tag, plainText);

        return plainText;
    }
    
    // --- RSA ---

    /// <inheritdoc />
    public (string publicKey, byte[] privateKey) GenerateRsaKeyPair()
    {
        // Exportieren in Standard-Formate (SPKI für Public, PKCS#8 für Private)
        using var rsa = RSA.Create(4096);
        var pubKey = Convert.ToBase64String(rsa.ExportSubjectPublicKeyInfo());
        var privKey = rsa.ExportPkcs8PrivateKey();
        return (pubKey, privKey);
    }

    /// <inheritdoc />
    public string EncryptRsa(byte[] data, string publicKey)
    {
        using var rsa = RSA.Create();
        rsa.ImportSubjectPublicKeyInfo(Convert.FromBase64String(publicKey), out _);
        var blob = rsa.Encrypt(data, RSAEncryptionPadding.OaepSHA256); // OAEP mit SHA-256 (BSI Empfehlung)
        return Convert.ToBase64String(blob);
    }

    /// <inheritdoc />
    public byte[] DecryptRsa(string encryptedData, byte[] privateKey)
    {
        var blob = Convert.FromBase64String(encryptedData);
        using var rsa = RSA.Create();
        rsa.ImportPkcs8PrivateKey(privateKey, out _);
        return rsa.Decrypt(blob, RSAEncryptionPadding.OaepSHA256);
    }

    /// <inheritdoc />
    public string Fingerprint(string publicKey)
    {
        if (string.IsNullOrWhiteSpace(publicKey)) return string.Empty;
        var hash = SHA256.HashData(Convert.FromBase64String(publicKey));
        return BitConverter.ToString(hash).Replace("-", ":");
    }

    // --- Sonstiges ---
    
    /// <inheritdoc />
    public byte[] DeriveKeyFromKey(byte[] inputKeyMaterial, byte[]? salt = null, string info = "")
    {
        // Wir nutzen HKDF-SHA256, um aus einem inputKey (z.B. RSA PrivKey) einen symmetrischen Key abzuleiten.
        // Das Ergebnis ist ein pseudozufälliger 32-Byte (256 Bit) Schlüssel.
        // salt ist optional, aber empfohlen. info ist Kontext (z.B. "friends-list-encryption").
            
        // RFC 5869
        return HKDF.DeriveKey(
            HashAlgorithmName.SHA256, 
            inputKeyMaterial, 
            32, // Output length für AES-256
            salt, 
            Encoding.UTF8.GetBytes(info));
    }

    /// <inheritdoc />
    public string ComputeHash(string input)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(input));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
    
    /// <inheritdoc />
    public byte[] GenerateSalt()
    {
        var salt = new byte[16];
        RandomNumberGenerator.Fill(salt);
        return salt;
    }

    /// <inheritdoc />
    public string SignData(byte[] data, byte[] privateKey)
    {
        using var rsa = RSA.Create();
        rsa.ImportPkcs8PrivateKey(privateKey, out _);
            
        // Signieren mit PKCS#1 v1.5 (für maximale Kompatibilität mit PHP) (PSS ist moderner, aber nicht kompatibel mit PHP)
        var signature = rsa.SignData(data, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
        return Convert.ToBase64String(signature);
    }
    
    /// <inheritdoc />
    public void WipeKey(byte[]? key)
    {
        if (key == null)
            return;
       
        // Explizite Schleife statt Array.Clear, um Compiler-Optimierungen zu verhindern.
        for (var i = 0; i < key.Length; i++)
        {
            key[i] = 0;
        }
    }
}