using System.Diagnostics;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using InsightLearn.Core.Models;

namespace InsightLearn.Infrastructure.Services;

public interface IVideoProcessingService
{
    Task<VideoMetadata[]> ExtractMetadataAsync(string filePath);
    Task<string> GenerateThumbnailAsync(string videoPath, TimeSpan timestamp, string outputPath);
    Task<bool> ConvertVideoAsync(string inputPath, string outputPath, VideoQuality targetQuality);
    Task<TimeSpan> GetVideoDurationAsync(string filePath);
    Task<bool> ValidateVideoFileAsync(string filePath);
    Task<VideoProcessingJob> ProcessVideoAsync(int videoId, VideoProcessingType processingType);
}

public class VideoProcessingService : IVideoProcessingService
{
    private readonly ILogger<VideoProcessingService> _logger;
    private const string FFmpegPath = "ffmpeg";
    private const string FFprobePath = "ffprobe";

    public VideoProcessingService(ILogger<VideoProcessingService> logger)
    {
        _logger = logger;
    }

    public async Task<VideoMetadata[]> ExtractMetadataAsync(string filePath)
    {
        try
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = FFprobePath,
                Arguments = $"-v quiet -print_format json -show_format -show_streams \"{filePath}\"",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };

            using var process = Process.Start(startInfo);
            if (process == null)
            {
                throw new InvalidOperationException("Failed to start FFprobe process");
            }

            var output = await process.StandardOutput.ReadToEndAsync();
            await process.WaitForExitAsync();

            if (process.ExitCode != 0)
            {
                var error = await process.StandardError.ReadToEndAsync();
                throw new Exception($"FFprobe failed: {error}");
            }

            var metadata = new List<VideoMetadata>();
            using var document = JsonDocument.Parse(output);

            if (document.RootElement.TryGetProperty("format", out var format))
            {
                if (format.TryGetProperty("duration", out var duration))
                {
                    metadata.Add(new VideoMetadata { Key = "duration", Value = duration.GetString() ?? "" });
                }

                if (format.TryGetProperty("size", out var size))
                {
                    metadata.Add(new VideoMetadata { Key = "file_size", Value = size.GetString() ?? "" });
                }

                if (format.TryGetProperty("bit_rate", out var bitRate))
                {
                    metadata.Add(new VideoMetadata { Key = "bit_rate", Value = bitRate.GetString() ?? "" });
                }
            }

            if (document.RootElement.TryGetProperty("streams", out var streams))
            {
                foreach (var stream in streams.EnumerateArray())
                {
                    if (stream.TryGetProperty("codec_type", out var codecType) &&
                        codecType.GetString() == "video")
                    {
                        if (stream.TryGetProperty("width", out var width))
                        {
                            metadata.Add(new VideoMetadata { Key = "width", Value = width.GetInt32().ToString() });
                        }

                        if (stream.TryGetProperty("height", out var height))
                        {
                            metadata.Add(new VideoMetadata { Key = "height", Value = height.GetInt32().ToString() });
                        }

                        if (stream.TryGetProperty("codec_name", out var codecName))
                        {
                            metadata.Add(new VideoMetadata { Key = "video_codec", Value = codecName.GetString() ?? "" });
                        }

                        break;
                    }
                }
            }

