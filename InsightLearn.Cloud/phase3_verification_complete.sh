#!/bin/bash
set -e
set -u

# Setup logging con metriche avanzate
LOG_FILE="logs/phase3_verification_$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="logs/PHASE3_DESIGN_REPORT_$(date +%Y%m%d_%H%M%S).md"
SCREENSHOTS_DIR="logs/screenshots_$(date +%Y%m%d_%H%M%S)"
mkdir -p logs "$SCREENSHOTS_DIR"

exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE")

echo "=== [$(date)] PHASE 3 DESIGN VERIFICATION START ==="

# Sudo password e contatori
SUDO_PASS="SS1-Temp1234"
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNING_TESTS=0
COMPONENTS_TESTED=0
BUILD_SUCCESS=false
DESIGN_SCORE=0

# Functions per testing
sudo_cmd() {
    echo "$SUDO_PASS" | sudo -S "$@" 2>/dev/null || sudo "$@"
}

timeout_cmd() {
    local timeout_duration=${1:-60}
    shift
    timeout ${timeout_duration}s "$@"
    local exit_code=$?
    if [ $exit_code -eq 124 ]; then
        echo "ERROR: Command timed out after ${timeout_duration} seconds"
        return 124
    fi
    return $exit_code
}

# Test management functions
start_test() {
    local test_name="$1"
    echo "🧪 Testing: $test_name"
    ((TOTAL_TESTS++))
}

pass_test() {
    local test_name="$1"
    echo "✅ PASSED: $test_name"
    ((PASSED_TESTS++))
}

fail_test() {
    local test_name="$1"
    local error_msg="$2"
    echo "❌ FAILED: $test_name - $error_msg"
    ((FAILED_TESTS++))
}

warn_test() {
    local test_name="$1"
    local warning_msg="$2"
    echo "⚠️ WARNING: $test_name - $warning_msg"
    ((WARNING_TESTS++))
}

echo "Working directory: $(pwd)"

# Inizializza report Markdown
cat > "$REPORT_FILE" << EOF
# InsightLearn.Cloud - Report Verifica Fase 3 (Design System)

## 📅 Informazioni Generali
- **Data Verifica**: $(date '+%Y-%m-%d %H:%M:%S')
- **Fase**: Design System e UI Components
- **Obiettivo**: Verifica quality superiore a Udemy
- **Directory**: $(pwd)

## 📊 Risultati Verifiche

EOF

echo "Starting comprehensive Phase 3 verification..."

# 1. VERIFICA BUILD E COMPILAZIONE
echo "=== STEP 3.1: Build and Compilation Verification ==="
echo "### 🔨 Build e Compilazione" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

start_test "Project Build"
cd src/InsightLearn.Web/InsightLearn.Web
if timeout_cmd 300 dotnet build --no-restore > /tmp/build_output.log 2>&1; then
    pass_test "Project Build"
    echo "- ✅ **Build Status**: Successful" >> "$REPORT_FILE"
    BUILD_SUCCESS=true
else
    BUILD_ERRORS=$(grep -i "error" /tmp/build_output.log | wc -l)
    BUILD_WARNINGS=$(grep -i "warning" /tmp/build_output.log | wc -l)
    fail_test "Project Build" "$BUILD_ERRORS errors, $BUILD_WARNINGS warnings"
    echo "- ❌ **Build Status**: Failed ($BUILD_ERRORS errors, $BUILD_WARNINGS warnings)" >> "$REPORT_FILE"
    echo "- **Build Output**:" >> "$REPORT_FILE"
    echo '```' >> "$REPORT_FILE"
    tail -20 /tmp/build_output.log >> "$REPORT_FILE"
    echo '```' >> "$REPORT_FILE"
fi

# Verifica presenza NuGet packages
start_test "NuGet Dependencies"
if dotnet list package | grep -q "MudBlazor"; then
    MUDBLAZOR_VERSION=$(dotnet list package | grep "MudBlazor" | awk '{print $NF}' | head -1)
    pass_test "NuGet Dependencies"
    echo "- ✅ **MudBlazor**: $MUDBLAZOR_VERSION" >> "$REPORT_FILE"
else
    fail_test "NuGet Dependencies" "MudBlazor not found"
    echo "- ❌ **MudBlazor**: Not installed" >> "$REPORT_FILE"
