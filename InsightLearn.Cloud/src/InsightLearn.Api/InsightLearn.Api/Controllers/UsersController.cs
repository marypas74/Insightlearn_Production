using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using InsightLearn.Core.DTOs;
using InsightLearn.Core.Interfaces;
using InsightLearn.Infrastructure.Authorization;

namespace InsightLearn.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class UsersController : ControllerBase
{
    private readonly IAuthService _authService;
    private readonly IUserService _userService;
    private readonly IRoleService _roleService;
    private readonly IAuditService _auditService;
    private readonly ILogger<UsersController> _logger;

    public UsersController(
        IAuthService authService,
        IUserService userService,
        IRoleService roleService,
        IAuditService auditService,
        ILogger<UsersController> logger)
    {
        _authService = authService;
        _userService = userService;
        _roleService = roleService;
        _auditService = auditService;
        _logger = logger;
    }

    /// <summary>
    /// Get all users (admin only)
    /// </summary>
    [HttpGet]
    [RequirePermission("admin.users")]
    public async Task<ActionResult<List<UserDto>>> GetUsers(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 10)
    {
        try
        {
            if (page < 1) page = 1;
            if (pageSize < 1 || pageSize > 100) pageSize = 10;

            var users = await _authService.GetUsersAsync(page, pageSize);
            return Ok(users);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving users for page {Page}, pageSize {PageSize}", page, pageSize);
            return StatusCode(500, new { error = "An error occurred while retrieving users" });
        }
    }

