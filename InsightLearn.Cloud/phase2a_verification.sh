#!/bin/bash
set -e  # Exit on error per singoli step
set -u  # Exit on undefined variable

# Setup logging con doppio output
LOG_FILE="logs/phase2a_verification_$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="logs/PHASE2A_VERIFICATION_REPORT_$(date +%Y%m%d_%H%M%S).md"
mkdir -p logs

# Start time tracking
START_TIME=$(date +%s)

# Sudo password per operazioni di sistema Debian
SUDO_PASS="SS1-Temp1234"

# Contatori per report finale
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Function per comandi sudo con password
sudo_cmd() {
    echo "$SUDO_PASS" | sudo -S "$@" 2>/dev/null || sudo "$@"
}

# Function timeout per comandi
timeout_cmd() {
    local timeout_duration=${1:-60}
    shift
    timeout ${timeout_duration}s "$@"
    local exit_code=$?
    if [ $exit_code -eq 124 ]; then
        echo "WARNING: Command timed out after ${timeout_duration} seconds" | tee -a "$LOG_FILE"
        return 124
    fi
    return $exit_code
}

# Function per gestione errori non fatali
handle_check_error() {
    local check_name="$1"
    local exit_code="$2"
    echo "FAILED: $check_name (exit code: $exit_code)" | tee -a "$LOG_FILE"
    ((FAILED_CHECKS++))
    return 0  # Non interrompere l'esecuzione
}

# Function per check di successo
handle_check_success() {
    local check_name="$1"
    echo "PASSED: $check_name" | tee -a "$LOG_FILE"
    ((PASSED_CHECKS++))
}

# Function per warning
handle_check_warning() {
    local check_name="$1"
    local warning_msg="$2"
    echo "WARNING: $check_name - $warning_msg" | tee -a "$LOG_FILE"
    ((WARNING_CHECKS++))
}

echo "=== [$(date)] FASE 2A VERIFICATION START ===" | tee -a "$LOG_FILE"
echo "Working directory: $(pwd)" | tee -a "$LOG_FILE"

# Inizializza report Markdown
cat > "$REPORT_FILE" << EOF
# InsightLearn.Cloud - Report Verifica Fase 2A

## 📅 Informazioni Generali
- **Data Verifica**: $(date '+%Y-%m-%d %H:%M:%S')
- **Fase**: Kubernetes e Docker Setup
- **Sistema**: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '"')
- **Kernel**: $(uname -r)
- **Architettura**: $(uname -m)
- **Directory**: $(pwd)

## 📊 Risultati Verifiche

EOF

echo "Starting comprehensive Phase 2A verification..." | tee -a "$LOG_FILE"

# 1. VERIFICA INFORMAZIONI SISTEMA
echo "=== STEP 1: System Information ===" | tee -a "$LOG_FILE"
((TOTAL_CHECKS++))

echo "### 🖥️ Informazioni Sistema" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# RAM disponibile
TOTAL_RAM_GB=$(free -h | grep '^Mem:' | awk '{print $2}')
AVAILABLE_RAM_GB=$(free -h | grep '^Mem:' | awk '{print $7}')
echo "- **RAM Totale**: $TOTAL_RAM_GB" >> "$REPORT_FILE"
echo "- **RAM Disponibile**: $AVAILABLE_RAM_GB" >> "$REPORT_FILE"

# Spazio disco
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_AVAILABLE=$(df -h / | awk 'NR==2 {print $4}')
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')
echo "- **Disco Totale**: $DISK_TOTAL" >> "$REPORT_FILE"
echo "- **Disco Disponibile**: $DISK_AVAILABLE" >> "$REPORT_FILE"
echo "- **Utilizzo Disco**: $DISK_USAGE" >> "$REPORT_FILE"

# CPU info
CPU_CORES=$(nproc)
CPU_MODEL=$(lscpu | grep "Model name" | cut -d':' -f2 | sed 's/^ *//')
echo "- **CPU Cores**: $CPU_CORES" >> "$REPORT_FILE"
echo "- **CPU Model**: $CPU_MODEL" >> "$REPORT_FILE"

handle_check_success "System Information Collection"

# 2. VERIFICA DOCKER
echo "=== STEP 2: Docker Verification ===" | tee -a "$LOG_FILE"
echo "" >> "$REPORT_FILE"
echo "### 🐳 Docker Status" >> "$REPORT_FILE"