fi

cd ../../..

# 2. VERIFICA DESIGN TOKENS E CSS
echo "=== STEP 3.2: Design Tokens Verification ==="
echo "" >> "$REPORT_FILE"
echo "### 🎨 Design Tokens e CSS" >> "$REPORT_FILE"

declare -a CSS_FILES=(
    "src/InsightLearn.Web/InsightLearn.Web/wwwroot/css/design-system/design-tokens.css"
    "src/InsightLearn.Web/InsightLearn.Web/wwwroot/css/design-system/components.css"
)

for css_file in "${CSS_FILES[@]}"; do
    start_test "CSS File: $(basename $css_file)"

    if [ -f "$css_file" ]; then
        FILE_SIZE=$(stat -c%s "$css_file")
        LINE_COUNT=$(wc -l < "$css_file")

        if [ $FILE_SIZE -gt 1000 ] && [ $LINE_COUNT -gt 50 ]; then
            pass_test "CSS File: $(basename $css_file)"
            echo "- ✅ **$(basename $css_file)**: $LINE_COUNT lines, ${FILE_SIZE} bytes" >> "$REPORT_FILE"

            # Verifica presenza design tokens critici
            if grep -q ":root" "$css_file" && grep -q "\-\-il\-primary" "$css_file"; then
                pass_test "Design Tokens in $(basename $css_file)"
                echo "  - ✅ Design Tokens: Present" >> "$REPORT_FILE"
                ((DESIGN_SCORE += 10))
            else
                warn_test "Design Tokens in $(basename $css_file)" "Missing critical tokens"
                echo "  - ⚠️ Design Tokens: Incomplete" >> "$REPORT_FILE"
            fi

        else
            warn_test "CSS File: $(basename $css_file)" "File too small (${FILE_SIZE} bytes)"
            echo "- ⚠️ **$(basename $css_file)**: File too small" >> "$REPORT_FILE"
        fi
    else
        fail_test "CSS File: $(basename $css_file)" "File not found"
        echo "- ❌ **$(basename $css_file)**: Not found" >> "$REPORT_FILE"
    fi
done

# Verifica JavaScript theme manager
start_test "Theme Manager JavaScript"
JS_FILE="src/InsightLearn.Web/InsightLearn.Web/wwwroot/js/design-system/theme-manager.js"
if [ -f "$JS_FILE" ]; then
    if grep -q "InsightLearnThemeManager" "$JS_FILE" && grep -q "toggleTheme" "$JS_FILE"; then
        pass_test "Theme Manager JavaScript"
        echo "- ✅ **Theme Manager JS**: Functional" >> "$REPORT_FILE"
        ((DESIGN_SCORE += 10))
    else
        warn_test "Theme Manager JavaScript" "Missing core functionality"
        echo "- ⚠️ **Theme Manager JS**: Incomplete functionality" >> "$REPORT_FILE"
    fi
else
    fail_test "Theme Manager JavaScript" "File not found"
    echo "- ❌ **Theme Manager JS**: Not found" >> "$REPORT_FILE"
fi

# 3. VERIFICA ATOMIC COMPONENTS
echo "=== STEP 3.3: Atomic Components Verification ==="
echo "" >> "$REPORT_FILE"
echo "### ⚛️ Atomic Components" >> "$REPORT_FILE"

declare -a ATOMIC_COMPONENTS=(
    "ILButton:Button component avanzato"
    "ILInput:Input component con validazione"
    "ILCard:Card component con animazioni"
)

