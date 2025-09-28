#!/bin/bash

echo "=== Phase 6 Advanced Features Verification (Simplified) ==="
echo "Date: $(date)"

# Change to project directory
cd /home/mpasqui/Kubernetes/InsightLearn.Cloud

echo ""
echo "=== Checking Advanced Features Implementation ==="

# Check FFmpeg availability
echo "1. Video Processing Infrastructure:"
if command -v ffmpeg >/dev/null 2>&1; then
    echo "✓ FFmpeg: AVAILABLE"
    ffmpeg -version | head -1 | sed 's/^/  /'
else
    echo "✗ FFmpeg: NOT INSTALLED"
fi

# Check video processing components
echo ""
echo "2. Video Processing Components:"
declare -a VIDEO_COMPONENTS=(
    "Components/Video/VideoPlayer.razor"
    "Services/VideoProcessingService.cs"
    "Services/ThumbnailService.cs"
    "Models/VideoModels.cs"
    "Controllers/VideoController.cs"
)

video_components_found=0
for component in "${VIDEO_COMPONENTS[@]}"; do
    found=false
    for base_path in "src/InsightLearn.Web" "src/InsightLearn.Api" "src/InsightLearn.Core"; do
        if [ -f "$base_path/$component" ]; then
            lines=$(wc -l < "$base_path/$component")
            echo "✓ $(basename $component): $lines lines"
            ((video_components_found++))
            found=true
            break
        fi
    done

    if [ "$found" = "false" ]; then
        echo "✗ $(basename $component): NOT FOUND"
    fi
done

echo "  Video Components Score: $video_components_found/5"

echo ""
echo "3. Real-time Features (SignalR):"
signalr_score=0

# Check SignalR files
SIGNALR_FILES=(
    "src/InsightLearn.Web/Hubs/ChatHub.cs"
    "src/InsightLearn.Web/Hubs/NotificationHub.cs"
    "src/InsightLearn.Web/Services/NotificationService.cs"
)

for signalr_file in "${SIGNALR_FILES[@]}"; do
    if [ -f "$signalr_file" ]; then
        lines=$(wc -l < "$signalr_file")
        echo "✓ $(basename $signalr_file): $lines lines"
        ((signalr_score++))
    else
        echo "✗ $(basename $signalr_file): NOT FOUND"
    fi
done

# Check SignalR in Program.cs
web_program_file="src/InsightLearn.Web/InsightLearn.Web/Program.cs"
if [ -f "$web_program_file" ]; then
    if grep -q "AddSignalR\|MapHub" "$web_program_file"; then
        echo "✓ SignalR Configuration: FOUND in Program.cs"
        ((signalr_score++))
    else
        echo "✗ SignalR Configuration: NOT FOUND in Program.cs"
    fi
else
    echo "✗ Program.cs: NOT FOUND in Web project"
fi

echo "  SignalR Score: $signalr_score/4"

echo ""
echo "4. PWA (Progressive Web App) Features:"
pwa_score=0

# Check PWA files
PWA_FILES=(
    "src/InsightLearn.Web/wwwroot/sw.js"
    "src/InsightLearn.Web/wwwroot/manifest.json"
    "src/InsightLearn.Web/wwwroot/icon-192.png"
    "src/InsightLearn.Web/wwwroot/icon-512.png"
)

# First check if wwwroot exists
if [ -d "src/InsightLearn.Web/wwwroot" ]; then
    echo "✓ wwwroot directory: EXISTS"

    for pwa_file in "${PWA_FILES[@]}"; do
        if [ -f "$pwa_file" ]; then
            size=$(stat -c%s "$pwa_file")
            echo "✓ $(basename $pwa_file): ${size} bytes"
            if [ $size -gt 100 ]; then
                ((pwa_score++))
            fi
        else
            echo "✗ $(basename $pwa_file): NOT FOUND"
        fi
    done
else
    echo "✗ wwwroot directory: NOT FOUND"