# Docker installato
((TOTAL_CHECKS++))
if command -v docker > /dev/null 2>&1; then
    DOCKER_VERSION=$(timeout_cmd 30 docker --version 2>/dev/null || echo "Version check failed")
    echo "- **Docker Version**: ✅ $DOCKER_VERSION" >> "$REPORT_FILE"
    handle_check_success "Docker Installation"
else
    echo "- **Docker Version**: ❌ Non installato" >> "$REPORT_FILE"
    handle_check_error "Docker Installation" 1
fi

# Docker service status
((TOTAL_CHECKS++))
if timeout_cmd 10 sudo_cmd systemctl is-active docker > /dev/null 2>&1; then
    echo "- **Docker Service**: ✅ Attivo" >> "$REPORT_FILE"
    handle_check_success "Docker Service"
else
    echo "- **Docker Service**: ❌ Non attivo" >> "$REPORT_FILE"
    handle_check_error "Docker Service" 1
fi

# Docker daemon test
((TOTAL_CHECKS++))
if timeout_cmd 60 sudo_cmd docker run --rm hello-world > /dev/null 2>&1; then
    echo "- **Docker Test**: ✅ Funzionante" >> "$REPORT_FILE"
    handle_check_success "Docker Functionality Test"
else
    echo "- **Docker Test**: ❌ Test fallito" >> "$REPORT_FILE"
    handle_check_error "Docker Functionality Test" 1
fi

# Docker Compose
((TOTAL_CHECKS++))
if command -v docker > /dev/null 2>&1 && timeout_cmd 30 docker compose version > /dev/null 2>&1; then
    COMPOSE_VERSION=$(timeout_cmd 30 docker compose version --short 2>/dev/null || echo "Version check failed")
    echo "- **Docker Compose**: ✅ $COMPOSE_VERSION" >> "$REPORT_FILE"
    handle_check_success "Docker Compose"
else
    echo "- **Docker Compose**: ❌ Non disponibile" >> "$REPORT_FILE"
    handle_check_error "Docker Compose" 1
fi

# 3. VERIFICA KUBERNETES TOOLS
echo "=== STEP 3: Kubernetes Tools Verification ===" | tee -a "$LOG_FILE"
echo "" >> "$REPORT_FILE"
echo "### ⚙️ Kubernetes Tools" >> "$REPORT_FILE"

# Check kubectl
((TOTAL_CHECKS++))
if command -v kubectl > /dev/null 2>&1; then
    VERSION=$(timeout_cmd 30 kubectl version --client --short 2>/dev/null | head -1 || echo "installed")
    echo "- **kubectl**: ✅ $VERSION" >> "$REPORT_FILE"
    handle_check_success "kubectl Installation"
else
    echo "- **kubectl**: ❌ Non installato" >> "$REPORT_FILE"
    handle_check_error "kubectl Installation" 1
fi

# Check minikube
((TOTAL_CHECKS++))
if command -v minikube > /dev/null 2>&1; then
    VERSION=$(timeout_cmd 30 minikube version --short 2>/dev/null || echo "installed")
    echo "- **minikube**: ✅ $VERSION" >> "$REPORT_FILE"
    handle_check_success "minikube Installation"
else
    echo "- **minikube**: ❌ Non installato" >> "$REPORT_FILE"
    handle_check_error "minikube Installation" 1
fi

# 4. VERIFICA CLUSTER KUBERNETES
echo "=== STEP 4: Kubernetes Cluster Verification ===" | tee -a "$LOG_FILE"
echo "" >> "$REPORT_FILE"
echo "### 🎯 Kubernetes Cluster" >> "$REPORT_FILE"

# Cluster reachability
((TOTAL_CHECKS++))
if timeout_cmd 60 kubectl cluster-info > /dev/null 2>&1; then
    echo "- **Cluster Status**: ✅ Attivo e raggiungibile" >> "$REPORT_FILE"
    handle_check_success "Cluster Reachability"

    # Cluster info details
    CLUSTER_INFO=$(timeout_cmd 60 kubectl cluster-info 2>/dev/null)
    echo "- **Cluster Info**:" >> "$REPORT_FILE"
    echo '```' >> "$REPORT_FILE"
    echo "$CLUSTER_INFO" >> "$REPORT_FILE"
    echo '```' >> "$REPORT_FILE"