            return metadata.ToArray();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to extract metadata from video: {FilePath}", filePath);
            throw;
        }
    }

    public async Task<string> GenerateThumbnailAsync(string videoPath, TimeSpan timestamp, string outputPath)
    {
        try
        {
            var directory = Path.GetDirectoryName(outputPath);
            if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }

            var startInfo = new ProcessStartInfo
            {
                FileName = FFmpegPath,
                Arguments = $"-i \"{videoPath}\" -ss {timestamp:hh\\:mm\\:ss} -vframes 1 -q:v 2 \"{outputPath}\"",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };

            using var process = Process.Start(startInfo);
            if (process == null)
            {
                throw new InvalidOperationException("Failed to start FFmpeg process");
            }

            await process.WaitForExitAsync();

            if (process.ExitCode != 0)
            {
                var error = await process.StandardError.ReadToEndAsync();
                throw new Exception($"Thumbnail generation failed: {error}");
            }

            if (!File.Exists(outputPath))
            {
                throw new Exception("Thumbnail file was not created");
            }

            _logger.LogInformation("Thumbnail generated successfully: {OutputPath}", outputPath);
            return outputPath;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to generate thumbnail: {VideoPath} -> {OutputPath}", videoPath, outputPath);
            throw;
        }
    }

    public async Task<bool> ConvertVideoAsync(string inputPath, string outputPath, VideoQuality targetQuality)
    {
        try
        {
            var directory = Path.GetDirectoryName(outputPath);
            if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }

            var height = (int)targetQuality;
            var bitRate = GetBitRateForQuality(targetQuality);

            var startInfo = new ProcessStartInfo
            {
                FileName = FFmpegPath,
                Arguments = $"-i \"{inputPath}\" -c:v libx264 -preset medium -crf 23 -vf scale=-2:{height} -b:v {bitRate} -c:a aac -b:a 128k \"{outputPath}\"",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };

            using var process = Process.Start(startInfo);
            if (process == null)
            {
                throw new InvalidOperationException("Failed to start FFmpeg process");
            }

            await process.WaitForExitAsync();

            if (process.ExitCode != 0)
            {
                var error = await process.StandardError.ReadToEndAsync();
                _logger.LogError("Video conversion failed: {Error}", error);
                return false;
            }

            var success = File.Exists(outputPath);
            if (success)
            {
                _logger.LogInformation("Video converted successfully: {InputPath} -> {OutputPath}", inputPath, outputPath);
            }

            return success;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to convert video: {InputPath} -> {OutputPath}", inputPath, outputPath);
            return false;
        }
    }

    public async Task<TimeSpan> GetVideoDurationAsync(string filePath)
    {
        try
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = FFprobePath,
                Arguments = $"-v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 \"{filePath}\"",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };

            using var process = Process.Start(startInfo);
            if (process == null)
            {
                throw new InvalidOperationException("Failed to start FFprobe process");
            }

            var output = await process.StandardOutput.ReadToEndAsync();
            await process.WaitForExitAsync();

            if (process.ExitCode != 0)
            {
                var error = await process.StandardError.ReadToEndAsync();
                throw new Exception($"Failed to get video duration: {error}");
            }

            if (double.TryParse(output.Trim(), out var seconds))
            {
                return TimeSpan.FromSeconds(seconds);
            }

            throw new Exception($"Invalid duration format: {output}");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to get video duration: {FilePath}", filePath);
            throw;
        }
    }

    public async Task<bool> ValidateVideoFileAsync(string filePath)
    {
        try
        {
            if (!File.Exists(filePath))
            {
                return false;
            }

            var startInfo = new ProcessStartInfo
            {
                FileName = FFprobePath,
                Arguments = $"-v error -select_streams v:0 -show_entries stream=codec_type -of csv=p=0 \"{filePath}\"",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };

            using var process = Process.Start(startInfo);
            if (process == null)
            {
                return false;
            }

            var output = await process.StandardOutput.ReadToEndAsync();
            await process.WaitForExitAsync();

            return process.ExitCode == 0 && output.Trim() == "video";
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to validate video file: {FilePath}", filePath);
            return false;
        }
    }

    public async Task<VideoProcessingJob> ProcessVideoAsync(int videoId, VideoProcessingType processingType)
    {
        var job = new VideoProcessingJob
        {
            VideoId = videoId,
            ProcessingType = processingType,
            Status = VideoProcessingStatus.Queued,
            StartedAt = DateTime.UtcNow,
            Progress = 0
        };

        try
        {
            job.Status = VideoProcessingStatus.Processing;

            switch (processingType)
            {
                case VideoProcessingType.ThumbnailGeneration:
                    await Task.Delay(1000); // Simulate processing
                    job.Progress = 100;
                    break;
                case VideoProcessingType.Transcode:
                    await Task.Delay(3000); // Simulate processing
                    job.Progress = 100;
                    break;
                default:
                    await Task.Delay(500);
                    job.Progress = 100;
                    break;
            }

            job.Status = VideoProcessingStatus.Completed;
            job.CompletedAt = DateTime.UtcNow;

            _logger.LogInformation("Video processing completed: VideoId={VideoId}, Type={ProcessingType}",
                videoId, processingType);
        }
        catch (Exception ex)
        {
            job.Status = VideoProcessingStatus.Failed;
            job.ErrorMessage = ex.Message;
            job.CompletedAt = DateTime.UtcNow;

            _logger.LogError(ex, "Video processing failed: VideoId={VideoId}, Type={ProcessingType}",
                videoId, processingType);
        }

        return job;
    }

    private static string GetBitRateForQuality(VideoQuality quality)
    {
        return quality switch
        {
            VideoQuality.SD360 => "500k",
            VideoQuality.SD480 => "1000k",
            VideoQuality.HD720 => "2500k",
            VideoQuality.HD1080 => "5000k",
            VideoQuality.HD1440 => "8000k",
            VideoQuality.UHD2160 => "15000k",
            _ => "2500k"
        };
    }
}