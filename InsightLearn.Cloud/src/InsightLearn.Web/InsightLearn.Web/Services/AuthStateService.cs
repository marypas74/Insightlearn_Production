using Microsoft.JSInterop;
using System.Net.Http.Headers;
using System.Text.Json;

namespace InsightLearn.Web.Services;

public class AuthStateService
{
    private readonly HttpClient _httpClient;
    private readonly IJSRuntime _jsRuntime;

    public event Action? OnAuthStateChanged;

    public AuthStateService(HttpClient httpClient, IJSRuntime jsRuntime)
    {
        _httpClient = httpClient;
        _jsRuntime = jsRuntime;
    }

    public async Task<bool> IsAuthenticatedAsync()
    {
        try
        {
            var token = await GetAccessTokenAsync();
            return !string.IsNullOrEmpty(token) && !IsTokenExpired(token);
        }
        catch
        {
            return false;
        }
    }

    public async Task<string?> GetAccessTokenAsync()
    {
        try
        {
            return await _jsRuntime.InvokeAsync<string>("localStorage.getItem", "accessToken");
        }
        catch
        {
            return null;
        }
    }

    public async Task<string?> GetRefreshTokenAsync()
    {
        try
        {
            return await _jsRuntime.InvokeAsync<string>("localStorage.getItem", "refreshToken");
        }
        catch
        {
            return null;
        }
    }

    public async Task<UserDto?> GetCurrentUserAsync()
    {
        try
        {
            var userJson = await _jsRuntime.InvokeAsync<string>("localStorage.getItem", "user");
            if (string.IsNullOrEmpty(userJson))
                return null;

            return JsonSerializer.Deserialize<UserDto>(userJson, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });
        }
        catch
        {
            return null;
        }
    }

    public async Task SetAuthDataAsync(string accessToken, string refreshToken, UserDto user)
    {
        try
        {
            await _jsRuntime.InvokeVoidAsync("localStorage.setItem", "accessToken", accessToken);
            await _jsRuntime.InvokeVoidAsync("localStorage.setItem", "refreshToken", refreshToken);
            await _jsRuntime.InvokeVoidAsync("localStorage.setItem", "user", JsonSerializer.Serialize(user));

            // Set authorization header
            _httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

            OnAuthStateChanged?.Invoke();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error setting auth data: {ex.Message}");
        }
    }

    public async Task ClearAuthDataAsync()
    {
        try
        {
            await _jsRuntime.InvokeVoidAsync("localStorage.removeItem", "accessToken");
            await _jsRuntime.InvokeVoidAsync("localStorage.removeItem", "refreshToken");
            await _jsRuntime.InvokeVoidAsync("localStorage.removeItem", "user");

            // Clear authorization header
            _httpClient.DefaultRequestHeaders.Authorization = null;

            OnAuthStateChanged?.Invoke();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error clearing auth data: {ex.Message}");
        }
    }

    public async Task<bool> RefreshTokenAsync()
    {
        try
        {
            var refreshToken = await GetRefreshTokenAsync();
            if (string.IsNullOrEmpty(refreshToken))
                return false;

            var request = new { refreshToken = refreshToken };
            var response = await _httpClient.PostAsJsonAsync("/api/auth/refresh-token", request);

            if (response.IsSuccessStatusCode)
            {
                var authResponse = await response.Content.ReadFromJsonAsync<AuthResponse>();
                if (authResponse != null)
                {
                    await SetAuthDataAsync(authResponse.AccessToken, authResponse.RefreshToken, authResponse.User);
                    return true;
                }
            }
            else
            {
                // Refresh failed, clear auth data
                await ClearAuthDataAsync();
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error refreshing token: {ex.Message}");
            await ClearAuthDataAsync();
        }

        return false;
    }

    public async Task<bool> LogoutAsync()
    {
        try
        {
            var refreshToken = await GetRefreshTokenAsync();
            if (!string.IsNullOrEmpty(refreshToken))
            {
                var request = new { refreshToken = refreshToken };
                await _httpClient.PostAsJsonAsync("/api/auth/logout", request);
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error during logout: {ex.Message}");
        }
        finally
        {
            await ClearAuthDataAsync();
        }

        return true;
    }

    public async Task InitializeAsync()
    {
        try
        {
            var token = await GetAccessTokenAsync();
            if (!string.IsNullOrEmpty(token))
            {
                if (IsTokenExpired(token))
                {
                    // Try to refresh the token
                    var refreshed = await RefreshTokenAsync();
                    if (!refreshed)
                    {
                        await ClearAuthDataAsync();
                    }
                }
                else
                {
                    // Set authorization header
                    _httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
                }
            }

            OnAuthStateChanged?.Invoke();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error initializing auth state: {ex.Message}");
            await ClearAuthDataAsync();
        }
    }

    public bool HasPermission(string permission)
    {
        var user = GetCurrentUserAsync().GetAwaiter().GetResult();
        return user?.Permissions.Contains(permission) == true;
    }

    public bool IsInRole(string role)
    {
        var user = GetCurrentUserAsync().GetAwaiter().GetResult();
        return user?.Roles.Contains(role, StringComparer.OrdinalIgnoreCase) == true;
    }

    public bool IsInAnyRole(params string[] roles)
    {
        var user = GetCurrentUserAsync().GetAwaiter().GetResult();
        if (user == null) return false;

        return roles.Any(role => user.Roles.Contains(role, StringComparer.OrdinalIgnoreCase));
    }

    private bool IsTokenExpired(string token)
    {
        try
        {
            var parts = token.Split('.');
            if (parts.Length != 3)
                return true;

            var payload = parts[1];

            // Add padding if needed
            var paddedPayload = payload.PadRight(payload.Length + (4 - payload.Length % 4) % 4, '=');

            var payloadBytes = Convert.FromBase64String(paddedPayload);
            var payloadJson = System.Text.Encoding.UTF8.GetString(payloadBytes);

            using var document = JsonDocument.Parse(payloadJson);
            var root = document.RootElement;

            if (root.TryGetProperty("exp", out var expProperty))
            {
                var exp = expProperty.GetInt64();
                var expDateTime = DateTimeOffset.FromUnixTimeSeconds(exp).DateTime;
                return DateTime.UtcNow >= expDateTime;
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error checking token expiration: {ex.Message}");
        }

        return true; // Assume expired if we can't parse it
    }

    // DTOs
    public class AuthResponse
    {
        public string AccessToken { get; set; } = string.Empty;
        public string RefreshToken { get; set; } = string.Empty;
        public DateTime ExpiresAt { get; set; }
        public UserDto User { get; set; } = new();
    }

    public class UserDto
    {
        public int Id { get; set; }
        public string FirstName { get; set; } = string.Empty;
        public string LastName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public bool EmailVerified { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? LastLoginAt { get; set; }
        public bool IsActive { get; set; }
        public string? ProfileImageUrl { get; set; }
        public string? Bio { get; set; }
        public List<string> Roles { get; set; } = new();
        public List<string> Permissions { get; set; } = new();
    }
}