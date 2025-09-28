using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using InsightLearn.Core.Interfaces;
using InsightLearn.Core.Models;
using InsightLearn.Infrastructure.Data;

namespace InsightLearn.Infrastructure.Services;

public class RoleService : IRoleService
{
    private readonly ApplicationDbContext _context;
    private readonly ILogger<RoleService> _logger;

    public RoleService(ApplicationDbContext context, ILogger<RoleService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<Role?> GetRoleByNameAsync(string name)
    {
        try
        {
            var role = await _context.Roles
                .Include(r => r.RolePermissions)
                    .ThenInclude(rp => rp.Permission)
                .FirstOrDefaultAsync(r => r.Name.ToLower() == name.ToLower());

            _logger.LogDebug("Retrieved role by name: {RoleName}, Found: {Found}", name, role != null);
            return role;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving role by name: {RoleName}", name);
            throw;
        }
    }

    public async Task<Role?> GetRoleByIdAsync(int id)
    {
        try
        {
            var role = await _context.Roles
                .Include(r => r.RolePermissions)
                    .ThenInclude(rp => rp.Permission)
                .FirstOrDefaultAsync(r => r.Id == id);

            _logger.LogDebug("Retrieved role by ID: {RoleId}, Found: {Found}", id, role != null);
            return role;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving role by ID: {RoleId}", id);
            throw;
        }
    }

    public async Task<List<Role>> GetRolesAsync()
    {
        try
        {
            var roles = await _context.Roles
                .Include(r => r.RolePermissions)
                    .ThenInclude(rp => rp.Permission)
                .OrderBy(r => r.Name)
                .ToListAsync();

            _logger.LogDebug("Retrieved {Count} roles", roles.Count);
            return roles;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving roles");
            throw;
        }
    }

    public async Task<Role> CreateRoleAsync(Role role)
    {
        try
        {
            // Check if role name already exists
            var existingRole = await GetRoleByNameAsync(role.Name);
            if (existingRole != null)
            {
                throw new InvalidOperationException($"Role '{role.Name}' already exists");
            }

            role.CreatedAt = DateTime.UtcNow;
            _context.Roles.Add(role);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Created new role: {RoleName} with ID: {RoleId}", role.Name, role.Id);
            return role;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating role: {RoleName}", role.Name);
            throw;
        }
    }

    public async Task<Role> UpdateRoleAsync(Role role)
    {
        try
        {
            var existingRole = await _context.Roles.FindAsync(role.Id);
            if (existingRole == null)
            {
                throw new InvalidOperationException($"Role with ID {role.Id} not found");
            }

            // Check if new name conflicts with another role
            var roleWithSameName = await _context.Roles
                .FirstOrDefaultAsync(r => r.Name.ToLower() == role.Name.ToLower() && r.Id != role.Id);

            if (roleWithSameName != null)
            {
                throw new InvalidOperationException($"Another role with name '{role.Name}' already exists");
            }

            existingRole.Name = role.Name;
            existingRole.Description = role.Description;
            existingRole.IsDefault = role.IsDefault;

            await _context.SaveChangesAsync();

            _logger.LogInformation("Updated role: {RoleId} - {RoleName}", role.Id, role.Name);
            return existingRole;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating role: {RoleId}", role.Id);
            throw;
        }
    }

    public async Task<bool> DeleteRoleAsync(int id)
    {
        try
        {
            var role = await _context.Roles.FindAsync(id);
            if (role == null)
            {
                _logger.LogWarning("Attempted to delete non-existent role: {RoleId}", id);
                return false;
            }

            // Check if role is assigned to any users
            var userCount = await _context.UserRoles.CountAsync(ur => ur.RoleId == id);
            if (userCount > 0)
            {
                throw new InvalidOperationException($"Cannot delete role '{role.Name}' as it is assigned to {userCount} user(s)");
            }

            // Check if this is a default role
            if (role.IsDefault)
            {
                throw new InvalidOperationException($"Cannot delete default role '{role.Name}'");
            }

            // Remove all role permissions first
            var rolePermissions = await _context.RolePermissions
                .Where(rp => rp.RoleId == id)
                .ToListAsync();

            _context.RolePermissions.RemoveRange(rolePermissions);
            _context.Roles.Remove(role);

            await _context.SaveChangesAsync();

            _logger.LogInformation("Deleted role: {RoleId} - {RoleName}", id, role.Name);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting role: {RoleId}", id);
            throw;
        }
    }

    public async Task AssignPermissionToRoleAsync(int roleId, int permissionId, int grantedBy)
    {
        try
        {
            // Check if permission assignment already exists
            var existingAssignment = await _context.RolePermissions
                .FirstOrDefaultAsync(rp => rp.RoleId == roleId && rp.PermissionId == permissionId);

            if (existingAssignment != null)
            {
                _logger.LogWarning("Permission assignment already exists for Role {RoleId} and Permission {PermissionId}",
                    roleId, permissionId);
                return;
            }

            // Verify role exists
            var role = await _context.Roles.FindAsync(roleId);
            if (role == null)
            {
                throw new InvalidOperationException($"Role with ID {roleId} not found");
            }

            // Verify permission exists
            var permission = await _context.Permissions.FindAsync(permissionId);
            if (permission == null)
            {
                throw new InvalidOperationException($"Permission with ID {permissionId} not found");
            }

            var rolePermission = new RolePermission
            {
                RoleId = roleId,
                PermissionId = permissionId,
                GrantedBy = grantedBy,
                GrantedAt = DateTime.UtcNow
            };

            _context.RolePermissions.Add(rolePermission);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Assigned permission {PermissionId} ({PermissionName}) to role {RoleId} ({RoleName}) by user {GrantedBy}",
                permissionId, permission.Name, roleId, role.Name, grantedBy);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error assigning permission {PermissionId} to role {RoleId}", permissionId, roleId);
            throw;
        }
    }

