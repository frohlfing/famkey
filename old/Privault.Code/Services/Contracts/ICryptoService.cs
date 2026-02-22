namespace Privault.Core.Services.Contracts;

/// <summary>
/// Definiert die kryptografischen Kernfunktionen der Anwendung basierend auf modernen Industriestandards (AES-GCM, RSA-4096, Argon2id).
/// Diese Klasse ist verantwortlich für den Schutz der Daten im Ruhezustand (at rest) und während der Übertragung (in transit).
/// <para>
/// <b>Sicherheitsmerkmale:</b>
/// <list type="bullet">
/// <item><b>Schlüsselableitung:</b> Argon2id zur Härtung von Master-Passwörtern gegen Brute-Force-Angriffe.</item>
/// <item><b>Symmetrische Verschlüsselung:</b> AES-256-GCM für authentifizierte Verschlüsselung der Tresordaten.</item>
/// <item><b>Asymmetrische Verschlüsselung:</b> RSA-4096 (OAEP-SHA256) für den sicheren Schlüsselaustausch und Identitätsnachweise.</item>
/// <item><b>Speichersicherheit:</b> Aktives Key-Wiping zur Minimierung der Lebensdauer von Schlüsseln im RAM.</item>
/// </list>
/// </para>
/// </summary>
public interface ICryptoService
{
    // --- AES ---
        
    /// <summary>
    /// Leitet aus einem Passwort und Salt einen 32-Byte AES-Schlüssel mittels Argon2id ab.
    /// </summary>
    /// <param name="password">Das Klartext-Passwort des Benutzers.</param>
    /// <param name="salt">Das benutzerspezifische 16-Byte Salt.</param>
    /// <returns>Der abgeleitete kryptografische Schlüssel.</returns>
    Task<byte[]> DeriveKeyAsync(string password, byte[] salt);

    /// <summary>
    /// Verschlüsselt Daten mit AES-256-GCM. Das Ergebnis ist ein kombinierter Base64-String.
    /// </summary>
    /// <param name="data">Die unverschlüsselten Rohdaten.</param>
    /// <param name="key">Der 32-Byte AES-Schlüssel.</param>
    /// <returns>Base64-String im Format: [Nonce (12 Bytes)] + [Tag (16 Bytes)] + [Ciphertext].</returns>
    string Encrypt(byte[] data, byte[] key);

    /// <summary>
    /// Entschlüsselt Daten, die mit <see cref="Encrypt"/> erstellt wurden, und prüft deren Integrität (Auth-Tag).
    /// </summary>
    /// <param name="encryptedData">Das kombinierte Base64-kodierte Byte-Array [Nonce+Tag+Ciphertext].</param>
    /// <param name="key">Der 32-Byte AES-Schlüssel.</param>
    /// <returns>Die entschlüsselten Rohdaten.</returns>
    /// <exception cref="System.Security.Cryptography.CryptographicException">Wird geworfen bei falschem Schlüssel oder Datenmanipulation.</exception>
    byte[] Decrypt(string encryptedData, byte[] key);
    
    // --- RSA ---

    /// <summary>
    /// Generiert ein neues RSA-4096 Schlüsselpaar für eine Benutzeridentität.
    /// </summary>
    /// <returns>Ein Tupel bestehend aus dem Public Key (Base64) und dem Private Key (PKCS#8 Byte-Array).</returns>
    (string publicKey, byte[] privateKey) GenerateRsaKeyPair();

    /// <summary>
    /// Verschlüsselt kleine Datenmengen (z.B. AES-Keys) mit einem öffentlichen RSA-Schlüssel.
    /// </summary>
    /// <param name="data">Die zu verschlüsselnden Daten.</param>
    /// <param name="publicKey">Der öffentliche RSA-Schlüssel als SPKI Base64-String.</param>
    /// <returns>Die verschlüsselten Daten als Base64-String.</returns>
    string EncryptRsa(byte[] data, string publicKey);

    /// <summary>
    /// Entschlüsselt Daten mit einem privaten RSA-Schlüssel (OAEP-SHA256 Padding).
    /// </summary>
    /// <param name="encryptedData">Die Base64-kodierten verschlüsselten Daten.</param>
    /// <param name="privateKey">Der private RSA-Schlüssel als PKCS#8 Byte-Array.</param>
    /// <returns>Die entschlüsselten Rohdaten.</returns>
    byte[] DecryptRsa(string encryptedData, byte[] privateKey);

    /// <summary>
    /// Berechnet einen visuellen Fingerprint (SHA-256) aus einem öffentlichen Schlüssel für den manuellen Vergleich.
    /// </summary>
    /// <param name="publicKey">Der öffentliche Schlüssel als Base64-String.</param>
    /// <returns>Ein formatierter String (z.B. "AA:BB:CC...").</returns>
    string Fingerprint(string publicKey);

    // --- Sonstiges ---
    
    /// <summary>
    /// Leitet mittels HKDF-SHA256 einen neuen symmetrischen Schlüssel aus einem bestehenden Schlüsselmaterial ab.
    /// </summary>
    /// <param name="inputKeyMaterial">Das geheime Eingangsmaterial (z.B. RSA Private Key).</param>
    /// <param name="salt">Optionales Salt (wenn null, wird ein leerer Salt angenommen).</param>
    /// <param name="info">Optionaler Kontext-String (z.B. Verwendungszweck).</param>
    /// <returns>Ein 32-Byte Schlüssel (für AES-256).</returns>
    byte[] DeriveKeyFromKey(byte[] inputKeyMaterial, byte[]? salt = null, string info = "");
    
    /// <summary>
    /// Berechnet den SHA-256 Hash einer Zeichenkette (z.B. zur Pseudonymisierung von Tresornamen).
    /// </summary>
    /// <param name="input">Die zu hashende Eingabe.</param>
    /// <returns>Der hexadezimale Hash-String.</returns>
    string ComputeHash(string input);

    /// <summary>
    /// Generiert ein kryptografisch sicheres Zufalls-Salt (16 Bytes).
    /// </summary>
    /// <returns>Ein zufälliges Byte-Array.</returns>
    byte[] GenerateSalt();
    
    /// <summary>
    /// Erzeugt eine digitale RSA-Signatur für Daten, um die Authentizität gegenüber dem Server nachzuweisen.
    /// </summary>
    /// <param name="data">Die zu signierenden Rohdaten.</param>
    /// <param name="privateKey">Der private RSA-Schlüssel.</param>
    /// <returns>Die Base64-kodierte Signatur.</returns>
    string SignData(byte[] data, byte[] privateKey);
    
    /// <summary>
    /// Überschreibt sensitive Daten im Arbeitsspeicher mit Nullen, um die Verweildauer von Schlüsseln zu minimieren.
    /// </summary>
    /// <param name="key">Das zu löschende Byte-Array.</param>
    void WipeKey(byte[]? key);
}