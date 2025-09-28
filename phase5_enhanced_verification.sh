#!/bin/bash
set -e
set -u

# Enhanced Phase 5 Backend Services Verification
LOG_FILE="logs/phase5_enhanced_verify_$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="logs/PHASE5_ENHANCED_BACKEND_VERIFICATION_$(date +%Y%m%d_%H%M%S).md"

mkdir -p logs
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE")

echo "=== [$(date)] ENHANCED PHASE 5 BACKEND VERIFICATION START ===" | tee -a "$LOG_FILE"

# Configuration
SUDO_PASS="SS1-Temp1234"

sudo_cmd() {
    echo "$SUDO_PASS" | sudo -S "$@" 2>/dev/null || sudo "$@"
}

# Navigate to project directory
cd /home/mpasqui/Kubernetes/InsightLearn.Cloud
echo "WORKING_DIRECTORY: $(pwd)" | tee -a "$LOG_FILE"

# Initialize report
cat > "$REPORT_FILE" << EOF
# InsightLearn.Cloud - Enhanced Phase 5 Backend Services Verification

## 📅 Informazioni Generali
- **Data Verifica**: $(date '+%Y-%m-%d %H:%M:%S')
- **Fase**: Backend Services e API - Deep Analysis
- **Directory**: $(pwd)
- **Sistema**: Ubuntu con .NET 8.0.414

## 📊 Analisi Dettagliata Backend Services

EOF

echo "Starting enhanced backend services verification..." | tee -a "$LOG_FILE"

# 1. DEEP API PROJECT ANALYSIS
echo "=== STEP 1: Deep API Project Analysis ===" | tee -a "$LOG_FILE"
echo "### 1. API Project Deep Analysis" >> "$REPORT_FILE"

# Check actual API project structure with correct nested path
API_PROJECT_PATH="src/InsightLearn.Api/InsightLearn.Api"

if [ -d "$API_PROJECT_PATH" ]; then
    echo "✅ **API Project Found**: $API_PROJECT_PATH" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"

    # Count and list controllers
    echo "#### Controllers Inventory:" >> "$REPORT_FILE"
    controller_count=$(find "$API_PROJECT_PATH/Controllers" -name "*.cs" 2>/dev/null | wc -l)
    echo "- **Total Controllers**: $controller_count" >> "$REPORT_FILE"

    if [ -d "$API_PROJECT_PATH/Controllers" ]; then
        for controller in "$API_PROJECT_PATH/Controllers"/*.cs; do
            if [ -f "$controller" ]; then
                filename=$(basename "$controller")
                lines=$(wc -l < "$controller")
                methods=$(grep -c "\[Http" "$controller" 2>/dev/null || echo "0")
                echo "  - $filename: $lines lines, $methods HTTP endpoints" >> "$REPORT_FILE"
            fi
        done
    fi

    echo "" >> "$REPORT_FILE"
else
    echo "❌ **API Project Not Found**" >> "$REPORT_FILE"
fi

# 2. ANALYZE NuGet PACKAGES
echo "=== STEP 2: NuGet Packages Analysis ===" | tee -a "$LOG_FILE"
echo "### 2. Package Dependencies Analysis" >> "$REPORT_FILE"

if [ -f "$API_PROJECT_PATH/InsightLearn.Api.csproj" ]; then
    echo "#### Installed Packages:" >> "$REPORT_FILE"
    grep "PackageReference" "$API_PROJECT_PATH/InsightLearn.Api.csproj" | while read -r line; do
        package=$(echo "$line" | sed -n 's/.*Include="\([^"]*\).*/\1/p')
        version=$(echo "$line" | sed -n 's/.*Version="\([^"]*\).*/\1/p')
        if [ ! -z "$package" ]; then
            echo "- **$package**: v$version" >> "$REPORT_FILE"
        fi
    done
fi

echo "" >> "$REPORT_FILE"

# 3. CHECK MIDDLEWARE CONFIGURATION
echo "=== STEP 3: Middleware Configuration Check ===" | tee -a "$LOG_FILE"
echo "### 3. Middleware Pipeline Configuration" >> "$REPORT_FILE"