    public async Task RemovePermissionFromRoleAsync(int roleId, int permissionId)
    {
        try
        {
            var rolePermission = await _context.RolePermissions
                .FirstOrDefaultAsync(rp => rp.RoleId == roleId && rp.PermissionId == permissionId);

            if (rolePermission != null)
            {
                _context.RolePermissions.Remove(rolePermission);
                await _context.SaveChangesAsync();

                _logger.LogInformation("Removed permission {PermissionId} from role {RoleId}", permissionId, roleId);
            }
            else
            {
                _logger.LogWarning("Permission assignment not found for Role {RoleId} and Permission {PermissionId}",
                    roleId, permissionId);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error removing permission {PermissionId} from role {RoleId}", permissionId, roleId);
            throw;
        }
    }

    public async Task<List<string>> GetRolePermissionsAsync(int roleId)
    {
        try
        {
            var permissions = await _context.RolePermissions
                .Where(rp => rp.RoleId == roleId)
                .Include(rp => rp.Permission)
                .Select(rp => rp.Permission.Name)
                .ToListAsync();

            _logger.LogDebug("Retrieved {Count} permissions for role {RoleId}", permissions.Count, roleId);
            return permissions;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving permissions for role {RoleId}", roleId);
            throw;
        }
    }

    public async Task<List<Permission>> GetAllPermissionsAsync()
    {
        try
        {
            var permissions = await _context.Permissions
                .OrderBy(p => p.Category)
                .ThenBy(p => p.Name)
                .ToListAsync();

            _logger.LogDebug("Retrieved {Count} permissions", permissions.Count);
            return permissions;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving all permissions");
            throw;
        }
    }

    public async Task<Permission?> GetPermissionByNameAsync(string name)
    {
        try
        {
            var permission = await _context.Permissions
                .FirstOrDefaultAsync(p => p.Name.ToLower() == name.ToLower());

            _logger.LogDebug("Retrieved permission by name: {PermissionName}, Found: {Found}", name, permission != null);
            return permission;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving permission by name: {PermissionName}", name);
            throw;
        }
    }

    public async Task<Permission> CreatePermissionAsync(Permission permission)
    {
        try
        {
            // Check if permission name already exists
            var existingPermission = await GetPermissionByNameAsync(permission.Name);
            if (existingPermission != null)
            {
                throw new InvalidOperationException($"Permission '{permission.Name}' already exists");
            }

            permission.CreatedAt = DateTime.UtcNow;
            _context.Permissions.Add(permission);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Created new permission: {PermissionName} with ID: {PermissionId}",
                permission.Name, permission.Id);
            return permission;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating permission: {PermissionName}", permission.Name);
            throw;
        }
    }

    public async Task<List<Permission>> GetPermissionsByCategoryAsync(string category)
    {
        try
        {
            var permissions = await _context.Permissions
                .Where(p => p.Category.ToLower() == category.ToLower())
                .OrderBy(p => p.Name)
                .ToListAsync();

            _logger.LogDebug("Retrieved {Count} permissions for category: {Category}", permissions.Count, category);
            return permissions;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving permissions for category: {Category}", category);
            throw;
        }
    }
}