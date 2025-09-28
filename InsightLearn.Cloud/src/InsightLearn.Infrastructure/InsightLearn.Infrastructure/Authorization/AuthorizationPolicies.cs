using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.DependencyInjection;
using System.Security.Claims;

namespace InsightLearn.Infrastructure.Authorization;

public static class AuthorizationPolicies
{
    // Policy constants
    public const string RequireStudentRole = "RequireStudentRole";
    public const string RequireInstructorRole = "RequireInstructorRole";
    public const string RequireAdminRole = "RequireAdminRole";
    public const string RequireInstructorOrAdmin = "RequireInstructorOrAdmin";
    public const string RequireEmailVerified = "RequireEmailVerified";
    public const string RequireActiveAccount = "RequireActiveAccount";

    // Permission-based policies
    public const string CanViewUsers = "CanViewUsers";
    public const string CanManageUsers = "CanManageUsers";
    public const string CanViewCourses = "CanViewCourses";
    public const string CanCreateCourses = "CanCreateCourses";
    public const string CanManageCourses = "CanManageCourses";
    public const string CanUploadVideos = "CanUploadVideos";
    public const string CanManageVideos = "CanManageVideos";
    public const string CanViewAnalytics = "CanViewAnalytics";
    public const string CanManageRoles = "CanManageRoles";
    public const string CanViewAuditLogs = "CanViewAuditLogs";

    public static void ConfigureAuthorizationPolicies(this IServiceCollection services)
    {
        services.AddAuthorizationBuilder()
            // Role-based policies
            .AddPolicy(RequireStudentRole, policy =>
                policy.RequireRole("Student"))

            .AddPolicy(RequireInstructorRole, policy =>
                policy.RequireRole("Instructor"))

            .AddPolicy(RequireAdminRole, policy =>
                policy.RequireRole("Admin"))

            .AddPolicy(RequireInstructorOrAdmin, policy =>
                policy.RequireRole("Instructor", "Admin"))

            // Account status policies
            .AddPolicy(RequireEmailVerified, policy =>
                policy.AddRequirements(new EmailVerifiedRequirement()))

            .AddPolicy(RequireActiveAccount, policy =>
                policy.AddRequirements(new ActiveAccountRequirement()))

            // Permission-based policies
            .AddPolicy(CanViewUsers, policy =>
                policy.AddRequirements(new PermissionRequirement("user.view")))

            .AddPolicy(CanManageUsers, policy =>
                policy.AddRequirements(new PermissionRequirement("admin.users")))

            .AddPolicy(CanViewCourses, policy =>
                policy.AddRequirements(new PermissionRequirement("course.view")))

            .AddPolicy(CanCreateCourses, policy =>
                policy.AddRequirements(new PermissionRequirement("course.create")))

            .AddPolicy(CanManageCourses, policy =>
                policy.AddRequirements(new PermissionRequirement("course.edit", "course.delete")))

            .AddPolicy(CanUploadVideos, policy =>
                policy.AddRequirements(new PermissionRequirement("video.upload")))

            .AddPolicy(CanManageVideos, policy =>
                policy.AddRequirements(new PermissionRequirement("video.edit", "video.delete")))

            .AddPolicy(CanViewAnalytics, policy =>
                policy.AddRequirements(new PermissionRequirement("admin.system")))

            .AddPolicy(CanManageRoles, policy =>
                policy.AddRequirements(new PermissionRequirement("admin.roles")))

            .AddPolicy(CanViewAuditLogs, policy =>
                policy.AddRequirements(new PermissionRequirement("admin.system")));

        // Register authorization handlers
        services.AddScoped<IAuthorizationHandler, PermissionAuthorizationHandler>();
        services.AddScoped<IAuthorizationHandler, EmailVerifiedAuthorizationHandler>();
        services.AddScoped<IAuthorizationHandler, ActiveAccountAuthorizationHandler>();
        services.AddScoped<IAuthorizationHandler, ResourceOwnershipAuthorizationHandler>();
    }
}

// Custom authorization requirements
public class PermissionRequirement : IAuthorizationRequirement
{
    public string[] RequiredPermissions { get; }
    public bool RequireAll { get; }

    public PermissionRequirement(params string[] requiredPermissions)
    {
        RequiredPermissions = requiredPermissions;
        RequireAll = false; // By default, require at least one permission
    }

    public PermissionRequirement(bool requireAll, params string[] requiredPermissions)
    {
        RequiredPermissions = requiredPermissions;
        RequireAll = requireAll;
    }
}

public class EmailVerifiedRequirement : IAuthorizationRequirement
{
}

public class ActiveAccountRequirement : IAuthorizationRequirement
{
}

public class ResourceOwnershipRequirement : IAuthorizationRequirement
{
    public string ResourceIdParameterName { get; }

    public ResourceOwnershipRequirement(string resourceIdParameterName = "id")
    {
        ResourceIdParameterName = resourceIdParameterName;
    }
}

