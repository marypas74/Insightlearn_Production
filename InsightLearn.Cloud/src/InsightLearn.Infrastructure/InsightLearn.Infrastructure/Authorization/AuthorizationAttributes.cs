using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.Extensions.DependencyInjection;
using InsightLearn.Core.Interfaces;
using System.Security.Claims;

namespace InsightLearn.Infrastructure.Authorization;

/// <summary>
/// Attribute to require specific permissions for an action
/// </summary>
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = true)]
public class RequirePermissionAttribute : Attribute, IAuthorizationFilter
{
    private readonly string[] _permissions;
    private readonly bool _requireAll;

    public RequirePermissionAttribute(params string[] permissions)
    {
        _permissions = permissions;
        _requireAll = false;
    }

    public RequirePermissionAttribute(bool requireAll, params string[] permissions)
    {
        _permissions = permissions;
        _requireAll = requireAll;
    }

    public void OnAuthorization(AuthorizationFilterContext context)
    {
        var user = context.HttpContext.User;

        if (!user.Identity?.IsAuthenticated ?? true)
        {
            context.Result = new UnauthorizedResult();
            return;
        }

        var userPermissions = user.Claims
            .Where(c => c.Type == "permission")
            .Select(c => c.Value)
            .ToList();

        bool hasPermission;

        if (_requireAll)
        {
            // User must have ALL specified permissions
            hasPermission = _permissions.All(permission => userPermissions.Contains(permission));
        }
        else
        {
            // User must have at least ONE of the specified permissions
            hasPermission = _permissions.Any(permission => userPermissions.Contains(permission));
        }

        if (!hasPermission)
        {
            context.Result = new ForbidResult();
            return;
        }
    }
}

/// <summary>
/// Attribute to require specific roles for an action
/// </summary>
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = true)]
public class RequireRoleAttribute : Attribute, IAuthorizationFilter
{
    private readonly string[] _roles;
    private readonly bool _requireAll;

    public RequireRoleAttribute(params string[] roles)
    {
        _roles = roles;
        _requireAll = false;
    }

    public RequireRoleAttribute(bool requireAll, params string[] roles)
    {
        _roles = roles;
        _requireAll = requireAll;
    }

    public void OnAuthorization(AuthorizationFilterContext context)
    {
        var user = context.HttpContext.User;

        if (!user.Identity?.IsAuthenticated ?? true)
        {
            context.Result = new UnauthorizedResult();
            return;
        }

        var userRoles = user.Claims
            .Where(c => c.Type == ClaimTypes.Role)
            .Select(c => c.Value)
            .ToList();

        bool hasRole;

        if (_requireAll)
        {
            // User must have ALL specified roles
            hasRole = _roles.All(role => userRoles.Contains(role, StringComparer.OrdinalIgnoreCase));
        }
        else
        {
            // User must have at least ONE of the specified roles
            hasRole = _roles.Any(role => userRoles.Contains(role, StringComparer.OrdinalIgnoreCase));
        }

        if (!hasRole)
        {
            context.Result = new ForbidResult();
            return;
        }
    }
}

/// <summary>
/// Attribute to require email verification
/// </summary>
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
public class RequireEmailVerificationAttribute : Attribute, IAsyncAuthorizationFilter
{
    public async Task OnAuthorizationAsync(AuthorizationFilterContext context)
    {
        var user = context.HttpContext.User;

        if (!user.Identity?.IsAuthenticated ?? true)
        {
            context.Result = new UnauthorizedResult();
            return;
        }

        var userIdClaim = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (!int.TryParse(userIdClaim, out var userId))
        {
            context.Result = new UnauthorizedResult();
            return;
        }

        var userService = context.HttpContext.RequestServices.GetRequiredService<IUserService>();
        var currentUser = await userService.GetUserByIdAsync(userId);

        if (currentUser == null || !currentUser.EmailVerified)
        {
            context.Result = new ObjectResult(new { error = "Email verification required" })
            {
                StatusCode = 403
            };
            return;
        }
    }
}

/// <summary>
/// Attribute to require account to be active
/// </summary>
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
public class RequireActiveAccountAttribute : Attribute, IAsyncAuthorizationFilter
{
    public async Task OnAuthorizationAsync(AuthorizationFilterContext context)
    {
        var user = context.HttpContext.User;

        if (!user.Identity?.IsAuthenticated ?? true)
        {
            context.Result = new UnauthorizedResult();
            return;
        }

        var userIdClaim = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (!int.TryParse(userIdClaim, out var userId))
        {
            context.Result = new UnauthorizedResult();
            return;
        }

        var userService = context.HttpContext.RequestServices.GetRequiredService<IUserService>();
        var currentUser = await userService.GetUserByIdAsync(userId);

        if (currentUser == null || !currentUser.IsActive)
        {
            context.Result = new ObjectResult(new { error = "Account is inactive" })
            {
                StatusCode = 403
            };
            return;
        }
    }
}

