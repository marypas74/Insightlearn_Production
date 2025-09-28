#!/bin/bash
# immediate_dashboard_fix.sh - Fix Dashboard access immediately

echo "🚨 IMMEDIATE DASHBOARD FIX"
echo "=========================="

echo "1. Current Dashboard Service Status:"
kubectl get service kubernetes-dashboard -n kubernetes-dashboard -o yaml

echo ""
echo "2. Dashboard Pod Status:"
kubectl get pods -n kubernetes-dashboard -l k8s-app=kubernetes-dashboard

echo ""
echo "3. Fixing Dashboard Service Configuration..."

# Delete and recreate the service properly
kubectl delete service kubernetes-dashboard -n kubernetes-dashboard

# Create proper service
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  ports:
  - port: 443
    protocol: TCP
    targetPort: 8443
    nodePort: 30443
  selector:
    k8s-app: kubernetes-dashboard
  type: NodePort
EOF

echo ""
echo "4. Waiting for service to be ready..."
sleep 5

echo ""
echo "5. New Service Status:"
kubectl get service kubernetes-dashboard -n kubernetes-dashboard

echo ""
echo "6. Testing connectivity..."
MINIKUBE_IP=$(minikube ip)

echo "Testing on Minikube IP: $MINIKUBE_IP:30443"
timeout 10 bash -c 'until nc -z 192.168.49.2 30443; do sleep 1; done' && echo "✅ Port 30443 is now open" || echo "❌ Port 30443 still not accessible"

echo ""
echo "7. Direct curl test:"
curl -k -I --max-time 5 "https://$MINIKUBE_IP:30443" 2>/dev/null || echo "Connection failed - checking port forward"

echo ""
echo "8. Alternative - Port Forward Method:"
echo "   Starting port forward..."
kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443 > /dev/null 2>&1 &
PF_PID=$!

echo "   Port forward PID: $PF_PID"
echo "   Testing port forward..."
sleep 3
curl -k -I --max-time 5 https://localhost:8443 2>/dev/null && echo "✅ Port forward working" || echo "❌ Port forward failed"

echo ""
echo "========================================="
echo "✅ DASHBOARD ACCESS SOLUTIONS:"
echo "========================================="
echo ""
echo "🔗 Method 1 (Port Forward - RECOMMENDED):"
echo "   URL: https://localhost:8443"
echo "   Status: Active (PID: $PF_PID)"
echo ""
echo "🔗 Method 2 (Minikube NodePort):"
echo "   URL: https://$MINIKUBE_IP:30443"
echo "   Note: May need certificate acceptance"
echo ""
echo "🔗 Method 3 (Minikube Tunnel):"
echo "   Run: minikube tunnel"
echo "   Then: https://127.0.0.1:30443"
echo ""
echo "🔑 Dashboard Token (copy this):"
echo "kubectl -n kubernetes-dashboard create token dashboard-user"
echo ""

# Generate token immediately
echo "🎫 CURRENT TOKEN:"
TOKEN=$(kubectl -n kubernetes-dashboard create token dashboard-user 2>/dev/null)
echo "$TOKEN"
echo "$TOKEN" > /tmp/dashboard_access_token.txt
echo ""
echo "Token saved to: /tmp/dashboard_access_token.txt"

echo ""
echo "========================================="
echo "🎯 RECOMMENDED ACTION:"
echo "========================================="
echo ""
echo "1. Open browser to: https://localhost:8443"
echo "2. Accept security certificate"
echo "3. Select 'Token' authentication"
echo "4. Paste the token above"
echo "5. Access Dashboard!"
echo ""
echo "If localhost doesn't work, try: https://$MINIKUBE_IP:30443"
echo "========================================="