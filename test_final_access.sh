#!/bin/bash
# test_final_access.sh - Test definitivo di tutti gli accessi

echo "🔍 TEST FINALE ACCESSI INSIGHTLEARN.CLOUD"
echo "=========================================="

MINIKUBE_IP=$(minikube ip)
echo "Minikube IP: $MINIKUBE_IP"
echo ""

echo "==== 1. KUBERNETES DASHBOARD ===="
echo "URL: http://$MINIKUBE_IP:30443"
echo "HTTPS URL: https://$MINIKUBE_IP:30443"
echo ""

# Test HTTP access (since service shows HTTP)
echo "Testing HTTP access..."
if curl -I --max-time 10 "http://$MINIKUBE_IP:30443" 2>/dev/null | grep -q "200\|401\|403\|302"; then
    echo "✅ HTTP Dashboard: ACCESSIBLE"
    echo "   Response:"
    curl -I --max-time 10 "http://$MINIKUBE_IP:30443" 2>/dev/null | head -3
else
    echo "❌ HTTP Dashboard: NOT ACCESSIBLE"
fi

echo ""
# Test HTTPS access
echo "Testing HTTPS access..."
if curl -k -I --max-time 10 "https://$MINIKUBE_IP:30443" 2>/dev/null | grep -q "200\|401\|403\|302"; then
    echo "✅ HTTPS Dashboard: ACCESSIBLE"
    echo "   Response:"
    curl -k -I --max-time 10 "https://$MINIKUBE_IP:30443" 2>/dev/null | head -3
else
    echo "❌ HTTPS Dashboard: NOT ACCESSIBLE"
fi

echo ""
echo "==== 2. MAIN APPLICATION ===="
echo "Testing main application..."

if curl -I --max-time 5 "http://$MINIKUBE_IP" 2>/dev/null | grep -q "200\|404\|502\|503"; then
    echo "✅ Main App: RESPONDING"
    echo "   Response:"
    curl -I --max-time 5 "http://$MINIKUBE_IP" 2>/dev/null | head -3
else
    echo "❌ Main App: NOT RESPONDING"
fi

echo ""
echo "==== 3. TEST APPLICATION ===="
echo "Testing simple test app on port 30081..."

# Create a simple working test app
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: simple-test
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: simple-test
  template:
    metadata:
      labels:
        app: simple-test
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: simple-test-service
  namespace: default
spec:
  type: NodePort
  selector:
    app: simple-test
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30081
EOF

echo "Waiting for test app..."
kubectl wait --for=condition=available deployment/simple-test --timeout=60s > /dev/null 2>&1

if curl -I --max-time 5 "http://$MINIKUBE_IP:30081" 2>/dev/null | grep -q "200"; then
    echo "✅ Simple Test App: WORKING on http://$MINIKUBE_IP:30081"
else
    echo "❌ Simple Test App: NOT WORKING"
fi

echo ""
echo "==== 4. PORT FORWARD TEST ===="
echo "Testing port forward method..."

# Kill existing port forwards
pkill -f "kubectl port-forward" 2>/dev/null || true

# Start fresh port forward
kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443 > /dev/null 2>&1 &
PF_PID=$!
echo "Port forward started (PID: $PF_PID)"

sleep 3
if curl -k -I --max-time 5 "https://localhost:8443" 2>/dev/null | grep -q "200\|401\|403"; then
    echo "✅ Port Forward: WORKING at https://localhost:8443"
else
    echo "❌ Port Forward: NOT WORKING"
fi

echo ""
echo "========================================="
echo "🎫 DASHBOARD ACCESS TOKEN:"
echo "========================================="
TOKEN=$(kubectl -n kubernetes-dashboard create token dashboard-user 2>/dev/null)
echo "$TOKEN"

echo ""
echo "========================================="
echo "📋 FINAL ACCESS SUMMARY"
echo "========================================="
echo ""
echo "🌐 WORKING ACCESS METHODS:"
echo ""

if curl -I --max-time 5 "http://$MINIKUBE_IP:30443" 2>/dev/null | grep -q "200\|401\|403\|302"; then
    echo "✅ Dashboard HTTP: http://$MINIKUBE_IP:30443"
fi

if curl -k -I --max-time 5 "https://$MINIKUBE_IP:30443" 2>/dev/null | grep -q "200\|401\|403\|302"; then
    echo "✅ Dashboard HTTPS: https://$MINIKUBE_IP:30443"
fi

if curl -k -I --max-time 5 "https://localhost:8443" 2>/dev/null | grep -q "200\|401\|403"; then
    echo "✅ Port Forward: https://localhost:8443"
fi

echo ""
echo "🔑 AUTHENTICATION:"
echo "   Method: Token"
echo "   Token: [Generated above]"
echo ""
echo "📱 TEST APPS:"
echo "   Simple Test: http://$MINIKUBE_IP:30081"
echo ""

echo "========================================="
echo "🎯 RECOMMENDED STEPS:"
echo "========================================="
echo ""
echo "1. Try: http://$MINIKUBE_IP:30443 (HTTP)"
echo "2. If that doesn't work, try: https://$MINIKUBE_IP:30443 (HTTPS)"
echo "3. If neither work, use: https://localhost:8443 (Port Forward)"
echo "4. Select 'Token' authentication and paste the token above"
echo "5. Access granted!"
echo ""

echo "🔧 TROUBLESHOOTING:"
echo "If nothing works:"
echo "   minikube stop && minikube start"
echo "   Then re-run this script"
echo ""

echo "========================================="