/// <summary>
/// Attribute to allow access only to the resource owner or admin
/// </summary>
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
public class RequireOwnershipOrAdminAttribute : Attribute, IAuthorizationFilter
{
    private readonly string _userIdParameterName;

    public RequireOwnershipOrAdminAttribute(string userIdParameterName = "userId")
    {
        _userIdParameterName = userIdParameterName;
    }

    public void OnAuthorization(AuthorizationFilterContext context)
    {
        var user = context.HttpContext.User;

        if (!user.Identity?.IsAuthenticated ?? true)
        {
            context.Result = new UnauthorizedResult();
            return;
        }

        // Check if user is admin
        var userRoles = user.Claims
            .Where(c => c.Type == ClaimTypes.Role)
            .Select(c => c.Value)
            .ToList();

        if (userRoles.Contains("Admin", StringComparer.OrdinalIgnoreCase))
        {
            return; // Admin can access everything
        }

        // Check ownership
        var currentUserIdClaim = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (!int.TryParse(currentUserIdClaim, out var currentUserId))
        {
            context.Result = new UnauthorizedResult();
            return;
        }

        // Try to get resource owner ID from route values
        if (context.RouteData.Values.TryGetValue(_userIdParameterName, out var resourceUserIdObj) &&
            int.TryParse(resourceUserIdObj?.ToString(), out var resourceUserId))
        {
            if (currentUserId != resourceUserId)
            {
                context.Result = new ForbidResult();
                return;
            }
        }
        else
        {
            // Try to get from query string
            if (context.HttpContext.Request.Query.TryGetValue(_userIdParameterName, out var queryUserId) &&
                int.TryParse(queryUserId, out var queryUserIdInt))
            {
                if (currentUserId != queryUserIdInt)
                {
                    context.Result = new ForbidResult();
                    return;
                }
            }
            else
            {
                // If no user ID parameter found, deny access
                context.Result = new ForbidResult();
                return;
            }
        }
    }
}

/// <summary>
/// Combined attribute that applies multiple authorization checks
/// </summary>
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
public class SecureEndpointAttribute : Attribute, IAsyncAuthorizationFilter
{
    private readonly string[] _requiredPermissions;
    private readonly string[] _requiredRoles;
    private readonly bool _requireEmailVerification;
    private readonly bool _requireActiveAccount;

    public SecureEndpointAttribute(
        string[]? requiredPermissions = null,
        string[]? requiredRoles = null,
        bool requireEmailVerification = true,
        bool requireActiveAccount = true)
    {
        _requiredPermissions = requiredPermissions ?? Array.Empty<string>();
        _requiredRoles = requiredRoles ?? Array.Empty<string>();
        _requireEmailVerification = requireEmailVerification;
        _requireActiveAccount = requireActiveAccount;
    }

    public async Task OnAuthorizationAsync(AuthorizationFilterContext context)
    {
        var user = context.HttpContext.User;

        if (!user.Identity?.IsAuthenticated ?? true)
        {
            context.Result = new UnauthorizedResult();
            return;
        }

        var userIdClaim = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (!int.TryParse(userIdClaim, out var userId))
        {
            context.Result = new UnauthorizedResult();
            return;
        }

        // Check account status if required
        if (_requireActiveAccount || _requireEmailVerification)
        {
            var userService = context.HttpContext.RequestServices.GetRequiredService<IUserService>();
            var currentUser = await userService.GetUserByIdAsync(userId);

            if (currentUser == null)
            {
                context.Result = new UnauthorizedResult();
                return;
            }

            if (_requireActiveAccount && !currentUser.IsActive)
            {
                context.Result = new ObjectResult(new { error = "Account is inactive" })
                {
                    StatusCode = 403
                };
                return;
            }

            if (_requireEmailVerification && !currentUser.EmailVerified)
            {
                context.Result = new ObjectResult(new { error = "Email verification required" })
                {
                    StatusCode = 403
                };
                return;
            }
        }

        // Check roles
        if (_requiredRoles.Length > 0)
        {
            var userRoles = user.Claims
                .Where(c => c.Type == ClaimTypes.Role)
                .Select(c => c.Value)
                .ToList();

            var hasRequiredRole = _requiredRoles.Any(role =>
                userRoles.Contains(role, StringComparer.OrdinalIgnoreCase));

            if (!hasRequiredRole)
            {
                context.Result = new ForbidResult();
                return;
            }
        }

        // Check permissions
        if (_requiredPermissions.Length > 0)
        {
            var userPermissions = user.Claims
                .Where(c => c.Type == "permission")
                .Select(c => c.Value)
                .ToList();

            var hasRequiredPermission = _requiredPermissions.Any(permission =>
                userPermissions.Contains(permission));

            if (!hasRequiredPermission)
            {
                context.Result = new ForbidResult();
                return;
            }
        }
    }
}