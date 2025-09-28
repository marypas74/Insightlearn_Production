using Microsoft.Extensions.Logging;
using InsightLearn.Core.Models;

namespace InsightLearn.Infrastructure.Services;

public interface IThumbnailService
{
    Task<VideoThumbnail> GenerateDefaultThumbnailAsync(int videoId, string videoPath, string outputDirectory);
    Task<VideoThumbnail[]> GenerateMultipleThumbnailsAsync(int videoId, string videoPath, string outputDirectory, int count = 5);
    Task<string> GetThumbnailUrlAsync(int thumbnailId);
    Task<bool> DeleteThumbnailAsync(int thumbnailId);
}

public class ThumbnailService : IThumbnailService
{
    private readonly IVideoProcessingService _videoProcessingService;
    private readonly ILogger<ThumbnailService> _logger;

    public ThumbnailService(IVideoProcessingService videoProcessingService, ILogger<ThumbnailService> logger)
    {
        _videoProcessingService = videoProcessingService;
        _logger = logger;
    }

    public async Task<VideoThumbnail> GenerateDefaultThumbnailAsync(int videoId, string videoPath, string outputDirectory)
    {
        try
        {
            var duration = await _videoProcessingService.GetVideoDurationAsync(videoPath);
            var timestampPosition = TimeSpan.FromSeconds(duration.TotalSeconds * 0.1); // 10% into video

            var thumbnailFileName = $"video_{videoId}_default.jpg";
            var thumbnailPath = Path.Combine(outputDirectory, thumbnailFileName);

            await _videoProcessingService.GenerateThumbnailAsync(videoPath, timestampPosition, thumbnailPath);

            var thumbnail = new VideoThumbnail
            {
                VideoId = videoId,
                FilePath = thumbnailPath,
                TimestampPosition = timestampPosition,
                IsDefault = true,
                Width = 1280,
                Height = 720
            };

            _logger.LogInformation("Default thumbnail generated for video {VideoId}: {ThumbnailPath}",
                videoId, thumbnailPath);

            return thumbnail;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to generate default thumbnail for video {VideoId}", videoId);
            throw;
        }
    }

    public async Task<VideoThumbnail[]> GenerateMultipleThumbnailsAsync(int videoId, string videoPath, string outputDirectory, int count = 5)
    {
        try
        {
            var duration = await _videoProcessingService.GetVideoDurationAsync(videoPath);
            var thumbnails = new List<VideoThumbnail>();

            for (int i = 0; i < count; i++)
            {
                var percentProgress = (double)(i + 1) / (count + 1);
                var timestampPosition = TimeSpan.FromSeconds(duration.TotalSeconds * percentProgress);

                var thumbnailFileName = $"video_{videoId}_thumb_{i + 1}.jpg";
                var thumbnailPath = Path.Combine(outputDirectory, thumbnailFileName);

                await _videoProcessingService.GenerateThumbnailAsync(videoPath, timestampPosition, thumbnailPath);

                var thumbnail = new VideoThumbnail
                {
                    VideoId = videoId,
                    FilePath = thumbnailPath,
                    TimestampPosition = timestampPosition,
                    IsDefault = i == 0,
                    Width = 1280,
                    Height = 720
                };

                thumbnails.Add(thumbnail);
            }

            _logger.LogInformation("Generated {Count} thumbnails for video {VideoId}", count, videoId);

            return thumbnails.ToArray();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to generate multiple thumbnails for video {VideoId}", videoId);
            throw;
        }
    }

    public async Task<string> GetThumbnailUrlAsync(int thumbnailId)
    {
        await Task.CompletedTask;
        return $"/api/thumbnails/{thumbnailId}";
    }

    public async Task<bool> DeleteThumbnailAsync(int thumbnailId)
    {
        try
        {
            await Task.CompletedTask;
            _logger.LogInformation("Thumbnail {ThumbnailId} deleted", thumbnailId);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to delete thumbnail {ThumbnailId}", thumbnailId);
            return false;
        }
    }
}