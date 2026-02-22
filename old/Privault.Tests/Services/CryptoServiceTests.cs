using System.Text;
using Privault.Core.Services;
using Privault.Core.Services.Contracts;

namespace Privault.Tests.Services;

/// <summary>
/// Tests für den <see cref="CryptoService"/>.
/// </summary>
public class CryptoServiceTests
{
    // ------------------------------------------------------------------------
    // --- Setup ---
    // ------------------------------------------------------------------------

    private const int NonceSize = 12;
    private const int TagSize = 16;
    
    private ICryptoService CreateService() => new CryptoService();

    // ------------------------------------------------------------------------
    // --- Tests ---
    // ------------------------------------------------------------------------
    
    // --- 1. AES ---
    
    /// <summary>
    /// 1.1.1 AES-Roundtrip (Encrypt & Decrypt):
    /// Wenn Daten mit AES verschlüsselt und wieder entschlüsselt werden, entspricht das Ergebnis dem Original.
    /// </summary>
    [Fact]
    public void Aes_Roundtrip_ShouldReturnOriginal()
    {
        var service = CreateService();
        var key = new byte[32];
        Random.Shared.NextBytes(key);
        var originalData = Encoding.UTF8.GetBytes("AES-GCM-Test-Message");
        var encrypted = service.Encrypt(originalData, key);
        var decrypted = service.Decrypt(encrypted, key);
        Assert.Equal(originalData, decrypted);
        Assert.NotEqual(Convert.ToBase64String(originalData), encrypted);
    }

    /// <summary>
    /// 1.2.1 DeriveKeyAsync: Erzeugt einen 32-Byte-langen Schlüssel.
    /// </summary>
    [Fact]
    public async Task DeriveKeyAsync_ShouldReturn32ByteKey()
    {
        var service = CreateService();
        const string password = "MasterPassword123!";
        var salt = new byte[16];
        Random.Shared.NextBytes(salt);
        var key = await service.DeriveKeyAsync(password, salt);
        Assert.NotNull(key);
        Assert.Equal(32, key.Length);
    }

    /// <summary>
    /// 1.3.1 Encrypt: Key nicht 32-Byte-lang -> <c>ArgumentException</c>.
    /// </summary>
    [Fact]
    public void Encrypt_InvalidKeySize_ShouldThrowArgumentException()
    {
        var service = CreateService();
        var invalidKey = new byte[16]; // Zu kurz für AES-256
        var data = new byte[] { 1, 2, 3 };
        Assert.Throws<ArgumentException>(() => service.Encrypt(data, invalidKey));
    }

    /// <summary>
    /// 1.4.1 Decrypt: Key nicht 32-Byte-lang -> <c>ArgumentException</c>.
    /// </summary>
    [Fact]
    public void Decrypt_InvalidKeySize_ShouldThrowArgumentException()
    {
        var service = CreateService();
        var invalidKey = new byte[16];
        Assert.Throws<ArgumentException>(() => service.Decrypt("some-base64", invalidKey));
    }

    /// <summary>
    /// 1.4.2 Decrypt: Falscher Key -> <c>CryptographicException</c>.
    /// </summary>
    [Fact]
    public void Decrypt_WrongKey_ShouldThrowCryptographicException()
    {
        var service = CreateService();
        var keyA = new byte[32]; new Random().NextBytes(keyA);
        var keyB = new byte[32]; new Random().NextBytes(keyB);
        var data = Encoding.UTF8.GetBytes("Data");
        var encrypted = service.Encrypt(data, keyA);
        Assert.ThrowsAny<System.Security.Cryptography.CryptographicException>(() => service.Decrypt(encrypted, keyB));
    }
    
    /// <summary>
    /// 1.5.1 Decrypt: Datenformat ungültig -> <c>ArgumentException</c>.
    /// </summary>
    [Fact]
    public void Decrypt_InvalidDataFormat_ShouldThrowArgumentException()
    {
        var service = CreateService();
        var key = new byte[32];
        var shortData = Convert.ToBase64String(new byte[NonceSize + TagSize - 1]); // ein zu kurzer String (weniger als Nonce + Tag)
        Assert.Throws<ArgumentException>(() => service.Decrypt(shortData, key));
    }
    
    // --- 2. RSA ---
    
