using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.EntityFrameworkCore;
using InsightLearn.Core.DTOs;
using InsightLearn.Core.Interfaces;
using InsightLearn.Core.Models;
using InsightLearn.Infrastructure.Data;
using System.Text.Json;
using System.Net.Http;
using System.Text;

namespace InsightLearn.Infrastructure.Services;

public class OAuthService : IOAuthService
{
    private readonly ApplicationDbContext _context;
    private readonly IUserService _userService;
    private readonly IJwtService _jwtService;
    private readonly IPasswordService _passwordService;
    private readonly IEmailService _emailService;
    private readonly IAuditService _auditService;
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;
    private readonly ILogger<OAuthService> _logger;

    public OAuthService(
        ApplicationDbContext context,
        IUserService userService,
        IJwtService jwtService,
        IPasswordService passwordService,
        IEmailService emailService,
        IAuditService auditService,
        HttpClient httpClient,
        IConfiguration configuration,
        ILogger<OAuthService> logger)
    {
        _context = context;
        _userService = userService;
        _jwtService = jwtService;
        _passwordService = passwordService;
        _emailService = emailService;
        _auditService = auditService;
        _httpClient = httpClient;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<AuthResponse> GoogleLoginAsync(string code, string? redirectUri = null, string? ipAddress = null)
    {
        try
        {
            _logger.LogInformation("Processing Google OAuth login");

            var googleConfig = _configuration.GetSection("OAuth:Google");
            var clientId = googleConfig["ClientId"] ?? throw new InvalidOperationException("Google ClientId not configured");
            var clientSecret = googleConfig["ClientSecret"] ?? throw new InvalidOperationException("Google ClientSecret not configured");

            // Exchange code for access token
            var tokenResponse = await ExchangeGoogleCodeForTokenAsync(code, clientId, clientSecret, redirectUri);

            // Get user info from Google
            var userInfo = await GetGoogleUserInfoAsync(tokenResponse.AccessToken);

            // Find or create user
            var existingUser = await _userService.GetUserByEmailAsync(userInfo.Email ?? string.Empty);
            User user;

            if (existingUser != null)
            {
                // Check if Google OAuth is already linked
                var existingOAuth = await _context.OAuthProviders
                    .FirstOrDefaultAsync(op => op.UserId == existingUser.Id && op.Provider == "Google");

                if (existingOAuth != null)
                {
                    // Update OAuth info
                    existingOAuth.AccessToken = tokenResponse.AccessToken;
                    existingOAuth.RefreshToken = tokenResponse.RefreshToken;
                    existingOAuth.TokenExpires = DateTime.UtcNow.AddSeconds(tokenResponse.ExpiresIn);
                    existingOAuth.LastUsedAt = DateTime.UtcNow;
                    await _context.SaveChangesAsync();
                }
                else
                {
                    // Link Google OAuth to existing user
                    await LinkGoogleToUserAsync(existingUser.Id, userInfo, tokenResponse);
                }

                user = existingUser;
            }
            else
            {
                // Create new user from Google info
                user = new User
                {
                    FirstName = userInfo.GivenName ?? userInfo.Name.Split(' ').FirstOrDefault() ?? "User",
                    LastName = userInfo.FamilyName ?? userInfo.Name.Split(' ').Skip(1).FirstOrDefault() ?? "",
                    Email = userInfo.Email,
                    PasswordHash = _passwordService.HashPassword(Guid.NewGuid().ToString()), // Random password
                    EmailVerified = userInfo.EmailVerified, // Google emails are usually verified
                    IsActive = true,
                    ProfileImageUrl = userInfo.Picture,
                    CreatedAt = DateTime.UtcNow
                };

                user = await _userService.CreateUserAsync(user);

                // Assign default student role
                await _userService.AssignRoleToUserAsync(user.Id, 1, user.Id);

                // Create OAuth provider link
                await LinkGoogleToUserAsync(user.Id, userInfo, tokenResponse);

                _logger.LogInformation("Created new user from Google OAuth: {UserId}", user.Id);
            }

            // Update last login
            user.LastLoginAt = DateTime.UtcNow;
            await _userService.UpdateUserAsync(user);

            // Generate JWT tokens
            var roles = await _userService.GetUserRolesAsync(user.Id);
            var permissions = await _userService.GetUserPermissionsAsync(user.Id);

            var accessToken = _jwtService.GenerateAccessToken(user, roles, permissions);
            var refreshTokenString = _jwtService.GenerateRefreshToken();

            var refreshToken = new RefreshToken
            {
                UserId = user.Id,
                Token = refreshTokenString,
                Expires = DateTime.UtcNow.AddDays(int.Parse(_configuration["JwtSettings:RefreshTokenExpirationDays"] ?? "7")),
                CreatedByIp = ipAddress
            };

            _context.RefreshTokens.Add(refreshToken);
            await _context.SaveChangesAsync();

            // Log successful OAuth login
            await _auditService.LogAsync("oauth_login_success", "user", user.Id, user.Id, null,
                new { Provider = "Google", Email = user.Email }, ipAddress);

            var userDto = MapToUserDto(user, roles, permissions);

            _logger.LogInformation("Successful Google OAuth login for user: {UserId}", user.Id);

            return new AuthResponse
            {
                AccessToken = accessToken,
                RefreshToken = refreshTokenString,
                ExpiresAt = DateTime.UtcNow.AddMinutes(int.Parse(_configuration["JwtSettings:AccessTokenExpirationMinutes"] ?? "15")),
                User = userDto
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during Google OAuth login");
            throw;
        }
    }

    public async Task<AuthResponse> GitHubLoginAsync(string code, string? redirectUri = null, string? ipAddress = null)
    {
        try
        {
            _logger.LogInformation("Processing GitHub OAuth login");

            var githubConfig = _configuration.GetSection("OAuth:GitHub");
            var clientId = githubConfig["ClientId"] ?? throw new InvalidOperationException("GitHub ClientId not configured");
            var clientSecret = githubConfig["ClientSecret"] ?? throw new InvalidOperationException("GitHub ClientSecret not configured");

            // Exchange code for access token
            var tokenResponse = await ExchangeGitHubCodeForTokenAsync(code, clientId, clientSecret, redirectUri);

            // Get user info from GitHub
            var userInfo = await GetGitHubUserInfoAsync(tokenResponse.AccessToken);

            // Find or create user
            var existingUser = await _userService.GetUserByEmailAsync(userInfo.Email ?? string.Empty);
            User user;

            if (existingUser != null)
            {
                // Check if GitHub OAuth is already linked
                var existingOAuth = await _context.OAuthProviders
                    .FirstOrDefaultAsync(op => op.UserId == existingUser.Id && op.Provider == "GitHub");

                if (existingOAuth != null)
                {
                    // Update OAuth info
                    existingOAuth.AccessToken = tokenResponse.AccessToken;
                    existingOAuth.LastUsedAt = DateTime.UtcNow;
                    await _context.SaveChangesAsync();
                }
                else
                {
                    // Link GitHub OAuth to existing user
                    await LinkGitHubToUserAsync(existingUser.Id, userInfo, tokenResponse);
                }

                user = existingUser;
            }
            else
            {
                // Create new user from GitHub info
                var nameParts = userInfo.Name?.Split(' ', StringSplitOptions.RemoveEmptyEntries) ?? new[] { "User" };

                user = new User
                {
                    FirstName = nameParts.FirstOrDefault() ?? "User",
                    LastName = nameParts.Skip(1).FirstOrDefault() ?? "",
                    Email = userInfo.Email,
                    PasswordHash = _passwordService.HashPassword(Guid.NewGuid().ToString()), // Random password
                    EmailVerified = true, // Assume GitHub emails are verified
                    IsActive = true,
                    ProfileImageUrl = userInfo.AvatarUrl,
                    Bio = userInfo.Bio,
                    CreatedAt = DateTime.UtcNow
                };

                user = await _userService.CreateUserAsync(user);

                // Assign default instructor role for GitHub users (assuming developers)
                await _userService.AssignRoleToUserAsync(user.Id, 2, user.Id);

                // Create OAuth provider link
                await LinkGitHubToUserAsync(user.Id, userInfo, tokenResponse);

                _logger.LogInformation("Created new user from GitHub OAuth: {UserId}", user.Id);
            }

            // Update last login
            user.LastLoginAt = DateTime.UtcNow;
            await _userService.UpdateUserAsync(user);

            // Generate JWT tokens
            var roles = await _userService.GetUserRolesAsync(user.Id);
            var permissions = await _userService.GetUserPermissionsAsync(user.Id);

            var accessToken = _jwtService.GenerateAccessToken(user, roles, permissions);
            var refreshTokenString = _jwtService.GenerateRefreshToken();

            var refreshToken = new RefreshToken
            {
                UserId = user.Id,
                Token = refreshTokenString,
                Expires = DateTime.UtcNow.AddDays(int.Parse(_configuration["JwtSettings:RefreshTokenExpirationDays"] ?? "7")),
                CreatedByIp = ipAddress
            };

            _context.RefreshTokens.Add(refreshToken);
            await _context.SaveChangesAsync();

            // Log successful OAuth login
            await _auditService.LogAsync("oauth_login_success", "user", user.Id, user.Id, null,
                new { Provider = "GitHub", Email = user.Email }, ipAddress);

            var userDto = MapToUserDto(user, roles, permissions);

            _logger.LogInformation("Successful GitHub OAuth login for user: {UserId}", user.Id);

            return new AuthResponse
            {
                AccessToken = accessToken,
                RefreshToken = refreshTokenString,
                ExpiresAt = DateTime.UtcNow.AddMinutes(int.Parse(_configuration["JwtSettings:AccessTokenExpirationMinutes"] ?? "15")),
                User = userDto
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during GitHub OAuth login");
            throw;
        }
    }

    public async Task<bool> LinkOAuthProviderAsync(int userId, string provider, string code, string? redirectUri = null)
    {
        try
        {
            var user = await _userService.GetUserByIdAsync(userId);
            if (user == null)
            {
                throw new InvalidOperationException("User not found");
            }

            // Check if provider is already linked
            var existingProvider = await _context.OAuthProviders
                .FirstOrDefaultAsync(op => op.UserId == userId && op.Provider == provider);

            if (existingProvider != null)
            {
                throw new InvalidOperationException($"{provider} is already linked to this account");
            }

            switch (provider.ToLower())
            {
                case "google":
                    await LinkGoogleProviderAsync(userId, code, redirectUri);
                    break;
                case "github":
                    await LinkGitHubProviderAsync(userId, code, redirectUri);
                    break;
                default:
                    throw new ArgumentException($"Unsupported OAuth provider: {provider}");
            }

            await _auditService.LogAsync("oauth_provider_linked", "user", userId, userId, null,
                new { Provider = provider });

            _logger.LogInformation("Linked {Provider} OAuth to user {UserId}", provider, userId);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error linking {Provider} OAuth to user {UserId}", provider, userId);
            throw;
        }
    }

    public async Task<bool> UnlinkOAuthProviderAsync(int userId, string provider)
    {
        try
        {
            var oauthProvider = await _context.OAuthProviders
                .FirstOrDefaultAsync(op => op.UserId == userId && op.Provider == provider);

            if (oauthProvider == null)
            {
                return false;
            }

            _context.OAuthProviders.Remove(oauthProvider);
            await _context.SaveChangesAsync();

            await _auditService.LogAsync("oauth_provider_unlinked", "user", userId, userId, null,
                new { Provider = provider });

            _logger.LogInformation("Unlinked {Provider} OAuth from user {UserId}", provider, userId);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error unlinking {Provider} OAuth from user {UserId}", provider, userId);
            throw;
        }
    }

    public async Task<List<OAuthProvider>> GetUserOAuthProvidersAsync(int userId)
    {
        try
        {
            var providers = await _context.OAuthProviders
                .Where(op => op.UserId == userId)
                .ToListAsync();

            return providers;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving OAuth providers for user {UserId}", userId);
            throw;
        }
    }

    // Private helper methods

    private async Task<GoogleTokenResponse> ExchangeGoogleCodeForTokenAsync(string code, string clientId, string clientSecret, string? redirectUri)
    {
        var tokenEndpoint = "https://oauth2.googleapis.com/token";
        var parameters = new Dictionary<string, string>
        {
            ["code"] = code,
            ["client_id"] = clientId,
            ["client_secret"] = clientSecret,
            ["grant_type"] = "authorization_code"
        };

        if (!string.IsNullOrEmpty(redirectUri))
        {
            parameters["redirect_uri"] = redirectUri;
        }

        var response = await _httpClient.PostAsync(tokenEndpoint, new FormUrlEncodedContent(parameters));
        response.EnsureSuccessStatusCode();

        var json = await response.Content.ReadAsStringAsync();
        var tokenResponse = JsonSerializer.Deserialize<GoogleTokenResponse>(json, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower
        });

        return tokenResponse ?? throw new InvalidOperationException("Failed to deserialize Google token response");
    }

    private async Task<GoogleUserInfo> GetGoogleUserInfoAsync(string accessToken)
    {
        var userInfoEndpoint = "https://www.googleapis.com/oauth2/v2/userinfo";

        _httpClient.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", accessToken);
        var response = await _httpClient.GetAsync(userInfoEndpoint);
        response.EnsureSuccessStatusCode();

        var json = await response.Content.ReadAsStringAsync();
        var userInfo = JsonSerializer.Deserialize<GoogleUserInfo>(json, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower
        });

        return userInfo ?? throw new InvalidOperationException("Failed to deserialize Google user info");
    }

    private async Task<GitHubTokenResponse> ExchangeGitHubCodeForTokenAsync(string code, string clientId, string clientSecret, string? redirectUri)
    {
        var tokenEndpoint = "https://github.com/login/oauth/access_token";
        var parameters = new Dictionary<string, string>
        {
            ["code"] = code,
            ["client_id"] = clientId,
            ["client_secret"] = clientSecret,
            ["grant_type"] = "authorization_code"
        };

        if (!string.IsNullOrEmpty(redirectUri))
        {
            parameters["redirect_uri"] = redirectUri;
        }

        _httpClient.DefaultRequestHeaders.Accept.Clear();
        _httpClient.DefaultRequestHeaders.Accept.Add(new System.Net.Http.Headers.MediaTypeWithQualityHeaderValue("application/json"));

        var response = await _httpClient.PostAsync(tokenEndpoint, new FormUrlEncodedContent(parameters));
        response.EnsureSuccessStatusCode();

        var json = await response.Content.ReadAsStringAsync();
        var tokenResponse = JsonSerializer.Deserialize<GitHubTokenResponse>(json, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower
        });

        return tokenResponse ?? throw new InvalidOperationException("Failed to deserialize GitHub token response");
    }