if [ -f "$API_PROJECT_PATH/Program.cs" ]; then
    echo "#### Program.cs Middleware Analysis:" >> "$REPORT_FILE"

    # Check specific middleware
    declare -a MIDDLEWARE_CHECKS=(
        "AddControllers:Controller Services"
        "AddSwaggerGen:Swagger Documentation"
        "AddEndpointsApiExplorer:API Explorer"
        "UseHttpsRedirection:HTTPS Redirection"
        "UseAuthorization:Authorization"
        "UseSwagger:Swagger UI"
        "UseSwaggerUI:Swagger Interface"
        "MapControllers:Controller Mapping"
        "AddAuthentication:Authentication Services"
        "AddCors:CORS Policy"
    )

    for check in "${MIDDLEWARE_CHECKS[@]}"; do
        IFS=':' read -ra PARTS <<< "$check"
        pattern="${PARTS[0]}"
        description="${PARTS[1]}"

        if grep -q "$pattern" "$API_PROJECT_PATH/Program.cs"; then
            echo "- ✅ **$description**: Configured" >> "$REPORT_FILE"
        else
            echo "- ❌ **$description**: Not configured" >> "$REPORT_FILE"
        fi
    done
fi

echo "" >> "$REPORT_FILE"

# 4. BUILD AND RUN TEST
echo "=== STEP 4: Build and Runtime Test ===" | tee -a "$LOG_FILE"
echo "### 4. Build and Runtime Verification" >> "$REPORT_FILE"

cd "$API_PROJECT_PATH"

# Clean and build
echo "#### Build Test:" >> "$REPORT_FILE"
if timeout 60s dotnet build --configuration Release --verbosity quiet > /tmp/build_output.log 2>&1; then
    echo "- ✅ **Build Status**: SUCCESS" >> "$REPORT_FILE"

    # Try to run the API briefly
    echo "#### Runtime Test:" >> "$REPORT_FILE"
    timeout 10s dotnet run --configuration Release --urls=http://localhost:5095 > /tmp/run_output.log 2>&1 &
    RUN_PID=$!

    sleep 5

    # Test if API responds
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:5095/WeatherForecast 2>/dev/null | grep -q "200\|404\|401"; then
        echo "- ✅ **API Runtime**: Responding to requests" >> "$REPORT_FILE"
    else
        echo "- ⚠️  **API Runtime**: Not responding (may need more setup)" >> "$REPORT_FILE"
    fi

    # Kill the test process
    kill $RUN_PID 2>/dev/null || true
    sudo_cmd pkill -f "dotnet.*InsightLearn" 2>/dev/null || true
else
    echo "- ❌ **Build Status**: FAILED" >> "$REPORT_FILE"
    echo "Build errors:" >> "$REPORT_FILE"
    tail -20 /tmp/build_output.log | sed 's/^/  /' >> "$REPORT_FILE"
fi

cd ../../..

echo "" >> "$REPORT_FILE"

# 5. CHECK ENTITY FRAMEWORK AND DATABASE
echo "=== STEP 5: Entity Framework and Database Check ===" | tee -a "$LOG_FILE"
echo "### 5. Database Layer Analysis" >> "$REPORT_FILE"

# Check for DbContext files
echo "#### DbContext Search:" >> "$REPORT_FILE"
dbcontext_files=$(find src/ -name "*DbContext.cs" -o -name "*Context.cs" 2>/dev/null | wc -l)
echo "- **DbContext Files Found**: $dbcontext_files" >> "$REPORT_FILE"

# Check for Entity models
echo "#### Entity Models:" >> "$REPORT_FILE"
if [ -d "src/InsightLearn.Core" ]; then
    entity_count=$(find src/InsightLearn.Core -name "*.cs" -exec grep -l "public class\|public interface" {} \; 2>/dev/null | wc -l)
    echo "- **Core Domain Models**: $entity_count files" >> "$REPORT_FILE"
fi

# Check for migrations
echo "#### Database Migrations:" >> "$REPORT_FILE"
migration_count=$(find src/ -path "*/Migrations/*.cs" 2>/dev/null | wc -l)
echo "- **Migration Files**: $migration_count" >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"

# 6. SERVICE LAYER ANALYSIS
echo "=== STEP 6: Service Layer Analysis ===" | tee -a "$LOG_FILE"
echo "### 6. Service Layer Implementation" >> "$REPORT_FILE"

# Check Core services (interfaces)
echo "#### Service Interfaces (Core):" >> "$REPORT_FILE"
if [ -d "src/InsightLearn.Core" ]; then
    find src/InsightLearn.Core -name "I*.cs" 2>/dev/null | while read -r interface; do
        filename=$(basename "$interface")
        echo "- Interface: $filename" >> "$REPORT_FILE"
    done