else
    echo "- **Cluster Status**: ❌ Non raggiungibile" >> "$REPORT_FILE"
    handle_check_error "Cluster Reachability" 1
fi

# Node status
((TOTAL_CHECKS++))
if timeout_cmd 60 kubectl get nodes > /dev/null 2>&1; then
    NODE_COUNT=$(timeout_cmd 60 kubectl get nodes --no-headers | wc -l)
    READY_NODES=$(timeout_cmd 60 kubectl get nodes --no-headers | grep " Ready" | wc -l)
    echo "- **Nodi Totali**: $NODE_COUNT" >> "$REPORT_FILE"
    echo "- **Nodi Ready**: $READY_NODES/$NODE_COUNT" >> "$REPORT_FILE"

    if [ "$READY_NODES" = "$NODE_COUNT" ] && [ "$NODE_COUNT" -gt 0 ]; then
        handle_check_success "Node Status"
    else
        handle_check_warning "Node Status" "Non tutti i nodi sono Ready"
    fi
else
    echo "- **Node Status**: ❌ Verifica fallita" >> "$REPORT_FILE"
    handle_check_error "Node Status" 1
fi

# System pods status
((TOTAL_CHECKS++))
if timeout_cmd 60 kubectl get pods -n kube-system > /dev/null 2>&1; then
    TOTAL_PODS=$(timeout_cmd 60 kubectl get pods -n kube-system --no-headers | wc -l)
    RUNNING_PODS=$(timeout_cmd 60 kubectl get pods -n kube-system --no-headers | grep "Running" | wc -l)

    echo "- **System Pods**: $RUNNING_PODS/$TOTAL_PODS Running" >> "$REPORT_FILE"

    if [ "$RUNNING_PODS" = "$TOTAL_PODS" ]; then
        handle_check_success "System Pods Status"
    else
        handle_check_warning "System Pods Status" "Non tutti i system pods sono Running"
    fi
else
    echo "- **System Pods**: ❌ Verifica fallita" >> "$REPORT_FILE"
    handle_check_error "System Pods Status" 1
fi

# 5. VERIFICA NAMESPACES
echo "=== STEP 5: Namespaces Verification ===" | tee -a "$LOG_FILE"
echo "" >> "$REPORT_FILE"
echo "### 📁 Namespaces" >> "$REPORT_FILE"

declare -a REQUIRED_NAMESPACES=("insightlearn")

for namespace in "${REQUIRED_NAMESPACES[@]}"; do
    ((TOTAL_CHECKS++))
    if timeout_cmd 30 kubectl get namespace $namespace > /dev/null 2>&1; then
        echo "- **$namespace**: ✅ Esistente" >> "$REPORT_FILE"
        handle_check_success "Namespace $namespace"
    else
        echo "- **$namespace**: ❌ Mancante" >> "$REPORT_FILE"
        handle_check_error "Namespace $namespace" 1
    fi
done

# 6. VERIFICA MANIFEST FILES
echo "=== STEP 6: Manifest Files Verification ===" | tee -a "$LOG_FILE"
echo "" >> "$REPORT_FILE"
echo "### 📄 Manifest Files" >> "$REPORT_FILE"

declare -a REQUIRED_MANIFESTS=(
    "kubernetes/namespace.yaml:Namespace definition"
    "kubernetes/configmaps/app-config.yaml:Application configuration"
    "kubernetes/secrets/app-secrets.yaml:Secrets template"
    "kubernetes/deployments/web-deployment.yaml:Web and API deployments"
    "kubernetes/services/web-service.yaml:Service definitions"
    "kubernetes/ingress.yaml:Ingress configuration"
)

for manifest_info in "${REQUIRED_MANIFESTS[@]}"; do
    IFS=':' read -ra MANIFEST_PARTS <<< "$manifest_info"
    manifest="${MANIFEST_PARTS[0]}"
    description="${MANIFEST_PARTS[1]}"

    ((TOTAL_CHECKS++))
    if [ -f "$manifest" ]; then
        # Verifica validità YAML
        if timeout_cmd 10 kubectl apply --dry-run=client -f "$manifest" > /dev/null 2>&1; then
            echo "- **$(basename $manifest)**: ✅ Valido ($description)" >> "$REPORT_FILE"
            handle_check_success "Manifest $(basename $manifest)"
        else
            echo "- **$(basename $manifest)**: ⚠️ Presente ma non valido ($description)" >> "$REPORT_FILE"
            handle_check_warning "Manifest $(basename $manifest)" "YAML non valido"
        fi
    else
        echo "- **$(basename $manifest)**: ❌ Mancante ($description)" >> "$REPORT_FILE"
        handle_check_error "Manifest $(basename $manifest)" 1
    fi
