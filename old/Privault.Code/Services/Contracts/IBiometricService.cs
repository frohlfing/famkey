// Privault.Core/Services/Contracts/IBiometricService.cs

namespace Privault.Core.Services.Contracts;

/// <summary>
/// Biometrie-Unterstützung.
/// <para>
/// Ermöglicht das Einloggen per Fingerabdruck oder Gesichtserkennung.
/// Definiert die Schnittstelle für biometrische Authentifizierung und die sichere 
/// Verwahrung des Master-Keys im Hardware-Keystore des Geräts.
/// </para>
/// </summary>
/// <remarks>
/// Die Implementierung ist plattformabhängig (MAUI/Web).
/// </remarks>
public interface IBiometricService
{
    /// <summary>
    /// Prüft, ob das Gerät Biometrie unterstützt und diese konfiguriert ist.
    /// </summary>
    Task<bool> IsAvailableAsync();

    /// <summary>
    /// Prüft, ob für den angegebenen Tresor bereits ein biometrisch geschützter 
    /// Schlüssel im sicheren Speicher existiert.
    /// </summary>
    /// <param name="vaultName">Der Name des Tresors.</param>
    /// <returns>True, wenn ein Schlüssel vorhanden ist.</returns>
    Task<bool> ContainsMasterKeyAsync(string vaultName);
    
    /// <summary>
    /// Speichert den abgeleiteten Master-Key im Hardware-Keystore/Keychain (Secure-Store).
    /// Der Zugriff auf diesen Wert wird durch das Betriebssystem biometrisch geschützt.
    /// </summary>
    /// <param name="vaultName">Der Name des Tresors.</param>
    /// <param name="masterKey">Der 32-Byte AES-Schlüssel.</param>
    Task SaveMasterKeyAsync(string vaultName, byte[] masterKey);

    /// <summary>
    /// Initiiert die biometrische Abfrage (System-Dialog) und gibt bei Erfolg 
    /// den gespeicherten Master-Key zurück. 
    /// </summary>
    /// <param name="vaultName">Der Name des Tresors.</param>
    /// <returns>Der Schlüssel als Byte-Array oder null bei Abbruch/Fehler.</returns>
    /// <remarks>
    /// Löst System-Dialog aus.
    /// </remarks>
    Task<byte[]?> GetMasterKeyAsync(string vaultName);

    /// <summary>
    /// Entfernt den biometrisch geschützten Schlüssel für einen Tresor.
    /// </summary>
    /// <param name="vaultName">Der Name des Tresors.</param>
    Task RemoveMasterKeyAsync(string vaultName);
}