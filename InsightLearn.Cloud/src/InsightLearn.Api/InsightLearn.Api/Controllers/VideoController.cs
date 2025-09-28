using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using InsightLearn.Core.Models;
using InsightLearn.Infrastructure.Services;
using System.ComponentModel.DataAnnotations;

namespace InsightLearn.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class VideoController : ControllerBase
{
    private readonly IVideoProcessingService _videoProcessingService;
    private readonly IThumbnailService _thumbnailService;
    private readonly ILogger<VideoController> _logger;

    public VideoController(
        IVideoProcessingService videoProcessingService,
        IThumbnailService thumbnailService,
        ILogger<VideoController> logger)
    {
        _videoProcessingService = videoProcessingService;
        _thumbnailService = thumbnailService;
        _logger = logger;
    }

    [HttpGet]
    public async Task<ActionResult<VideoListResponse>> GetVideos(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 10,
        [FromQuery] string? search = null)
    {
        try
        {
            await Task.CompletedTask;

            var videos = new List<VideoDto>
            {
                new VideoDto
                {
                    Id = 1,
                    Title = "Sample Video 1",
                    Description = "This is a sample video",
                    Duration = TimeSpan.FromMinutes(5),
                    ThumbnailUrl = "/api/thumbnails/1",
                    ViewCount = 150,
                    UploadedAt = DateTime.UtcNow.AddDays(-2)
                }
            };

            var response = new VideoListResponse
            {
                Videos = videos,
                TotalCount = 1,
                Page = page,
                PageSize = pageSize
            };

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to get videos");
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<VideoDetailsDto>> GetVideo(int id)
    {
        try
        {
            await Task.CompletedTask;

            var video = new VideoDetailsDto
            {
                Id = id,
                Title = $"Sample Video {id}",
                Description = "This is a detailed sample video",
                Duration = TimeSpan.FromMinutes(5),
                ThumbnailUrl = $"/api/thumbnails/{id}",
                VideoUrl = $"/api/videos/{id}/stream",
                ViewCount = 150,
                UploadedAt = DateTime.UtcNow.AddDays(-2),
                ProcessingStatus = VideoProcessingStatus.Completed,
                Quality = VideoQuality.HD1080,
                FileSize = 1024 * 1024 * 50 // 50MB
            };

            return Ok(video);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to get video {VideoId}", id);
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpPost("upload")]
    public async Task<ActionResult<VideoUploadResponse>> UploadVideo(IFormFile file, [FromForm] VideoUploadRequest request)
    {
        try
        {
            if (file == null || file.Length == 0)
            {
                return BadRequest("No file provided");
            }

            if (!await _videoProcessingService.ValidateVideoFileAsync(file.FileName))
            {
                return BadRequest("Invalid video file format");
            }

            var uploadDirectory = Path.Combine("uploads", "videos");
            Directory.CreateDirectory(uploadDirectory);

            var fileName = $"{Guid.NewGuid()}_{file.FileName}";
            var filePath = Path.Combine(uploadDirectory, fileName);

            using (var stream = new FileStream(filePath, FileMode.Create))
            {
                await file.CopyToAsync(stream);
            }

            var duration = await _videoProcessingService.GetVideoDurationAsync(filePath);
            var metadata = await _videoProcessingService.ExtractMetadataAsync(filePath);

            var video = new Video
            {
                Title = request.Title,
                Description = request.Description ?? string.Empty,
                FileName = fileName,
                FilePath = filePath,
                FileSizeBytes = file.Length,
                Duration = duration,
                VideoFormat = Path.GetExtension(file.FileName),
                Quality = VideoQuality.HD1080,
                ProcessingStatus = VideoProcessingStatus.Queued,
                UploadedAt = DateTime.UtcNow,
                UploadedByUserId = 1, // TODO: Get from authenticated user
                ViewCount = 0,
                Metadata = metadata.ToList()
            };

            // Start background processing
            _ = Task.Run(async () =>
            {
                await _videoProcessingService.ProcessVideoAsync(video.Id, VideoProcessingType.ThumbnailGeneration);
            });

            var response = new VideoUploadResponse
            {
                VideoId = video.Id,
                FileName = fileName,
                FileSize = file.Length,
                Duration = duration,
                ProcessingStatus = VideoProcessingStatus.Queued
            };

            _logger.LogInformation("Video uploaded successfully: {FileName}", fileName);

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to upload video");
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpGet("{id}/stream")]
    [AllowAnonymous]
    public async Task<IActionResult> StreamVideo(int id)
    {
        try
        {
            await Task.CompletedTask;

            var videoPath = Path.Combine("uploads", "videos", $"sample_video_{id}.mp4");

            if (!System.IO.File.Exists(videoPath))
            {
                return NotFound("Video not found");
            }

            var stream = new FileStream(videoPath, FileMode.Open, FileAccess.Read, FileShare.Read);
            var contentType = "video/mp4";

            return File(stream, contentType, enableRangeProcessing: true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to stream video {VideoId}", id);
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpPost("{id}/process")]
    public async Task<ActionResult<VideoProcessingJob>> ProcessVideo(int id, [FromBody] VideoProcessRequest request)
    {
        try
        {
            var job = await _videoProcessingService.ProcessVideoAsync(id, request.ProcessingType);
            return Ok(job);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to start video processing for video {VideoId}", id);
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpGet("{id}/thumbnails")]
    public async Task<ActionResult<VideoThumbnail[]>> GetVideoThumbnails(int id)
    {
        try
        {
            await Task.CompletedTask;

            var thumbnails = new[]
            {
                new VideoThumbnail
                {
                    Id = 1,
                    VideoId = id,
                    FilePath = $"/api/thumbnails/{id}_1.jpg",
                    TimestampPosition = TimeSpan.FromSeconds(30),
                    Width = 1280,
                    Height = 720,
                    IsDefault = true
                }
            };

            return Ok(thumbnails);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to get thumbnails for video {VideoId}", id);
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteVideo(int id)
    {
        try
        {
            await Task.CompletedTask;

            _logger.LogInformation("Video {VideoId} deleted", id);
            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to delete video {VideoId}", id);
            return StatusCode(500, "Internal server error");
        }
    }
}

// DTOs
public class VideoDto
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public TimeSpan Duration { get; set; }
    public string ThumbnailUrl { get; set; } = string.Empty;
    public int ViewCount { get; set; }
    public DateTime UploadedAt { get; set; }
}

public class VideoDetailsDto : VideoDto
{
    public string VideoUrl { get; set; } = string.Empty;
    public VideoProcessingStatus ProcessingStatus { get; set; }
    public VideoQuality Quality { get; set; }
    public long FileSize { get; set; }
}

public class VideoListResponse
{
    public List<VideoDto> Videos { get; set; } = new();
    public int TotalCount { get; set; }
    public int Page { get; set; }
    public int PageSize { get; set; }
}

public class VideoUploadRequest
{
    [Required]
    [MaxLength(200)]
    public string Title { get; set; } = string.Empty;

    [MaxLength(1000)]
    public string? Description { get; set; }
}

public class VideoUploadResponse
{
    public int VideoId { get; set; }
    public string FileName { get; set; } = string.Empty;
    public long FileSize { get; set; }
    public TimeSpan Duration { get; set; }
    public VideoProcessingStatus ProcessingStatus { get; set; }
}

public class VideoProcessRequest
{
    public VideoProcessingType ProcessingType { get; set; }
}