using Microsoft.AspNetCore.SignalR;
using InsightLearn.Web.Hubs;

namespace InsightLearn.Web.Services;

public interface INotificationService
{
    Task SendNotificationToUserAsync(string userId, NotificationMessage notification);
    Task SendBroadcastNotificationAsync(NotificationMessage notification);
    Task SendSystemAlertAsync(string alertType, string message, string severity = "info");
    Task SendProgressUpdateAsync(string taskId, int progress, string status = "");
    Task SendVideoProcessingNotificationAsync(string userId, int videoId, string status, string? error = null);
}

public class NotificationService : INotificationService
{
    private readonly IHubContext<NotificationHub> _hubContext;
    private readonly ILogger<NotificationService> _logger;

    public NotificationService(IHubContext<NotificationHub> hubContext, ILogger<NotificationService> logger)
    {
        _hubContext = hubContext;
        _logger = logger;
    }

    public async Task SendNotificationToUserAsync(string userId, NotificationMessage notification)
    {
        try
        {
            var groupName = $"user_{userId}";

            var notificationData = new
            {
                notification.Id,
                notification.Title,
                notification.Message,
                notification.Type,
                notification.Timestamp,
                notification.Data,
                notification.IsRead,
                notification.Priority
            };

            await _hubContext.Clients.Group(groupName).SendAsync("ReceiveNotification", notificationData);

            _logger.LogInformation("Notification sent to user {UserId}: {Title}", userId, notification.Title);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send notification to user {UserId}", userId);
            throw;
        }
    }

    public async Task SendBroadcastNotificationAsync(NotificationMessage notification)
    {
        try
        {
            var notificationData = new
            {
                notification.Id,
                notification.Title,
                notification.Message,
                notification.Type,
                notification.Timestamp,
                notification.Data,
                notification.IsRead,
                notification.Priority
            };

            await _hubContext.Clients.All.SendAsync("ReceiveBroadcast", notificationData);

            _logger.LogInformation("Broadcast notification sent: {Title}", notification.Title);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send broadcast notification");
            throw;
        }
    }

    public async Task SendSystemAlertAsync(string alertType, string message, string severity = "info")
    {
        try
        {
            var alertData = new
            {
                AlertType = alertType,
                Message = message,
                Severity = severity,
                Timestamp = DateTime.UtcNow,
                Id = Guid.NewGuid().ToString()
            };

            await _hubContext.Clients.All.SendAsync("SystemAlert", alertData);

            _logger.LogInformation("System alert sent: {AlertType} - {Message}", alertType, message);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send system alert: {AlertType}", alertType);
            throw;
        }
    }

    public async Task SendProgressUpdateAsync(string taskId, int progress, string status = "")
    {
        try
        {
            var progressData = new
            {
                TaskId = taskId,
                Progress = progress,
                Status = status,
                Timestamp = DateTime.UtcNow
            };

            await _hubContext.Clients.All.SendAsync("ProgressUpdate", progressData);

            _logger.LogDebug("Progress update sent for task {TaskId}: {Progress}%", taskId, progress);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send progress update for task {TaskId}", taskId);
            throw;
        }
    }

    public async Task SendVideoProcessingNotificationAsync(string userId, int videoId, string status, string? error = null)
    {
        try
        {
            var notification = new NotificationMessage
            {
                Title = "Video Processing Update",
                Message = error != null
                    ? $"Video processing failed: {error}"
                    : $"Video processing {status.ToLower()}",
                Type = error != null ? NotificationType.Error : NotificationType.VideoProcessing,
                Priority = error != null ? NotificationPriority.High : NotificationPriority.Normal,
                Data = new Dictionary<string, object>
                {
                    ["videoId"] = videoId,
                    ["status"] = status,
                    ["error"] = error ?? ""
                }
            };

            await SendNotificationToUserAsync(userId, notification);

            _logger.LogInformation("Video processing notification sent to user {UserId} for video {VideoId}: {Status}",
                userId, videoId, status);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send video processing notification to user {UserId}", userId);
            throw;
        }
    }
}

// Extension methods for easier usage
public static class NotificationExtensions
{
    public static NotificationMessage CreateInfoNotification(string title, string message)
    {
        return new NotificationMessage
        {
            Title = title,
            Message = message,
            Type = NotificationType.Info,
            Priority = NotificationPriority.Normal
        };
    }

    public static NotificationMessage CreateSuccessNotification(string title, string message)
    {
        return new NotificationMessage
        {
            Title = title,
            Message = message,
            Type = NotificationType.Success,
            Priority = NotificationPriority.Normal
        };
    }

    public static NotificationMessage CreateWarningNotification(string title, string message)
    {
        return new NotificationMessage
        {
            Title = title,
            Message = message,
            Type = NotificationType.Warning,
            Priority = NotificationPriority.High
        };
    }

    public static NotificationMessage CreateErrorNotification(string title, string message)
    {
        return new NotificationMessage
        {
            Title = title,
            Message = message,
            Type = NotificationType.Error,
            Priority = NotificationPriority.Urgent
        };
    }
}