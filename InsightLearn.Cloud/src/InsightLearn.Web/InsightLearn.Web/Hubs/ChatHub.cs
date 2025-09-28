using Microsoft.AspNetCore.SignalR;
using Microsoft.AspNetCore.Authorization;
using System.Collections.Concurrent;

namespace InsightLearn.Web.Hubs;

[Authorize]
public class ChatHub : Hub
{
    private static readonly ConcurrentDictionary<string, UserConnection> _connections = new();
    private static readonly ConcurrentDictionary<string, HashSet<string>> _groupConnections = new();

    public async Task SendMessage(string user, string message)
    {
        try
        {
            var timestamp = DateTime.UtcNow;
            var messageData = new
            {
                User = user,
                Message = message,
                Timestamp = timestamp,
                ConnectionId = Context.ConnectionId
            };

            await Clients.All.SendAsync("ReceiveMessage", messageData);
        }
        catch (Exception ex)
        {
            await Clients.Caller.SendAsync("Error", $"Failed to send message: {ex.Message}");
        }
    }

    public async Task SendMessageToGroup(string groupName, string user, string message)
    {
        try
        {
            var timestamp = DateTime.UtcNow;
            var messageData = new
            {
                User = user,
                Message = message,
                Timestamp = timestamp,
                GroupName = groupName,
                ConnectionId = Context.ConnectionId
            };

            await Clients.Group(groupName).SendAsync("ReceiveGroupMessage", messageData);
        }
        catch (Exception ex)
        {
            await Clients.Caller.SendAsync("Error", $"Failed to send group message: {ex.Message}");
        }
    }

    public async Task JoinGroup(string groupName, string userName)
    {
        try
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, groupName);

            if (!_groupConnections.ContainsKey(groupName))
            {
                _groupConnections[groupName] = new HashSet<string>();
            }
            _groupConnections[groupName].Add(Context.ConnectionId);

            _connections[Context.ConnectionId] = new UserConnection
            {
                ConnectionId = Context.ConnectionId,
                UserName = userName,
                GroupName = groupName,
                JoinedAt = DateTime.UtcNow
            };

            await Clients.Group(groupName).SendAsync("UserJoined", new
            {
                UserName = userName,
                GroupName = groupName,
                Timestamp = DateTime.UtcNow
            });

            await Clients.Caller.SendAsync("JoinedGroup", new
            {
                GroupName = groupName,
                Message = $"You joined the group '{groupName}'"
            });
        }
        catch (Exception ex)
        {
            await Clients.Caller.SendAsync("Error", $"Failed to join group: {ex.Message}");
        }
    }

    public async Task LeaveGroup(string groupName)
    {
        try
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, groupName);

            if (_groupConnections.ContainsKey(groupName))
            {
                _groupConnections[groupName].Remove(Context.ConnectionId);
                if (!_groupConnections[groupName].Any())
                {
                    _groupConnections.TryRemove(groupName, out _);
                }
            }

            if (_connections.TryGetValue(Context.ConnectionId, out var connection))
            {
                await Clients.Group(groupName).SendAsync("UserLeft", new
                {
                    UserName = connection.UserName,
                    GroupName = groupName,
                    Timestamp = DateTime.UtcNow
                });
            }

            await Clients.Caller.SendAsync("LeftGroup", new
            {
                GroupName = groupName,
                Message = $"You left the group '{groupName}'"
            });
        }
        catch (Exception ex)
        {
            await Clients.Caller.SendAsync("Error", $"Failed to leave group: {ex.Message}");
        }
    }

    public async Task SendPrivateMessage(string targetConnectionId, string message)
    {
        try
        {
            var senderConnection = _connections.GetValueOrDefault(Context.ConnectionId);
            if (senderConnection == null)
            {
                await Clients.Caller.SendAsync("Error", "User not found");
                return;
            }

            var messageData = new
            {
                From = senderConnection.UserName,
                Message = message,
                Timestamp = DateTime.UtcNow,
                IsPrivate = true
            };

            await Clients.Client(targetConnectionId).SendAsync("ReceivePrivateMessage", messageData);
            await Clients.Caller.SendAsync("PrivateMessageSent", messageData);
        }
        catch (Exception ex)
        {
            await Clients.Caller.SendAsync("Error", $"Failed to send private message: {ex.Message}");
        }
    }

    public async Task GetOnlineUsers()
    {
        try
        {
            var onlineUsers = _connections.Values
                .Select(c => new
                {
                    c.UserName,
                    c.GroupName,
                    c.JoinedAt,
                    c.ConnectionId
                })
                .ToList();

            await Clients.Caller.SendAsync("OnlineUsers", onlineUsers);
        }
        catch (Exception ex)
        {
            await Clients.Caller.SendAsync("Error", $"Failed to get online users: {ex.Message}");
        }
    }

    public async Task Typing(string groupName, string userName)
    {
        try
        {
            await Clients.OthersInGroup(groupName).SendAsync("UserTyping", new
            {
                UserName = userName,
                GroupName = groupName,
                Timestamp = DateTime.UtcNow
            });
        }
        catch (Exception ex)
        {
            await Clients.Caller.SendAsync("Error", $"Failed to send typing indicator: {ex.Message}");
        }
    }

    public async Task StopTyping(string groupName, string userName)
    {
        try
        {
            await Clients.OthersInGroup(groupName).SendAsync("UserStoppedTyping", new
            {
                UserName = userName,
                GroupName = groupName,
                Timestamp = DateTime.UtcNow
            });
        }
        catch (Exception ex)
        {
            await Clients.Caller.SendAsync("Error", $"Failed to send stop typing indicator: {ex.Message}");
        }
    }

    public override async Task OnConnectedAsync()
    {
        try
        {
            var connectionId = Context.ConnectionId;
            var userId = Context.User?.Identity?.Name ?? "Anonymous";

            await Clients.All.SendAsync("UserConnected", new
            {
                ConnectionId = connectionId,
                UserId = userId,
                Timestamp = DateTime.UtcNow
            });

            await base.OnConnectedAsync();
        }
        catch (Exception ex)
        {
            await Clients.Caller.SendAsync("Error", $"Connection error: {ex.Message}");
        }
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        try
        {
            var connectionId = Context.ConnectionId;

            if (_connections.TryRemove(connectionId, out var connection))
            {
                if (!string.IsNullOrEmpty(connection.GroupName))
                {
                    await Clients.Group(connection.GroupName).SendAsync("UserLeft", new
                    {
                        UserName = connection.UserName,
                        GroupName = connection.GroupName,
                        Timestamp = DateTime.UtcNow
                    });

                    if (_groupConnections.ContainsKey(connection.GroupName))
                    {
                        _groupConnections[connection.GroupName].Remove(connectionId);
                        if (!_groupConnections[connection.GroupName].Any())
                        {
                            _groupConnections.TryRemove(connection.GroupName, out _);
                        }
                    }
                }

                await Clients.All.SendAsync("UserDisconnected", new
                {
                    ConnectionId = connectionId,
                    UserName = connection.UserName,
                    Timestamp = DateTime.UtcNow,
                    Exception = exception?.Message
                });
            }

            await base.OnDisconnectedAsync(exception);
        }
        catch (Exception ex)
        {
            // Log the exception but don't throw to avoid connection issues
            System.Diagnostics.Debug.WriteLine($"Error in OnDisconnectedAsync: {ex.Message}");
        }
    }
}

public class UserConnection
{
    public string ConnectionId { get; set; } = string.Empty;
    public string UserName { get; set; } = string.Empty;
    public string GroupName { get; set; } = string.Empty;
    public DateTime JoinedAt { get; set; }
}