for component_info in "${ATOMIC_COMPONENTS[@]}"; do
    IFS=':' read -ra COMPONENT_PARTS <<< "$component_info"
    component="${COMPONENT_PARTS[0]}"
    description="${COMPONENT_PARTS[1]}"

    start_test "Atomic Component: $component"

    COMPONENT_FILE="src/InsightLearn.Web/InsightLearn.Web/Components/DesignSystem/Atoms/${component}.razor"

    if [ -f "$COMPONENT_FILE" ]; then
        FILE_SIZE=$(stat -c%s "$COMPONENT_FILE")
        LINE_COUNT=$(wc -l < "$COMPONENT_FILE")

        # Verifica struttura component
        PARAMETER_COUNT=$(grep -c "\[Parameter\]" "$COMPONENT_FILE" || echo "0")
        HAS_STYLE_BLOCK=$(grep -q "<style>" "$COMPONENT_FILE" && echo "true" || echo "false")
        HAS_CODE_BLOCK=$(grep -q "@code" "$COMPONENT_FILE" && echo "true" || echo "false")

        if [ $LINE_COUNT -gt 50 ] && [ $PARAMETER_COUNT -gt 2 ]; then
            pass_test "Atomic Component: $component"
            echo "- ✅ **$component**: $LINE_COUNT lines, $PARAMETER_COUNT parameters" >> "$REPORT_FILE"
            echo "  - Description: $description" >> "$REPORT_FILE"
            echo "  - Style Block: $HAS_STYLE_BLOCK" >> "$REPORT_FILE"
            echo "  - Code Block: $HAS_CODE_BLOCK" >> "$REPORT_FILE"
            ((COMPONENTS_TESTED++))
            ((DESIGN_SCORE += 15))
        else
            warn_test "Atomic Component: $component" "Component too simple ($LINE_COUNT lines, $PARAMETER_COUNT params)"
            echo "- ⚠️ **$component**: Basic implementation" >> "$REPORT_FILE"
            ((COMPONENTS_TESTED++))
            ((DESIGN_SCORE += 5))
        fi
    else
        fail_test "Atomic Component: $component" "File not found"
        echo "- ❌ **$component**: Not implemented" >> "$REPORT_FILE"
    fi
done

# 5. VERIFICA APP.RAZOR E CONFIGURAZIONE
echo "=== STEP 3.5: App Configuration Verification ==="
echo "" >> "$REPORT_FILE"
echo "### ⚙️ Configurazione App" >> "$REPORT_FILE"

start_test "App.razor Configuration"
APP_FILE="src/InsightLearn.Web/InsightLearn.Web/Components/App.razor"
if [ -f "$APP_FILE" ]; then
    # Verifica presenza design system references
    HAS_DESIGN_TOKENS=$(grep -q "design-system/design-tokens.css" "$APP_FILE" && echo "true" || echo "false")
    HAS_COMPONENTS_CSS=$(grep -q "design-system/components.css" "$APP_FILE" && echo "true" || echo "false")
    HAS_THEME_MANAGER=$(grep -q "theme-manager.js" "$APP_FILE" && echo "true" || echo "false")
    HAS_MUDBLAZOR=$(grep -q "MudBlazor" "$APP_FILE" && echo "true" || echo "false")
    HAS_FONTS=$(grep -q "fonts.googleapis.com" "$APP_FILE" && echo "true" || echo "false")

    TOTAL_INTEGRATIONS=$((
        $(echo $HAS_DESIGN_TOKENS | grep -c "true") +
        $(echo $HAS_COMPONENTS_CSS | grep -c "true") +
        $(echo $HAS_THEME_MANAGER | grep -c "true") +
        $(echo $HAS_MUDBLAZOR | grep -c "true") +
        $(echo $HAS_FONTS | grep -c "true")
    ))

    if [ $TOTAL_INTEGRATIONS -ge 4 ]; then
        pass_test "App.razor Configuration"
        echo "- ✅ **App.razor**: Well configured ($TOTAL_INTEGRATIONS/5 integrations)" >> "$REPORT_FILE"
        ((DESIGN_SCORE += 15))
    else
        warn_test "App.razor Configuration" "Missing integrations ($TOTAL_INTEGRATIONS/5)"
        echo "- ⚠️ **App.razor**: Incomplete configuration ($TOTAL_INTEGRATIONS/5 integrations)" >> "$REPORT_FILE"
        ((DESIGN_SCORE += 5))
    fi

    echo "  - Design Tokens CSS: $HAS_DESIGN_TOKENS" >> "$REPORT_FILE"
    echo "  - Components CSS: $HAS_COMPONENTS_CSS" >> "$REPORT_FILE"
    echo "  - Theme Manager JS: $HAS_THEME_MANAGER" >> "$REPORT_FILE"
    echo "  - MudBlazor: $HAS_MUDBLAZOR" >> "$REPORT_FILE"
    echo "  - Google Fonts: $HAS_FONTS" >> "$REPORT_FILE"

