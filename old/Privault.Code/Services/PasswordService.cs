using Privault.Core.Services.Contracts;

namespace Privault.Core.Services;

/// <inheritdoc />
public class PasswordService : IPasswordService
{
    /// <inheritdoc />
    public int EstimateStrength(string password)
    {
        if (string.IsNullOrEmpty(password)) return 0;
        
        // Zxcvbn bewertet Passwörter sehr realistisch.
        // 0 = Zu erraten < 10^3 Versuche
        // 1 = < 10^6
        // 2 = < 10^8
        // 3 = < 10^10
        // 4 = Sehr stark
        var result = Zxcvbn.Core.EvaluatePassword(password);
        return result.Score;
    }

    /// <inheritdoc />
    public string GeneratePassword(int length, bool avoidIlO0, string? specialChars)
    {
        specialChars ??= "!@#$%^&*()_+-=[]{}|;:,.<>?";
        // ReSharper disable once StringLiteralTypo
        var chars = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ123456789" + (!avoidIlO0 ? "IlO0" : "" ) + specialChars;
        var random = new Random();
        return new string(Enumerable.Repeat(chars, length).Select(s => s[random.Next(s.Length)]).ToArray());
    }
}