fi

# Check Infrastructure services (implementations)
echo "#### Service Implementations (Infrastructure):" >> "$REPORT_FILE"
if [ -d "src/InsightLearn.Infrastructure" ]; then
    service_count=$(find src/InsightLearn.Infrastructure -name "*Service.cs" 2>/dev/null | wc -l)
    echo "- **Service Implementations**: $service_count files" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"

# 7. AI INTEGRATION STATUS
echo "=== STEP 7: AI Integration Status ===" | tee -a "$LOG_FILE"
echo "### 7. AI Integration Analysis" >> "$REPORT_FILE"

if [ -d "src/InsightLearn.AI" ]; then
    echo "#### AI Project Structure:" >> "$REPORT_FILE"

    # List all AI components
    find src/InsightLearn.AI -name "*.cs" | while read -r ai_file; do
        rel_path=$(echo "$ai_file" | sed 's|src/InsightLearn.AI/||')
        lines=$(wc -l < "$ai_file")
        echo "- $rel_path: $lines lines" >> "$REPORT_FILE"
    done

    # Check for Ollama integration
    if find src/InsightLearn.AI -name "*.cs" -exec grep -l "Ollama" {} \; 2>/dev/null | grep -q .; then
        echo "- ✅ **Ollama Integration**: References found" >> "$REPORT_FILE"
    else
        echo "- ❌ **Ollama Integration**: No references found" >> "$REPORT_FILE"
    fi
fi

echo "" >> "$REPORT_FILE"

# 8. CACHING AND PERFORMANCE
echo "=== STEP 8: Caching and Performance Features ===" | tee -a "$LOG_FILE"
echo "### 8. Performance Features" >> "$REPORT_FILE"

# Check for Redis references
redis_refs=$(find src/ -name "*.cs" -exec grep -l "Redis\|IDistributedCache" {} \; 2>/dev/null | wc -l)
echo "- **Redis/Distributed Cache References**: $redis_refs files" >> "$REPORT_FILE"

# Check for memory cache
memory_cache_refs=$(find src/ -name "*.cs" -exec grep -l "IMemoryCache\|MemoryCache" {} \; 2>/dev/null | wc -l)
echo "- **Memory Cache References**: $memory_cache_refs files" >> "$REPORT_FILE"

# Check for async patterns
async_methods=$(find src/ -name "*.cs" -exec grep -c "async Task\|async ValueTask" {} \; 2>/dev/null | awk '{sum+=$1} END {print sum}')
echo "- **Async Methods**: $async_methods found" >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"

# 9. SECURITY FEATURES
echo "=== STEP 9: Security Features Analysis ===" | tee -a "$LOG_FILE"
echo "### 9. Security Implementation" >> "$REPORT_FILE"

# Check for authentication attributes
auth_attributes=$(find src/ -name "*.cs" -exec grep -c "\[Authorize\]\|\[AllowAnonymous\]" {} \; 2>/dev/null | awk '{sum+=$1} END {print sum}')
echo "- **Authorization Attributes**: $auth_attributes uses" >> "$REPORT_FILE"

# Check for data validation
validation_attrs=$(find src/ -name "*.cs" -exec grep -c "\[Required\]\|\[StringLength\]\|\[Range\]" {} \; 2>/dev/null | awk '{sum+=$1} END {print sum}')
echo "- **Validation Attributes**: $validation_attrs uses" >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"

# 10. FINAL SCORING AND RECOMMENDATIONS
echo "=== STEP 10: Final Analysis and Scoring ===" | tee -a "$LOG_FILE"
echo "## 📊 Final Analysis Summary" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Calculate implementation scores
TOTAL_SCORE=0
MAX_SCORE=100

# Score API structure (20 points)
if [ $controller_count -ge 5 ]; then
    API_SCORE=20
elif [ $controller_count -ge 2 ]; then
    API_SCORE=10
else
    API_SCORE=5
fi
TOTAL_SCORE=$((TOTAL_SCORE + API_SCORE))

# Score middleware (20 points)
MIDDLEWARE_COUNT=$(grep -c "✅" "$REPORT_FILE" | head -1)
MIDDLEWARE_SCORE=$((MIDDLEWARE_COUNT * 2))
[ $MIDDLEWARE_SCORE -gt 20 ] && MIDDLEWARE_SCORE=20
TOTAL_SCORE=$((TOTAL_SCORE + MIDDLEWARE_SCORE))