done

# 7. VERIFICA DOCKER FILES
echo "=== STEP 7: Docker Files Verification ===" | tee -a "$LOG_FILE"
echo "" >> "$REPORT_FILE"
echo "### 🐳 Docker Files" >> "$REPORT_FILE"

declare -a DOCKER_FILES=(
    "docker/docker-compose.yml:Development environment"
)

for docker_info in "${DOCKER_FILES[@]}"; do
    IFS=':' read -ra DOCKER_PARTS <<< "$docker_info"
    dockerfile="${DOCKER_PARTS[0]}"
    description="${DOCKER_PARTS[1]}"

    ((TOTAL_CHECKS++))
    if [ -f "$dockerfile" ]; then
        # Per docker-compose, verifica validità
        if [[ "$dockerfile" == *"docker-compose.yml" ]] && command -v docker > /dev/null 2>&1; then
            if timeout_cmd 30 docker compose -f "$dockerfile" config > /dev/null 2>&1; then
                echo "- **$(basename $dockerfile)**: ✅ Valido ($description)" >> "$REPORT_FILE"
                handle_check_success "Docker file $(basename $dockerfile)"
            else
                echo "- **$(basename $dockerfile)**: ⚠️ Presente ma non valido ($description)" >> "$REPORT_FILE"
                handle_check_warning "Docker file $(basename $dockerfile)" "Configurazione non valida"
            fi
        else
            echo "- **$(basename $dockerfile)**: ✅ Presente ($description)" >> "$REPORT_FILE"
            handle_check_success "Docker file $(basename $dockerfile)"
        fi
    else
        echo "- **$(basename $dockerfile)**: ❌ Mancante ($description)" >> "$REPORT_FILE"
        handle_check_error "Docker file $(basename $dockerfile)" 1
    fi
done

# 8. VERIFICA SCRIPT HELPER
echo "=== STEP 8: Helper Scripts Verification ===" | tee -a "$LOG_FILE"
echo "" >> "$REPORT_FILE"
echo "### 🔧 Helper Scripts" >> "$REPORT_FILE"

declare -a HELPER_SCRIPTS=(
    "scripts/k8s-deploy.sh:Kubernetes deployment"
    "scripts/k8s-logs.sh:Log viewing"
    "scripts/docker-dev.sh:Development environment"
    "scripts/k8s-stop.sh:Stop deployment"
)

for script_info in "${HELPER_SCRIPTS[@]}"; do
    IFS=':' read -ra SCRIPT_PARTS <<< "$script_info"
    script="${SCRIPT_PARTS[0]}"
    description="${SCRIPT_PARTS[1]}"

    ((TOTAL_CHECKS++))
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            echo "- **$(basename $script)**: ✅ Executable ($description)" >> "$REPORT_FILE"
            handle_check_success "Script $(basename $script)"
        else
            echo "- **$(basename $script)**: ⚠️ Presente ma non executable ($description)" >> "$REPORT_FILE"
            handle_check_warning "Script $(basename $script)" "Non executable"
        fi
    else
        echo "- **$(basename $script)**: ❌ Mancante ($description)" >> "$REPORT_FILE"
        handle_check_error "Script $(basename $script)" 1
    fi
done

# 9. VERIFICA CONFIGURAZIONI AVANZATE
echo "=== STEP 9: Advanced Configuration Verification ===" | tee -a "$LOG_FILE"
echo "" >> "$REPORT_FILE"
echo "### ⚙️ Configurazioni Avanzate" >> "$REPORT_FILE"

# Swap status (deve essere disabilitato per K8s)
((TOTAL_CHECKS++))
if [ "$(cat /proc/swaps | wc -l)" -le 1 ]; then
    echo "- **Swap**: ✅ Disabilitato (richiesto per K8s)" >> "$REPORT_FILE"
    handle_check_success "Swap Configuration"