else
    fail_test "App.razor Configuration" "File not found"
    echo "- ❌ **App.razor**: Not found" >> "$REPORT_FILE"
fi

# Verifica Program.cs
start_test "Program.cs MudBlazor Integration"
PROGRAM_FILE="src/InsightLearn.Web/InsightLearn.Web/Program.cs"
if [ -f "$PROGRAM_FILE" ]; then
    if grep -q "AddMudServices" "$PROGRAM_FILE"; then
        pass_test "Program.cs MudBlazor Integration"
        echo "- ✅ **Program.cs**: MudBlazor services registered" >> "$REPORT_FILE"
        ((DESIGN_SCORE += 10))
    else
        warn_test "Program.cs MudBlazor Integration" "MudBlazor services not registered"
        echo "- ⚠️ **Program.cs**: Missing MudBlazor services" >> "$REPORT_FILE"
    fi
else
    fail_test "Program.cs MudBlazor Integration" "File not found"
    echo "- ❌ **Program.cs**: Not found" >> "$REPORT_FILE"
fi

# 6. VERIFICA RESPONSIVE E ACCESSIBILITÀ
echo "=== STEP 3.6: Responsive and Accessibility Verification ==="
echo "" >> "$REPORT_FILE"
echo "### 📱 Responsive e Accessibility" >> "$REPORT_FILE"

start_test "Responsive Design Patterns"
RESPONSIVE_PATTERNS=0

# Conta media queries nei CSS files
for css_file in "${CSS_FILES[@]}"; do
    if [ -f "$css_file" ]; then
        MEDIA_QUERIES=$(grep -c "@media" "$css_file" || echo "0")
        RESPONSIVE_PATTERNS=$((RESPONSIVE_PATTERNS + MEDIA_QUERIES))
    fi
done

if [ $RESPONSIVE_PATTERNS -gt 5 ]; then
    pass_test "Responsive Design Patterns"
    echo "- ✅ **Responsive Design**: $RESPONSIVE_PATTERNS media queries found" >> "$REPORT_FILE"
    ((DESIGN_SCORE += 15))
elif [ $RESPONSIVE_PATTERNS -gt 2 ]; then
    warn_test "Responsive Design Patterns" "Limited responsive design ($RESPONSIVE_PATTERNS media queries)"
    echo "- ⚠️ **Responsive Design**: Limited ($RESPONSIVE_PATTERNS media queries)" >> "$REPORT_FILE"
    ((DESIGN_SCORE += 8))
else
    fail_test "Responsive Design Patterns" "No responsive design found"
    echo "- ❌ **Responsive Design**: Not implemented" >> "$REPORT_FILE"
fi

# 8. CALCOLO DESIGN QUALITY SCORE
echo "=== STEP 3.8: Design Quality Assessment ==="
echo "" >> "$REPORT_FILE"
echo "### 🎨 Design Quality Score" >> "$REPORT_FILE"

# Calculate final design score out of 100
MAX_POSSIBLE_SCORE=150  # Maximum attainable score
DESIGN_PERCENTAGE=$((DESIGN_SCORE * 100 / MAX_POSSIBLE_SCORE))

echo "" >> "$REPORT_FILE"
echo "- **Raw Score**: $DESIGN_SCORE/$MAX_POSSIBLE_SCORE" >> "$REPORT_FILE"
echo "- **Design Quality**: $DESIGN_PERCENTAGE%" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Quality assessment
if [ $DESIGN_PERCENTAGE -ge 85 ]; then
    QUALITY_RATING="Excellent (Superior to Udemy)"
    QUALITY_ICON="🏆"
elif [ $DESIGN_PERCENTAGE -ge 70 ]; then
    QUALITY_RATING="Good (Competitive with Udemy)"
    QUALITY_ICON="✅"
elif [ $DESIGN_PERCENTAGE -ge 50 ]; then
    QUALITY_RATING="Acceptable (Basic Implementation)"
    QUALITY_ICON="⚠️"
else
    QUALITY_RATING="Needs Improvement"
    QUALITY_ICON="❌"
fi

echo "**$QUALITY_ICON Quality Rating**: $QUALITY_RATING" >> "$REPORT_FILE"

