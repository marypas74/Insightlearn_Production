using System.Security.Cryptography;
using Microsoft.Extensions.Logging;
using InsightLearn.Core.Interfaces;
using BCrypt.Net;

namespace InsightLearn.Infrastructure.Services;

public class PasswordService : IPasswordService
{
    private readonly ILogger<PasswordService> _logger;

    public PasswordService(ILogger<PasswordService> logger)
    {
        _logger = logger;
    }

    public string HashPassword(string password)
    {
        if (string.IsNullOrWhiteSpace(password))
        {
            throw new ArgumentException("Password cannot be null or empty", nameof(password));
        }

        try
        {
            // Use BCrypt with work factor 12 for strong security
            var hashedPassword = BCrypt.Net.BCrypt.HashPassword(password, 12);

            _logger.LogDebug("Password hashed successfully");

            return hashedPassword;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error occurred while hashing password");
            throw new InvalidOperationException("Failed to hash password", ex);
        }
    }

    public bool VerifyPassword(string password, string hash)
    {
        if (string.IsNullOrWhiteSpace(password))
        {
            return false;
        }

        if (string.IsNullOrWhiteSpace(hash))
        {
            return false;
        }

        try
        {
            var isValid = BCrypt.Net.BCrypt.Verify(password, hash);

            _logger.LogDebug("Password verification completed with result: {IsValid}", isValid);

            return isValid;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error occurred while verifying password");
            return false;
        }
    }

    public string GenerateSecureToken()
    {
        try
        {
            // Generate a 32-byte (256-bit) secure random token
            using var rng = RandomNumberGenerator.Create();
            var tokenBytes = new byte[32];
            rng.GetBytes(tokenBytes);

            // Convert to URL-safe base64 string
            var token = Convert.ToBase64String(tokenBytes)
                .Replace('+', '-')
                .Replace('/', '_')
                .Replace("=", "");

            _logger.LogDebug("Secure token generated successfully");

            return token;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error occurred while generating secure token");
            throw new InvalidOperationException("Failed to generate secure token", ex);
        }
    }

    /// <summary>
    /// Validates password strength according to security requirements
    /// </summary>
    /// <param name="password">Password to validate</param>
    /// <returns>Tuple indicating if password is valid and error message if not</returns>
    public (bool IsValid, string ErrorMessage) ValidatePasswordStrength(string password)
    {
        if (string.IsNullOrWhiteSpace(password))
        {
            return (false, "Password is required");
        }

        if (password.Length < 8)
        {
            return (false, "Password must be at least 8 characters long");
        }

        if (password.Length > 128)
        {
            return (false, "Password must be no longer than 128 characters");
        }

        var hasLower = password.Any(char.IsLower);
        var hasUpper = password.Any(char.IsUpper);
        var hasDigit = password.Any(char.IsDigit);
        var hasSpecial = password.Any(c => !char.IsLetterOrDigit(c));

        if (!hasLower)
        {
            return (false, "Password must contain at least one lowercase letter");
        }

        if (!hasUpper)
        {
            return (false, "Password must contain at least one uppercase letter");
        }

        if (!hasDigit)
        {
            return (false, "Password must contain at least one digit");
        }

        if (!hasSpecial)
        {
            return (false, "Password must contain at least one special character");
        }

        // Check for common weak patterns
        var lowerPassword = password.ToLower();
        var weakPatterns = new[]
        {
            "password", "123456", "qwerty", "abc123", "admin", "letmein",
            "welcome", "monkey", "dragon", "master", "login", "password123"
        };

        if (weakPatterns.Any(pattern => lowerPassword.Contains(pattern)))
        {
            return (false, "Password contains common weak patterns");
        }

        return (true, string.Empty);
    }
}