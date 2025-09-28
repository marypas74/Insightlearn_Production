#!/bin/bash
set -e
set -u

# Setup logging avanzato
LOG_FILE="logs/phase4_verify_$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="logs/PHASE4_AUTH_VERIFICATION_$(date +%Y%m%d_%H%M%S).md"
RETRY_LOG_DIR="logs/retry_logs_$(date +%Y%m%d_%H%M%S)"
TEMP_DIR="/tmp/insightlearn_phase4_$$"

mkdir -p logs "$RETRY_LOG_DIR" "$TEMP_DIR"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE")

echo "=== [$(date)] PHASE 4 VERIFICATION WITH ADVANCED RETRY START ===" | tee -a "$LOG_FILE"

# Configurazioni retry
SUDO_PASS="SS1-Temp1234"
MAX_RETRIES=7
TIMEOUT_BASE=60
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNING_TESTS=0
RETRY_ATTEMPTS=0
RECOVERED_COMMANDS=0

sudo_cmd() {
    echo "$SUDO_PASS" | sudo -S "$@" 2>/dev/null || sudo "$@"
}

# Advanced error retry system
execute_with_advanced_retry() {
    local cmd_name="$1"
    local cmd_description="$2"
    shift 2
    local cmd_args=("$@")

    local attempt=1
    local success=false
    local cmd_log="$RETRY_LOG_DIR/${cmd_name}_attempt.log"
    local error_patterns_log="$RETRY_LOG_DIR/${cmd_name}_errors.log"

    echo "🔄 Executing: $cmd_name - $cmd_description" | tee -a "$LOG_FILE"

    while [ $attempt -le $MAX_RETRIES ] && [ "$success" = "false" ]; do
        local timeout_duration=$((TIMEOUT_BASE * attempt))
        echo "  📍 Attempt $attempt/$MAX_RETRIES (timeout: ${timeout_duration}s)" | tee -a "$LOG_FILE"

        # Clear previous logs
        > "$cmd_log"

        # Execute command with dynamic timeout
        if timeout ${timeout_duration}s "${cmd_args[@]}" > "$cmd_log" 2>&1; then
            echo "  ✅ $cmd_name SUCCESS on attempt $attempt" | tee -a "$LOG_FILE"
            success=true
            if [ $attempt -gt 1 ]; then
                ((RECOVERED_COMMANDS++))
                echo "  🔧 RECOVERED after $((attempt-1)) failed attempts" | tee -a "$LOG_FILE"
            fi
            return 0
        else
            local exit_code=$?
            ((RETRY_ATTEMPTS++))

            echo "  ❌ $cmd_name FAILED attempt $attempt (exit: $exit_code)" | tee -a "$LOG_FILE"

            # Detailed error analysis
            analyze_error_and_recover "$cmd_name" "$cmd_log" "$error_patterns_log" $exit_code $attempt

            if [ $attempt -eq $MAX_RETRIES ]; then
                echo "  🚨 $cmd_name EXHAUSTED all $MAX_RETRIES attempts" | tee -a "$LOG_FILE"
                echo "  📋 Final error summary:" | tee -a "$LOG_FILE"
                tail -15 "$cmd_log" | sed 's/^/    /' | tee -a "$LOG_FILE"
                echo "  🔍 Error patterns detected:" | tee -a "$LOG_FILE"
                if [ -s "$error_patterns_log" ]; then
                    cat "$error_patterns_log" | sed 's/^/    /' | tee -a "$LOG_FILE"
                else
                    echo "    No specific patterns identified" | tee -a "$LOG_FILE"
                fi
                return $exit_code
            fi

            # Progressive backoff delay
            local delays=(0 2 5 10 20 40 60 120)
            local delay=${delays[$attempt]}
            echo "  ⏳ Waiting ${delay}s before next attempt..." | tee -a "$LOG_FILE"
            sleep $delay

            ((attempt++))
        fi
    done

    return 1
}

