using InsightLearn.Core.DTOs;
using InsightLearn.Core.Models;

namespace InsightLearn.Core.Interfaces;

public interface IAuthService
{
    Task<AuthResponse> LoginAsync(LoginRequest request, string? ipAddress = null);
    Task<AuthResponse> RegisterAsync(RegisterRequest request, string? ipAddress = null);
    Task<AuthResponse> RefreshTokenAsync(string refreshToken, string? ipAddress = null);
    Task<bool> RevokeTokenAsync(string refreshToken, string? ipAddress = null);
    Task<bool> ForgotPasswordAsync(ForgotPasswordRequest request);
    Task<bool> ResetPasswordAsync(ResetPasswordRequest request);
    Task<bool> ChangePasswordAsync(int userId, ChangePasswordRequest request);
    Task<bool> VerifyEmailAsync(VerifyEmailRequest request);
    Task<bool> ResendEmailVerificationAsync(string email);
    Task<UserDto> GetUserByIdAsync(int userId);
    Task<UserDto> UpdateUserProfileAsync(int userId, UpdateUserProfileRequest request);
    Task<bool> DeactivateUserAsync(int userId);
    Task<bool> ActivateUserAsync(int userId);
    Task<List<UserDto>> GetUsersAsync(int page = 1, int pageSize = 10);
    Task<AuthResponse> OAuthLoginAsync(OAuthLoginRequest request, string? ipAddress = null);
}

public interface IJwtService
{
    string GenerateAccessToken(User user, List<string> roles, List<string> permissions);
    string GenerateRefreshToken();
    int? ValidateAccessToken(string token);
    RefreshToken? GetRefreshToken(string token);
    Task RevokeRefreshTokenAsync(RefreshToken token, string? ipAddress = null, string? replacedByToken = null);
    Task RevokeDescendantRefreshTokensAsync(RefreshToken refreshToken, User user, string ipAddress, string reason);
    Task RotateRefreshTokenAsync(RefreshToken refreshToken, string ipAddress);
}

public interface IPasswordService
{
    string HashPassword(string password);
    bool VerifyPassword(string password, string hash);
    string GenerateSecureToken();
}

public interface IEmailService
{
    Task SendEmailVerificationAsync(string email, string firstName, string token);
    Task SendPasswordResetAsync(string email, string firstName, string token);
    Task SendWelcomeEmailAsync(string email, string firstName);
    Task SendLoginNotificationAsync(string email, string firstName, string ipAddress, DateTime loginTime);
}

public interface IOAuthService
{
    Task<AuthResponse> GoogleLoginAsync(string code, string? redirectUri = null, string? ipAddress = null);
    Task<AuthResponse> GitHubLoginAsync(string code, string? redirectUri = null, string? ipAddress = null);
    Task<bool> LinkOAuthProviderAsync(int userId, string provider, string code, string? redirectUri = null);
    Task<bool> UnlinkOAuthProviderAsync(int userId, string provider);
    Task<List<OAuthProvider>> GetUserOAuthProvidersAsync(int userId);
}

public interface IUserService
{
    Task<User?> GetUserByEmailAsync(string email);
    Task<User?> GetUserByIdAsync(int id);
    Task<User> CreateUserAsync(User user);
    Task<User> UpdateUserAsync(User user);
    Task<bool> EmailExistsAsync(string email);
    Task<List<User>> GetUsersAsync(int page, int pageSize);
    Task<int> GetUsersCountAsync();
    Task AssignRoleToUserAsync(int userId, int roleId, int assignedBy);
    Task RemoveRoleFromUserAsync(int userId, int roleId);
    Task<List<string>> GetUserRolesAsync(int userId);
    Task<List<string>> GetUserPermissionsAsync(int userId);
}

public interface IRoleService
{
    Task<Role?> GetRoleByNameAsync(string name);
    Task<Role?> GetRoleByIdAsync(int id);
    Task<List<Role>> GetRolesAsync();
    Task<Role> CreateRoleAsync(Role role);
    Task<Role> UpdateRoleAsync(Role role);
    Task<bool> DeleteRoleAsync(int id);
    Task AssignPermissionToRoleAsync(int roleId, int permissionId, int grantedBy);
    Task RemovePermissionFromRoleAsync(int roleId, int permissionId);
    Task<List<string>> GetRolePermissionsAsync(int roleId);
}

public interface IAuditService
{
    Task LogAsync(string action, string entity, int? entityId = null, int? userId = null,
        object? oldValues = null, object? newValues = null, string? ipAddress = null, string? userAgent = null);
    Task<List<AuditLog>> GetAuditLogsAsync(int page = 1, int pageSize = 50, int? userId = null,
        string? action = null, DateTime? fromDate = null, DateTime? toDate = null);
    Task CleanupOldAuditLogsAsync(int retentionDays);
}