else
    echo "- **Swap**: ⚠️ Abilitato (dovrebbe essere disabilitato per K8s)" >> "$REPORT_FILE"
    handle_check_warning "Swap Configuration" "Swap abilitato"
fi

# IP forwarding
((TOTAL_CHECKS++))
IP_FORWARD=$(cat /proc/sys/net/ipv4/ip_forward)
if [ "$IP_FORWARD" = "1" ]; then
    echo "- **IP Forwarding**: ✅ Abilitato" >> "$REPORT_FILE"
    handle_check_success "IP Forwarding"
else
    echo "- **IP Forwarding**: ❌ Disabilitato" >> "$REPORT_FILE"
    handle_check_error "IP Forwarding" 1
fi

# Kernel modules
((TOTAL_CHECKS++))
if lsmod | grep -q "overlay" && lsmod | grep -q "br_netfilter"; then
    echo "- **Kernel Modules**: ✅ overlay e br_netfilter caricati" >> "$REPORT_FILE"
    handle_check_success "Kernel Modules"
else
    echo "- **Kernel Modules**: ❌ Moduli richiesti non caricati" >> "$REPORT_FILE"
    handle_check_error "Kernel Modules" 1
fi

# 10. GENERAZIONE STATISTICHE FINALI
echo "=== STEP 10: Final Statistics Generation ===" | tee -a "$LOG_FILE"
echo "" >> "$REPORT_FILE"
echo "## 📊 Statistiche Finali" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Calcola percentuali
if [ $TOTAL_CHECKS -gt 0 ]; then
    SUCCESS_RATE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    FAILURE_RATE=$((FAILED_CHECKS * 100 / TOTAL_CHECKS))
    WARNING_RATE=$((WARNING_CHECKS * 100 / TOTAL_CHECKS))
else
    SUCCESS_RATE=0
    FAILURE_RATE=0
    WARNING_RATE=0
fi

echo "- **Verifiche Totali**: $TOTAL_CHECKS" >> "$REPORT_FILE"
echo "- **Successi**: $PASSED_CHECKS ($SUCCESS_RATE%)" >> "$REPORT_FILE"
echo "- **Fallimenti**: $FAILED_CHECKS ($FAILURE_RATE%)" >> "$REPORT_FILE"
echo "- **Warning**: $WARNING_CHECKS ($WARNING_RATE%)" >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"

# Progress bar visuale
echo "### 📈 Progress Bar" >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"
printf "Successi  [" >> "$REPORT_FILE"
for i in $(seq 1 $((SUCCESS_RATE/2))); do printf "█" >> "$REPORT_FILE"; done
for i in $(seq $((SUCCESS_RATE/2 + 1)) 50); do printf "░" >> "$REPORT_FILE"; done
printf "] %d%%\n" $SUCCESS_RATE >> "$REPORT_FILE"

printf "Fallimenti[" >> "$REPORT_FILE"
for i in $(seq 1 $((FAILURE_RATE/2))); do printf "█" >> "$REPORT_FILE"; done
for i in $(seq $((FAILURE_RATE/2 + 1)) 50); do printf "░" >> "$REPORT_FILE"; done
printf "] %d%%\n" $FAILURE_RATE >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"

# Verdetto finale
echo "## 🎯 Verdetto Finale" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ $FAILED_CHECKS -eq 0 ]; then
    echo "### ✅ FASE 2A COMPLETATA CON SUCCESSO" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Il setup di Kubernetes e Docker è stato completato correttamente. L'ambiente è pronto per il deployment di InsightLearn.Cloud." >> "$REPORT_FILE"

    if [ $WARNING_CHECKS -gt 0 ]; then
        echo "" >> "$REPORT_FILE"
        echo "**Note**: $WARNING_CHECKS warning rilevati. Il sistema è funzionale ma potrebbero esserci ottimizzazioni da considerare." >> "$REPORT_FILE"
    fi

    echo "" >> "$REPORT_FILE"
    echo "### 🚀 Prossimi Passi Raccomandati" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "1. ✅ **Kubernetes cluster** → Ready per deployment" >> "$REPORT_FILE"
    echo "2. ✅ **Docker environment** → Configurato correttamente" >> "$REPORT_FILE"
    echo "3. 🔄 **Fase 3** → Procedere con Design System e UI Components" >> "$REPORT_FILE"
    echo "4. 🧪 **Test locale** → Eseguire \`./scripts/docker-dev.sh\` per ambiente development" >> "$REPORT_FILE"
    echo "5. 🚀 **Deploy test** → Eseguire \`./scripts/k8s-deploy.sh\` per test deploy" >> "$REPORT_FILE"

    FINAL_EXIT_CODE=0