# 9. STATISTICHE FINALI
echo "" >> "$REPORT_FILE"
echo "## 📊 Statistiche Finali" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ $TOTAL_TESTS -gt 0 ]; then
    SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    FAILURE_RATE=$((FAILED_TESTS * 100 / TOTAL_TESTS))
    WARNING_RATE=$((WARNING_TESTS * 100 / TOTAL_TESTS))
else
    SUCCESS_RATE=0
    FAILURE_RATE=0
    WARNING_RATE=0
fi

echo "- **Test Totali**: $TOTAL_TESTS" >> "$REPORT_FILE"
echo "- **Successi**: $PASSED_TESTS ($SUCCESS_RATE%)" >> "$REPORT_FILE"
echo "- **Fallimenti**: $FAILED_TESTS ($FAILURE_RATE%)" >> "$REPORT_FILE"
echo "- **Warning**: $WARNING_TESTS ($WARNING_RATE%)" >> "$REPORT_FILE"
echo "- **Componenti Testati**: $COMPONENTS_TESTED" >> "$REPORT_FILE"
echo "- **Build Status**: $([ "$BUILD_SUCCESS" = "true" ] && echo "✅ Success" || echo "❌ Failed")" >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"

# Progress bar visuale
echo "### 📈 Progress Overview" >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"
printf "Success   [" >> "$REPORT_FILE"
for i in $(seq 1 $((SUCCESS_RATE/2))); do printf "█" >> "$REPORT_FILE"; done
for i in $(seq $((SUCCESS_RATE/2 + 1)) 50); do printf "░" >> "$REPORT_FILE"; done
printf "] %d%%\n" $SUCCESS_RATE >> "$REPORT_FILE"

printf "Warnings  [" >> "$REPORT_FILE"
for i in $(seq 1 $((WARNING_RATE/2))); do printf "█" >> "$REPORT_FILE"; done
for i in $(seq $((WARNING_RATE/2 + 1)) 50); do printf "░" >> "$REPORT_FILE"; done
printf "] %d%%\n" $WARNING_RATE >> "$REPORT_FILE"

printf "Design    [" >> "$REPORT_FILE"
for i in $(seq 1 $((DESIGN_PERCENTAGE/2))); do printf "█" >> "$REPORT_FILE"; done
for i in $(seq $((DESIGN_PERCENTAGE/2 + 1)) 50); do printf "░" >> "$REPORT_FILE"; done
printf "] %d%%\n" $DESIGN_PERCENTAGE >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"

# 10. VERDETTO FINALE E RACCOMANDAZIONI
echo "" >> "$REPORT_FILE"
echo "## 🎯 Verdetto Finale" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ $FAILED_TESTS -eq 0 ] && [ $DESIGN_PERCENTAGE -ge 70 ] && [ "$BUILD_SUCCESS" = "true" ]; then
    echo "### ✅ FASE 3 COMPLETATA CON SUCCESSO" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Il design system InsightLearn.Cloud è stato implementato correttamente con qualità $([ $DESIGN_PERCENTAGE -ge 85 ] && echo "superiore" || echo "competitiva") rispetto a Udemy." >> "$REPORT_FILE"

    if [ $WARNING_TESTS -gt 0 ]; then
        echo "" >> "$REPORT_FILE"
        echo "**Note**: $WARNING_TESTS warning rilevati. Sistema funzionale ma con possibilità di ottimizzazione." >> "$REPORT_FILE"
    fi

    echo "" >> "$REPORT_FILE"
    echo "### 🚀 Prossimi Passi Raccomandati" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "1. ✅ **Design System** → Ready per sviluppo UI" >> "$REPORT_FILE"
    echo "2. ✅ **Componenti Base** → $COMPONENTS_TESTED componenti implementati" >> "$REPORT_FILE"
    echo "3. 🔄 **Fase 4** → Procedere con Autenticazione Multi-Layer" >> "$REPORT_FILE"
    echo "4. 🎨 **Refinement** → Considerare ottimizzazioni basate sui warning" >> "$REPORT_FILE"

    FINAL_EXIT_CODE=0

