using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using InsightLearn.Core.Interfaces;
using InsightLearn.Core.Models;
using InsightLearn.Infrastructure.Data;
using System.Text.Json;

namespace InsightLearn.Infrastructure.Services;

public class AuditService : IAuditService
{
    private readonly ApplicationDbContext _context;
    private readonly ILogger<AuditService> _logger;

    public AuditService(ApplicationDbContext context, ILogger<AuditService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task LogAsync(string action, string entity, int? entityId = null, int? userId = null,
        object? oldValues = null, object? newValues = null, string? ipAddress = null, string? userAgent = null)
    {
        try
        {
            var auditLog = new AuditLog
            {
                Action = action,
                Entity = entity,
                EntityId = entityId,
                UserId = userId,
                OldValues = oldValues != null ? JsonSerializer.Serialize(oldValues) : null,
                NewValues = newValues != null ? JsonSerializer.Serialize(newValues) : null,
                IpAddress = ipAddress,
                UserAgent = userAgent,
                Timestamp = DateTime.UtcNow
            };

            _context.AuditLogs.Add(auditLog);
            await _context.SaveChangesAsync();

            _logger.LogDebug("Audit log created: {Action} on {Entity} {EntityId} by user {UserId}",
                action, entity, entityId, userId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating audit log for action: {Action} on {Entity} {EntityId}",
                action, entity, entityId);
            // Don't throw - audit logging shouldn't break the main flow
        }
    }

    public async Task<List<AuditLog>> GetAuditLogsAsync(int page = 1, int pageSize = 50, int? userId = null,
        string? action = null, DateTime? fromDate = null, DateTime? toDate = null)
    {
        try
        {
            var query = _context.AuditLogs
                .Include(al => al.User)
                .AsQueryable();

            // Apply filters
            if (userId.HasValue)
            {
                query = query.Where(al => al.UserId == userId.Value);
            }

            if (!string.IsNullOrWhiteSpace(action))
            {
                query = query.Where(al => al.Action.ToLower().Contains(action.ToLower()));
            }

            if (fromDate.HasValue)
            {
                query = query.Where(al => al.Timestamp >= fromDate.Value);
            }

            if (toDate.HasValue)
            {
                query = query.Where(al => al.Timestamp <= toDate.Value);
            }

            // Apply pagination and ordering
            var skip = (page - 1) * pageSize;
            var auditLogs = await query
                .OrderByDescending(al => al.Timestamp)
                .Skip(skip)
                .Take(pageSize)
                .ToListAsync();

            _logger.LogDebug("Retrieved {Count} audit logs for page {Page}", auditLogs.Count, page);
            return auditLogs;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving audit logs");
            throw;
        }
    }

    public async Task<List<AuditLog>> GetUserAuditLogsAsync(int userId, int page = 1, int pageSize = 20)
    {
        try
        {
            var skip = (page - 1) * pageSize;
            var auditLogs = await _context.AuditLogs
                .Where(al => al.UserId == userId)
                .OrderByDescending(al => al.Timestamp)
                .Skip(skip)
                .Take(pageSize)
                .ToListAsync();

            _logger.LogDebug("Retrieved {Count} audit logs for user {UserId} on page {Page}",
                auditLogs.Count, userId, page);
            return auditLogs;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving audit logs for user {UserId}", userId);
            throw;
        }
    }

    public async Task<List<AuditLog>> GetEntityAuditLogsAsync(string entity, int entityId, int page = 1, int pageSize = 20)
    {
        try
        {
            var skip = (page - 1) * pageSize;
            var auditLogs = await _context.AuditLogs
                .Include(al => al.User)
                .Where(al => al.Entity.ToLower() == entity.ToLower() && al.EntityId == entityId)
                .OrderByDescending(al => al.Timestamp)
                .Skip(skip)
                .Take(pageSize)
                .ToListAsync();

            _logger.LogDebug("Retrieved {Count} audit logs for {Entity} {EntityId} on page {Page}",
                auditLogs.Count, entity, entityId, page);
            return auditLogs;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving audit logs for {Entity} {EntityId}", entity, entityId);
            throw;
        }
    }

    public async Task<int> GetAuditLogsCountAsync(int? userId = null, string? action = null,
        DateTime? fromDate = null, DateTime? toDate = null)
    {
        try
        {
            var query = _context.AuditLogs.AsQueryable();

            // Apply filters
            if (userId.HasValue)
            {
                query = query.Where(al => al.UserId == userId.Value);
            }

            if (!string.IsNullOrWhiteSpace(action))
            {
                query = query.Where(al => al.Action.ToLower().Contains(action.ToLower()));
            }

            if (fromDate.HasValue)
            {
                query = query.Where(al => al.Timestamp >= fromDate.Value);
            }

            if (toDate.HasValue)
            {
                query = query.Where(al => al.Timestamp <= toDate.Value);
            }

            var count = await query.CountAsync();

            _logger.LogDebug("Total audit logs count: {Count}", count);
            return count;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting audit logs count");
            throw;
        }
    }

    public async Task<List<string>> GetDistinctActionsAsync()
    {
        try
        {
            var actions = await _context.AuditLogs
                .Select(al => al.Action)
                .Distinct()
                .OrderBy(action => action)
                .ToListAsync();

            _logger.LogDebug("Retrieved {Count} distinct actions", actions.Count);
            return actions;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving distinct actions");
            throw;
        }
    }

    public async Task<List<string>> GetDistinctEntitiesAsync()
    {
        try
        {
            var entities = await _context.AuditLogs
                .Select(al => al.Entity)
                .Distinct()
                .OrderBy(entity => entity)
                .ToListAsync();

            _logger.LogDebug("Retrieved {Count} distinct entities", entities.Count);
            return entities;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving distinct entities");
            throw;
        }
    }

    public async Task<Dictionary<string, int>> GetActionStatsAsync(DateTime? fromDate = null, DateTime? toDate = null)
    {
        try
        {
            var query = _context.AuditLogs.AsQueryable();

            if (fromDate.HasValue)
            {
                query = query.Where(al => al.Timestamp >= fromDate.Value);
            }

            if (toDate.HasValue)
            {
                query = query.Where(al => al.Timestamp <= toDate.Value);
            }

            var stats = await query
                .GroupBy(al => al.Action)
                .Select(g => new { Action = g.Key, Count = g.Count() })
                .OrderByDescending(x => x.Count)
                .ToDictionaryAsync(x => x.Action, x => x.Count);

            _logger.LogDebug("Retrieved action statistics for {Count} actions", stats.Count);
            return stats;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving action statistics");
            throw;
        }
    }

    public async Task CleanupOldAuditLogsAsync(int retentionDays = 365)
    {
        try
        {
            var cutoffDate = DateTime.UtcNow.AddDays(-retentionDays);

            var oldLogs = await _context.AuditLogs
                .Where(al => al.Timestamp < cutoffDate)
                .ToListAsync();

            if (oldLogs.Any())
            {
                _context.AuditLogs.RemoveRange(oldLogs);
                await _context.SaveChangesAsync();

                _logger.LogInformation("Cleaned up {Count} audit logs older than {RetentionDays} days",
                    oldLogs.Count, retentionDays);
            }
            else
            {
                _logger.LogDebug("No old audit logs found for cleanup");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during audit log cleanup");
            throw;
        }
    }

    public async Task<List<AuditLog>> GetSecurityAuditLogsAsync(int page = 1, int pageSize = 50, DateTime? fromDate = null)
    {
        try
        {
            var securityActions = new[]
            {
                "login_success", "login_failed", "logout", "password_changed", "password_reset",
                "email_verified", "account_locked", "account_unlocked", "permission_granted",
                "permission_revoked", "role_assigned", "role_removed", "oauth_linked", "oauth_unlinked"
            };

            var query = _context.AuditLogs
                .Include(al => al.User)
                .Where(al => securityActions.Contains(al.Action));

            if (fromDate.HasValue)
            {
                query = query.Where(al => al.Timestamp >= fromDate.Value);
            }

            var skip = (page - 1) * pageSize;
            var securityLogs = await query
                .OrderByDescending(al => al.Timestamp)
                .Skip(skip)
                .Take(pageSize)
                .ToListAsync();

            _logger.LogDebug("Retrieved {Count} security audit logs for page {Page}", securityLogs.Count, page);
            return securityLogs;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving security audit logs");
            throw;
        }
    }
}