fi

echo "  PWA Score: $pwa_score/4"

echo ""
echo "5. Performance Features:"
perf_score=0

# Check for lazy loading implementations
lazy_loading=$(find src/ -name "*.razor" -o -name "*.cs" | xargs grep -c "lazy\|Lazy\|@lazy" 2>/dev/null | awk '{sum += $1} END {print sum+0}')
if [ "$lazy_loading" -gt 0 ]; then
    echo "✓ Lazy Loading: $lazy_loading implementations found"
    ((perf_score++))
else
    echo "✗ Lazy Loading: NOT FOUND"
fi

# Check for async patterns
async_patterns=$(find src/ -name "*.cs" | xargs grep -c "async Task\|await " 2>/dev/null | awk '{sum += $1} END {print sum+0}')
if [ "$async_patterns" -gt 10 ]; then
    echo "✓ Async Patterns: $async_patterns implementations"
    ((perf_score++))
else
    echo "✗ Async Patterns: $async_patterns found (need >10)"
fi

# Check for caching
caching_impl=$(find src/ -name "*.cs" | xargs grep -c "IMemoryCache\|IDistributedCache\|Cache" 2>/dev/null | awk '{sum += $1} END {print sum+0}')
if [ "$caching_impl" -gt 0 ]; then
    echo "✓ Caching: $caching_impl implementations found"
    ((perf_score++))
else
    echo "✗ Caching: NOT IMPLEMENTED"
fi

echo "  Performance Score: $perf_score/3"

echo ""
echo "6. Advanced UI Features:"
ui_score=0

# Check for advanced UI patterns
UI_PATTERNS=(
    "animation\|Animation\|transition\|Transition"
    "modal\|Modal\|dialog\|Dialog"
    "toast\|Toast\|notification\|Notification"
)

for pattern in "${UI_PATTERNS[@]}"; do
    pattern_count=$(find src/InsightLearn.Web -name "*.razor" -o -name "*.cs" | xargs grep -c "$pattern" 2>/dev/null | awk '{sum += $1} END {print sum+0}')
    if [ "$pattern_count" -gt 1 ]; then
        echo "✓ UI Pattern ($pattern): $pattern_count found"
        ((ui_score++))
    else
        echo "✗ UI Pattern ($pattern): $pattern_count found (need >1)"
    fi
done

echo "  Advanced UI Score: $ui_score/3"

echo ""
echo "=== Build Test ==="
echo "Testing Web project build..."
cd src/InsightLearn.Web/InsightLearn.Web
if timeout 60s dotnet build --verbosity quiet 2>/dev/null; then
    echo "✅ Web Build: SUCCESS"
else
    echo "⚠️ Web Build: FAILED or TIMEOUT"
fi

cd ../../..

echo ""
echo "=== Final Scoring ==="
total_score=$((video_components_found + signalr_score + pwa_score + perf_score + ui_score))
max_score=19

echo "Video Processing: $video_components_found/5"
echo "Real-time (SignalR): $signalr_score/4"
echo "PWA Features: $pwa_score/4"
echo "Performance: $perf_score/3"
echo "Advanced UI: $ui_score/3"
echo ""
echo "TOTAL SCORE: $total_score/$max_score"

percentage=$((total_score * 100 / max_score))
echo "PERCENTAGE: $percentage%"

echo ""
if [ $percentage -ge 75 ]; then
    echo "🎉 Phase 6 Status: EXCELLENT IMPLEMENTATION"
elif [ $percentage -ge 50 ]; then
    echo "⚠️  Phase 6 Status: GOOD FOUNDATION"
elif [ $percentage -ge 25 ]; then
    echo "🟡 Phase 6 Status: BASIC STRUCTURE"
else
    echo "❌ Phase 6 Status: SIGNIFICANT WORK NEEDED"
fi

echo ""
echo "=== Phase 6 Advanced Features Verification Complete ==="