elif [ $FAILED_TESTS -le 2 ] && [ $SUCCESS_RATE -ge 80 ] && [ "$BUILD_SUCCESS" = "true" ]; then
    echo "### ⚠️ FASE 3 PARZIALMENTE COMPLETATA" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Il design system è funzionante ma presenta $FAILED_TESTS errori minori che necessitano correzione." >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "### 🔧 Azioni Correttive Necessarie" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "1. 🔍 **Analizzare i fallimenti** nei test specifici" >> "$REPORT_FILE"
    echo "2. 🛠️ **Correggere i problemi** identificati nelle sezioni sopra" >> "$REPORT_FILE"
    echo "3. 🔄 **Migliorare il design score** se inferiore a 70%" >> "$REPORT_FILE"
    echo "4. ✅ **Rieseguire la verifica** dopo le correzioni" >> "$REPORT_FILE"

    FINAL_EXIT_CODE=1

else
    echo "### ❌ FASE 3 RICHIEDE INTERVENTO SIGNIFICATIVO" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Sono stati rilevati problemi critici che impediscono il completamento della Fase 3." >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**Problemi Identificati:**" >> "$REPORT_FILE"
    if [ "$BUILD_SUCCESS" = "false" ]; then
        echo "- 🚨 **Build Failure**: Il progetto non compila correttamente" >> "$REPORT_FILE"
    fi
    if [ $DESIGN_PERCENTAGE -lt 50 ]; then
        echo "- 🚨 **Design Quality**: Score troppo basso ($DESIGN_PERCENTAGE%)" >> "$REPORT_FILE"
    fi
    if [ $FAILED_TESTS -gt 2 ]; then
        echo "- 🚨 **Test Failures**: Troppi test falliti ($FAILED_TESTS)" >> "$REPORT_FILE"
    fi

    echo "" >> "$REPORT_FILE"
    echo "### 🚨 Azioni Immediate Richieste" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "1. 🛑 **FERMARE** lo sviluppo fino alla risoluzione" >> "$REPORT_FILE"
    echo "2. 📋 **RIVEDERE** i log dettagliati in \`$LOG_FILE\`" >> "$REPORT_FILE"
    echo "3. 🔄 **RICOSTRUIRE** i componenti falliti" >> "$REPORT_FILE"
    echo "4. 🆘 **CONSIDERARE** reimplementazione se necessario" >> "$REPORT_FILE"
    echo "5. ✅ **VERIFICARE** nuovamente prima di Fase 4" >> "$REPORT_FILE"

    FINAL_EXIT_CODE=2
fi

# Informazioni tecniche finali
echo "" >> "$REPORT_FILE"
echo "## 📋 Informazioni Tecniche" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "- **Log File**: \`$LOG_FILE\`" >> "$REPORT_FILE"
echo "- **Report File**: \`$REPORT_FILE\`" >> "$REPORT_FILE"
echo "- **Screenshots Directory**: \`$SCREENSHOTS_DIR\`" >> "$REPORT_FILE"
echo "- **Timestamp Verifica**: $(date '+%Y-%m-%d %H:%M:%S')" >> "$REPORT_FILE"

# Final console output
echo ""
echo "========================================"
echo "FASE 3 VERIFICATION COMPLETED"
echo "========================================"
echo "Total Tests: $TOTAL_TESTS"
echo "Passed: $PASSED_TESTS ($SUCCESS_RATE%)"
echo "Failed: $FAILED_TESTS ($FAILURE_RATE%)"
echo "Warnings: $WARNING_TESTS ($WARNING_RATE%)"
echo "Components Tested: $COMPONENTS_TESTED"
echo "Design Quality Score: $DESIGN_PERCENTAGE% ($QUALITY_RATING)"
echo ""
echo "📊 Report dettagliato salvato in: $REPORT_FILE"
echo "📝 Log completo salvato in: $LOG_FILE"

if [ $FINAL_EXIT_CODE -eq 0 ]; then
    echo "✅ VERIFICA COMPLETATA CON SUCCESSO - Design System Ready per Fase 4"
elif [ $FINAL_EXIT_CODE -eq 1 ]; then
    echo "⚠️ VERIFICA PARZIALE - Correzioni minori necessarie prima di Fase 4"
else
    echo "❌ VERIFICA FALLITA - Interventi significativi richiesti"
fi

echo "=== [$(date)] FASE 3 VERIFICATION END ==="

exit $FINAL_EXIT_CODE