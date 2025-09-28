#!/bin/bash
set -e
set -u

# Setup logging
LOG_FILE="logs/phase3_design_$(date +%Y%m%d_%H%M%S).log"
mkdir -p logs
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE")

echo "=== [$(date)] PHASE 3 DESIGN SYSTEM START ===" | tee -a "$LOG_FILE"

# Sudo password per operazioni sistema
SUDO_PASS="SS1-Temp1234"

# Contatori per tracking
COMPONENTS_CREATED=0
COMPONENTS_TESTED=0
BUILD_ERRORS=0

sudo_cmd() {
    echo "$SUDO_PASS" | sudo -S "$@" 2>/dev/null || sudo "$@"
}

timeout_cmd() {
    local timeout_duration=${1:-60}
    shift
    timeout ${timeout_duration}s "$@"
    local exit_code=$?
    if [ $exit_code -eq 124 ]; then
        echo "ERROR: Command timed out after ${timeout_duration} seconds" | tee -a "$LOG_FILE"
        return 124
    fi
    return $exit_code
}

# Verifica build dopo ogni componente
verify_build() {
    local component_name="$1"
    echo "Verifying build for $component_name..." | tee -a "$LOG_FILE"

    cd src/InsightLearn.Web/InsightLearn.Web
    if timeout_cmd 300 dotnet build --no-restore > /dev/null 2>&1; then
        echo "✅ Build successful for $component_name" | tee -a "$LOG_FILE"
        ((COMPONENTS_TESTED++))
        cd ../../..
        return 0
    else
        echo "❌ Build failed for $component_name" | tee -a "$LOG_FILE"
        ((BUILD_ERRORS++))
        cd ../../..
        return 1
    fi
}

echo "Working directory: $(pwd)" | tee -a "$LOG_FILE"

echo "=== STEP 3.1: Design System Foundation ===" | tee -a "$LOG_FILE"

# Verifica che i progetti base esistano
if [ ! -f "src/InsightLearn.Web/InsightLearn.Web/InsightLearn.Web.csproj" ]; then
    echo "ERROR: Progetto Web non trovato. Eseguire prima le fasi precedenti." | tee -a "$LOG_FILE"
    exit 1
fi

cd src/InsightLearn.Web/InsightLearn.Web

# Installare MudBlazor per componenti base avanzati
echo "Installing MudBlazor and design dependencies..." | tee -a "$LOG_FILE"
timeout_cmd 120 dotnet add package MudBlazor
timeout_cmd 120 dotnet add package MudBlazor.ThemeManager

# Creare struttura directory per design system
echo "Creating design system directory structure..." | tee -a "$LOG_FILE"
mkdir -p wwwroot/css/design-system
mkdir -p wwwroot/js/design-system
mkdir -p wwwroot/assets/icons
mkdir -p wwwroot/assets/images
mkdir -p Components/DesignSystem
mkdir -p Components/DesignSystem/Atoms
mkdir -p Components/DesignSystem/Molecules
mkdir -p Components/DesignSystem/Organisms
mkdir -p Components/DesignSystem/Templates
mkdir -p Services/Design

echo "Directory structure created successfully!" | tee -a "$LOG_FILE"

# Final summary
echo "" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "PHASE 3 STEP 1 COMPLETED" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "Components Created: $COMPONENTS_CREATED" | tee -a "$LOG_FILE"
echo "Build Errors: $BUILD_ERRORS" | tee -a "$LOG_FILE"
echo "=== [$(date)] PHASE 3 STEP 1 END ===" | tee -a "$LOG_FILE"

cd ../../..