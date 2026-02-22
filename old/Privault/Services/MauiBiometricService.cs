using Privault.Core.Services.Contracts;

#if WINDOWS
using Windows.Security.Credentials.UI;
#else
using Plugin.Fingerprint;
using Plugin.Fingerprint.Abstractions;
#endif

namespace Privault.Services;

/// <summary>
/// MAUI-Implementierung für die Biometrie-Unterstützung.
/// </summary>
public class MauiBiometricService : IBiometricService
{
    private string GetKey(string vaultName) => $"priVault_key_{vaultName}";
    
    /// <inheritdoc />
    public async Task<bool> IsAvailableAsync()
    {
        try
        {
#if WINDOWS
            // Windows Hello Check.
            // Die Klasse `UserConsentVerifier` ist der offizielle Weg für WinUI3-Apps, um den Standard-Windows-Dialog
            // für PIN, Fingerabdruck oder Gesichtserkennung aufzurufen.
            var availability = await UserConsentVerifier.CheckAvailabilityAsync();
            return availability == UserConsentVerifierAvailability.Available;
#else
            // Android/iOS Check
            return await CrossFingerprint.Current.IsAvailableAsync();
#endif
        }
        catch (Exception)
        {
            return false; 
        }
    }

    /// <inheritdoc />
    public async Task<bool> ContainsMasterKeyAsync(string vaultName)
    {
        // Wir lesen nur den Header/Existenz, ohne den User zu nerven
        var result = await SecureStorage.Default.GetAsync(GetKey(vaultName));
        return !string.IsNullOrEmpty(result);
    }
    
    /// <inheritdoc />
    public async Task SaveMasterKeyAsync(string vaultName, byte[] masterKey)
    {
        // Speichert den Key im OS-Secure-Store.
        var base64Key = Convert.ToBase64String(masterKey);
        await SecureStorage.Default.SetAsync(GetKey(vaultName), base64Key);
    }

    /// <inheritdoc />
    public async Task<byte[]?> GetMasterKeyAsync(string vaultName)
    {
        var base64Key = await SecureStorage.Default.GetAsync(GetKey(vaultName));
        if (string.IsNullOrEmpty(base64Key)) return null;

#if WINDOWS
        // Windows Hello Abfrage
        var result = await UserConsentVerifier.RequestVerificationAsync($"Tresor '{vaultName}' entschlüsseln");
        var authenticated = result == UserConsentVerificationResult.Verified;
#else
        // Android/iOS Abfrage
        var request = new AuthenticationRequestConfiguration("priVault Login", $"Tresor '{vaultName}' entschlüsseln");
        var authResult = await CrossFingerprint.Current.AuthenticateAsync(request);
        var authenticated = authResult.Authenticated;
#endif

        return authenticated ? Convert.FromBase64String(base64Key) : null;
    }

    /// <inheritdoc />
    public Task RemoveMasterKeyAsync(string vaultName)
    {
        SecureStorage.Default.Remove(GetKey(vaultName));
        return Task.CompletedTask;
    }
}