    private async Task<GitHubUserInfo> GetGitHubUserInfoAsync(string accessToken)
    {
        var userInfoEndpoint = "https://api.github.com/user";

        _httpClient.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", accessToken);
        _httpClient.DefaultRequestHeaders.UserAgent.Clear();
        _httpClient.DefaultRequestHeaders.UserAgent.ParseAdd("InsightLearn-OAuth/1.0");

        var response = await _httpClient.GetAsync(userInfoEndpoint);
        response.EnsureSuccessStatusCode();

        var json = await response.Content.ReadAsStringAsync();
        var userInfo = JsonSerializer.Deserialize<GitHubUserInfo>(json, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower
        });

        if (userInfo == null)
        {
            throw new InvalidOperationException("Failed to deserialize GitHub user info");
        }

        // Get primary email if not public
        if (string.IsNullOrEmpty(userInfo.Email))
        {
            userInfo.Email = await GetGitHubPrimaryEmailAsync(accessToken);
        }

        return userInfo;
    }

    private async Task<string> GetGitHubPrimaryEmailAsync(string accessToken)
    {
        var emailEndpoint = "https://api.github.com/user/emails";

        var response = await _httpClient.GetAsync(emailEndpoint);
        response.EnsureSuccessStatusCode();

        var json = await response.Content.ReadAsStringAsync();
        var emails = JsonSerializer.Deserialize<GitHubEmail[]>(json, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower
        });

        return emails?.FirstOrDefault(e => e.Primary)?.Email ??
               emails?.FirstOrDefault()?.Email ??
               throw new InvalidOperationException("No email address found in GitHub profile");
    }

    private async Task LinkGoogleToUserAsync(int userId, GoogleUserInfo userInfo, GoogleTokenResponse tokenResponse)
    {
        var oauthProvider = new OAuthProvider
        {
            UserId = userId,
            Provider = "Google",
            ProviderUserId = userInfo.Id,
            ProviderEmail = userInfo.Email,
            ProviderName = userInfo.Name,
            AccessToken = tokenResponse.AccessToken,
            RefreshToken = tokenResponse.RefreshToken,
            TokenExpires = DateTime.UtcNow.AddSeconds(tokenResponse.ExpiresIn),
            ConnectedAt = DateTime.UtcNow,
            LastUsedAt = DateTime.UtcNow
        };

        _context.OAuthProviders.Add(oauthProvider);
        await _context.SaveChangesAsync();
    }

    private async Task LinkGitHubToUserAsync(int userId, GitHubUserInfo userInfo, GitHubTokenResponse tokenResponse)
    {
        var oauthProvider = new OAuthProvider
        {
            UserId = userId,
            Provider = "GitHub",
            ProviderUserId = userInfo.Id.ToString(),
            ProviderEmail = userInfo.Email,
            ProviderName = userInfo.Name ?? userInfo.Login,
            AccessToken = tokenResponse.AccessToken,
            ConnectedAt = DateTime.UtcNow,
            LastUsedAt = DateTime.UtcNow
        };

        _context.OAuthProviders.Add(oauthProvider);
        await _context.SaveChangesAsync();
    }

    private async Task LinkGoogleProviderAsync(int userId, string code, string? redirectUri)
    {
        var googleConfig = _configuration.GetSection("OAuth:Google");
        var clientId = googleConfig["ClientId"] ?? throw new InvalidOperationException("Google ClientId not configured");
        var clientSecret = googleConfig["ClientSecret"] ?? throw new InvalidOperationException("Google ClientSecret not configured");

        var tokenResponse = await ExchangeGoogleCodeForTokenAsync(code, clientId, clientSecret, redirectUri);
        var userInfo = await GetGoogleUserInfoAsync(tokenResponse.AccessToken);

        await LinkGoogleToUserAsync(userId, userInfo, tokenResponse);
    }

    private async Task LinkGitHubProviderAsync(int userId, string code, string? redirectUri)
    {
        var githubConfig = _configuration.GetSection("OAuth:GitHub");
        var clientId = githubConfig["ClientId"] ?? throw new InvalidOperationException("GitHub ClientId not configured");
        var clientSecret = githubConfig["ClientSecret"] ?? throw new InvalidOperationException("GitHub ClientSecret not configured");

        var tokenResponse = await ExchangeGitHubCodeForTokenAsync(code, clientId, clientSecret, redirectUri);
        var userInfo = await GetGitHubUserInfoAsync(tokenResponse.AccessToken);

        await LinkGitHubToUserAsync(userId, userInfo, tokenResponse);
    }

    private UserDto MapToUserDto(User user, List<string> roles, List<string> permissions)
    {
        return new UserDto
        {
            Id = user.Id,
            FirstName = user.FirstName,
            LastName = user.LastName,
            Email = user.Email,
            EmailVerified = user.EmailVerified,
            CreatedAt = user.CreatedAt,
            LastLoginAt = user.LastLoginAt,
            IsActive = user.IsActive,
            ProfileImageUrl = user.ProfileImageUrl,
            Bio = user.Bio,
            Roles = roles,
            Permissions = permissions
        };
    }

    // OAuth response models
    private class GoogleTokenResponse
    {
        public string AccessToken { get; set; } = string.Empty;
        public string? RefreshToken { get; set; }
        public int ExpiresIn { get; set; }
        public string TokenType { get; set; } = string.Empty;
    }

    private class GoogleUserInfo
    {
        public string Id { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public bool EmailVerified { get; set; }
        public string Name { get; set; } = string.Empty;
        public string? GivenName { get; set; }
        public string? FamilyName { get; set; }
        public string? Picture { get; set; }
    }

    private class GitHubTokenResponse
    {
        public string AccessToken { get; set; } = string.Empty;
        public string TokenType { get; set; } = string.Empty;
        public string? Scope { get; set; }
    }

    private class GitHubUserInfo
    {
        public int Id { get; set; }
        public string Login { get; set; } = string.Empty;
        public string? Name { get; set; }
        public string? Email { get; set; }
        public string? Bio { get; set; }
        public string? AvatarUrl { get; set; }
    }

    private class GitHubEmail
    {
        public string Email { get; set; } = string.Empty;
        public bool Primary { get; set; }
        public bool Verified { get; set; }
    }
}