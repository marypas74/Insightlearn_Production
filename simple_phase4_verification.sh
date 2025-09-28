#!/bin/bash

echo "=== Phase 4 Authentication Verification (Simplified) ==="
echo "Date: $(date)"

# Change to project directory
cd /home/mpasqui/Kubernetes/InsightLearn.Cloud

# Check if we can find authentication-related files
echo ""
echo "=== Checking Authentication Components ==="

# Check Program.cs for JWT configuration
echo "Checking Program.cs for JWT configuration:"
if [ -f "src/InsightLearn.Web/Program.cs" ]; then
    echo "✓ Program.cs found"
    if grep -q "AddAuthentication\|AddJwtBearer\|UseAuthentication" "src/InsightLearn.Web/Program.cs"; then
        echo "✓ Authentication middleware found in Program.cs"
    else
        echo "✗ No authentication middleware found in Program.cs"
    fi
else
    echo "✗ Program.cs not found"
fi

# Check appsettings for JWT configuration
echo ""
echo "Checking configuration files for JWT settings:"
for config in "src/InsightLearn.Web/appsettings.json" "src/InsightLearn.Web/appsettings.Development.json"; do
    if [ -f "$config" ]; then
        echo "✓ $config found"
        if grep -qi "jwt\|token\|secret" "$config"; then
            echo "  - JWT/Token configuration detected"
        fi
    fi
done

# Look for authentication controllers and services
echo ""
echo "Checking for Authentication Controllers and Services:"
find src/ -name "*Auth*.cs" -o -name "*Account*.cs" -o -name "*Login*.cs" -o -name "*Jwt*.cs" -o -name "*User*.cs" | while read file; do
    if [ -f "$file" ]; then
        lines=$(wc -l < "$file")
        echo "✓ $file ($lines lines)"
    fi
done

# Try a simple build test
echo ""
echo "=== Testing Basic Build ==="
echo "Testing dotnet restore..."
cd src/InsightLearn.Web
if timeout 60s dotnet restore --verbosity quiet 2>/dev/null; then
    echo "✓ Package restore successful"

    echo "Testing dotnet build..."
    if timeout 120s dotnet build --no-restore --verbosity quiet 2>/dev/null; then
        echo "✅ Build successful - Authentication components appear to be working"
    else
        echo "⚠️ Build failed - May indicate authentication implementation issues"
    fi
else
    echo "⚠️ Package restore failed - May indicate missing authentication packages"
fi

echo ""
echo "=== Phase 4 Verification Complete ==="