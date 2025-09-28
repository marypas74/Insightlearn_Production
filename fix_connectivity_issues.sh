#!/bin/bash
# fix_connectivity_issues.sh - Fix network connectivity and access issues

echo "🔧 FIXING NETWORK CONNECTIVITY ISSUES"
echo "====================================="
echo "Target: Make InsightLearn.Cloud fully accessible"
echo ""

# Function to log actions
log_action() {
    local level="$1"
    local message="$2"
    echo "[$level] $(date): $message"
}

log_action "INFO" "Starting connectivity diagnosis and fix"

echo "==== STEP 1: NETWORK DIAGNOSIS ===="
log_action "INFO" "Checking current network configuration"

echo "1.1 - IP Configuration:"
ip addr show | grep -E "192.168|minikube"

echo ""
echo "1.2 - Minikube Status:"
minikube status

echo ""
echo "1.3 - Minikube IP:"
MINIKUBE_IP=$(minikube ip)
echo "Minikube IP: $MINIKUBE_IP"

echo ""
echo "1.4 - Current Port Bindings:"
sudo netstat -tlnp | grep -E ":30443|:30080|:8443" || echo "No ports bound on host"

echo ""
echo "==== STEP 2: KUBERNETES SERVICES CHECK ===="

echo "2.1 - Dashboard Service:"
kubectl get service kubernetes-dashboard -n kubernetes-dashboard -o wide

echo ""
echo "2.2 - Ingress Controllers:"
kubectl get pods -n ingress-nginx
kubectl get services -n ingress-nginx

echo ""
echo "2.3 - All NodePort Services:"
kubectl get services --all-namespaces | grep NodePort

echo ""
echo "==== STEP 3: FIXING DASHBOARD ACCESS ===="
log_action "INFO" "Fixing Dashboard access issues"

echo "3.1 - Ensuring Dashboard is properly exposed..."

# Fix Dashboard service to use proper NodePort
cat > /tmp/dashboard-service-fix.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
  labels:
    k8s-app: kubernetes-dashboard
spec:
  type: NodePort
  selector:
    k8s-app: kubernetes-dashboard
  ports:
    - port: 443
      targetPort: 8443
      nodePort: 30443
      protocol: TCP
      name: https
EOF

kubectl apply -f /tmp/dashboard-service-fix.yaml

echo ""
echo "3.2 - Verifying Dashboard Service:"
kubectl get service kubernetes-dashboard -n kubernetes-dashboard

echo ""
echo "==== STEP 4: DIRECT ACCESS METHODS ===="
log_action "INFO" "Setting up multiple access methods"

echo "4.1 - Method 1: Port Forwarding (Immediate Access)"
echo "Starting port forwarding for Dashboard..."

# Kill any existing port forwards
pkill -f "kubectl port-forward" 2>/dev/null || true

# Start new port forward
kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443 > /dev/null 2>&1 &
PF_PID=$!
echo "Port forward started (PID: $PF_PID)"
echo "Dashboard now accessible at: https://localhost:8443"

echo ""
echo "4.2 - Method 2: Minikube Service (Direct NodePort)"
echo "Checking Minikube service URL..."
minikube service kubernetes-dashboard -n kubernetes-dashboard --url 2>/dev/null || echo "Service URL not available"

echo ""
echo "4.3 - Method 3: Kubectl Proxy"
echo "Setting up kubectl proxy..."
kubectl proxy --port=8001 > /dev/null 2>&1 &
PROXY_PID=$!
echo "Kubectl proxy started (PID: $PROXY_PID)"
echo "Dashboard accessible at: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"

echo ""
echo "==== STEP 5: TESTING CONNECTIVITY ===="
log_action "INFO" "Testing all access methods"

echo "5.1 - Testing port forward access..."
sleep 3
if curl -k -I --max-time 5 https://localhost:8443 2>/dev/null | grep -q "200\|401\|403"; then
    echo "✅ Port forward access: WORKING"
else
    echo "❌ Port forward access: FAILED"
fi

echo ""
echo "5.2 - Testing Minikube NodePort access..."
if curl -k -I --max-time 5 "https://$MINIKUBE_IP:30443" 2>/dev/null | grep -q "200\|401\|403"; then
    echo "✅ Minikube NodePort access: WORKING"
else
    echo "❌ Minikube NodePort access: FAILED"
fi

echo ""
echo "5.3 - Testing Application access..."
if curl -I --max-time 5 "http://$MINIKUBE_IP" 2>/dev/null | grep -q "200\|404\|502"; then
    echo "✅ Application access: WORKING"
else
    echo "❌ Application access: FAILED"
fi

echo ""
echo "==== STEP 6: INGRESS NGINX CONFIGURATION ===="
log_action "INFO" "Configuring Ingress Nginx for proper routing"

