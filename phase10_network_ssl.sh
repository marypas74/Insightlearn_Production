#!/bin/bash
# phase10_network_ssl.sh - Configure networking and SSL for production

PRODUCTION_IP="192.168.1.103"
SUDO_PASS="SS1-Temp1234"

echo "=== [$(date)] Configurazione Network e SSL per Production ==="

# Crea directory per SSL
echo "🔒 Creazione certificati SSL..."
cd /home/mpasqui/Kubernetes/InsightLearn.Cloud
mkdir -p ssl

# Genera certificato SSL self-signed per production
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ssl/insightlearn.key \
    -out ssl/insightlearn.crt \
    -subj "/C=IT/ST=Lombardy/L=Ponte San Pietro/O=InsightLearn/OU=Cloud/CN=$PRODUCTION_IP" \
    -addext "subjectAltName=IP:$PRODUCTION_IP"

echo "✅ Certificato SSL creato"

# Crea secret Kubernetes per SSL
echo "🔧 Creazione Kubernetes secret per SSL..."
kubectl create namespace insightlearn 2>/dev/null || true
kubectl create secret tls insightlearn-tls-secret \
    --cert=ssl/insightlearn.crt \
    --key=ssl/insightlearn.key \
    -n insightlearn --dry-run=client -o yaml | kubectl apply -f -

# Configura iptables per port forwarding
echo "🌐 Configurazione iptables per production..."
cat > /tmp/configure-iptables.sh << 'EOF'
#!/bin/bash
PRODUCTION_IP="192.168.1.103"
HTTP_PORT="30080"
HTTPS_PORT="30443"

echo "Configurazione iptables per InsightLearn.Cloud Production"
echo "IP Production: $PRODUCTION_IP"

# Allow NodePort range for Kubernetes
sudo iptables -A INPUT -p tcp --dport 30000:32767 -j ACCEPT 2>/dev/null || true

# Allow Kubernetes internal traffic
sudo iptables -A INPUT -p tcp --dport 6443 -j ACCEPT 2>/dev/null || true
sudo iptables -A INPUT -p tcp --dport 2379:2380 -j ACCEPT 2>/dev/null || true
sudo iptables -A INPUT -p tcp --dport 10250:10252 -j ACCEPT 2>/dev/null || true
sudo iptables -A INPUT -p tcp --dport 10255 -j ACCEPT 2>/dev/null || true

# Save rules
sudo iptables-save > /tmp/iptables.rules 2>/dev/null || true

echo "✅ iptables configured for production"
EOF

chmod +x /tmp/configure-iptables.sh
echo "$SUDO_PASS" | sudo -S /tmp/configure-iptables.sh

# Configura hosts file
echo "📝 Configurazione /etc/hosts..."
cat > /tmp/hosts-config << EOF
# InsightLearn.Cloud Production
$PRODUCTION_IP insightlearn.local
$PRODUCTION_IP www.insightlearn.local
$PRODUCTION_IP api.insightlearn.local
$PRODUCTION_IP dashboard.insightlearn.local
EOF

# Aggiungi al file hosts se non già presente
grep -q "insightlearn.local" /etc/hosts || echo "$SUDO_PASS" | sudo -S tee -a /etc/hosts < /tmp/hosts-config

# Crea Ingress per production
echo "🚀 Creazione Ingress per production..."
cat > kubernetes/ingress-production.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: insightlearn-production-ingress
  namespace: insightlearn
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "false"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - "$PRODUCTION_IP"
    secretName: insightlearn-tls-secret
  rules:
  - host: "$PRODUCTION_IP"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: insightlearn-web-service
            port:
              number: 80
EOF

kubectl apply -f kubernetes/ingress-production.yaml

# Verifica configurazione
echo ""
echo "🔍 Verifica configurazione..."
echo "SSL Certificates:"
ls -la ssl/
echo ""
echo "Kubernetes Secrets:"
kubectl get secrets -n insightlearn
echo ""
echo "Ingress Configuration:"
kubectl get ingress -n insightlearn
echo ""
echo "Services accessible:"
echo "✅ Main App: https://$PRODUCTION_IP"
echo "✅ Dashboard: https://$PRODUCTION_IP:30443"
echo ""
echo "📊 Network configuration completed!"