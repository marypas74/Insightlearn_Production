using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.EntityFrameworkCore;
using InsightLearn.Infrastructure.Data;

namespace InsightLearn.Infrastructure.Services;

public class TokenCleanupService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<TokenCleanupService> _logger;
    private readonly TimeSpan _period = TimeSpan.FromHours(1); // Run every hour

    public TokenCleanupService(IServiceProvider serviceProvider, ILogger<TokenCleanupService> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await CleanupExpiredTokensAsync();
                await Task.Delay(_period, stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred during token cleanup");
                await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken); // Wait 5 minutes before retry
            }
        }
    }

    private async Task CleanupExpiredTokensAsync()
    {
        using var scope = _serviceProvider.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();

        try
        {
            var expiredTokens = await context.RefreshTokens
                .Where(rt => rt.Expires < DateTime.UtcNow || rt.RevokedAt != null)
                .Where(rt => rt.CreatedAt < DateTime.UtcNow.AddDays(-30)) // Keep for 30 days for audit purposes
                .ToListAsync();

            if (expiredTokens.Any())
            {
                context.RefreshTokens.RemoveRange(expiredTokens);
                await context.SaveChangesAsync();

                _logger.LogInformation("Cleaned up {Count} expired refresh tokens", expiredTokens.Count);
            }
            else
            {
                _logger.LogDebug("No expired refresh tokens found for cleanup");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during token cleanup process");
        }
    }
}