# Score database (20 points)
if [ $dbcontext_files -gt 0 ] && [ $migration_count -gt 0 ]; then
    DB_SCORE=20
elif [ $dbcontext_files -gt 0 ] || [ $entity_count -gt 5 ]; then
    DB_SCORE=10
else
    DB_SCORE=5
fi
TOTAL_SCORE=$((TOTAL_SCORE + DB_SCORE))

# Score services (20 points)
if [ $service_count -ge 3 ]; then
    SERVICE_SCORE=20
elif [ $service_count -ge 1 ]; then
    SERVICE_SCORE=10
else
    SERVICE_SCORE=5
fi
TOTAL_SCORE=$((TOTAL_SCORE + SERVICE_SCORE))

# Score performance (10 points)
if [ $redis_refs -gt 0 ] || [ $memory_cache_refs -gt 0 ]; then
    PERF_SCORE=10
else
    PERF_SCORE=5
fi
TOTAL_SCORE=$((TOTAL_SCORE + PERF_SCORE))

# Score security (10 points)
if [ $auth_attributes -gt 0 ] && [ $validation_attrs -gt 0 ]; then
    SEC_SCORE=10
elif [ $auth_attributes -gt 0 ] || [ $validation_attrs -gt 0 ]; then
    SEC_SCORE=5
else
    SEC_SCORE=2
fi
TOTAL_SCORE=$((TOTAL_SCORE + SEC_SCORE))

echo "### Implementation Scores" >> "$REPORT_FILE"
echo "- **API Structure**: $API_SCORE/20" >> "$REPORT_FILE"
echo "- **Middleware Pipeline**: $MIDDLEWARE_SCORE/20" >> "$REPORT_FILE"
echo "- **Database Layer**: $DB_SCORE/20" >> "$REPORT_FILE"
echo "- **Service Layer**: $SERVICE_SCORE/20" >> "$REPORT_FILE"
echo "- **Performance Features**: $PERF_SCORE/10" >> "$REPORT_FILE"
echo "- **Security Features**: $SEC_SCORE/10" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "### **TOTAL SCORE: $TOTAL_SCORE/100**" >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"
echo "## 🎯 Verdict and Recommendations" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ $TOTAL_SCORE -ge 80 ]; then
    echo "### ✅ FASE 5: EXCELLENTLY IMPLEMENTED" >> "$REPORT_FILE"
    echo "Backend services are well-structured and ready for production development." >> "$REPORT_FILE"
elif [ $TOTAL_SCORE -ge 60 ]; then
    echo "### ⚠️ FASE 5: GOOD FOUNDATION" >> "$REPORT_FILE"
    echo "Backend services have a solid foundation but need more implementation." >> "$REPORT_FILE"
elif [ $TOTAL_SCORE -ge 40 ]; then
    echo "### 🟡 FASE 5: BASIC STRUCTURE" >> "$REPORT_FILE"
    echo "Basic structure is in place but significant implementation is required." >> "$REPORT_FILE"
else
    echo "### ❌ FASE 5: REQUIRES SIGNIFICANT WORK" >> "$REPORT_FILE"
    echo "Backend services need substantial development effort." >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"
echo "### 🚀 Priority Actions" >> "$REPORT_FILE"

if [ $controller_count -lt 5 ]; then
    echo "1. **Implement Business Controllers**: Add Course, User, Enrollment controllers" >> "$REPORT_FILE"
fi

if [ $dbcontext_files -eq 0 ]; then
    echo "2. **Configure Entity Framework**: Create DbContext and entity models" >> "$REPORT_FILE"
fi

if [ $service_count -lt 3 ]; then
    echo "3. **Develop Service Layer**: Implement business logic services" >> "$REPORT_FILE"
fi

if [ $auth_attributes -eq 0 ]; then
    echo "4. **Add Security**: Implement authentication and authorization" >> "$REPORT_FILE"
fi

if [ $redis_refs -eq 0 ] && [ $memory_cache_refs -eq 0 ]; then
    echo "5. **Add Caching**: Implement caching for performance" >> "$REPORT_FILE"
fi

# Final output
echo "" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "ENHANCED PHASE 5 VERIFICATION COMPLETED" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "Total Score: $TOTAL_SCORE/100" | tee -a "$LOG_FILE"
echo "Report saved: $REPORT_FILE" | tee -a "$LOG_FILE"
echo "Log saved: $LOG_FILE" | tee -a "$LOG_FILE"

exit 0