elif [ $FAILED_CHECKS -le 3 ] && [ $SUCCESS_RATE -ge 80 ]; then
    echo "### ⚠️ FASE 2A PARZIALMENTE COMPLETATA" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "La maggior parte del setup è stata completata correttamente, ma ci sono $FAILED_CHECKS errori che necessitano correzione." >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "### 🔧 Azioni Correttive Necessarie" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "1. 🔍 **Analizzare i log** per identificare la causa degli errori" >> "$REPORT_FILE"
    echo "2. 🛠️ **Correggere i problemi** identificati nelle sezioni sopra" >> "$REPORT_FILE"
    echo "3. 🔄 **Rieseguire la verifica** dopo le correzioni" >> "$REPORT_FILE"
    echo "4. ✅ **Procedere** solo dopo aver risolto tutti gli errori critici" >> "$REPORT_FILE"

    FINAL_EXIT_CODE=1

else
    echo "### ❌ FASE 2A RICHIEDE INTERVENTO SIGNIFICATIVO" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Sono stati rilevati $FAILED_CHECKS errori critici ($FAILURE_RATE% di fallimento). Il setup non è ancora pronto per la produzione." >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "### 🚨 Azioni Immediate Richieste" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "1. 🛑 **FERMARE** lo sviluppo fino alla risoluzione degli errori" >> "$REPORT_FILE"
    echo "2. 📋 **RIVEDERE** i log dettagliati in \`$LOG_FILE\`" >> "$REPORT_FILE"
    echo "3. 🔄 **RIPETERE** gli step di installazione falliti" >> "$REPORT_FILE"
    echo "4. 🆘 **CONSIDERARE** reinstallazione completa se necessario" >> "$REPORT_FILE"
    echo "5. ✅ **VERIFICARE** nuovamente prima di procedere" >> "$REPORT_FILE"

    FINAL_EXIT_CODE=2
fi

# Informazioni tecniche finali
echo "" >> "$REPORT_FILE"
echo "## 📋 Informazioni Tecniche" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "- **Log File**: \`$LOG_FILE\`" >> "$REPORT_FILE"
echo "- **Report File**: \`$REPORT_FILE\`" >> "$REPORT_FILE"
echo "- **Timestamp Fine Verifica**: $(date '+%Y-%m-%d %H:%M:%S')" >> "$REPORT_FILE"
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "- **Durata Verifica**: $(date -d@$DURATION -u +%H:%M:%S)" >> "$REPORT_FILE"

# Final console output
echo "" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "FASE 2A VERIFICATION COMPLETED" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "Total Checks: $TOTAL_CHECKS" | tee -a "$LOG_FILE"
echo "Passed: $PASSED_CHECKS ($SUCCESS_RATE%)" | tee -a "$LOG_FILE"
echo "Failed: $FAILED_CHECKS ($FAILURE_RATE%)" | tee -a "$LOG_FILE"
echo "Warnings: $WARNING_CHECKS ($WARNING_RATE%)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "📊 Report dettagliato salvato in: $REPORT_FILE" | tee -a "$LOG_FILE"
echo "📝 Log completo salvato in: $LOG_FILE" | tee -a "$LOG_FILE"

if [ $FINAL_EXIT_CODE -eq 0 ]; then
    echo "✅ VERIFICA COMPLETATA CON SUCCESSO - Pronto per Fase 3" | tee -a "$LOG_FILE"
elif [ $FINAL_EXIT_CODE -eq 1 ]; then
    echo "⚠️ VERIFICA PARZIALE - Correzioni minori necessarie" | tee -a "$LOG_FILE"
else
    echo "❌ VERIFICA FALLITA - Interventi significativi richiesti" | tee -a "$LOG_FILE"
fi

echo "=== [$(date)] FASE 2A VERIFICATION END ===" | tee -a "$LOG_FILE"

exit $FINAL_EXIT_CODE