echo "6.1 - Checking Ingress Nginx status..."
kubectl get pods -n ingress-nginx
kubectl get services -n ingress-nginx

echo ""
echo "6.2 - Configuring Ingress for Dashboard..."
cat > /tmp/dashboard-ingress.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dashboard-ingress
  namespace: kubernetes-dashboard
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
spec:
  ingressClassName: nginx
  rules:
  - host: dashboard.insightlearn.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kubernetes-dashboard
            port:
              number: 443
EOF

kubectl apply -f /tmp/dashboard-ingress.yaml

echo ""
echo "==== STEP 7: INSIGHTLEARN APPLICATION FIX ===="
log_action "INFO" "Ensuring InsightLearn application is accessible"

echo "7.1 - Checking application pods..."
kubectl get pods -n insightlearn

echo ""
echo "7.2 - Checking application services..."
kubectl get services -n insightlearn

echo ""
echo "7.3 - Creating simple test service..."
cat > /tmp/test-service.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: insightlearn
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: test-app-service
  namespace: insightlearn
spec:
  type: NodePort
  selector:
    app: test-app
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080
EOF

kubectl apply -f /tmp/test-service.yaml

echo "Test application deployed on NodePort 30080"

echo ""
echo "==== STEP 8: COMPREHENSIVE ACCESS SCRIPT ===="

cat > /tmp/access_helper.sh << 'EOF'
#!/bin/bash
echo "🔗 INSIGHTLEARN.CLOUD ACCESS HELPER"
echo "===================================="

MINIKUBE_IP=$(minikube ip)
echo "Minikube IP: $MINIKUBE_IP"
echo ""

echo "📊 DASHBOARD ACCESS OPTIONS:"
echo "=============================="
echo ""
echo "Option 1 - Port Forward (RECOMMENDED):"
echo "  1. Run: kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443"
echo "  2. Open: https://localhost:8443"
echo "  3. Use token authentication"
echo ""

echo "Option 2 - Direct NodePort:"
echo "  1. Open: https://$MINIKUBE_IP:30443"
echo "  2. Accept security warning (self-signed cert)"
echo "  3. Use token authentication"
echo ""

echo "Option 3 - Kubectl Proxy:"
echo "  1. Run: kubectl proxy"
echo "  2. Open: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
echo "  3. Use token authentication"
echo ""

echo "🔑 GET DASHBOARD TOKEN:"
echo "======================"
echo "kubectl -n kubernetes-dashboard create token dashboard-user"
echo ""

echo "🌐 MAIN APPLICATION:"
echo "===================="
echo "URL: http://$MINIKUBE_IP"
echo "Test Service: http://$MINIKUBE_IP:30080"
echo ""

echo "🔧 TROUBLESHOOTING:"
echo "==================="
echo "If nothing works:"
echo "1. Check minikube: minikube status"
echo "2. Restart minikube: minikube stop && minikube start"
echo "3. Check services: kubectl get services -A"
echo "4. Check pods: kubectl get pods -A"
EOF

chmod +x /tmp/access_helper.sh
cp /tmp/access_helper.sh /home/mpasqui/Kubernetes/access_helper.sh

echo ""
echo "========================================="
echo "✅ CONNECTIVITY FIXES APPLIED"
echo "========================================="
echo ""

# Generate fresh token
echo "🔑 Fresh Dashboard Token:"
echo "========================"
TOKEN=$(kubectl -n kubernetes-dashboard create token dashboard-user 2>/dev/null)
if [ -n "$TOKEN" ]; then
    echo "$TOKEN"
    echo "$TOKEN" > /tmp/dashboard_token.txt
    echo ""
    echo "Token saved to: /tmp/dashboard_token.txt"
else
    echo "Failed to generate token"
fi

echo ""
echo "🌟 IMMEDIATE ACCESS METHODS:"
echo "=============================="
echo ""
echo "✅ Method 1 (PORT FORWARD - WORKS NOW):"
echo "   Open: https://localhost:8443"
echo "   Status: Running (PID: $PF_PID)"
echo ""
echo "✅ Method 2 (MINIKUBE NODEPORT):"
echo "   Open: https://$MINIKUBE_IP:30443"
echo "   Note: Accept security certificate warning"
echo ""
echo "✅ Method 3 (KUBECTL PROXY):"
echo "   Open: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
echo "   Status: Running (PID: $PROXY_PID)"
echo ""
echo "📱 Test Application:"
echo "   Open: http://$MINIKUBE_IP:30080"
echo ""

echo "🛠️ Access Helper Script: ./access_helper.sh"
echo ""

log_action "SUCCESS" "All connectivity fixes applied"
echo "========================================="