#!/bin/bash
set -e

# Setup logging con doppio output
LOG_FILE="logs/debug_verification_$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="logs/DEBUG_VERIFICATION_REPORT_$(date +%Y%m%d_%H%M%S).md"
mkdir -p logs

echo "=== [$(date)] DEBUG VERIFICATION START ===" | tee -a "$LOG_FILE"

# Start time tracking
START_TIME=$(date +%s)

# Contatori per report finale
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Function per check di successo
handle_check_success() {
    local check_name="$1"
    echo "PASSED: $check_name" | tee -a "$LOG_FILE"
    ((PASSED_CHECKS++))
}

echo "Initializing report file..." | tee -a "$LOG_FILE"

# Inizializza report Markdown
cat > "$REPORT_FILE" << EOF
# InsightLearn.Cloud - Debug Report Verifica Fase 2A

## 📅 Informazioni Generali
- **Data Verifica**: $(date '+%Y-%m-%d %H:%M:%S')
- **Fase**: Kubernetes e Docker Setup
- **Sistema**: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '"')
- **Kernel**: $(uname -r)
- **Architettura**: $(uname -m)
- **Directory**: $(pwd)

## 📊 Risultati Verifiche

EOF

echo "Report file created, starting system info collection..." | tee -a "$LOG_FILE"

# 1. VERIFICA INFORMAZIONI SISTEMA
echo "=== STEP 1: System Information ===" | tee -a "$LOG_FILE"
((TOTAL_CHECKS++))

echo "### 🖥️ Informazioni Sistema" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "Collecting RAM info..." | tee -a "$LOG_FILE"
# RAM disponibile
TOTAL_RAM_GB=$(free -h | grep '^Mem:' | awk '{print $2}')
AVAILABLE_RAM_GB=$(free -h | grep '^Mem:' | awk '{print $7}')
echo "- **RAM Totale**: $TOTAL_RAM_GB" >> "$REPORT_FILE"
echo "- **RAM Disponibile**: $AVAILABLE_RAM_GB" >> "$REPORT_FILE"

echo "Collecting disk info..." | tee -a "$LOG_FILE"
# Spazio disco
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_AVAILABLE=$(df -h / | awk 'NR==2 {print $4}')
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')
echo "- **Disco Totale**: $DISK_TOTAL" >> "$REPORT_FILE"
echo "- **Disco Disponibile**: $DISK_AVAILABLE" >> "$REPORT_FILE"
echo "- **Utilizzo Disco**: $DISK_USAGE" >> "$REPORT_FILE"

echo "Collecting CPU info..." | tee -a "$LOG_FILE"
# CPU info
CPU_CORES=$(nproc)
CPU_MODEL=$(lscpu | grep "Model name" | cut -d':' -f2 | sed 's/^ *//')
echo "- **CPU Cores**: $CPU_CORES" >> "$REPORT_FILE"
echo "- **CPU Model**: $CPU_MODEL" >> "$REPORT_FILE"

handle_check_success "System Information Collection"

echo "System information step completed!" | tee -a "$LOG_FILE"
echo "Current stats: Total=$TOTAL_CHECKS, Passed=$PASSED_CHECKS" | tee -a "$LOG_FILE"

echo "DEBUG: Script completed successfully" | tee -a "$LOG_FILE"