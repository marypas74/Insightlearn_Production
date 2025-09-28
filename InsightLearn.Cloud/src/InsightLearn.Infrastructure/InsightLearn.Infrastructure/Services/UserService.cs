using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using InsightLearn.Core.Interfaces;
using InsightLearn.Core.Models;
using InsightLearn.Infrastructure.Data;

namespace InsightLearn.Infrastructure.Services;

public class UserService : IUserService
{
    private readonly ApplicationDbContext _context;
    private readonly ILogger<UserService> _logger;

    public UserService(ApplicationDbContext context, ILogger<UserService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<User?> GetUserByEmailAsync(string email)
    {
        try
        {
            var user = await _context.Users
                .Include(u => u.UserRoles)
                    .ThenInclude(ur => ur.Role)
                        .ThenInclude(r => r.RolePermissions)
                            .ThenInclude(rp => rp.Permission)
                .Include(u => u.RefreshTokens)
                .Include(u => u.OAuthProviders)
                .FirstOrDefaultAsync(u => u.Email.ToLower() == email.ToLower());

            _logger.LogDebug("Retrieved user by email: {Email}, Found: {Found}", email, user != null);
            return user;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving user by email: {Email}", email);
            throw;
        }
    }

    public async Task<User?> GetUserByIdAsync(int id)
    {
        try
        {
            var user = await _context.Users
                .Include(u => u.UserRoles)
                    .ThenInclude(ur => ur.Role)
                        .ThenInclude(r => r.RolePermissions)
                            .ThenInclude(rp => rp.Permission)
                .Include(u => u.RefreshTokens)
                .Include(u => u.OAuthProviders)
                .FirstOrDefaultAsync(u => u.Id == id);

            _logger.LogDebug("Retrieved user by ID: {UserId}, Found: {Found}", id, user != null);
            return user;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving user by ID: {UserId}", id);
            throw;
        }
    }

    public async Task<User> CreateUserAsync(User user)
    {
        try
        {
            // Set creation timestamp
            user.CreatedAt = DateTime.UtcNow;

            _context.Users.Add(user);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Created new user with ID: {UserId}, Email: {Email}", user.Id, user.Email);
            return user;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating user with email: {Email}", user.Email);
            throw;
        }
    }

    public async Task<User> UpdateUserAsync(User user)
    {
        try
        {
            _context.Users.Update(user);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Updated user with ID: {UserId}", user.Id);
            return user;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating user with ID: {UserId}", user.Id);
            throw;
        }
    }

    public async Task<bool> EmailExistsAsync(string email)
    {
        try
        {
            var exists = await _context.Users
                .AnyAsync(u => u.Email.ToLower() == email.ToLower());

            _logger.LogDebug("Email exists check for {Email}: {Exists}", email, exists);
            return exists;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error checking if email exists: {Email}", email);
            throw;
        }
    }

    public async Task<List<User>> GetUsersAsync(int page, int pageSize)
    {
        try
        {
            var skip = (page - 1) * pageSize;

            var users = await _context.Users
                .Include(u => u.UserRoles)
                    .ThenInclude(ur => ur.Role)
                .OrderBy(u => u.CreatedAt)
                .Skip(skip)
                .Take(pageSize)
                .ToListAsync();

            _logger.LogDebug("Retrieved {Count} users for page {Page} with page size {PageSize}", users.Count, page, pageSize);
            return users;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving users for page: {Page}, pageSize: {PageSize}", page, pageSize);
            throw;
        }
    }

    public async Task<int> GetUsersCountAsync()
    {
        try
        {
            var count = await _context.Users.CountAsync();
            _logger.LogDebug("Total users count: {Count}", count);
            return count;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting users count");
            throw;
        }
    }

    public async Task AssignRoleToUserAsync(int userId, int roleId, int assignedBy)
    {
        try
        {
            // Check if role assignment already exists
            var existingAssignment = await _context.UserRoles
                .FirstOrDefaultAsync(ur => ur.UserId == userId && ur.RoleId == roleId);

            if (existingAssignment != null)
            {
                _logger.LogWarning("Role assignment already exists for User {UserId} and Role {RoleId}", userId, roleId);
                return;
            }

            var userRole = new UserRole
            {
                UserId = userId,
                RoleId = roleId,
                AssignedBy = assignedBy,
                AssignedAt = DateTime.UtcNow
            };

            _context.UserRoles.Add(userRole);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Assigned role {RoleId} to user {UserId} by user {AssignedBy}", roleId, userId, assignedBy);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error assigning role {RoleId} to user {UserId}", roleId, userId);
            throw;
        }
    }

    public async Task RemoveRoleFromUserAsync(int userId, int roleId)
    {
        try
        {
            var userRole = await _context.UserRoles
                .FirstOrDefaultAsync(ur => ur.UserId == userId && ur.RoleId == roleId);

            if (userRole != null)
            {
                _context.UserRoles.Remove(userRole);
                await _context.SaveChangesAsync();

                _logger.LogInformation("Removed role {RoleId} from user {UserId}", roleId, userId);
            }
            else
            {
                _logger.LogWarning("Role assignment not found for User {UserId} and Role {RoleId}", userId, roleId);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error removing role {RoleId} from user {UserId}", roleId, userId);
            throw;
        }
    }

    public async Task<List<string>> GetUserRolesAsync(int userId)
    {
        try
        {
            var roles = await _context.UserRoles
                .Where(ur => ur.UserId == userId)
                .Include(ur => ur.Role)
                .Select(ur => ur.Role.Name)
                .ToListAsync();

            _logger.LogDebug("Retrieved {Count} roles for user {UserId}", roles.Count, userId);
            return roles;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving roles for user {UserId}", userId);
            throw;
        }
    }

    public async Task<List<string>> GetUserPermissionsAsync(int userId)
    {
        try
        {
            var permissions = await _context.UserRoles
                .Where(ur => ur.UserId == userId)
                .Include(ur => ur.Role)
                    .ThenInclude(r => r.RolePermissions)
                        .ThenInclude(rp => rp.Permission)
                .SelectMany(ur => ur.Role.RolePermissions)
                .Select(rp => rp.Permission.Name)
                .Distinct()
                .ToListAsync();

            _logger.LogDebug("Retrieved {Count} permissions for user {UserId}", permissions.Count, userId);
            return permissions;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving permissions for user {UserId}", userId);
            throw;
        }
    }
}