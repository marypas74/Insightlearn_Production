#!/bin/bash

echo "🚀 Avvio di InsightLearn con accesso HTTPS"
echo "=========================================="

# Verifica che tutti i pod siano pronti
echo "⏳ Verificando che tutti i servizi siano pronti..."
kubectl wait --for=condition=ready pod -l app=insightlearn-backend -n insightlearn --timeout=60s
kubectl wait --for=condition=ready pod -l app=insightlearn-frontend -n insightlearn --timeout=60s

echo "✅ Tutti i servizi sono pronti!"

# Avvia Minikube tunnel in background per LoadBalancer access
echo "🔧 Avvio Minikube tunnel per accesso esterno..."
minikube tunnel &
TUNNEL_PID=$!

# Aspetta un momento per il tunnel
sleep 5

# Port forwarding per HTTPS su porta 443 (richiede sudo)
echo "🔐 Configurazione accesso HTTPS..."
echo "⚠️  Potrebbe essere richiesta la password sudo per il port forwarding HTTPS (porta 443)"

# Port forward per accesso diretto ai servizi
kubectl port-forward -n insightlearn service/insightlearn-frontend-service 8080:80 &
FRONTEND_PF_PID=$!

kubectl port-forward -n insightlearn service/insightlearn-backend-service 5000:5000 &
BACKEND_PF_PID=$!

# Port forward per HTTPS tramite ingress controller (richiede sudo)
kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 443:443 &
HTTPS_PF_PID=$!

kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 80:80 &
HTTP_PF_PID=$!

echo ""
echo "🎉 InsightLearn è ora accessibile!"
echo "=================================="
echo ""
echo "📍 ACCESSO LOCALE:"
echo "   • Frontend diretto:     http://localhost:8080"
echo "   • Backend API diretto:  http://localhost:5000"
echo "   • Health check:         http://localhost:5000/health"
echo ""
echo "📍 ACCESSO HTTPS (con certificato self-signed):"
echo "   • HTTPS localhost:      https://localhost"
echo "   • HTTP localhost:       http://localhost"
echo ""
echo "📍 ACCESSO DA RETE (192.168.1.103):"
echo "   • Aggiungi al file /etc/hosts su altri dispositivi:"
echo "     192.168.1.103 insightlearn.local"
echo "   • Poi accedi tramite:   https://insightlearn.local"
echo ""
echo "⚠️  NOTA: Il certificato SSL è self-signed."
echo "    Il browser mostrerà un avviso di sicurezza - clicca 'Avanzate' -> 'Procedi'"
echo ""
echo "🛑 Per fermare tutti i servizi, premi Ctrl+C"

# Funzione per cleanup quando viene interrotto
cleanup() {
    echo ""
    echo "🛑 Fermando tutti i servizi..."
    kill $TUNNEL_PID $FRONTEND_PF_PID $BACKEND_PF_PID $HTTPS_PF_PID $HTTP_PF_PID 2>/dev/null
    echo "✅ Cleanup completato!"
    exit 0
}

# Intercetta Ctrl+C
trap cleanup INT

# Mantieni lo script in esecuzione
echo "📊 Stato dei servizi (Ctrl+C per fermare):"
while true; do
    echo -n "."
    sleep 5
done