    /// <summary>
    /// Get user by ID
    /// </summary>
    [HttpGet("{id}")]
    [RequireOwnershipOrAdmin("id")]
    public async Task<ActionResult<UserDto>> GetUser(int id)
    {
        try
        {
            var user = await _authService.GetUserByIdAsync(id);
            return Ok(user);
        }
        catch (InvalidOperationException ex)
        {
            _logger.LogWarning("User not found for ID {UserId}: {Message}", id, ex.Message);
            return NotFound(new { error = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving user {UserId}", id);
            return StatusCode(500, new { error = "An error occurred while retrieving user" });
        }
    }

    /// <summary>
    /// Update user profile (owner or admin only)
    /// </summary>
    [HttpPut("{id}")]
    [RequireOwnershipOrAdmin("id")]
    public async Task<ActionResult<UserDto>> UpdateUser(int id, [FromBody] UpdateUserProfileRequest request)
    {
        try
        {
            var user = await _authService.UpdateUserProfileAsync(id, request);

            // Log the update
            await _auditService.LogAsync("user_profile_updated", "user", id, User.GetUserId(), null,
                new { FirstName = request.FirstName, LastName = request.LastName });

            return Ok(user);
        }
        catch (InvalidOperationException ex)
        {
            _logger.LogWarning("Profile update failed for user {UserId}: {Message}", id, ex.Message);
            return NotFound(new { error = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating profile for user {UserId}", id);
            return StatusCode(500, new { error = "An error occurred while updating user profile" });
        }
    }

    /// <summary>
    /// Deactivate user account (admin only)
    /// </summary>
    [HttpPost("{id}/deactivate")]
    [RequirePermission("admin.users")]
    public async Task<IActionResult> DeactivateUser(int id)
    {
        try
        {
            var currentUserId = User.GetUserId();
            if (currentUserId == id)
            {
                return BadRequest(new { error = "Cannot deactivate your own account" });
            }

            var success = await _authService.DeactivateUserAsync(id);
            if (!success)
            {
                return NotFound(new { error = "User not found" });
            }

            await _auditService.LogAsync("user_deactivated", "user", id, currentUserId);

            return Ok(new { message = "User deactivated successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deactivating user {UserId}", id);
            return StatusCode(500, new { error = "An error occurred while deactivating user" });
        }
    }

    /// <summary>
    /// Activate user account (admin only)
    /// </summary>
    [HttpPost("{id}/activate")]
    [RequirePermission("admin.users")]
    public async Task<IActionResult> ActivateUser(int id)
    {
        try
        {
            var success = await _authService.ActivateUserAsync(id);
            if (!success)
            {
                return NotFound(new { error = "User not found" });
            }

            await _auditService.LogAsync("user_activated", "user", id, User.GetUserId());

            return Ok(new { message = "User activated successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error activating user {UserId}", id);
            return StatusCode(500, new { error = "An error occurred while activating user" });
        }
    }

    /// <summary>
    /// Assign role to user (admin only)
    /// </summary>
    [HttpPost("{id}/roles/{roleId}")]
    [RequirePermission("admin.roles")]
    public async Task<IActionResult> AssignRole(int id, int roleId)
    {
        try
        {
            var currentUserId = User.GetUserId();
            if (!currentUserId.HasValue)
            {
                return Unauthorized();
            }

            // Check if role exists
            var role = await _roleService.GetRoleByIdAsync(roleId);
            if (role == null)
            {
                return NotFound(new { error = "Role not found" });
            }

            // Check if user exists
            var user = await _userService.GetUserByIdAsync(id);
            if (user == null)
            {
                return NotFound(new { error = "User not found" });
            }

            await _userService.AssignRoleToUserAsync(id, roleId, currentUserId.Value);

            await _auditService.LogAsync("role_assigned", "user", id, currentUserId,
                null, new { RoleId = roleId, RoleName = role.Name });

            return Ok(new { message = $"Role '{role.Name}' assigned successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error assigning role {RoleId} to user {UserId}", roleId, id);
            return StatusCode(500, new { error = "An error occurred while assigning role" });
        }
    }

    /// <summary>
    /// Remove role from user (admin only)
    /// </summary>
    [HttpDelete("{id}/roles/{roleId}")]
    [RequirePermission("admin.roles")]
    public async Task<IActionResult> RemoveRole(int id, int roleId)
    {
        try
        {
            var currentUserId = User.GetUserId();

            // Check if role exists
            var role = await _roleService.GetRoleByIdAsync(roleId);
            if (role == null)
            {
                return NotFound(new { error = "Role not found" });
            }

            // Check if user exists
            var user = await _userService.GetUserByIdAsync(id);
            if (user == null)
            {
                return NotFound(new { error = "User not found" });
            }

            // Prevent removing admin role from yourself
            if (currentUserId == id && role.Name.Equals("Admin", StringComparison.OrdinalIgnoreCase))
            {
                return BadRequest(new { error = "Cannot remove admin role from your own account" });
            }

            await _userService.RemoveRoleFromUserAsync(id, roleId);

            await _auditService.LogAsync("role_removed", "user", id, currentUserId,
                null, new { RoleId = roleId, RoleName = role.Name });

            return Ok(new { message = $"Role '{role.Name}' removed successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error removing role {RoleId} from user {UserId}", roleId, id);
            return StatusCode(500, new { error = "An error occurred while removing role" });
        }
    }

    /// <summary>
    /// Get user's roles
    /// </summary>
    [HttpGet("{id}/roles")]
    [RequireOwnershipOrAdmin("id")]
    public async Task<ActionResult<List<string>>> GetUserRoles(int id)
    {
        try
        {
            var roles = await _userService.GetUserRolesAsync(id);
            return Ok(roles);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving roles for user {UserId}", id);
            return StatusCode(500, new { error = "An error occurred while retrieving user roles" });
        }
    }

    /// <summary>
    /// Get user's permissions
    /// </summary>
    [HttpGet("{id}/permissions")]
    [RequireOwnershipOrAdmin("id")]
    public async Task<ActionResult<List<string>>> GetUserPermissions(int id)
    {
        try
        {
            var permissions = await _userService.GetUserPermissionsAsync(id);
            return Ok(permissions);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving permissions for user {UserId}", id);
            return StatusCode(500, new { error = "An error occurred while retrieving user permissions" });
        }
    }

    /// <summary>
    /// Get user's audit logs (admin or owner only)
    /// </summary>
    [HttpGet("{id}/audit-logs")]
    [RequireOwnershipOrAdmin("id")]
    public async Task<ActionResult<List<object>>> GetUserAuditLogs(
        int id,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
    {
        try
        {
            if (page < 1) page = 1;
            if (pageSize < 1 || pageSize > 100) pageSize = 20;

            var auditLogs = await _auditService.GetUserAuditLogsAsync(id, page, pageSize);

            var result = auditLogs.Select(log => new
            {
                id = log.Id,
                action = log.Action,
                entity = log.Entity,
                entityId = log.EntityId,
                timestamp = log.Timestamp,
                ipAddress = log.IpAddress,
                userAgent = log.UserAgent,
                oldValues = log.OldValues,
                newValues = log.NewValues
            }).ToList();

            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving audit logs for user {UserId}", id);
            return StatusCode(500, new { error = "An error occurred while retrieving audit logs" });
        }
    }

    /// <summary>
    /// Search users by email or name (admin only)
    /// </summary>
    [HttpGet("search")]
    [RequirePermission("admin.users")]
    public async Task<ActionResult<List<UserDto>>> SearchUsers(
        [FromQuery] string query,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 10)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(query))
            {
                return BadRequest(new { error = "Search query is required" });
            }

            if (page < 1) page = 1;
            if (pageSize < 1 || pageSize > 100) pageSize = 10;

            // For now, return all users and filter client-side
            // In a real implementation, you'd add search functionality to the service layer
            var allUsers = await _authService.GetUsersAsync(page, pageSize);

            var filteredUsers = allUsers.Where(u =>
                u.Email.Contains(query, StringComparison.OrdinalIgnoreCase) ||
                u.FirstName.Contains(query, StringComparison.OrdinalIgnoreCase) ||
                u.LastName.Contains(query, StringComparison.OrdinalIgnoreCase) ||
                $"{u.FirstName} {u.LastName}".Contains(query, StringComparison.OrdinalIgnoreCase)
            ).ToList();

            return Ok(filteredUsers);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error searching users with query '{Query}'", query);
            return StatusCode(500, new { error = "An error occurred while searching users" });
        }
    }

    /// <summary>
    /// Get user statistics (admin only)
    /// </summary>
    [HttpGet("statistics")]
    [RequirePermission("admin.system")]
    public async Task<ActionResult<object>> GetUserStatistics()
    {
        try
        {
            var totalUsers = await _userService.GetUsersCountAsync();

            // You could extend this with more statistics like:
            // - Active vs inactive users
            // - Users by role
            // - Recent registrations
            // - Email verification status

            var stats = new
            {
                totalUsers = totalUsers,
                // Add more statistics as needed
            };

            return Ok(stats);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving user statistics");
            return StatusCode(500, new { error = "An error occurred while retrieving user statistics" });
        }
    }
}