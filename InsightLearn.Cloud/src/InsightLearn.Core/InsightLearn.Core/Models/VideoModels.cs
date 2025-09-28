using System;
using System.ComponentModel.DataAnnotations;

namespace InsightLearn.Core.Models;

public class Video
{
    public int Id { get; set; }

    [Required]
    [MaxLength(200)]
    public string Title { get; set; } = string.Empty;

    [MaxLength(1000)]
    public string Description { get; set; } = string.Empty;

    [Required]
    public string FileName { get; set; } = string.Empty;

    [Required]
    public string FilePath { get; set; } = string.Empty;

    public string? ThumbnailPath { get; set; }

    public long FileSizeBytes { get; set; }

    public TimeSpan Duration { get; set; }

    public string VideoFormat { get; set; } = string.Empty;

    public VideoQuality Quality { get; set; }

    public VideoProcessingStatus ProcessingStatus { get; set; }

    public DateTime UploadedAt { get; set; }

    public DateTime? ProcessedAt { get; set; }

    public int UploadedByUserId { get; set; }

    public int ViewCount { get; set; }

    public virtual ICollection<VideoMetadata> Metadata { get; set; } = new List<VideoMetadata>();
}

public class VideoMetadata
{
    public int Id { get; set; }

    public int VideoId { get; set; }

    [Required]
    public string Key { get; set; } = string.Empty;

    public string Value { get; set; } = string.Empty;

    public virtual Video Video { get; set; } = null!;
}

public class VideoProcessingJob
{
    public int Id { get; set; }

    public int VideoId { get; set; }

    public VideoProcessingType ProcessingType { get; set; }

    public VideoProcessingStatus Status { get; set; }

    public DateTime StartedAt { get; set; }

    public DateTime? CompletedAt { get; set; }

    public string? ErrorMessage { get; set; }

    public int Progress { get; set; }

    public virtual Video Video { get; set; } = null!;
}

public class VideoThumbnail
{
    public int Id { get; set; }

    public int VideoId { get; set; }

    public string FilePath { get; set; } = string.Empty;

    public TimeSpan TimestampPosition { get; set; }

    public int Width { get; set; }

    public int Height { get; set; }

    public bool IsDefault { get; set; }

    public virtual Video Video { get; set; } = null!;
}

public enum VideoQuality
{
    SD360 = 360,
    SD480 = 480,
    HD720 = 720,
    HD1080 = 1080,
    HD1440 = 1440,
    UHD2160 = 2160
}

public enum VideoProcessingStatus
{
    Uploading,
    Queued,
    Processing,
    Completed,
    Failed,
    Cancelled
}

public enum VideoProcessingType
{
    Transcode,
    ThumbnailGeneration,
    QualityConversion,
    Compression,
    MetadataExtraction
}