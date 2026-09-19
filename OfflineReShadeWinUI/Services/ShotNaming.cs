using System.Text.Json;

namespace OfflineReShade.WinUI.Services;

/// <summary>
/// Builds the timestamped file name a ReShade Shot is saved under. The game name comes from
/// the metadata.json the ScreenshotManager plugin writes next to the exported color input.
/// </summary>
public static class ShotNaming
{
    public const string FallbackProductName = "OfflineReshade";

    public static string? TryReadProductName(string colorPath)
    {
        try
        {
            var dir = Path.GetDirectoryName(colorPath);
            if (string.IsNullOrWhiteSpace(dir))
                return null;

            var metadataPath = Path.Combine(dir, "metadata.json");
            if (!File.Exists(metadataPath))
                return null;

            using var document = JsonDocument.Parse(File.ReadAllText(metadataPath));
            if (!document.RootElement.TryGetProperty("productName", out var element))
                return null;

            var value = element.ValueKind == JsonValueKind.String ? element.GetString() : null;
            return string.IsNullOrWhiteSpace(value) ? null : value;
        }
        catch
        {
            return null;
        }
    }

    /// <summary>
    /// With a known game name the file gets a "-Reshaded" suffix so it cannot be confused with the
    /// game's own screenshots; the fallback name already says where the file came from.
    /// </summary>
    public static string BuildShotFileName(string? productName, DateTime now)
    {
        var timestamp = now.ToString("yyyy-MM-dd-HH-mm-ss");
        return string.IsNullOrWhiteSpace(productName)
            ? $"{FallbackProductName}-{timestamp}-Render.png"
            : $"{productName}-{timestamp}-Render-Reshaded.png";
    }

    /// <summary>
    /// Two shots within the same second would otherwise overwrite each other, so append -1, -2, ...
    /// </summary>
    public static string ResolveNonClashingPath(string target)
    {
        if (!File.Exists(target))
            return target;

        var dir = Path.GetDirectoryName(target) ?? string.Empty;
        var stem = Path.GetFileNameWithoutExtension(target);
        var extension = Path.GetExtension(target);

        for (var index = 1; index < 1000; index++)
        {
            var candidate = Path.Combine(dir, $"{stem}-{index}{extension}");
            if (!File.Exists(candidate))
                return candidate;
        }

        return target;
    }
}