// Authorization handlers
public class PermissionAuthorizationHandler : AuthorizationHandler<PermissionRequirement>
{
    protected override Task HandleRequirementAsync(AuthorizationHandlerContext context,
        PermissionRequirement requirement)
    {
        var userPermissions = context.User.Claims
            .Where(c => c.Type == "permission")
            .Select(c => c.Value)
            .ToHashSet();

        bool hasPermission;

        if (requirement.RequireAll)
        {
            // User must have ALL required permissions
            hasPermission = requirement.RequiredPermissions.All(permission =>
                userPermissions.Contains(permission));
        }
        else
        {
            // User must have at least ONE of the required permissions
            hasPermission = requirement.RequiredPermissions.Any(permission =>
                userPermissions.Contains(permission));
        }

        if (hasPermission)
        {
            context.Succeed(requirement);
        }

        return Task.CompletedTask;
    }
}

public class EmailVerifiedAuthorizationHandler : AuthorizationHandler<EmailVerifiedRequirement>
{
    private readonly Core.Interfaces.IUserService _userService;

    public EmailVerifiedAuthorizationHandler(Core.Interfaces.IUserService userService)
    {
        _userService = userService;
    }

    protected override async Task HandleRequirementAsync(AuthorizationHandlerContext context,
        EmailVerifiedRequirement requirement)
    {
        var userIdClaim = context.User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (!int.TryParse(userIdClaim, out var userId))
        {
            return;
        }

        var user = await _userService.GetUserByIdAsync(userId);
        if (user != null && user.EmailVerified)
        {
            context.Succeed(requirement);
        }
    }
}

public class ActiveAccountAuthorizationHandler : AuthorizationHandler<ActiveAccountRequirement>
{
    private readonly Core.Interfaces.IUserService _userService;

    public ActiveAccountAuthorizationHandler(Core.Interfaces.IUserService userService)
    {
        _userService = userService;
    }

    protected override async Task HandleRequirementAsync(AuthorizationHandlerContext context,
        ActiveAccountRequirement requirement)
    {
        var userIdClaim = context.User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (!int.TryParse(userIdClaim, out var userId))
        {
            return;
        }

        var user = await _userService.GetUserByIdAsync(userId);
        if (user != null && user.IsActive)
        {
            context.Succeed(requirement);
        }
    }
}

public class ResourceOwnershipAuthorizationHandler : AuthorizationHandler<ResourceOwnershipRequirement>
{
    protected override Task HandleRequirementAsync(AuthorizationHandlerContext context,
        ResourceOwnershipRequirement requirement)
    {
        var user = context.User;

        // Check if user is admin (admin can access all resources)
        var userRoles = user.Claims
            .Where(c => c.Type == ClaimTypes.Role)
            .Select(c => c.Value)
            .ToList();

        if (userRoles.Contains("Admin", StringComparer.OrdinalIgnoreCase))
        {
            context.Succeed(requirement);
            return Task.CompletedTask;
        }

        // Check if user is the owner of the resource
        var userIdClaim = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (!int.TryParse(userIdClaim, out var userId))
        {
            return Task.CompletedTask;
        }

        // Try to extract resource ID from the context
        if (context.Resource is Microsoft.AspNetCore.Http.HttpContext httpContext)
        {
            // Try route values first
            if (httpContext.Request.RouteValues.TryGetValue(requirement.ResourceIdParameterName, out var routeValue) &&
                int.TryParse(routeValue?.ToString(), out var resourceUserId))
            {
                if (userId == resourceUserId)
                {
                    context.Succeed(requirement);
                }
                return Task.CompletedTask;
            }

            // Try query parameters
            if (httpContext.Request.Query.TryGetValue(requirement.ResourceIdParameterName, out var queryValue) &&
                int.TryParse(queryValue, out var queryUserId))
            {
                if (userId == queryUserId)
                {
                    context.Succeed(requirement);
                }
                return Task.CompletedTask;
            }
        }

        return Task.CompletedTask;
    }
}

// Extension methods for easier policy application
public static class AuthorizationExtensions
{
    public static bool HasPermission(this ClaimsPrincipal user, string permission)
    {
        return user.Claims.Any(c => c.Type == "permission" && c.Value == permission);
    }

    public static bool HasAnyPermission(this ClaimsPrincipal user, params string[] permissions)
    {
        var userPermissions = user.Claims
            .Where(c => c.Type == "permission")
            .Select(c => c.Value)
            .ToHashSet();

        return permissions.Any(permission => userPermissions.Contains(permission));
    }

    public static bool HasAllPermissions(this ClaimsPrincipal user, params string[] permissions)
    {
        var userPermissions = user.Claims
            .Where(c => c.Type == "permission")
            .Select(c => c.Value)
            .ToHashSet();

        return permissions.All(permission => userPermissions.Contains(permission));
    }

    public static bool IsInAnyRole(this ClaimsPrincipal user, params string[] roles)
    {
        return roles.Any(role => user.IsInRole(role));
    }

    public static int? GetUserId(this ClaimsPrincipal user)
    {
        var userIdClaim = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return int.TryParse(userIdClaim, out var userId) ? userId : null;
    }

    public static string? GetUserEmail(this ClaimsPrincipal user)
    {
        return user.FindFirst(ClaimTypes.Email)?.Value;
    }

    public static List<string> GetUserRoles(this ClaimsPrincipal user)
    {
        return user.Claims
            .Where(c => c.Type == ClaimTypes.Role)
            .Select(c => c.Value)
            .ToList();
    }

    public static List<string> GetUserPermissions(this ClaimsPrincipal user)
    {
        return user.Claims
            .Where(c => c.Type == "permission")
            .Select(c => c.Value)
            .ToList();
    }
}