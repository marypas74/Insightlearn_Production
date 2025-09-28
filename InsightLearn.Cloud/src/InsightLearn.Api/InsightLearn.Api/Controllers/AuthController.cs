using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using InsightLearn.Core.DTOs;
using InsightLearn.Core.Interfaces;
using InsightLearn.Infrastructure.Authorization;
using System.Security.Claims;

namespace InsightLearn.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;
    private readonly IOAuthService _oauthService;
    private readonly ILogger<AuthController> _logger;

    public AuthController(
        IAuthService authService,
        IOAuthService oauthService,
        ILogger<AuthController> logger)
    {
        _authService = authService;
        _oauthService = oauthService;
        _logger = logger;
    }

    /// <summary>
    /// Authenticate user with email and password
    /// </summary>
    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<ActionResult<AuthResponse>> Login([FromBody] LoginRequest request)
    {
        try
        {
            var ipAddress = GetIpAddress();
            var response = await _authService.LoginAsync(request, ipAddress);

            SetRefreshTokenCookie(response.RefreshToken);

            return Ok(response);
        }
        catch (UnauthorizedAccessException ex)
        {
            _logger.LogWarning("Login failed for {Email}: {Message}", request.Email, ex.Message);
            return Unauthorized(new { error = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during login for {Email}", request.Email);
            return StatusCode(500, new { error = "An error occurred during login" });
        }
    }

    /// <summary>
    /// Register a new user account
    /// </summary>
    [HttpPost("register")]
    [AllowAnonymous]
    public async Task<ActionResult<AuthResponse>> Register([FromBody] RegisterRequest request)
    {
        try
        {
            var ipAddress = GetIpAddress();
            var response = await _authService.RegisterAsync(request, ipAddress);

            SetRefreshTokenCookie(response.RefreshToken);

            return Ok(response);
        }
        catch (InvalidOperationException ex)
        {
            _logger.LogWarning("Registration failed for {Email}: {Message}", request.Email, ex.Message);
            return BadRequest(new { error = ex.Message });
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning("Invalid registration data for {Email}: {Message}", request.Email, ex.Message);
            return BadRequest(new { error = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during registration for {Email}", request.Email);
            return StatusCode(500, new { error = "An error occurred during registration" });
        }
    }

    /// <summary>
    /// Refresh access token using refresh token
    /// </summary>
    [HttpPost("refresh-token")]
    [AllowAnonymous]
    public async Task<ActionResult<AuthResponse>> RefreshToken([FromBody] RefreshTokenRequest? request = null)
    {
        try
        {
            var refreshToken = request?.RefreshToken ?? GetRefreshTokenFromCookie();

            if (string.IsNullOrEmpty(refreshToken))
            {
                return BadRequest(new { error = "Refresh token is required" });
            }

            var ipAddress = GetIpAddress();
            var response = await _authService.RefreshTokenAsync(refreshToken, ipAddress);

            SetRefreshTokenCookie(response.RefreshToken);

            return Ok(response);
        }
        catch (UnauthorizedAccessException ex)
        {
            _logger.LogWarning("Token refresh failed: {Message}", ex.Message);
            return Unauthorized(new { error = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during token refresh");
            return StatusCode(500, new { error = "An error occurred during token refresh" });
        }
    }

    /// <summary>
    /// Logout user and revoke refresh token
    /// </summary>
    [HttpPost("logout")]
    [Authorize]
    public async Task<IActionResult> Logout([FromBody] RefreshTokenRequest? request = null)
    {
        try
        {
            var refreshToken = request?.RefreshToken ?? GetRefreshTokenFromCookie();
            var ipAddress = GetIpAddress();

            if (!string.IsNullOrEmpty(refreshToken))
            {
                await _authService.RevokeTokenAsync(refreshToken, ipAddress);
            }

            ClearRefreshTokenCookie();

            return Ok(new { message = "Logged out successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during logout");
            return StatusCode(500, new { error = "An error occurred during logout" });
        }
    }

    /// <summary>
    /// Revoke a refresh token
    /// </summary>
    [HttpPost("revoke-token")]
    [Authorize]
    public async Task<IActionResult> RevokeToken([FromBody] RefreshTokenRequest request)
    {
        try
        {
            var ipAddress = GetIpAddress();
            var success = await _authService.RevokeTokenAsync(request.RefreshToken, ipAddress);

            if (!success)
            {
                return BadRequest(new { error = "Token not found" });
            }

            return Ok(new { message = "Token revoked successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error revoking token");
            return StatusCode(500, new { error = "An error occurred while revoking token" });
        }
    }

    /// <summary>
    /// Send password reset email
    /// </summary>
    [HttpPost("forgot-password")]
    [AllowAnonymous]
    public async Task<IActionResult> ForgotPassword([FromBody] ForgotPasswordRequest request)
    {
        try
        {
            await _authService.ForgotPasswordAsync(request);
            return Ok(new { message = "If the email exists, a password reset link has been sent" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during password reset request for {Email}", request.Email);
            return StatusCode(500, new { error = "An error occurred while processing password reset request" });
        }
    }

    /// <summary>
    /// Reset password using reset token
    /// </summary>
    [HttpPost("reset-password")]
    [AllowAnonymous]
    public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordRequest request)
    {
        try
        {
            var success = await _authService.ResetPasswordAsync(request);

            if (!success)
            {
                return BadRequest(new { error = "Invalid or expired reset token" });
            }

            return Ok(new { message = "Password reset successfully" });
        }
        catch (InvalidOperationException ex)
        {
            _logger.LogWarning("Password reset failed: {Message}", ex.Message);
            return BadRequest(new { error = ex.Message });
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning("Invalid password reset data: {Message}", ex.Message);
            return BadRequest(new { error = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during password reset");
            return StatusCode(500, new { error = "An error occurred during password reset" });
        }
    }

    /// <summary>
    /// Change user password (requires current password)
    /// </summary>
    [HttpPost("change-password")]
    [Authorize]
    [RequireActiveAccount]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordRequest request)
    {
        try
        {
            var userId = User.GetUserId();
            if (!userId.HasValue)
            {
                return Unauthorized();
            }

            var success = await _authService.ChangePasswordAsync(userId.Value, request);

            if (!success)
            {
                return BadRequest(new { error = "Failed to change password" });
            }

            return Ok(new { message = "Password changed successfully" });
        }
        catch (UnauthorizedAccessException ex)
        {
            _logger.LogWarning("Password change failed for user {UserId}: {Message}", User.GetUserId(), ex.Message);
            return BadRequest(new { error = ex.Message });
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning("Invalid password change data for user {UserId}: {Message}", User.GetUserId(), ex.Message);
            return BadRequest(new { error = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during password change for user {UserId}", User.GetUserId());
            return StatusCode(500, new { error = "An error occurred while changing password" });
        }
    }

    /// <summary>
    /// Verify email address using verification token
    /// </summary>
    [HttpPost("verify-email")]
    [AllowAnonymous]
    public async Task<IActionResult> VerifyEmail([FromBody] VerifyEmailRequest request)
    {
        try
        {
            var success = await _authService.VerifyEmailAsync(request);

            if (!success)
            {
                return BadRequest(new { error = "Invalid or expired verification token" });
            }

            return Ok(new { message = "Email verified successfully" });
        }
        catch (InvalidOperationException ex)
        {
            _logger.LogWarning("Email verification failed: {Message}", ex.Message);
            return BadRequest(new { error = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during email verification");
            return StatusCode(500, new { error = "An error occurred during email verification" });
        }
    }

    /// <summary>
    /// Resend email verification
    /// </summary>
    [HttpPost("resend-verification")]
    [AllowAnonymous]
    public async Task<IActionResult> ResendEmailVerification([FromBody] ForgotPasswordRequest request)
    {
        try
        {
            await _authService.ResendEmailVerificationAsync(request.Email);
            return Ok(new { message = "If the email exists and is not verified, a verification link has been sent" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error resending email verification for {Email}", request.Email);
            return StatusCode(500, new { error = "An error occurred while resending verification email" });
        }
    }

    /// <summary>
    /// Get current user information
    /// </summary>
    [HttpGet("me")]
    [Authorize]
    public async Task<ActionResult<UserDto>> GetCurrentUser()
    {
        try
        {
            var userId = User.GetUserId();
            if (!userId.HasValue)
            {
                return Unauthorized();
            }

            var user = await _authService.GetUserByIdAsync(userId.Value);
            return Ok(user);
        }
        catch (InvalidOperationException ex)
        {
            _logger.LogWarning("User not found for ID {UserId}: {Message}", User.GetUserId(), ex.Message);
            return NotFound(new { error = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving current user {UserId}", User.GetUserId());
            return StatusCode(500, new { error = "An error occurred while retrieving user information" });
        }
    }

    /// <summary>
    /// Update current user profile
    /// </summary>
    [HttpPut("profile")]
    [Authorize]
    [RequireActiveAccount]
    public async Task<ActionResult<UserDto>> UpdateProfile([FromBody] UpdateUserProfileRequest request)
    {
        try
        {
            var userId = User.GetUserId();
            if (!userId.HasValue)
            {
                return Unauthorized();
            }

            var user = await _authService.UpdateUserProfileAsync(userId.Value, request);
            return Ok(user);
        }
        catch (InvalidOperationException ex)
        {
            _logger.LogWarning("Profile update failed for user {UserId}: {Message}", User.GetUserId(), ex.Message);
            return NotFound(new { error = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating profile for user {UserId}", User.GetUserId());
            return StatusCode(500, new { error = "An error occurred while updating profile" });
        }
    }

    // OAuth endpoints

    /// <summary>
    /// Login with Google OAuth
    /// </summary>
    [HttpPost("oauth/google")]
    [AllowAnonymous]
    public async Task<ActionResult<AuthResponse>> GoogleLogin([FromBody] OAuthLoginRequest request)
    {
        try
        {
            var ipAddress = GetIpAddress();
            var response = await _oauthService.GoogleLoginAsync(request.Code, request.RedirectUri, ipAddress);

            SetRefreshTokenCookie(response.RefreshToken);

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during Google OAuth login");
            return StatusCode(500, new { error = "An error occurred during Google login" });
        }
    }

    /// <summary>
    /// Login with GitHub OAuth
    /// </summary>
    [HttpPost("oauth/github")]
    [AllowAnonymous]
    public async Task<ActionResult<AuthResponse>> GitHubLogin([FromBody] OAuthLoginRequest request)
    {
        try
        {
            var ipAddress = GetIpAddress();
            var response = await _oauthService.GitHubLoginAsync(request.Code, request.RedirectUri, ipAddress);

            SetRefreshTokenCookie(response.RefreshToken);

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during GitHub OAuth login");
            return StatusCode(500, new { error = "An error occurred during GitHub login" });
        }
    }

    /// <summary>
    /// Link OAuth provider to current account
    /// </summary>
    [HttpPost("oauth/link/{provider}")]
    [Authorize]
    [RequireActiveAccount]
    public async Task<IActionResult> LinkOAuthProvider(string provider, [FromBody] OAuthLoginRequest request)
    {
        try
        {
            var userId = User.GetUserId();
            if (!userId.HasValue)
            {
                return Unauthorized();
            }

            var success = await _oauthService.LinkOAuthProviderAsync(userId.Value, provider, request.Code, request.RedirectUri);

            if (!success)
            {
                return BadRequest(new { error = "Failed to link OAuth provider" });
            }

            return Ok(new { message = $"{provider} linked successfully" });
        }
        catch (InvalidOperationException ex)
        {
            _logger.LogWarning("OAuth linking failed for user {UserId} and provider {Provider}: {Message}",
                User.GetUserId(), provider, ex.Message);
            return BadRequest(new { error = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error linking OAuth provider {Provider} for user {UserId}", provider, User.GetUserId());
            return StatusCode(500, new { error = "An error occurred while linking OAuth provider" });
        }
    }

    /// <summary>
    /// Unlink OAuth provider from current account
    /// </summary>
    [HttpDelete("oauth/unlink/{provider}")]
    [Authorize]
    [RequireActiveAccount]
    public async Task<IActionResult> UnlinkOAuthProvider(string provider)
    {
        try
        {
            var userId = User.GetUserId();
            if (!userId.HasValue)
            {
                return Unauthorized();
            }

            var success = await _oauthService.UnlinkOAuthProviderAsync(userId.Value, provider);

            if (!success)
            {
                return NotFound(new { error = "OAuth provider not found" });
            }

            return Ok(new { message = $"{provider} unlinked successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error unlinking OAuth provider {Provider} for user {UserId}", provider, User.GetUserId());
            return StatusCode(500, new { error = "An error occurred while unlinking OAuth provider" });
        }
    }

    /// <summary>
    /// Get linked OAuth providers for current user
    /// </summary>
    [HttpGet("oauth/providers")]
    [Authorize]
    public async Task<ActionResult<List<object>>> GetLinkedOAuthProviders()
    {
        try
        {
            var userId = User.GetUserId();
            if (!userId.HasValue)
            {
                return Unauthorized();
            }

            var providers = await _oauthService.GetUserOAuthProvidersAsync(userId.Value);
            var result = providers.Select(p => new
            {
                provider = p.Provider,
                connectedAt = p.ConnectedAt,
                lastUsedAt = p.LastUsedAt,
                providerEmail = p.ProviderEmail,
                providerName = p.ProviderName
            }).ToList();

            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving OAuth providers for user {UserId}", User.GetUserId());
            return StatusCode(500, new { error = "An error occurred while retrieving OAuth providers" });
        }
    }

    // Helper methods
    private string GetIpAddress()
    {
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();
        if (string.IsNullOrEmpty(ipAddress) || ipAddress == "::1")
            ipAddress = HttpContext.Request.Headers["X-Forwarded-For"].FirstOrDefault();
        if (string.IsNullOrEmpty(ipAddress))
            ipAddress = HttpContext.Request.Headers["X-Real-IP"].FirstOrDefault();

        return ipAddress ?? "Unknown";
    }

    private void SetRefreshTokenCookie(string refreshToken)
    {
        var cookieOptions = new CookieOptions
        {
            HttpOnly = true,
            Secure = true,
            SameSite = SameSiteMode.Strict,
            Expires = DateTime.UtcNow.AddDays(7),
            Path = "/"
        };

        Response.Cookies.Append("refreshToken", refreshToken, cookieOptions);
    }

    private string? GetRefreshTokenFromCookie()
    {
        return Request.Cookies["refreshToken"];
    }

    private void ClearRefreshTokenCookie()
    {
        Response.Cookies.Delete("refreshToken");
    }
}