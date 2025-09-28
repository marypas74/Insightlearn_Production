using Microsoft.AspNetCore.SignalR;
using Microsoft.AspNetCore.Authorization;
using System.Collections.Concurrent;

namespace InsightLearn.Web.Hubs;

[Authorize]
public class NotificationHub : Hub
{
    private static readonly ConcurrentDictionary<string, NotificationConnection> _connections = new();
    private static readonly ConcurrentDictionary<string, HashSet<string>> _userGroups = new();

    public async Task JoinUserGroup(string userId)
    {
        try
        {
            var groupName = $"user_{userId}";
            await Groups.AddToGroupAsync(Context.ConnectionId, groupName);

            if (!_userGroups.ContainsKey(userId))
            {
                _userGroups[userId] = new HashSet<string>();
            }
            _userGroups[userId].Add(Context.ConnectionId);

            _connections[Context.ConnectionId] = new NotificationConnection
            {
                ConnectionId = Context.ConnectionId,
                UserId = userId,
                ConnectedAt = DateTime.UtcNow
            };

            await Clients.Caller.SendAsync("JoinedNotificationGroup", new
            {
                UserId = userId,
                Message = "Connected to notifications"
            });
        }
        catch (Exception ex)
        {
            await Clients.Caller.SendAsync("NotificationError", $"Failed to join notifications: {ex.Message}");
        }
    }

    public async Task SendNotificationToUser(string targetUserId, NotificationMessage notification)
    {
        try
        {
            var groupName = $"user_{targetUserId}";

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

            await Clients.Group(groupName).SendAsync("ReceiveNotification", notificationData);
        }
        catch (Exception ex)
        {
            await Clients.Caller.SendAsync("NotificationError", $"Failed to send notification: {ex.Message}");
        }
    }

    public async Task SendBroadcastNotification(NotificationMessage notification)
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

            await Clients.All.SendAsync("ReceiveBroadcast", notificationData);
        }
        catch (Exception ex)
        {
            await Clients.Caller.SendAsync("NotificationError", $"Failed to send broadcast: {ex.Message}");
        }
    }

    public async Task MarkNotificationAsRead(string notificationId)
    {
        try
        {
            await Clients.Caller.SendAsync("NotificationRead", new
            {
                NotificationId = notificationId,
                ReadAt = DateTime.UtcNow
            });
        }
        catch (Exception ex)
        {
            await Clients.Caller.SendAsync("NotificationError", $"Failed to mark notification as read: {ex.Message}");
        }
    }

    public async Task MarkAllAsRead(string userId)
    {
        try
        {
            var groupName = $"user_{userId}";
            await Clients.Group(groupName).SendAsync("AllNotificationsRead", new
            {
                UserId = userId,
                ReadAt = DateTime.UtcNow
            });
        }
        catch (Exception ex)
        {
            await Clients.Caller.SendAsync("NotificationError", $"Failed to mark all as read: {ex.Message}");
        }
    }

    public async Task GetUnreadCount(string userId)
    {
        try
        {
            // In a real implementation, this would query the database
            var unreadCount = 5; // Mock data

            await Clients.Caller.SendAsync("UnreadCount", new
            {
                UserId = userId,
                Count = unreadCount
            });
        }
        catch (Exception ex)
        {
            await Clients.Caller.SendAsync("NotificationError", $"Failed to get unread count: {ex.Message}");
        }
    }

    public async Task SendProgressUpdate(string taskId, int progress, string status = "")
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

            await Clients.All.SendAsync("ProgressUpdate", progressData);
        }
        catch (Exception ex)
        {
            await Clients.Caller.SendAsync("NotificationError", $"Failed to send progress update: {ex.Message}");
        }
    }

    public async Task SendSystemAlert(string alertType, string message, string severity = "info")
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

            await Clients.All.SendAsync("SystemAlert", alertData);
        }
        catch (Exception ex)
        {
            await Clients.Caller.SendAsync("NotificationError", $"Failed to send system alert: {ex.Message}");
        }
    }

    public override async Task OnConnectedAsync()
    {
        try
        {
            var connectionId = Context.ConnectionId;
            var userId = Context.User?.Identity?.Name ?? "Anonymous";

            await Clients.Caller.SendAsync("NotificationHubConnected", new
            {
                ConnectionId = connectionId,
                UserId = userId,
                Timestamp = DateTime.UtcNow
            });

            await base.OnConnectedAsync();
        }
        catch (Exception ex)
        {
            await Clients.Caller.SendAsync("NotificationError", $"Connection error: {ex.Message}");
        }
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        try
        {
            var connectionId = Context.ConnectionId;

            if (_connections.TryRemove(connectionId, out var connection))
            {
                var userId = connection.UserId;

                if (_userGroups.ContainsKey(userId))
                {
                    _userGroups[userId].Remove(connectionId);
                    if (!_userGroups[userId].Any())
                    {
                        _userGroups.TryRemove(userId, out _);
                    }
                }
            }

            await base.OnDisconnectedAsync(exception);
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Error in NotificationHub.OnDisconnectedAsync: {ex.Message}");
        }
    }
}

public class NotificationConnection
{
    public string ConnectionId { get; set; } = string.Empty;
    public string UserId { get; set; } = string.Empty;
    public DateTime ConnectedAt { get; set; }
}

public class NotificationMessage
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string Title { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public NotificationType Type { get; set; }
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    public Dictionary<string, object> Data { get; set; } = new();
    public bool IsRead { get; set; } = false;
    public NotificationPriority Priority { get; set; } = NotificationPriority.Normal;
}

public enum NotificationType
{
    Info,
    Success,
    Warning,
    Error,
    VideoProcessing,
    SystemUpdate,
    UserActivity,
    Custom
}

public enum NotificationPriority
{
    Low,
    Normal,
    High,
    Urgent
}