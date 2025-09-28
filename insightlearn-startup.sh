#!/bin/bash
# insightlearn-startup.sh - Script di avvio automatico per InsightLearn
# Ripristina tutta la configurazione al riavvio del server

set -e

LOGFILE="/home/mpasqui/Kubernetes/logs/startup.log"
mkdir -p "$(dirname "$LOGFILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

log "🚀 === AVVIO AUTOMATICO INSIGHTLEARN ==="

# 1. Verifica che Minikube sia installato
if ! command -v minikube &> /dev/null; then
    log "❌ Minikube non trovato!"
    exit 1
fi

# 2. Avvio Minikube se non è già running
log "🔄 Verificando stato Minikube..."
if ! minikube status | grep -q "Running"; then
    log "🔄 Avvio Minikube..."
    minikube start --driver=docker --memory=4096 --cpus=2
    log "✅ Minikube avviato"
else
    log "✅ Minikube già in esecuzione"
fi

# 3. Attesa che Kubernetes sia pronto
log "⏳ Attesa che Kubernetes sia pronto..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# 4. Verifica namespace insightlearn
log "📁 Verifica namespace insightlearn..."
if ! kubectl get namespace insightlearn &> /dev/null; then
    log "🔄 Creazione namespace insightlearn..."
    kubectl create namespace insightlearn
fi

# 5. Deploy di tutte le risorse InsightLearn
log "🚀 Deploy risorse InsightLearn..."

# Deploy componenti base
cd /home/mpasqui/Kubernetes/InsightLearn
if [ -f "k8s-manifests/namespace.yaml" ]; then
    kubectl apply -f k8s-manifests/namespace.yaml
fi
kubectl apply -f k8s-manifests/postgresql.yaml -n insightlearn
kubectl apply -f k8s-manifests/backend.yaml -n insightlearn
kubectl apply -f k8s-manifests/frontend.yaml -n insightlearn

# Deploy InsightLearn.Cloud
cd /home/mpasqui/Kubernetes
./complete_insightlearn_deployment.sh

# Deploy workload specifici
kubectl apply -f /home/mpasqui/Kubernetes/insightlearn-metrics-workloads.yaml

# Inizializzazione dati se necessario
if ! kubectl get job insightlearn-data-init -n insightlearn &> /dev/null; then
    log "📊 Inizializzazione dati InsightLearn..."
    kubectl apply -f /home/mpasqui/Kubernetes/insightlearn-data-init.yaml
fi

# 6. Attesa che tutti i pod siano pronti
log "⏳ Attesa che tutti i pod siano pronti..."
kubectl wait --for=condition=Ready pods --all -n insightlearn --timeout=600s

# 7. Setup port forwarding
log "🌐 Configurazione port forwarding..."

# Termina eventuali port forward esistenti
pkill -f "kubectl port-forward" 2>/dev/null || true
sleep 2

# Dashboard Kubernetes su porta 8443 (porta corretta del container: 9090)
nohup kubectl port-forward -n kubernetes-dashboard pod/kubernetes-dashboard-8694d4445c-m75wg 8443:9090 --address='0.0.0.0' > /dev/null 2>&1 &
log "✅ Dashboard Kubernetes: http://192.168.1.103:8443"

# InsightLearn HTTPS su porta 443 (standard, richiede sudo)
nohup sudo kubectl port-forward -n insightlearn service/nginx-proxy-service 443:443 --address='0.0.0.0' > /dev/null 2>&1 &
log "✅ InsightLearn HTTPS: https://192.168.1.103"

# Avvia Minikube tunnel per accesso diretto
nohup sudo minikube tunnel > /dev/null 2>&1 &
log "✅ Minikube tunnel attivo - Accesso diretto: https://192.168.49.2:30443"

# 8. Generazione token dashboard
log "🔑 Generazione token dashboard..."
sleep 5
TOKEN=$(kubectl -n kubernetes-dashboard create token dashboard-admin --duration=24h 2>/dev/null || echo "Token non generato")

# 9. Verifica finale
log "🔍 Verifica finale configurazione..."
PODS_COUNT=$(kubectl get pods -n insightlearn --no-headers | wc -l)
DEPLOYMENTS_COUNT=$(kubectl get deployments -n insightlearn --no-headers | wc -l)
SERVICES_COUNT=$(kubectl get services -n insightlearn --no-headers | wc -l)

log "📊 Riepilogo finale:"
log "   - Pods attivi: $PODS_COUNT"
log "   - Deployments: $DEPLOYMENTS_COUNT"
log "   - Services: $SERVICES_COUNT"

# 10. Salvataggio informazioni di accesso
cat > /home/mpasqui/Kubernetes/ACCESSO_RAPIDO.md << EOF
# 🎓 ACCESSO RAPIDO INSIGHTLEARN

## 🌐 URL di Accesso
- **Dashboard Kubernetes**: http://192.168.1.103:8443/#/workloads?namespace=insightlearn
- **InsightLearn HTTPS**: https://192.168.1.103
- **Accesso Diretto**: https://192.168.49.2:30443 (via Minikube)

## 🔑 Token Dashboard (valido 24h)
\`\`\`
$TOKEN
\`\`\`

## 📊 Stato Sistema
- Pods: $PODS_COUNT
- Deployments: $DEPLOYMENTS_COUNT
- Services: $SERVICES_COUNT
- Ultimo avvio: $(date)

## 🚀 Comandi Utili
\`\`\`bash
# Verifica stato
kubectl get pods -n insightlearn

# Riavvio servizi
sudo systemctl restart insightlearn

# Log di sistema
tail -f /home/mpasqui/Kubernetes/logs/startup.log
\`\`\`
EOF

log "✅ === AVVIO COMPLETATO ==="
log "🎯 Dashboard: http://192.168.1.103:8443/#/workloads?namespace=insightlearn"
log "🏠 InsightLearn HTTPS: https://192.168.1.103"
log "🔗 Accesso Diretto: https://192.168.49.2:30443"
log "📋 Token salvato in: /home/mpasqui/Kubernetes/ACCESSO_RAPIDO.md"

exit 0