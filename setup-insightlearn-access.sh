#!/bin/bash

echo "🚀 Configurazione accesso InsightLearn su https://192.168.1.103"
echo "============================================================"

# Ottieni IP di Minikube
MINIKUBE_IP=$(minikube ip)
echo "✅ Minikube IP: $MINIKUBE_IP"

# Ottieni IP del LoadBalancer Ingress
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [ -z "$INGRESS_IP" ]; then
    echo "⚠️ LoadBalancer IP non disponibile, uso NodePort..."
    INGRESS_PORT=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
    echo "✅ NodePort HTTPS: $INGRESS_PORT"

    # Setup port forward da 192.168.1.103:443 a Minikube
    echo ""
    echo "📌 Per accedere da https://192.168.1.103:"
    echo ""
    echo "OPZIONE 1: Port Forward (Raccomandato)"
    echo "---------------------------------------"
    echo "sudo socat TCP4-LISTEN:443,bind=192.168.1.103,fork TCP4:$MINIKUBE_IP:$INGRESS_PORT &"
    echo ""
    echo "OPZIONE 2: iptables redirect"
    echo "-----------------------------"
    echo "sudo iptables -t nat -A OUTPUT -d 192.168.1.103 -p tcp --dport 443 -j DNAT --to-destination $MINIKUBE_IP:$INGRESS_PORT"
    echo "sudo iptables -t nat -A PREROUTING -d 192.168.1.103 -p tcp --dport 443 -j DNAT --to-destination $MINIKUBE_IP:$INGRESS_PORT"
    echo ""
else
    echo "✅ Ingress LoadBalancer IP: $INGRESS_IP"
fi

echo ""
echo "📝 Aggiungi questa riga a /etc/hosts:"
echo "192.168.1.103 insightlearn.local"
echo ""
echo "oppure usa:"
echo "echo '192.168.1.103 insightlearn.local' | sudo tee -a /etc/hosts"
echo ""

# Verifica stato pods
echo "📊 Stato Deployment:"
kubectl get pods -n insightlearn

echo ""
echo "🌐 Servizi disponibili:"
kubectl get svc -n insightlearn

echo ""
echo "🔐 Ingress configurato:"
kubectl get ingress -n insightlearn

echo ""
echo "✅ Setup completato!"
echo ""
echo "Per attivare l'accesso HTTPS su 192.168.1.103, esegui:"
echo "sudo socat TCP4-LISTEN:443,bind=192.168.1.103,fork TCP4:$MINIKUBE_IP:$INGRESS_PORT &"
echo ""
echo "Poi accedi a: https://192.168.1.103"