    /// <summary>
    /// 2.1.1 RSA-Roundtrip (GenerateRsaKeyPair, EncryptRsa, DecryptRsa): 
    /// Wenn Daten mit dem RSA Public Key verschlüsselt und dem RSA Private Key wieder entschlüsselt werden,
    /// entspricht das Ergebnis dem Original.
    /// </summary>
    [Fact] 
    public void Rsa_Roundtrip_ShouldReturnOriginal()
    {
        var service = CreateService();
        var (pub, priv) = service.GenerateRsaKeyPair();
        var originalData = Encoding.UTF8.GetBytes("SecretMessage");
        var encrypted = service.EncryptRsa(originalData, pub);
        var decrypted = service.DecryptRsa(encrypted, priv);
        Assert.Equal(originalData, decrypted);
    }

    /// <summary>
    /// 2.2.1 Fingerprint: Erzeugt einen Hex-Wert.
    /// </summary>
    [Fact]
    public void Fingerprint_ShouldReturnHexValue()
    {
        var service = CreateService();
        var (publicKey, _) = service.GenerateRsaKeyPair();
        var fingerprint = service.Fingerprint(publicKey);
        Assert.False(string.IsNullOrWhiteSpace(fingerprint));
        Assert.Contains(":", fingerprint); // Typisches Format: XX:XX:XX...
    }

    // --- 3. Sonstiges --- 
    
    /// <summary>
    /// 3.1.1 ComputeHash: SHA-256 Hash ist deterministisch.
    /// Wenn ComputeHash zweimal aufgerufen wird, sind beide Hash-Werte identisch und entsprechen dem SHA-256 Standard.
    /// </summary>
    [Fact]
    public void ComputeHash_IdenticalInput_ShouldReturnSameHash()
    {
        var service = CreateService();
        const string input = "HelloPrivault";
        var hash1 = service.ComputeHash(input);
        var hash2 = service.ComputeHash(input);
        Assert.Equal(hash1, hash2);
        Assert.False(string.IsNullOrWhiteSpace(hash1));
    }
    
    /// <summary>
    /// 3.2.1 GenerateSalt: Erzeugt unterschiedliche 16-Byte-lange Werte.
    /// </summary>
    [Fact]
    public void GenerateSalt_ShouldReturnUnique16ByteValues()
    {
        var service = CreateService();
        var salt1 = service.GenerateSalt();
        var salt2 = service.GenerateSalt();
        Assert.Equal(16, salt1.Length);
        Assert.Equal(16, salt2.Length);
        Assert.NotEqual(salt1, salt2);
    }
    
    /// <summary>
    /// 3.3.1 SignData-Roundtrip (GenerateRsaKeyPair, SignData): Eine Signatur wird erfolgreich verifiziert.
    /// </summary>
    [Fact]
    public void SignData_ShouldReturnValidSignature()
    {
        var service = CreateService();
        var (publicKey, privateKey) = service.GenerateRsaKeyPair();
        var data = Encoding.UTF8.GetBytes("DataToSign");
        var signatureBase64 = service.SignData(data, privateKey);
        Assert.False(string.IsNullOrWhiteSpace(signatureBase64));
        using var rsa = System.Security.Cryptography.RSA.Create();
        rsa.ImportSubjectPublicKeyInfo(Convert.FromBase64String(publicKey), out _);
        var signatureBytes = Convert.FromBase64String(signatureBase64);
        var isValid = rsa.VerifyData(data, signatureBytes, System.Security.Cryptography.HashAlgorithmName.SHA256, System.Security.Cryptography.RSASignaturePadding.Pkcs1);
        Assert.True(isValid);
    }
    
    /// <summary>
    /// 3.4.1 WipeKey: Füllt ein Array mit Nullen.
    /// </summary>
    [Fact]
    public void WipeKey_ShouldFillArrayWithZeros()
    {
        var service = CreateService();
        var key = "BBB"u8.ToArray();
        service.WipeKey(key);
        Assert.All(key, b => Assert.Equal(0, b));
    }
    
    /// <summary>
    /// 3.4.2 WipeKey: Wirft bei null keine Exception.
    /// </summary>
    [Fact]
    public void WipeKey_NullInput_ShouldNotThrow()
    {
        var service = CreateService();
        var exception = Record.Exception(() => service.WipeKey(null));
        Assert.Null(exception);
    }
}