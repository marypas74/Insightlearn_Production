#!/bin/bash

echo "=== Phase 5 Backend Services Verification (Simplified) ==="
echo "Date: $(date)"

# Change to project directory
cd /home/mpasqui/Kubernetes/InsightLearn.Cloud

echo ""
echo "=== Checking Backend Services Structure ==="

# Check API project exists and can build
echo "1. API Project Structure:"
if [ -d "src/InsightLearn.Api" ]; then
    echo "✓ API project directory found"

    # Check Program.cs
    if [ -f "src/InsightLearn.Api/Program.cs" ]; then
        echo "✓ Program.cs found"

        # Check for key middleware
        if grep -q "AddControllers\|MapControllers" "src/InsightLearn.Api/Program.cs"; then
            echo "  - Controller middleware: CONFIGURED"
        fi

        if grep -q "AddSwaggerGen\|UseSwagger" "src/InsightLearn.Api/Program.cs"; then
            echo "  - Swagger middleware: CONFIGURED"
        fi

        if grep -q "UseHttpsRedirection" "src/InsightLearn.Api/Program.cs"; then
            echo "  - HTTPS redirection: CONFIGURED"
        fi
    else
        echo "✗ Program.cs not found"
    fi

    # Check Controllers
    echo ""
    echo "2. API Controllers:"
    if [ -d "src/InsightLearn.Api/Controllers" ]; then
        controller_count=$(find src/InsightLearn.Api/Controllers -name "*.cs" | wc -l)
        echo "✓ Controllers directory found with $controller_count controllers"

        find src/InsightLearn.Api/Controllers -name "*.cs" | while read controller; do
            lines=$(wc -l < "$controller")
            echo "  - $(basename "$controller"): $lines lines"
        done
    else
        echo "✗ Controllers directory not found"
    fi
else
    echo "✗ API project directory not found"
fi

echo ""
echo "3. Infrastructure and Core Projects:"

# Check Core project
if [ -d "src/InsightLearn.Core" ]; then
    echo "✓ Core project found"

    if [ -d "src/InsightLearn.Core/Entities" ]; then
        entity_count=$(find src/InsightLearn.Core/Entities -name "*.cs" 2>/dev/null | wc -l)
        echo "  - Entities: $entity_count files"
    fi

    if [ -d "src/InsightLearn.Core/Services" ]; then
        service_count=$(find src/InsightLearn.Core/Services -name "*.cs" 2>/dev/null | wc -l)
        echo "  - Service interfaces: $service_count files"
    fi
else
    echo "✗ Core project not found"
fi

# Check Infrastructure project
if [ -d "src/InsightLearn.Infrastructure" ]; then
    echo "✓ Infrastructure project found"

    if [ -d "src/InsightLearn.Infrastructure/Data" ]; then
        data_count=$(find src/InsightLearn.Infrastructure/Data -name "*.cs" 2>/dev/null | wc -l)
        echo "  - Data layer: $data_count files"
    fi

    if [ -d "src/InsightLearn.Infrastructure/Services" ]; then
        impl_count=$(find src/InsightLearn.Infrastructure/Services -name "*.cs" 2>/dev/null | wc -l)
        echo "  - Service implementations: $impl_count files"
    fi
else
    echo "✗ Infrastructure project not found"
fi

echo ""
echo "4. AI Integration:"
if [ -d "src/InsightLearn.AI" ]; then
    echo "✓ AI project found"
    ai_files=$(find src/InsightLearn.AI -name "*.cs" | wc -l)
    echo "  - AI components: $ai_files files"
else
    echo "✗ AI project not found"
fi

echo ""
echo "=== Build Test ==="
echo "Testing API project build..."
cd src/InsightLearn.Api
if timeout 60s dotnet build --verbosity quiet 2>/dev/null; then
    echo "✅ API Build: SUCCESS"
else
    echo "⚠️ API Build: FAILED or TIMEOUT"
fi

cd ../..

echo ""
echo "=== Phase 5 Backend Services Verification Complete ==="