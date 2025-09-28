using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using InsightLearn.Core.DTOs;
using InsightLearn.Core.Interfaces;
using InsightLearn.Core.Models;
using InsightLearn.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace InsightLearn.Infrastructure.Services;

public class AuthService : IAuthService
{
    private readonly IUserService _userService;
    private readonly IJwtService _jwtService;
    private readonly IPasswordService _passwordService;
    private readonly IEmailService _emailService;
    private readonly IAuditService _auditService;
    private readonly ApplicationDbContext _context;
    private readonly IConfiguration _configuration;
    private readonly ILogger<AuthService> _logger;

    public AuthService(
        IUserService userService,
        IJwtService jwtService,
        IPasswordService passwordService,
        IEmailService emailService,
        IAuditService auditService,
        ApplicationDbContext context,
        IConfiguration configuration,
        ILogger<AuthService> logger)
    {
        _userService = userService;
        _jwtService = jwtService;
        _passwordService = passwordService;
        _emailService = emailService;
        _auditService = auditService;
        _context = context;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<AuthResponse> LoginAsync(LoginRequest request, string? ipAddress = null)
    {
        try
        {
            _logger.LogInformation("Login attempt for email: {Email}", request.Email);

            var user = await _userService.GetUserByEmailAsync(request.Email);
            if (user == null || !_passwordService.VerifyPassword(request.Password, user.PasswordHash))
            {
                _logger.LogWarning("Invalid login attempt for email: {Email}", request.Email);
                await _auditService.LogAsync("login_failed", "user", null, null, null,
                    new { Email = request.Email }, ipAddress);
                throw new UnauthorizedAccessException("Invalid email or password");
            }

            if (!user.IsActive)
            {
                _logger.LogWarning("Login attempt for inactive user: {UserId}", user.Id);
                throw new UnauthorizedAccessException("Account is deactivated");
            }

            if (!user.EmailVerified)
            {
                _logger.LogWarning("Login attempt for unverified email: {Email}", request.Email);
                throw new UnauthorizedAccessException("Please verify your email address before logging in");
            }

            // Update last login timestamp
            user.LastLoginAt = DateTime.UtcNow;
            await _userService.UpdateUserAsync(user);

            // Generate tokens
            var roles = await _userService.GetUserRolesAsync(user.Id);
            var permissions = await _userService.GetUserPermissionsAsync(user.Id);

            var accessToken = _jwtService.GenerateAccessToken(user, roles, permissions);
            var refreshTokenString = _jwtService.GenerateRefreshToken();

            // Create refresh token entity
            var refreshToken = new RefreshToken
            {
                UserId = user.Id,
                Token = refreshTokenString,
                Expires = DateTime.UtcNow.AddDays(int.Parse(_configuration["JwtSettings:RefreshTokenExpirationDays"] ?? "7")),
                CreatedByIp = ipAddress
            };

            _context.RefreshTokens.Add(refreshToken);
            await _context.SaveChangesAsync();

            // Clean up old refresh tokens (keep only last 5)
            await CleanupOldRefreshTokensAsync(user.Id);

            // Log successful login
            await _auditService.LogAsync("login_success", "user", user.Id, user.Id, null,
                new { Email = user.Email, IpAddress = ipAddress });

            // Send login notification (optional, can be disabled in settings)
            if (bool.Parse(_configuration["SecuritySettings:SendLoginNotifications"] ?? "false"))
            {
                try
                {
                    await _emailService.SendLoginNotificationAsync(user.Email, user.FirstName,
                        ipAddress ?? "Unknown", DateTime.UtcNow);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to send login notification to {Email}", user.Email);
                }
            }

            var userDto = MapToUserDto(user, roles, permissions);

            _logger.LogInformation("Successful login for user: {UserId}", user.Id);

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
            _logger.LogError(ex, "Error during login for email: {Email}", request.Email);
            throw;
        }
    }

    public async Task<AuthResponse> RegisterAsync(RegisterRequest request, string? ipAddress = null)
    {
        try
        {
            _logger.LogInformation("Registration attempt for email: {Email}", request.Email);

            // Check if email already exists
            if (await _userService.EmailExistsAsync(request.Email))
            {
                _logger.LogWarning("Registration attempt with existing email: {Email}", request.Email);
                throw new InvalidOperationException("Email address is already registered");
            }

            // Validate password strength
            var passwordValidation = ((PasswordService)_passwordService).ValidatePasswordStrength(request.Password);
            if (!passwordValidation.IsValid)
            {
                throw new ArgumentException(passwordValidation.ErrorMessage);
            }

            // Create user entity
            var user = new User
            {
                FirstName = request.FirstName.Trim(),
                LastName = request.LastName.Trim(),
                Email = request.Email.ToLower().Trim(),
                PasswordHash = _passwordService.HashPassword(request.Password),
                EmailVerified = false,
                EmailVerificationToken = _passwordService.GenerateSecureToken(),
                EmailVerificationTokenExpires = DateTime.UtcNow.AddHours(24),
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            };

            // Create user
            var createdUser = await _userService.CreateUserAsync(user);

            // Assign default role based on user type
            var defaultRoleId = request.UserType switch
            {
                Core.DTOs.UserType.Student => 1, // Student role
                Core.DTOs.UserType.Instructor => 2, // Instructor role
                _ => 1 // Default to Student
            };

            await _userService.AssignRoleToUserAsync(createdUser.Id, defaultRoleId, createdUser.Id);

            // Log registration
            await _auditService.LogAsync("user_registered", "user", createdUser.Id, createdUser.Id, null,
                new { Email = createdUser.Email, UserType = request.UserType }, ipAddress);

            // Send email verification
            try
            {
                await _emailService.SendEmailVerificationAsync(createdUser.Email, createdUser.FirstName,
                    createdUser.EmailVerificationToken!);
                _logger.LogInformation("Email verification sent to {Email}", createdUser.Email);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to send verification email to {Email}", createdUser.Email);
                // Don't fail registration if email sending fails
            }

            // Generate tokens for immediate login (user still needs to verify email)
            var roles = await _userService.GetUserRolesAsync(createdUser.Id);
            var permissions = await _userService.GetUserPermissionsAsync(createdUser.Id);

            var accessToken = _jwtService.GenerateAccessToken(createdUser, roles, permissions);
            var refreshTokenString = _jwtService.GenerateRefreshToken();

            var refreshToken = new RefreshToken
            {
                UserId = createdUser.Id,
                Token = refreshTokenString,
                Expires = DateTime.UtcNow.AddDays(int.Parse(_configuration["JwtSettings:RefreshTokenExpirationDays"] ?? "7")),
                CreatedByIp = ipAddress
            };

            _context.RefreshTokens.Add(refreshToken);
            await _context.SaveChangesAsync();

            var userDto = MapToUserDto(createdUser, roles, permissions);

            _logger.LogInformation("Successful registration for user: {UserId}", createdUser.Id);

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
            _logger.LogError(ex, "Error during registration for email: {Email}", request.Email);
            throw;
        }
    }

    public async Task<AuthResponse> RefreshTokenAsync(string refreshToken, string? ipAddress = null)
    {
        try
        {
            var token = _jwtService.GetRefreshToken(refreshToken);
            if (token == null || !token.IsActive)
            {
                _logger.LogWarning("Invalid or expired refresh token used");
                throw new UnauthorizedAccessException("Invalid or expired refresh token");
            }

            var user = await _userService.GetUserByIdAsync(token.UserId);
            if (user == null || !user.IsActive)
            {
                _logger.LogWarning("Refresh token used for inactive user: {UserId}", token.UserId);
                throw new UnauthorizedAccessException("User account is inactive");
            }

            // Rotate refresh token
            await _jwtService.RotateRefreshTokenAsync(token, ipAddress ?? "Unknown");

            // Get new refresh token
            var newRefreshToken = await _context.RefreshTokens
                .Where(rt => rt.UserId == user.Id && rt.IsActive && rt.Token == token.ReplacedByToken)
                .FirstOrDefaultAsync();

            if (newRefreshToken == null)
            {
                throw new InvalidOperationException("Failed to create new refresh token");
            }

            // Generate new access token
            var roles = await _userService.GetUserRolesAsync(user.Id);
            var permissions = await _userService.GetUserPermissionsAsync(user.Id);
            var accessToken = _jwtService.GenerateAccessToken(user, roles, permissions);

            var userDto = MapToUserDto(user, roles, permissions);

            _logger.LogInformation("Token refreshed for user: {UserId}", user.Id);

            return new AuthResponse
            {
                AccessToken = accessToken,
                RefreshToken = newRefreshToken.Token,
                ExpiresAt = DateTime.UtcNow.AddMinutes(int.Parse(_configuration["JwtSettings:AccessTokenExpirationMinutes"] ?? "15")),
                User = userDto
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during token refresh");
            throw;
        }
    }

    public async Task<bool> RevokeTokenAsync(string refreshToken, string? ipAddress = null)
    {
        try
        {
            var token = _jwtService.GetRefreshToken(refreshToken);
            if (token == null)
            {
                return false;
            }

            if (token.IsActive)
            {
                await _jwtService.RevokeRefreshTokenAsync(token, ipAddress, "Revoked by user");

                // Revoke all descendant tokens
                if (token.User != null)
                {
                    await _jwtService.RevokeDescendantRefreshTokensAsync(token, token.User, ipAddress ?? "Unknown", "Revoked by user");
                }
            }

            _logger.LogInformation("Token revoked for user: {UserId}", token.UserId);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error revoking token");
            throw;
        }
    }

    public async Task<bool> ForgotPasswordAsync(ForgotPasswordRequest request)
    {
        try
        {
            var user = await _userService.GetUserByEmailAsync(request.Email);
            if (user == null)
            {
                // Don't reveal if email exists or not
                _logger.LogWarning("Password reset requested for non-existent email: {Email}", request.Email);
                return true; // Return true to not reveal email doesn't exist
            }

            // Generate password reset token
            user.PasswordResetToken = _passwordService.GenerateSecureToken();
            user.PasswordResetTokenExpires = DateTime.UtcNow.AddHours(1); // 1 hour expiration

            await _userService.UpdateUserAsync(user);

            // Send password reset email
            await _emailService.SendPasswordResetAsync(user.Email, user.FirstName, user.PasswordResetToken);

            _logger.LogInformation("Password reset email sent to: {Email}", request.Email);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during password reset for email: {Email}", request.Email);
            throw;
        }
    }

    public async Task<bool> ResetPasswordAsync(ResetPasswordRequest request)
    {
        try
        {
            var user = await _context.Users
                .FirstOrDefaultAsync(u => u.PasswordResetToken == request.Token &&
                                         u.PasswordResetTokenExpires > DateTime.UtcNow);

            if (user == null)
            {
                _logger.LogWarning("Invalid or expired password reset token used");
                throw new InvalidOperationException("Invalid or expired password reset token");
            }

            // Validate new password
            var passwordValidation = ((PasswordService)_passwordService).ValidatePasswordStrength(request.Password);
            if (!passwordValidation.IsValid)
            {
                throw new ArgumentException(passwordValidation.ErrorMessage);
            }

            // Update password and clear reset token
            user.PasswordHash = _passwordService.HashPassword(request.Password);
            user.PasswordResetToken = null;
            user.PasswordResetTokenExpires = null;

            await _userService.UpdateUserAsync(user);

            // Revoke all refresh tokens to force re-login
            var refreshTokens = await _context.RefreshTokens
                .Where(rt => rt.UserId == user.Id && rt.IsActive)
                .ToListAsync();

            foreach (var token in refreshTokens)
            {
                await _jwtService.RevokeRefreshTokenAsync(token, null, "Password reset");
            }

            _logger.LogInformation("Password reset successfully for user: {UserId}", user.Id);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during password reset");
            throw;
        }
    }

    public async Task<bool> ChangePasswordAsync(int userId, ChangePasswordRequest request)
    {
        try
        {
            var user = await _userService.GetUserByIdAsync(userId);
            if (user == null)
            {
                throw new InvalidOperationException("User not found");
            }

            if (!_passwordService.VerifyPassword(request.CurrentPassword, user.PasswordHash))
            {
                throw new UnauthorizedAccessException("Current password is incorrect");
            }

            // Validate new password
            var passwordValidation = ((PasswordService)_passwordService).ValidatePasswordStrength(request.NewPassword);
            if (!passwordValidation.IsValid)
            {
                throw new ArgumentException(passwordValidation.ErrorMessage);
            }

            user.PasswordHash = _passwordService.HashPassword(request.NewPassword);
            await _userService.UpdateUserAsync(user);

            _logger.LogInformation("Password changed for user: {UserId}", userId);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error changing password for user: {UserId}", userId);
            throw;
        }
    }

    public async Task<bool> VerifyEmailAsync(VerifyEmailRequest request)
    {
        try
        {
            var user = await _context.Users
                .FirstOrDefaultAsync(u => u.EmailVerificationToken == request.Token &&
                                         u.EmailVerificationTokenExpires > DateTime.UtcNow);

            if (user == null)
            {
                _logger.LogWarning("Invalid or expired email verification token used");
                throw new InvalidOperationException("Invalid or expired verification token");
            }

            user.EmailVerified = true;
            user.EmailVerificationToken = null;
            user.EmailVerificationTokenExpires = null;

            await _userService.UpdateUserAsync(user);

            // Send welcome email
            try
            {
                await _emailService.SendWelcomeEmailAsync(user.Email, user.FirstName);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to send welcome email to {Email}", user.Email);
            }

            _logger.LogInformation("Email verified for user: {UserId}", user.Id);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during email verification");
            throw;
        }
    }

    public async Task<bool> ResendEmailVerificationAsync(string email)
    {
        try
        {
            var user = await _userService.GetUserByEmailAsync(email);
            if (user == null || user.EmailVerified)
            {
                return true; // Don't reveal if email exists or is already verified
            }

            user.EmailVerificationToken = _passwordService.GenerateSecureToken();
            user.EmailVerificationTokenExpires = DateTime.UtcNow.AddHours(24);

            await _userService.UpdateUserAsync(user);

            await _emailService.SendEmailVerificationAsync(user.Email, user.FirstName, user.EmailVerificationToken);

            _logger.LogInformation("Email verification resent to: {Email}", email);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error resending email verification for: {Email}", email);
            throw;
        }
    }

    public async Task<UserDto> GetUserByIdAsync(int userId)
    {
        var user = await _userService.GetUserByIdAsync(userId);
        if (user == null)
        {
            throw new InvalidOperationException("User not found");
        }

        var roles = await _userService.GetUserRolesAsync(userId);
        var permissions = await _userService.GetUserPermissionsAsync(userId);

        return MapToUserDto(user, roles, permissions);
    }

    public async Task<UserDto> UpdateUserProfileAsync(int userId, UpdateUserProfileRequest request)
    {
        try
        {
            var user = await _userService.GetUserByIdAsync(userId);
            if (user == null)
            {
                throw new InvalidOperationException("User not found");
            }

            user.FirstName = request.FirstName.Trim();
            user.LastName = request.LastName.Trim();
            user.Bio = request.Bio?.Trim();
            user.ProfileImageUrl = request.ProfileImageUrl?.Trim();

            await _userService.UpdateUserAsync(user);

            var roles = await _userService.GetUserRolesAsync(userId);
            var permissions = await _userService.GetUserPermissionsAsync(userId);

            _logger.LogInformation("Profile updated for user: {UserId}", userId);
            return MapToUserDto(user, roles, permissions);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating profile for user: {UserId}", userId);
            throw;
        }
    }

    public async Task<bool> DeactivateUserAsync(int userId)
    {
        var user = await _userService.GetUserByIdAsync(userId);
        if (user == null)
        {
            return false;
        }

        user.IsActive = false;
        await _userService.UpdateUserAsync(user);

        // Revoke all active refresh tokens
        var refreshTokens = await _context.RefreshTokens
            .Where(rt => rt.UserId == userId && rt.IsActive)
            .ToListAsync();

        foreach (var token in refreshTokens)
        {
            await _jwtService.RevokeRefreshTokenAsync(token, null, "User deactivated");
        }

        _logger.LogInformation("User deactivated: {UserId}", userId);
        return true;
    }

    public async Task<bool> ActivateUserAsync(int userId)
    {
        var user = await _userService.GetUserByIdAsync(userId);
        if (user == null)
        {
            return false;
        }

        user.IsActive = true;
        await _userService.UpdateUserAsync(user);

        _logger.LogInformation("User activated: {UserId}", userId);
        return true;
    }

    public async Task<List<UserDto>> GetUsersAsync(int page = 1, int pageSize = 10)
    {
        var users = await _userService.GetUsersAsync(page, pageSize);
        var userDtos = new List<UserDto>();

        foreach (var user in users)
        {
            var roles = await _userService.GetUserRolesAsync(user.Id);
            var permissions = await _userService.GetUserPermissionsAsync(user.Id);
            userDtos.Add(MapToUserDto(user, roles, permissions));
        }

        return userDtos;
    }

    public Task<AuthResponse> OAuthLoginAsync(OAuthLoginRequest request, string? ipAddress = null)
    {
        // This method will be implemented in the OAuth service
        return Task.FromException<AuthResponse>(new NotImplementedException("OAuth login will be implemented in OAuthService"));
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

    private async Task CleanupOldRefreshTokensAsync(int userId)
    {
        try
        {
            var oldTokens = await _context.RefreshTokens
                .Where(rt => rt.UserId == userId)
                .OrderByDescending(rt => rt.CreatedAt)
                .Skip(5) // Keep the 5 most recent tokens
                .ToListAsync();

            if (oldTokens.Any())
            {
                _context.RefreshTokens.RemoveRange(oldTokens);
                await _context.SaveChangesAsync();

                _logger.LogDebug("Cleaned up {Count} old refresh tokens for user {UserId}", oldTokens.Count, userId);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to cleanup old refresh tokens for user {UserId}", userId);
            // Don't throw - this is cleanup, not critical
        }
    }
}