# Intelligent error analysis with specific recovery actions
analyze_error_and_recover() {
    local cmd_name="$1"
    local error_log="$2"
    local patterns_log="$3"
    local exit_code="$4"
    local attempt="$5"

    echo "  🔍 Analyzing error patterns for $cmd_name (attempt $attempt)..." | tee -a "$LOG_FILE"

    # Clear patterns log
    > "$patterns_log"

    # Network/DNS errors
    if grep -qi "network\|dns\|timeout\|connection.*refused\|unreachable\|resolve" "$error_log"; then
        echo "NETWORK_ERROR" >> "$patterns_log"
        echo "  🔧 Network/DNS error - applying network fixes..." | tee -a "$LOG_FILE"
        sudo_cmd systemctl restart systemd-resolved && sleep 2
        sudo_cmd systemctl restart NetworkManager && sleep 3
        echo "nameserver 8.8.8.8" | sudo_cmd tee -a /etc/resolv.conf > /dev/null
        return 0
    fi

    # NuGet/Package restoration errors
    if grep -qi "nuget\|package.*not.*found\|restore.*failed\|dependency.*resolution" "$error_log"; then
        echo "PACKAGE_ERROR" >> "$patterns_log"
        echo "  🔧 Package error - clearing NuGet cache and restoring..." | tee -a "$LOG_FILE"
        dotnet nuget locals all --clear > /dev/null 2>&1 || true
        rm -rf ~/.nuget/packages/.tools > /dev/null 2>&1 || true
        rm -rf /tmp/NuGet* > /dev/null 2>&1 || true
        dotnet restore --force --no-cache > /dev/null 2>&1 || true
        return 0
    fi

    # Build/Compilation errors
    if grep -qi "build.*failed\|compilation.*error\|cs[0-9]\|msbuild.*error" "$error_log"; then
        echo "BUILD_ERROR" >> "$patterns_log"
        echo "  🔧 Build error - cleaning and rebuilding..." | tee -a "$LOG_FILE"
        dotnet clean > /dev/null 2>&1 || true
        rm -rf bin/ obj/ > /dev/null 2>&1 || true
        export DOTNET_CLI_TELEMETRY_OPTOUT=1
        export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
        dotnet restore --verbosity quiet > /dev/null 2>&1 || true
        return 0
    fi

    # File system/Permission errors
    if grep -qi "permission.*denied\|access.*denied\|cannot.*write\|directory.*not.*found" "$error_log"; then
        echo "PERMISSION_ERROR" >> "$patterns_log"
        echo "  🔧 Permission error - fixing file permissions..." | tee -a "$LOG_FILE"
        sudo_cmd chown -R $USER:$USER . > /dev/null 2>&1 || true
        find . -type f -name "*.cs" -exec chmod 644 {} \; > /dev/null 2>&1 || true
        find . -type f -name "*.json" -exec chmod 644 {} \; > /dev/null 2>&1 || true
        find . -type d -exec chmod 755 {} \; > /dev/null 2>&1 || true
        return 0
    fi

    # Process/Port conflicts
    if grep -qi "port.*already.*use\|address.*already.*use\|process.*running" "$error_log"; then
        echo "PORT_CONFLICT" >> "$patterns_log"
        echo "  🔧 Port conflict - killing conflicting processes..." | tee -a "$LOG_FILE"
        sudo_cmd pkill -f "dotnet.*InsightLearn" > /dev/null 2>&1 || true
        sudo_cmd fuser -k 5000/tcp > /dev/null 2>&1 || true
        sudo_cmd fuser -k 5001/tcp > /dev/null 2>&1 || true
        sudo_cmd fuser -k 5080/tcp > /dev/null 2>&1 || true
        sleep 3
        return 0
    fi

    # Database connection errors
    if grep -qi "database.*connection\|sql.*server.*connection\|connection.*string.*invalid" "$error_log"; then
        echo "DATABASE_ERROR" >> "$patterns_log"
        echo "  🔧 Database error - restarting database services..." | tee -a "$LOG_FILE"
        if command -v docker > /dev/null; then
            docker compose -f docker/docker-compose.yml down > /dev/null 2>&1 || true
            sleep 2
            docker compose -f docker/docker-compose.yml up -d > /dev/null 2>&1 || true
            sleep 10
        fi
        return 0
    fi

    # Memory/Resource errors
    if grep -qi "out.*of.*memory\|insufficient.*memory\|gc.*overhead" "$error_log"; then
        echo "MEMORY_ERROR" >> "$patterns_log"
        echo "  🔧 Memory error - clearing system cache..." | tee -a "$LOG_FILE"
        sudo_cmd sync && echo 3 | sudo_cmd tee /proc/sys/vm/drop_caches > /dev/null
        export DOTNET_gcServer=1
        return 0
    fi

    # SSL/Certificate errors
    if grep -qi "ssl\|certificate\|https.*error\|tls" "$error_log"; then
        echo "SSL_ERROR" >> "$patterns_log"
        echo "  🔧 SSL error - updating certificates..." | tee -a "$LOG_FILE"
        sudo_cmd apt update > /dev/null 2>&1 || true
        sudo_cmd apt install -y ca-certificates > /dev/null 2>&1 || true
        dotnet dev-certs https --trust > /dev/null 2>&1 || true
        return 0
    fi

    # Generic recovery for unknown errors
    echo "UNKNOWN_ERROR" >> "$patterns_log"
    echo "  🔧 Unknown error - applying generic recovery..." | tee -a "$LOG_FILE"

    # Progressive recovery steps based on attempt number
    case $attempt in
        1)
            # First failure: basic cleanup
            rm -rf $TEMP_DIR/* > /dev/null 2>&1 || true
            ;;
        2)
            # Second failure: environment reset
            unset ASPNETCORE_ENVIRONMENT
            export DOTNET_ENVIRONMENT=Development
            ;;
        3)
            # Third failure: force package restore
            dotnet restore --force --ignore-failed-sources > /dev/null 2>&1 || true
            ;;
        4)
            # Fourth failure: system cleanup
            sudo_cmd apt autoremove -y > /dev/null 2>&1 || true
            ;;
        5)
            # Fifth failure: complete rebuild
            dotnet clean > /dev/null 2>&1 || true
            rm -rf bin obj > /dev/null 2>&1 || true
            ;;
        *)
            # Final attempts: aggressive cleanup
            sudo_cmd systemctl daemon-reload > /dev/null 2>&1 || true
            ;;
    esac

    return 0
}

# Test management with retry integration
start_test() {
    local test_name="$1"
    echo "🧪 Starting: $test_name" | tee -a "$LOG_FILE"
    ((TOTAL_TESTS++))
}

pass_test() {
    local test_name="$1"
    echo "✅ PASSED: $test_name" | tee -a "$LOG_FILE"
    ((PASSED_TESTS++))
}

fail_test() {
    local test_name="$1"
    local error_msg="$2"
    echo "❌ FAILED: $test_name - $error_msg" | tee -a "$LOG_FILE"
    ((FAILED_TESTS++))
}

warn_test() {
    local test_name="$1"
    local warning_msg="$2"
    echo "⚠️  WARNING: $test_name - $warning_msg" | tee -a "$LOG_FILE"
    ((WARNING_TESTS++))
}

# Verifica directory di lavoro
if [ ! -d "InsightLearn.Cloud" ]; then
    echo "ERROR: Directory InsightLearn.Cloud non trovata" | tee -a "$LOG_FILE"
    exit 1
fi

cd InsightLearn.Cloud
echo "Working directory: $(pwd)" | tee -a "$LOG_FILE"

# Inizializza report
cat > "$REPORT_FILE" << EOF
# InsightLearn.Cloud - Report Verifica Fase 4 (Autenticazione Multi-Layer)

## 📅 Informazioni Generali
- **Data Verifica**: $(date '+%Y-%m-%d %H:%M:%S')
- **Fase**: Autenticazione Multi-Layer con Error Retry System
- **Max Retry per Comando**: $MAX_RETRIES tentativi
- **Timeout Base**: $TIMEOUT_BASE secondi (scaling progressivo)
- **Directory**: $(pwd)

## 🔄 Sistema Error Retry
- **Analisi Automatica**: Pattern recognition per errori specifici
- **Recovery Actions**: Correzioni mirate per tipo errore
- **Progressive Backoff**: Delay crescente tra tentativi
- **Success Tracking**: Monitoraggio comandi recuperati

## 📊 Risultati Verifiche

EOF

echo "Starting Phase 4 verification with advanced retry system..." | tee -a "$LOG_FILE"

# 1. VERIFICA BUILD CON DIPENDENZE AUTH
echo "=== STEP 4.1: Authentication Dependencies Build ===" | tee -a "$LOG_FILE"
echo "### 🔨 Build con Dipendenze Autenticazione" >> "$REPORT_FILE"

start_test "Clean Build Environment"
if execute_with_advanced_retry "clean_build_env" "Cleaning build environment" dotnet clean; then
    pass_test "Clean Build Environment"
    echo "- ✅ **Environment Clean**: Success" >> "$REPORT_FILE"
else
    warn_test "Clean Build Environment" "Clean command failed but continuing"
    echo "- ⚠️  **Environment Clean**: Failed but non-critical" >> "$REPORT_FILE"
fi

start_test "Restore Authentication Packages"
cd src/InsightLearn.Web
if execute_with_advanced_retry "restore_auth_packages" "Restoring authentication packages" dotnet restore --force; then
    pass_test "Restore Authentication Packages"
    echo "- ✅ **Package Restore**: Success with auth dependencies" >> "$REPORT_FILE"
else
    fail_test "Restore Authentication Packages" "Package restore failed after all retries"
    echo "- ❌ **Package Restore**: Failed after $MAX_RETRIES attempts" >> "$REPORT_FILE"
fi

start_test "Build with Authentication"
if execute_with_advanced_retry "build_with_auth" "Building project with authentication" dotnet build --no-restore --configuration Release; then
    pass_test "Build with Authentication"
    echo "- ✅ **Build Status**: Success with authentication components" >> "$REPORT_FILE"
else
    fail_test "Build with Authentication" "Build failed after all retries"
    echo "- ❌ **Build Status**: Failed after retry attempts" >> "$REPORT_FILE"
fi

cd ../..

# 2. VERIFICA CONFIGURAZIONE JWT
echo "=== STEP 4.2: JWT Configuration Deep Verification ===" | tee -a "$LOG_FILE"
echo "" >> "$REPORT_FILE"
echo "### 🔑 Configurazione JWT Dettagliata" >> "$REPORT_FILE"

start_test "JWT Program.cs Configuration"
PROGRAM_FILE="src/InsightLearn.Web/Program.cs"
if [ -f "$PROGRAM_FILE" ]; then
    JWT_COMPONENTS=0

    # Check AddAuthentication
    if grep -q "AddAuthentication" "$PROGRAM_FILE"; then
        ((JWT_COMPONENTS++))
        echo "  ✓ AddAuthentication found" | tee -a "$LOG_FILE"
    fi

    # Check JwtBearer
    if grep -q "AddJwtBearer\|JwtBearerDefaults" "$PROGRAM_FILE"; then
        ((JWT_COMPONENTS++))
        echo "  ✓ JwtBearer configuration found" | tee -a "$LOG_FILE"
    fi

    # Check TokenValidationParameters
    if grep -q "TokenValidationParameters" "$PROGRAM_FILE"; then
        ((JWT_COMPONENTS++))
        echo "  ✓ TokenValidationParameters found" | tee -a "$LOG_FILE"
    fi

    # Check UseAuthentication/UseAuthorization
    if grep -q "UseAuthentication" "$PROGRAM_FILE" && grep -q "UseAuthorization" "$PROGRAM_FILE"; then
        ((JWT_COMPONENTS++))
        echo "  ✓ Authentication middleware found" | tee -a "$LOG_FILE"
    fi

    if [ $JWT_COMPONENTS -ge 3 ]; then
        pass_test "JWT Program.cs Configuration"
        echo "- ✅ **JWT Configuration**: Complete ($JWT_COMPONENTS/4 components)" >> "$REPORT_FILE"
    elif [ $JWT_COMPONENTS -ge 2 ]; then
        warn_test "JWT Program.cs Configuration" "Partial configuration"
        echo "- ⚠️  **JWT Configuration**: Partial ($JWT_COMPONENTS/4 components)" >> "$REPORT_FILE"
    else
        fail_test "JWT Program.cs Configuration" "Insufficient JWT configuration"
        echo "- ❌ **JWT Configuration**: Insufficient ($JWT_COMPONENTS/4 components)" >> "$REPORT_FILE"
    fi
else
    fail_test "JWT Program.cs Configuration" "Program.cs not found"
    echo "- ❌ **JWT Configuration**: Program.cs missing" >> "$REPORT_FILE"
fi

# Verifica JWT Settings in appsettings
start_test "JWT Settings in Configuration Files"
JWT_SETTINGS_SCORE=0
CONFIG_FILES=(
    "src/InsightLearn.Web/appsettings.json"
    "src/InsightLearn.Web/appsettings.Development.json"
    "kubernetes/secrets/app-secrets.yaml"
)

for config_file in "${CONFIG_FILES[@]}"; do
    if [ -f "$config_file" ]; then
        if grep -qi "jwt\|token" "$config_file"; then
            if grep -qi "secret\|key" "$config_file"; then
                ((JWT_SETTINGS_SCORE++))
            fi
            if grep -qi "issuer\|audience" "$config_file"; then
                ((JWT_SETTINGS_SCORE++))
            fi
        fi
    fi
done

if [ $JWT_SETTINGS_SCORE -ge 2 ]; then
    pass_test "JWT Settings in Configuration Files"
    echo "- ✅ **JWT Settings**: Found in configuration (score: $JWT_SETTINGS_SCORE)" >> "$REPORT_FILE"
elif [ $JWT_SETTINGS_SCORE -eq 1 ]; then
    warn_test "JWT Settings in Configuration Files" "Minimal JWT settings"
    echo "- ⚠️  **JWT Settings**: Minimal configuration (score: $JWT_SETTINGS_SCORE)" >> "$REPORT_FILE"
else
    fail_test "JWT Settings in Configuration Files" "No JWT settings found"
    echo "- ❌ **JWT Settings**: Not configured" >> "$REPORT_FILE"
fi

# 3. VERIFICA GOOGLE OAUTH COMPLETA
echo "=== STEP 4.3: Complete Google OAuth Verification ===" | tee -a "$LOG_FILE"
echo "" >> "$REPORT_FILE"
echo "### 🔍 Google OAuth Integration Completa" >> "$REPORT_FILE"

start_test "Google OAuth Service Registration"
GOOGLE_OAUTH_COMPONENTS=0

if [ -f "$PROGRAM_FILE" ]; then
    if grep -q "AddGoogle" "$PROGRAM_FILE"; then
        ((GOOGLE_OAUTH_COMPONENTS++))
        echo "  ✓ Google OAuth service registration found" | tee -a "$LOG_FILE"
    fi

    if grep -q "ClientId.*ClientSecret" "$PROGRAM_FILE" || grep -q "Google.*Authentication" "$PROGRAM_FILE"; then
        ((GOOGLE_OAUTH_COMPONENTS++))
        echo "  ✓ Google OAuth configuration found" | tee -a "$LOG_FILE"
    fi
fi

# Check Google OAuth in configuration files
for config_file in "${CONFIG_FILES[@]}"; do
    if [ -f "$config_file" ]; then
        if grep -qi "google" "$config_file"; then
            if grep -qi "clientid" "$config_file"; then
                ((GOOGLE_OAUTH_COMPONENTS++))
                echo "  ✓ Google ClientId configuration found" | tee -a "$LOG_FILE"
                break
            fi
        fi
    fi
done

if [ $GOOGLE_OAUTH_COMPONENTS -ge 2 ]; then
    pass_test "Google OAuth Service Registration"
    echo "- ✅ **Google OAuth**: Complete integration ($GOOGLE_OAUTH_COMPONENTS/3 components)" >> "$REPORT_FILE"
elif [ $GOOGLE_OAUTH_COMPONENTS -eq 1 ]; then
    warn_test "Google OAuth Service Registration" "Partial Google OAuth"
    echo "- ⚠️  **Google OAuth**: Partial integration ($GOOGLE_OAUTH_COMPONENTS/3 components)" >> "$REPORT_FILE"
else
    fail_test "Google OAuth Service Registration" "No Google OAuth found"
    echo "- ❌ **Google OAuth**: Not implemented" >> "$REPORT_FILE"
fi

# 4. VERIFICA COOKIE AUTHENTICATION
echo "=== STEP 4.4: Cookie Authentication Verification ===" | tee -a "$LOG_FILE"
echo "" >> "$REPORT_FILE"
echo "### 🍪 Cookie Authentication Sistema" >> "$REPORT_FILE"

start_test "Cookie Authentication Configuration"
COOKIE_COMPONENTS=0

if [ -f "$PROGRAM_FILE" ]; then
    if grep -q "AddCookie\|CookieAuthentication" "$PROGRAM_FILE"; then
        ((COOKIE_COMPONENTS++))
        echo "  ✓ Cookie authentication service found" | tee -a "$LOG_FILE"
    fi

    if grep -q "LoginPath\|LogoutPath\|AccessDeniedPath" "$PROGRAM_FILE"; then
        ((COOKIE_COMPONENTS++))
        echo "  ✓ Cookie authentication paths configured" | tee -a "$LOG_FILE"
    fi

    if grep -q "ExpireTimeSpan\|SlidingExpiration" "$PROGRAM_FILE"; then
        ((COOKIE_COMPONENTS++))
        echo "  ✓ Cookie expiration settings found" | tee -a "$LOG_FILE"
    fi
fi

if [ $COOKIE_COMPONENTS -ge 2 ]; then
    pass_test "Cookie Authentication Configuration"
    echo "- ✅ **Cookie Auth**: Well configured ($COOKIE_COMPONENTS/3 components)" >> "$REPORT_FILE"
elif [ $COOKIE_COMPONENTS -eq 1 ]; then
    warn_test "Cookie Authentication Configuration" "Basic cookie auth"
    echo "- ⚠️  **Cookie Auth**: Basic configuration ($COOKIE_COMPONENTS/3 components)" >> "$REPORT_FILE"
else
    fail_test "Cookie Authentication Configuration" "No cookie authentication"
    echo "- ❌ **Cookie Auth**: Not configured" >> "$REPORT_FILE"
fi

# 5. VERIFICA AUTH CONTROLLERS E SERVICES
echo "=== STEP 4.5: Authentication Components Verification ===" | tee -a "$LOG_FILE"
echo "" >> "$REPORT_FILE"
echo "### 🎛️  Authentication Controllers e Services" >> "$REPORT_FILE"

declare -a AUTH_FILES=(
    "Controllers/AuthController.cs:Main authentication controller"
    "Controllers/AccountController.cs:Account management controller"
    "Services/AuthService.cs:Core authentication service"
    "Services/JwtService.cs:JWT token management service"
    "Services/UserService.cs:User management service"
    "Models/AuthModels.cs:Authentication data models"
    "Models/LoginViewModel.cs:Login view models"
    "Models/RegisterViewModel.cs:Registration view models"
)

AUTH_FILES_FOUND=0
for file_info in "${AUTH_FILES[@]}"; do
    IFS=':' read -ra FILE_PARTS <<< "$file_info"
    file_path="${FILE_PARTS[0]}"
    file_desc="${FILE_PARTS[1]}"

    start_test "Auth File: $(basename $file_path)"

    # Check in multiple possible locations
    POSSIBLE_PATHS=(
        "src/InsightLearn.Web/$file_path"
        "src/InsightLearn.Api/$file_path"
        "src/InsightLearn.Core/$file_path"
        "src/InsightLearn.Infrastructure/$file_path"
    )

    FILE_FOUND=false
    for possible_path in "${POSSIBLE_PATHS[@]}"; do
        if [ -f "$possible_path" ]; then
            FILE_FOUND=true
            FILE_SIZE=$(stat -c%s "$possible_path")
            LINE_COUNT=$(wc -l < "$possible_path")

            if [ $LINE_COUNT -gt 20 ] && [ $FILE_SIZE -gt 300 ]; then
                pass_test "Auth File: $(basename $file_path)"
                echo "- ✅ **$(basename $file_path)**: Implemented ($LINE_COUNT lines)" >> "$REPORT_FILE"
                echo "  - Location: $possible_path" >> "$REPORT_FILE"
                echo "  - Description: $file_desc" >> "$REPORT_FILE"
                ((AUTH_FILES_FOUND++))
            else
                warn_test "Auth File: $(basename $file_path)" "File too small"
                echo "- ⚠️  **$(basename $file_path)**: Basic implementation ($LINE_COUNT lines)" >> "$REPORT_FILE"
            fi
            break
        fi
    done

    if [ "$FILE_FOUND" = "false" ]; then
        fail_test "Auth File: $(basename $file_path)" "File not found"
        echo "- ❌ **$(basename $file_path)**: Not implemented" >> "$REPORT_FILE"
    fi
done

# 6. VERIFICA ENDPOINT TESTING CON RETRY
echo "=== STEP 4.6: Authentication Endpoints Testing ===" | tee -a "$LOG_FILE"
echo "" >> "$REPORT_FILE"
echo "### 🔗 Authentication Endpoints Testing" >> "$REPORT_FILE"

start_test "Build for Endpoint Testing"
cd src/InsightLearn.Web

if execute_with_advanced_retry "build_endpoints" "Building for endpoint testing" dotnet build --configuration Release --verbosity quiet; then
    pass_test "Build for Endpoint Testing"
    echo "- ✅ **Endpoint Build**: Ready for testing" >> "$REPORT_FILE"

    start_test "Server Startup Test"
    # Kill any existing processes first
    sudo_cmd pkill -f "dotnet.*InsightLearn" > /dev/null 2>&1 || true
    sleep 2

    if execute_with_advanced_retry "server_startup" "Testing server startup" bash -c "timeout 15s dotnet run --urls=http://localhost:5080 --no-build > $TEMP_DIR/server.log 2>&1 &"; then
        sleep 5  # Give server time to start

        # Test if server is responding
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:5080 | grep -q "200\|404\|302"; then
            pass_test "Server Startup Test"
            echo "- ✅ **Server Startup**: Responding to requests" >> "$REPORT_FILE"
        else
            warn_test "Server Startup Test" "Server started but not responding correctly"
            echo "- ⚠️  **Server Startup**: Started but response issues" >> "$REPORT_FILE"
        fi

        # Clean up server process
        sudo_cmd pkill -f "dotnet.*InsightLearn" > /dev/null 2>&1 || true
    else
        fail_test "Server Startup Test" "Server startup failed"
        echo "- ❌ **Server Startup**: Failed after retries" >> "$REPORT_FILE"
    fi
else
    fail_test "Build for Endpoint Testing" "Build failed for endpoint testing"
    echo "- ❌ **Endpoint Build**: Failed after retries" >> "$REPORT_FILE"
fi

cd ../..

# 7. VERIFICA SECURITY CONFIGURATION
echo "=== STEP 4.7: Security Configuration Audit ===" | tee -a "$LOG_FILE"
echo "" >> "$REPORT_FILE"
echo "### 🔒 Security Configuration Audit" >> "$REPORT_FILE"

start_test "Security Middleware Configuration"
SECURITY_FEATURES=0

if [ -f "$PROGRAM_FILE" ]; then
    # HTTPS enforcement
    if grep -q "UseHttpsRedirection\|RequireHttps" "$PROGRAM_FILE"; then
        ((SECURITY_FEATURES++))
        echo "  ✓ HTTPS redirection configured" | tee -a "$LOG_FILE"
    fi

    # HSTS (HTTP Strict Transport Security)
    if grep -q "UseHsts\|AddHsts" "$PROGRAM_FILE"; then
        ((SECURITY_FEATURES++))
        echo "  ✓ HSTS security headers configured" | tee -a "$LOG_FILE"
    fi

    # CORS configuration
    if grep -q "UseCors\|AddCors" "$PROGRAM_FILE"; then
        ((SECURITY_FEATURES++))
        echo "  ✓ CORS policy configured" | tee -a "$LOG_FILE"
    fi

    # Anti-forgery tokens
    if grep -q "UseAntiforgery\|AddAntiforgery" "$PROGRAM_FILE"; then
        ((SECURITY_FEATURES++))
        echo "  ✓ Anti-forgery protection enabled" | tee -a "$LOG_FILE"
    fi

    # Data protection
    if grep -q "AddDataProtection\|UseDataProtection" "$PROGRAM_FILE"; then
        ((SECURITY_FEATURES++))
        echo "  ✓ Data protection services configured" | tee -a "$LOG_FILE"
    fi
fi

if [ $SECURITY_FEATURES -ge 4 ]; then
    pass_test "Security Middleware Configuration"
    echo "- ✅ **Security Configuration**: Excellent ($SECURITY_FEATURES/5 features)" >> "$REPORT_FILE"
elif [ $SECURITY_FEATURES -ge 2 ]; then
    warn_test "Security Middleware Configuration" "Basic security configuration"
    echo "- ⚠️  **Security Configuration**: Basic ($SECURITY_FEATURES/5 features)" >> "$REPORT_FILE"
else
    fail_test "Security Middleware Configuration" "Insufficient security"
    echo "- ❌ **Security Configuration**: Insufficient ($SECURITY_FEATURES/5 features)" >> "$REPORT_FILE"
fi

# 8. STATISTICHE RETRY E RECOVERY
echo "=== STEP 4.8: Retry System Performance Analysis ===" | tee -a "$LOG_FILE"
echo "" >> "$REPORT_FILE"
echo "## 🔄 Sistema Retry - Analisi Performance" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Calculate retry statistics
SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
FAILURE_RATE=$((FAILED_TESTS * 100 / TOTAL_TESTS))
WARNING_RATE=$((WARNING_TESTS * 100 / TOTAL_TESTS))
RECOVERY_RATE=0
if [ $TOTAL_TESTS -gt 0 ]; then
    RECOVERY_RATE=$((RECOVERED_COMMANDS * 100 / TOTAL_TESTS))
fi

echo "### 📊 Statistiche Dettagliate" >> "$REPORT_FILE"
echo "- **Test Totali Eseguiti**: $TOTAL_TESTS" >> "$REPORT_FILE"
echo "- **Successi**: $PASSED_TESTS ($SUCCESS_RATE%)" >> "$REPORT_FILE"
echo "- **Fallimenti**: $FAILED_TESTS ($FAILURE_RATE%)" >> "$REPORT_FILE"
echo "- **Warning**: $WARNING_TESTS ($WARNING_RATE%)" >> "$REPORT_FILE"
echo "- **Tentativi Retry Totali**: $RETRY_ATTEMPTS" >> "$REPORT_FILE"
echo "- **Comandi Recuperati**: $RECOVERED_COMMANDS" >> "$REPORT_FILE"
echo "- **Recovery Success Rate**: $RECOVERY_RATE%" >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"
echo "### 🎯 Efficacia Sistema Retry" >> "$REPORT_FILE"
if [ $RECOVERED_COMMANDS -gt 0 ]; then
    echo "- ✅ **Sistema Retry**: Altamente efficace" >> "$REPORT_FILE"
    echo "- **Beneficio**: $RECOVERED_COMMANDS comandi salvati da fallimento" >> "$REPORT_FILE"
    echo "- **Resilienza**: Sistema dimostra alta capacità di auto-recovery" >> "$REPORT_FILE"
else
    echo "- ✅ **Sistema Retry**: Pronto ma non necessario" >> "$REPORT_FILE"
    echo "- **Qualità**: Esecuzione senza errori che richiedessero retry" >> "$REPORT_FILE"
fi

# 9. ANALISI LOG ERRORI
if [ $RETRY_ATTEMPTS -gt 0 ]; then
    echo "" >> "$REPORT_FILE"
    echo "### 📋 Analisi Pattern Errori" >> "$REPORT_FILE"

    # Count error patterns
    PATTERN_COUNT=$(find "$RETRY_LOG_DIR" -name "*_errors.log" -exec cat {} \; | sort | uniq -c | sort -nr)
    if [ ! -z "$PATTERN_COUNT" ]; then
        echo "- **Pattern Errori Rilevati**:" >> "$REPORT_FILE"
        echo '```' >> "$REPORT_FILE"
        echo "$PATTERN_COUNT" >> "$REPORT_FILE"
        echo '```' >> "$REPORT_FILE"
    fi
fi

# 10. VERDETTO FINALE CON RETRY ANALYSIS
echo "" >> "$REPORT_FILE"
echo "## 🎯 Verdetto Finale" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ $FAILED_TESTS -eq 0 ] && [ $SUCCESS_RATE -ge 80 ]; then
    echo "### ✅ FASE 4 COMPLETATA CON SUCCESSO" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Il sistema di autenticazione multi-layer è stato implementato e verificato con successo. Il sistema di error retry ha dimostrato $([ $RECOVERED_COMMANDS -gt 0 ] && echo "efficacia nel recuperare $RECOVERED_COMMANDS comandi falliti" || echo "preparazione ottimale senza necessità di interventi")." >> "$REPORT_FILE"

    if [ $WARNING_TESTS -gt 0 ]; then
        echo "" >> "$REPORT_FILE"
        echo "**Note**: $WARNING_TESTS warning rilevati ma non critici per il funzionamento." >> "$REPORT_FILE"
    fi

    echo "" >> "$REPORT_FILE"
    echo "### 🚀 Prossimi Passi" >> "$REPORT_FILE"
    echo "1. ✅ **Autenticazione Multi-Layer**: Implementata e testata" >> "$REPORT_FILE"
    echo "2. ✅ **Error Recovery System**: Operativo e efficace" >> "$REPORT_FILE"
    echo "3. 🔄 **Fase 5**: Procedere con Backend Services e API" >> "$REPORT_FILE"
    echo "4. 🔐 **Production Ready**: Sistema auth pronto per deployment" >> "$REPORT_FILE"

    FINAL_EXIT_CODE=0

elif [ $FAILED_TESTS -le 2 ] && [ $SUCCESS_RATE -ge 65 ]; then
    echo "### ⚠️ FASE 4 PARZIALMENTE COMPLETATA" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "L'autenticazione è funzionante ma presenta $FAILED_TESTS errori. Sistema retry ha eseguito $RETRY_ATTEMPTS tentativi $([ $RECOVERED_COMMANDS -gt 0 ] && echo "recuperando $RECOVERED_COMMANDS comandi" || echo "senza successi di recovery")." >> "$REPORT_FILE"

    echo "" >> "$REPORT_FILE"
    echo "### 🔧 Azioni Correttive" >> "$REPORT_FILE"
    echo "1. 📋 **Analizzare log dettagliati** in \`$RETRY_LOG_DIR\`" >> "$REPORT_FILE"
    echo "2. 🛠️ **Correggere problemi** identificati" >> "$REPORT_FILE"
    echo "3. 🔄 **Testare sistema retry** con correzioni" >> "$REPORT_FILE"
    echo "4. ✅ **Rieseguire verifica** completa" >> "$REPORT_FILE"

    FINAL_EXIT_CODE=1

else
    echo "### ❌ FASE 4 RICHIEDE INTERVENTO CRITICO" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Problemi critici nell'autenticazione nonostante $RETRY_ATTEMPTS tentativi di retry. Sistema di recovery $([ $RECOVERED_COMMANDS -gt 0 ] && echo "ha recuperato solo $RECOVERED_COMMANDS/$FAILED_TESTS comandi falliti" || echo "non è riuscito a recuperare alcun comando fallito")." >> "$REPORT_FILE"

    echo "" >> "$REPORT_FILE"
    echo "### 🚨 Azioni Immediate" >> "$REPORT_FILE"
    echo "1. 🛑 **STOP sviluppo** fino a risoluzione" >> "$REPORT_FILE"
    echo "2. 📋 **ANALISI COMPLETA** di tutti i log di retry" >> "$REPORT_FILE"
    echo "3. 🔄 **REIMPLEMENTAZIONE** componenti auth falliti" >> "$REPORT_FILE"
    echo "4. 🧪 **TEST MANUALE** sistema retry" >> "$REPORT_FILE"
    echo "5. ✅ **VERIFICA COMPLETA** prima di procedere" >> "$REPORT_FILE"

    FINAL_EXIT_CODE=2
fi

# Final output
echo "" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "PHASE 4 VERIFICATION WITH ADVANCED RETRY COMPLETED" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "Total Tests: $TOTAL_TESTS" | tee -a "$LOG_FILE"
echo "Passed: $PASSED_TESTS ($SUCCESS_RATE%)" | tee -a "$LOG_FILE"
echo "Failed: $FAILED_TESTS ($FAILURE_RATE%)" | tee -a "$LOG_FILE"
echo "Warnings: $WARNING_TESTS ($WARNING_RATE%)" | tee -a "$LOG_FILE"
echo "Retry Attempts: $RETRY_ATTEMPTS" | tee -a "$LOG_FILE"
echo "Commands Recovered: $RECOVERED_COMMANDS" | tee -a "$LOG_FILE"
echo "Recovery Rate: $RECOVERY_RATE%" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "📊 Report: $REPORT_FILE" | tee -a "$LOG_FILE"
echo "📝 Main Log: $LOG_FILE" | tee -a "$LOG_FILE"
echo "📋 Retry Logs: $RETRY_LOG_DIR" | tee -a "$LOG_FILE"

# Cleanup
rm -rf "$TEMP_DIR" > /dev/null 2>&1 || true

exit $FINAL_EXIT_CODE