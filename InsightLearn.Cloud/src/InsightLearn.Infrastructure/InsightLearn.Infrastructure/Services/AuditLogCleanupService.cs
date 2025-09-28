using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using InsightLearn.Core.Interfaces;

namespace InsightLearn.Infrastructure.Services;

public class AuditLogCleanupService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly IConfiguration _configuration;
    private readonly ILogger<AuditLogCleanupService> _logger;
    private readonly TimeSpan _period = TimeSpan.FromDays(1); // Run daily

    public AuditLogCleanupService(
        IServiceProvider serviceProvider,
        IConfiguration configuration,
        ILogger<AuditLogCleanupService> logger)
    {
        _serviceProvider = serviceProvider;
        _configuration = configuration;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // Wait 1 hour after startup before first cleanup
        await Task.Delay(TimeSpan.FromHours(1), stoppingToken);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await CleanupOldAuditLogsAsync();
                await Task.Delay(_period, stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred during audit log cleanup");
                await Task.Delay(TimeSpan.FromHours(1), stoppingToken); // Wait 1 hour before retry
            }
        }
    }

    private async Task CleanupOldAuditLogsAsync()
    {
        using var scope = _serviceProvider.CreateScope();
        var auditService = scope.ServiceProvider.GetRequiredService<IAuditService>();

        try
        {
            var retentionDays = int.Parse(_configuration["AuditSettings:RetentionDays"] ?? "365");
            await auditService.CleanupOldAuditLogsAsync(retentionDays);

            _logger.LogInformation("Audit log cleanup completed successfully");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during audit log cleanup process");
        }
    }
}