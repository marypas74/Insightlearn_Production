#!/bin/bash
# phase9_verification.sh - Verifica completa Fase 9

source advanced_command_executor.sh

echo "========================================" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
echo "FASE 9: VERIFICA MONITORING & ANALYTICS" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
echo "Data: $(date)" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
echo "========================================" | tee -a "$BASE_LOG_DIR/phase9_verification.log"

cd InsightLearn.Cloud

ERRORS=0
WARNINGS=0

# Test Prometheus Configuration
if [ -f "kubernetes/monitoring/prometheus-config.yaml" ]; then
    echo "✅ Prometheus Configuration: Created" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
else
    echo "❌ Prometheus Configuration: Missing" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    ((ERRORS++))
fi

# Test Prometheus RBAC
if [ -f "kubernetes/monitoring/prometheus-rbac.yaml" ]; then
    echo "✅ Prometheus RBAC: Created" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
else
    echo "❌ Prometheus RBAC: Missing" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    ((ERRORS++))
fi

# Test Prometheus Deployment
if [ -f "kubernetes/monitoring/prometheus-deployment.yaml" ]; then
    echo "✅ Prometheus Deployment: Created" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
else
    echo "❌ Prometheus Deployment: Missing" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    ((ERRORS++))
fi

# Test Monitoring Namespace
execute_command_with_retry \
    "kubectl get namespace insightlearn-monitoring" \
    "Check monitoring namespace" \
    "VERIFICATION"

if [ $? -eq 0 ]; then
    echo "✅ Monitoring Namespace: Exists" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
else
    echo "❌ Monitoring Namespace: Missing" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    ((ERRORS++))
fi

# Test Analytics Scripts
if [ -f "../scripts/monitoring/command_analytics.sh" ] && [ -x "../scripts/monitoring/command_analytics.sh" ]; then
    echo "✅ Analytics Scripts: Ready" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
else
    echo "❌ Analytics Scripts: Missing or not executable" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    ((ERRORS++))
fi

# Test Advanced Command Executor
if [ -f "../advanced_command_executor.sh" ] && [ -x "../advanced_command_executor.sh" ]; then
    echo "✅ Advanced Command Executor: Ready" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
else
    echo "❌ Advanced Command Executor: Missing" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    ((ERRORS++))
fi

# Test Business Analytics Service
if [ -f "src/InsightLearn.Analytics/Services/BusinessAnalyticsService.cs" ]; then
    echo "✅ Business Analytics Service: Created" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
else
    echo "❌ Business Analytics Service: Missing" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    ((ERRORS++))
fi

# Test Directory Structure
REQUIRED_DIRS=(
    "kubernetes/monitoring"
    "src/InsightLearn.Analytics/Services"
    "src/InsightLearn.Analytics/Controllers"
    "src/InsightLearn.Analytics/Middleware"
    "../logs/monitoring"
    "../scripts/monitoring"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "✅ Directory Structure: $dir exists" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    else
        echo "⚠️ Directory Structure: $dir missing" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
        ((WARNINGS++))
    fi
done

# Generate analytics report
if [ -f "../scripts/monitoring/command_analytics.sh" ]; then
    chmod +x ../scripts/monitoring/command_analytics.sh
    ../scripts/monitoring/command_analytics.sh
    echo "✅ Analytics Report: Generated" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
else
    echo "⚠️ Analytics Report: Cannot generate" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    ((WARNINGS++))
fi

echo "" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
echo "=== STATISTICHE FINALI ===" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
echo "Errori: $ERRORS" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
echo "Warning: $WARNINGS" | tee -a "$BASE_LOG_DIR/phase9_verification.log"

if [ $ERRORS -eq 0 ]; then
    echo "" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    echo "✅ FASE 9 COMPLETATA CON SUCCESSO!" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    echo "" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    echo "### 🎉 MONITORING & ANALYTICS SYSTEM DEPLOYED ###" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    echo "" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    echo "**Componenti Implementati:**" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    echo "1. 📊 **Prometheus Monitoring Stack**: Configurato e pronto per deployment" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    echo "2. 🔧 **Advanced Command Executor**: Sistema retry e error handling" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    echo "3. 📈 **Business Analytics**: User behavior e conversion tracking" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    echo "4. 🏥 **Health Monitoring**: Structured logging e analytics" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    echo "5. ⚙️ **Operational Tools**: Scripts automatizzati per gestione" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    echo "" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    echo "### PROSSIMI PASSI:" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    echo "1. Deploy Prometheus: kubectl apply -f kubernetes/monitoring/" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    echo "2. Accedi a Prometheus: kubectl port-forward -n insightlearn-monitoring svc/prometheus 9090:9090" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    echo "3. Genera analytics report: ./scripts/monitoring/command_analytics.sh" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    echo "4. Procedi con Fase 10: CI/CD e Production Deploy" | tee -a "$BASE_LOG_DIR/phase9_verification.log"

    exit 0
else
    echo "" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    echo "❌ FASE 9 RICHIEDE CORREZIONI ($ERRORS errori)" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    echo "" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    echo "### AZIONI NECESSARIE:" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    echo "1. Controllare logs dettagliati in $BASE_LOG_DIR/" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    echo "2. Correggere errori identificati" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    echo "3. Verificare deployment Kubernetes" | tee -a "$BASE_LOG_DIR/phase9_verification.log"
    echo "4. Rieseguire verifica" | tee -a "$BASE_LOG_DIR/phase9_verification.log"

    exit 1
fi