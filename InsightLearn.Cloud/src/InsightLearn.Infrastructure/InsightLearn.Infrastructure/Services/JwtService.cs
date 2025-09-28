using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Tokens;
using InsightLearn.Core.Interfaces;
using InsightLearn.Core.Models;
using InsightLearn.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace InsightLearn.Infrastructure.Services;

public class JwtService : IJwtService
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<JwtService> _logger;
    private readonly ApplicationDbContext _context;

    public JwtService(IConfiguration configuration, ILogger<JwtService> logger, ApplicationDbContext context)
    {
        _configuration = configuration;
        _logger = logger;
        _context = context;
    }

    public string GenerateAccessToken(User user, List<string> roles, List<string> permissions)
    {
        var jwtSettings = _configuration.GetSection("JwtSettings");
        var key = Encoding.ASCII.GetBytes(jwtSettings["SecretKey"] ?? throw new InvalidOperationException("JWT SecretKey not configured"));
        var tokenLifetime = TimeSpan.FromMinutes(int.Parse(jwtSettings["AccessTokenExpirationMinutes"] ?? "15"));

        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new(JwtRegisteredClaimNames.Email, user.Email),
            new(JwtRegisteredClaimNames.GivenName, user.FirstName),
            new(JwtRegisteredClaimNames.FamilyName, user.LastName),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new(JwtRegisteredClaimNames.Iat, DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString(), ClaimValueTypes.Integer64)
        };

        // Add roles as claims
        foreach (var role in roles)
        {
            claims.Add(new Claim(ClaimTypes.Role, role));
        }

        // Add permissions as claims
        foreach (var permission in permissions)
        {
            claims.Add(new Claim("permission", permission));
        }

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Expires = DateTime.UtcNow.Add(tokenLifetime),
            SigningCredentials = new SigningCredentials(new SymmetricSecurityKey(key), SecurityAlgorithms.HmacSha256),
            Issuer = jwtSettings["Issuer"],
            Audience = jwtSettings["Audience"]
        };

        var tokenHandler = new JwtSecurityTokenHandler();
        var token = tokenHandler.CreateToken(tokenDescriptor);

        _logger.LogInformation("Generated JWT token for user {UserId} with {RoleCount} roles and {PermissionCount} permissions",
            user.Id, roles.Count, permissions.Count);

        return tokenHandler.WriteToken(token);
    }

    public string GenerateRefreshToken()
    {
        var randomBytes = new byte[64];
        using var rng = RandomNumberGenerator.Create();
        rng.GetBytes(randomBytes);
        return Convert.ToBase64String(randomBytes);
    }

    public int? ValidateAccessToken(string token)
    {
        try
        {
            var jwtSettings = _configuration.GetSection("JwtSettings");
            var key = Encoding.ASCII.GetBytes(jwtSettings["SecretKey"] ?? throw new InvalidOperationException("JWT SecretKey not configured"));

            var tokenHandler = new JwtSecurityTokenHandler();
            var validationParameters = new TokenValidationParameters
            {
                ValidateIssuerSigningKey = true,
                IssuerSigningKey = new SymmetricSecurityKey(key),
                ValidateIssuer = true,
                ValidIssuer = jwtSettings["Issuer"],
                ValidateAudience = true,
                ValidAudience = jwtSettings["Audience"],
                ValidateLifetime = true,
                ClockSkew = TimeSpan.Zero
            };

            var principal = tokenHandler.ValidateToken(token, validationParameters, out var validatedToken);
            var userIdClaim = principal.FindFirst(JwtRegisteredClaimNames.Sub)?.Value;

            if (int.TryParse(userIdClaim, out var userId))
            {
                return userId;
            }

            return null;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to validate JWT token");
            return null;
        }
    }

    public RefreshToken? GetRefreshToken(string token)
    {
        return _context.RefreshTokens
            .Include(rt => rt.User)
            .FirstOrDefault(rt => rt.Token == token);
    }

    public async Task RevokeRefreshTokenAsync(RefreshToken token, string? ipAddress = null, string? replacedByToken = null)
    {
        token.RevokedAt = DateTime.UtcNow;
        token.RevokedByIp = ipAddress;
        token.ReplacedByToken = replacedByToken;

        _context.RefreshTokens.Update(token);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Revoked refresh token for user {UserId} from IP {IpAddress}",
            token.UserId, ipAddress);
    }

    public async Task RevokeDescendantRefreshTokensAsync(RefreshToken refreshToken, User user, string ipAddress, string reason)
    {
        // Recursively traverse the refresh token chain and revoke each descendant token
        if (!string.IsNullOrEmpty(refreshToken.ReplacedByToken))
        {
            var childToken = _context.RefreshTokens
                .FirstOrDefault(rt => rt.Token == refreshToken.ReplacedByToken);

            if (childToken != null && childToken.IsActive)
            {
                await RevokeRefreshTokenAsync(childToken, ipAddress, reason);
                await RevokeDescendantRefreshTokensAsync(childToken, user, ipAddress, reason);
            }
        }
    }

    public async Task RotateRefreshTokenAsync(RefreshToken refreshToken, string ipAddress)
    {
        var newRefreshToken = new RefreshToken
        {
            UserId = refreshToken.UserId,
            Token = GenerateRefreshToken(),
            Expires = DateTime.UtcNow.AddDays(int.Parse(_configuration.GetSection("JwtSettings")["RefreshTokenExpirationDays"] ?? "7")),
            CreatedAt = DateTime.UtcNow,
            CreatedByIp = ipAddress
        };

        // Mark the old token as revoked and replaced by the new token
        refreshToken.RevokedAt = DateTime.UtcNow;
        refreshToken.RevokedByIp = ipAddress;
        refreshToken.ReplacedByToken = newRefreshToken.Token;

        // Add the new refresh token
        _context.RefreshTokens.Add(newRefreshToken);
        _context.RefreshTokens.Update(refreshToken);

        await _context.SaveChangesAsync();

        _logger.LogInformation("Rotated refresh token for user {UserId} from IP {IpAddress}",
            refreshToken.UserId, ipAddress);
    }
}