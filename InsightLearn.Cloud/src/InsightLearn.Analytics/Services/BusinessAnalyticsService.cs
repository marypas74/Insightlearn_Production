using Microsoft.Extensions.Logging;
using System.Text.Json;

namespace InsightLearn.Analytics.Services
{
    public class BusinessAnalyticsService
    {
        private readonly ILogger<BusinessAnalyticsService> _logger;
        private readonly string _analyticsLogPath;

        public BusinessAnalyticsService(ILogger<BusinessAnalyticsService> logger)
        {
            _logger = logger;
            _analyticsLogPath = Path.Combine("logs", "business-analytics.jsonl");
            Directory.CreateDirectory(Path.GetDirectoryName(_analyticsLogPath));
        }

        public async Task TrackUserRegistration(string userId, Dictionary<string, object> metadata)
        {
            var analyticsEvent = new
            {
                Timestamp = DateTime.UtcNow,
                EventType = "user_registration",
                UserId = userId,
                Metadata = metadata
            };

            await LogAnalyticsEvent(analyticsEvent);
            _logger.LogInformation("User registration tracked: {UserId}", userId);
        }

        public async Task TrackCourseEnrollment(string userId, string courseId, decimal price)
        {
            var analyticsEvent = new
            {
                Timestamp = DateTime.UtcNow,
                EventType = "course_enrollment",
                UserId = userId,
                CourseId = courseId,
                Price = price,
                Metadata = new
                {
                    RevenueImpact = price,
                    ConversionPoint = "enrollment"
                }
            };

            await LogAnalyticsEvent(analyticsEvent);
            _logger.LogInformation("Course enrollment tracked: {UserId} -> {CourseId}", userId, courseId);
        }

        public async Task TrackCourseCompletion(string userId, string courseId, TimeSpan completionTime)
        {
            var analyticsEvent = new
            {
                Timestamp = DateTime.UtcNow,
                EventType = "course_completion",
                UserId = userId,
                CourseId = courseId,
                Metadata = new
                {
                    CompletionTimeMinutes = completionTime.TotalMinutes,
                    CompletionPoint = "course_end"
                }
            };

            await LogAnalyticsEvent(analyticsEvent);
            _logger.LogInformation("Course completion tracked: {UserId} completed {CourseId}", userId, courseId);
        }

        public async Task TrackAIInteraction(string userId, string interactionType, string aiModel, TimeSpan responseTime)
        {
            var analyticsEvent = new
            {
                Timestamp = DateTime.UtcNow,
                EventType = "ai_interaction",
                UserId = userId,
                Metadata = new
                {
                    InteractionType = interactionType,
                    AIModel = aiModel,
                    ResponseTimeMs = responseTime.TotalMilliseconds,
                    ServiceHealth = responseTime.TotalSeconds < 2 ? "good" : "degraded"
                }
            };

            await LogAnalyticsEvent(analyticsEvent);
        }

        public async Task TrackVideoWatched(string userId, string courseId, string videoId, TimeSpan watchTime, TimeSpan totalDuration)
        {
            var watchPercentage = watchTime.TotalSeconds / totalDuration.TotalSeconds * 100;

            var analyticsEvent = new
            {
                Timestamp = DateTime.UtcNow,
                EventType = "video_watched",
                UserId = userId,
                CourseId = courseId,
                VideoId = videoId,
                Metadata = new
                {
                    WatchTimeSeconds = watchTime.TotalSeconds,
                    TotalDurationSeconds = totalDuration.TotalSeconds,
                    WatchPercentage = watchPercentage,
                    EngagementLevel = watchPercentage switch
                    {
                        >= 90 => "high",
                        >= 50 => "medium",
                        _ => "low"
                    }
                }
            };

            await LogAnalyticsEvent(analyticsEvent);
        }

        private async Task LogAnalyticsEvent(object analyticsEvent)
        {
            try
            {
                var jsonLine = JsonSerializer.Serialize(analyticsEvent, new JsonSerializerOptions
                {
                    PropertyNamingPolicy = JsonNamingPolicy.CamelCase
                });

                await File.AppendAllTextAsync(_analyticsLogPath, jsonLine + Environment.NewLine);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to log analytics event");
            }
        }

        public async Task<Dictionary<string, object>> GetBusinessMetrics(DateTime fromDate, DateTime toDate)
        {
            try
            {
                var lines = await File.ReadAllLinesAsync(_analyticsLogPath);
                var events = lines.Select(line => JsonSerializer.Deserialize<JsonElement>(line))
                             .Where(e =>
                             {
                                 if (e.TryGetProperty("timestamp", out var timestampProp))
                                 {
                                     if (DateTime.TryParse(timestampProp.GetString(), out var timestamp))
                                     {
                                         return timestamp >= fromDate && timestamp <= toDate;
                                     }
                                 }
                                 return false;
                             })
                             .ToList();

                var metrics = new Dictionary<string, object>
                {
                    ["totalEvents"] = events.Count,
                    ["uniqueUsers"] = events.Where(e => e.TryGetProperty("userId", out _))
                                           .Select(e => e.GetProperty("userId").GetString())
                                           .Distinct()
                                           .Count(),
                    ["registrations"] = events.Count(e => e.GetProperty("eventType").GetString() == "user_registration"),
                    ["enrollments"] = events.Count(e => e.GetProperty("eventType").GetString() == "course_enrollment"),
                    ["completions"] = events.Count(e => e.GetProperty("eventType").GetString() == "course_completion"),
                    ["aiInteractions"] = events.Count(e => e.GetProperty("eventType").GetString() == "ai_interaction"),
                    ["videoWatches"] = events.Count(e => e.GetProperty("eventType").GetString() == "video_watched")
                };

                return metrics;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to calculate business metrics");
                return new Dictionary<string, object> { ["error"] = "Failed to calculate metrics" };
            }
        }
    }
}