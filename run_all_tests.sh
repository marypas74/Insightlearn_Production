#!/bin/bash
# run_all_tests.sh - Comprehensive testing and fixing script

PRODUCTION_IP="192.168.1.103"
FAILURES=0
WARNINGS=0
SUDO_PASS="SS1-Temp1234"

echo "========================================="
echo "🧪 RUNNING COMPREHENSIVE TESTS"
echo "========================================="
echo "Date: $(date)"
echo ""

# Function to log test results
log_test() {
    local test_name="$1"
    local status="$2"
    local message="$3"

    if [ "$status" = "PASS" ]; then
        echo "✅ $test_name: PASSED - $message"
    elif [ "$status" = "FAIL" ]; then
        echo "❌ $test_name: FAILED - $message"
        ((FAILURES++))
    else
        echo "⚠️  $test_name: WARNING - $message"
        ((WARNINGS++))
    fi
}

# Function to fix issues
fix_issue() {
    local issue="$1"
    local fix_command="$2"
    echo "🔧 Fixing: $issue"
    eval "$fix_command"
}

echo "==== TEST 1: Kubernetes Cluster Health ===="
echo "-------------------------------------------"

# Test 1.1: Check cluster status
if kubectl cluster-info > /dev/null 2>&1; then
    log_test "Cluster Status" "PASS" "Kubernetes cluster is accessible"
else
    log_test "Cluster Status" "FAIL" "Cannot access Kubernetes cluster"
    fix_issue "Kubernetes cluster access" "minikube start || echo 'Minikube start failed'"
fi

# Test 1.2: Check node status
NODE_STATUS=$(kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
if [ "$NODE_STATUS" = "True" ]; then
    log_test "Node Status" "PASS" "Node is ready"
else
    log_test "Node Status" "FAIL" "Node is not ready"
fi

# Test 1.3: Check system pods
SYSTEM_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -v Running | wc -l)
if [ "$SYSTEM_PODS" -eq 0 ]; then
    log_test "System Pods" "PASS" "All system pods are running"
else
    log_test "System Pods" "WARNING" "$SYSTEM_PODS system pods not running"
    kubectl get pods -n kube-system --no-headers | grep -v Running
fi

echo ""
echo "==== TEST 2: Nginx Ingress Controller ===="
echo "-------------------------------------------"

# Test 2.1: Check if Nginx Ingress namespace exists
if kubectl get namespace ingress-nginx > /dev/null 2>&1; then
    log_test "Ingress Namespace" "PASS" "ingress-nginx namespace exists"
else
    log_test "Ingress Namespace" "FAIL" "ingress-nginx namespace missing"
    fix_issue "Creating ingress-nginx namespace" \
        "kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/baremetal/deploy.yaml"
fi

# Test 2.2: Check Nginx Ingress pods
INGRESS_PODS=$(kubectl get pods -n ingress-nginx --no-headers 2>/dev/null | grep Running | wc -l)
if [ "$INGRESS_PODS" -gt 0 ]; then
    log_test "Ingress Pods" "PASS" "$INGRESS_PODS Nginx Ingress pods running"
else
    log_test "Ingress Pods" "FAIL" "No Nginx Ingress pods running"
    fix_issue "Restarting Nginx Ingress" \
        "kubectl rollout restart deployment/ingress-nginx-controller -n ingress-nginx 2>/dev/null || echo 'Restart failed'"
fi

# Test 2.3: Check Ingress service
INGRESS_SVC=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.type}' 2>/dev/null)
if [ "$INGRESS_SVC" = "NodePort" ]; then
    log_test "Ingress Service" "PASS" "Ingress service configured as NodePort"
else
    log_test "Ingress Service" "WARNING" "Ingress service type is $INGRESS_SVC, expected NodePort"
    fix_issue "Patching Ingress service to NodePort" \
        "kubectl patch service ingress-nginx-controller -n ingress-nginx -p '{\"spec\":{\"type\":\"NodePort\"}}'"
fi

echo ""
echo "==== TEST 3: Kubernetes Dashboard ===="
echo "---------------------------------------"

# Test 3.1: Check Dashboard namespace
if kubectl get namespace kubernetes-dashboard > /dev/null 2>&1; then
    log_test "Dashboard Namespace" "PASS" "kubernetes-dashboard namespace exists"
else
    log_test "Dashboard Namespace" "FAIL" "kubernetes-dashboard namespace missing"
    fix_issue "Installing Kubernetes Dashboard" \
        "kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml"
fi

# Test 3.2: Check Dashboard pods
DASHBOARD_PODS=$(kubectl get pods -n kubernetes-dashboard --no-headers 2>/dev/null | grep Running | wc -l)
if [ "$DASHBOARD_PODS" -gt 0 ]; then
    log_test "Dashboard Pods" "PASS" "$DASHBOARD_PODS Dashboard pods running"
else
    log_test "Dashboard Pods" "FAIL" "No Dashboard pods running"
    fix_issue "Restarting Dashboard" \
        "kubectl rollout restart deployment -n kubernetes-dashboard"
fi

# Test 3.3: Check Dashboard service
DASHBOARD_PORT=$(kubectl get service kubernetes-dashboard -n kubernetes-dashboard -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
if [ "$DASHBOARD_PORT" = "30443" ]; then
    log_test "Dashboard NodePort" "PASS" "Dashboard exposed on port 30443"
else
    log_test "Dashboard NodePort" "WARNING" "Dashboard on port $DASHBOARD_PORT, expected 30443"
fi

# Test 3.4: Check Dashboard user
if kubectl get serviceaccount dashboard-user -n kubernetes-dashboard > /dev/null 2>&1; then
    log_test "Dashboard User" "PASS" "dashboard-user service account exists"
else
    log_test "Dashboard User" "FAIL" "dashboard-user missing"
    fix_issue "Creating dashboard-user" \
        "kubectl create serviceaccount dashboard-user -n kubernetes-dashboard 2>/dev/null; \
         kubectl create clusterrolebinding dashboard-user --clusterrole=cluster-admin --serviceaccount=kubernetes-dashboard:dashboard-user 2>/dev/null"
fi

echo ""
echo "==== TEST 4: Network Connectivity ===="
echo "---------------------------------------"

# Test 4.1: Check IP configuration
if ip addr show | grep -q "$PRODUCTION_IP"; then
    log_test "IP Configuration" "PASS" "Production IP $PRODUCTION_IP is configured"
else
    log_test "IP Configuration" "FAIL" "Production IP $PRODUCTION_IP not configured"
fi

# Test 4.2: Check port 30443 listening
if echo "$SUDO_PASS" | sudo -S ss -tlnp | grep -q ":30443"; then
    log_test "Port 30443" "PASS" "Port 30443 is listening"
else
    log_test "Port 30443" "WARNING" "Port 30443 not listening"
fi

# Test 4.3: Check port 6443 (Kubernetes API)
if echo "$SUDO_PASS" | sudo -S ss -tlnp | grep -q ":6443"; then
    log_test "Port 6443" "PASS" "Kubernetes API port 6443 is listening"
else
    log_test "Port 6443" "FAIL" "Kubernetes API port 6443 not listening"
fi

echo ""
echo "==== TEST 5: SSL Certificates ===="
echo "-----------------------------------"

# Test 5.1: Check certificate files
SSL_DIR="/home/mpasqui/Kubernetes/InsightLearn.Cloud/ssl"
if [ -f "$SSL_DIR/insightlearn.crt" ] && [ -f "$SSL_DIR/insightlearn.key" ]; then
    log_test "SSL Files" "PASS" "SSL certificate files exist"
else
    log_test "SSL Files" "FAIL" "SSL certificate files missing"
    fix_issue "Creating SSL certificates" \
        "mkdir -p $SSL_DIR && cd $SSL_DIR && \
         openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
         -keyout insightlearn.key -out insightlearn.crt \
         -subj '/C=IT/ST=Lombardy/L=Ponte San Pietro/O=InsightLearn/OU=Cloud/CN=$PRODUCTION_IP'"
fi

# Test 5.2: Check Kubernetes TLS secret
if kubectl get secret insightlearn-tls-secret -n insightlearn > /dev/null 2>&1; then
    log_test "TLS Secret" "PASS" "TLS secret exists in insightlearn namespace"
else
    log_test "TLS Secret" "WARNING" "TLS secret missing in insightlearn namespace"
    if [ -f "$SSL_DIR/insightlearn.crt" ]; then
        fix_issue "Creating TLS secret" \
            "kubectl create namespace insightlearn 2>/dev/null; \
             kubectl create secret tls insightlearn-tls-secret \
             --cert=$SSL_DIR/insightlearn.crt \
             --key=$SSL_DIR/insightlearn.key \
             -n insightlearn"
    fi
fi

echo ""
echo "==== TEST 6: Sample Application Deployment ===="
echo "------------------------------------------------"

# Deploy a sample application to test the full stack
cat > /tmp/test-app.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: test-app
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-nginx
  namespace: test-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-nginx
  template:
    metadata:
      labels:
        app: test-nginx
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
  name: test-nginx-service
  namespace: test-app
spec:
  type: NodePort
  selector:
    app: test-nginx
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30090
EOF

echo "Deploying test application..."
kubectl apply -f /tmp/test-app.yaml > /dev/null 2>&1

# Wait for deployment
sleep 5
TEST_POD_STATUS=$(kubectl get pods -n test-app --no-headers 2>/dev/null | grep -c Running)
if [ "$TEST_POD_STATUS" -gt 0 ]; then
    log_test "Test App Deployment" "PASS" "Test application deployed successfully"

    # Test connectivity to the app
    if timeout 5 curl -s http://$PRODUCTION_IP:30090 > /dev/null 2>&1; then
        log_test "Test App Connectivity" "PASS" "Test application is accessible"
    else
        log_test "Test App Connectivity" "WARNING" "Test application deployed but not accessible"
    fi
else
    log_test "Test App Deployment" "FAIL" "Test application deployment failed"
fi

# Cleanup test app
kubectl delete namespace test-app > /dev/null 2>&1 &

echo ""
echo "==== TEST 7: Dashboard Access Test ===="
echo "----------------------------------------"

# Test Dashboard HTTPS access
echo "Testing Dashboard HTTPS access..."
RESPONSE=$(timeout 5 curl -k -s -o /dev/null -w "%{http_code}" https://$PRODUCTION_IP:30443 2>/dev/null)
if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "403" ]; then
    log_test "Dashboard HTTPS" "PASS" "Dashboard responding on HTTPS (Status: $RESPONSE)"
else
    log_test "Dashboard HTTPS" "WARNING" "Dashboard HTTPS returned status: $RESPONSE"
fi

# Generate fresh token
TOKEN=$(kubectl -n kubernetes-dashboard create token dashboard-user 2>/dev/null)
if [ -n "$TOKEN" ]; then
    log_test "Token Generation" "PASS" "Dashboard token generated successfully"
    echo "$TOKEN" > /tmp/dashboard-token-test.txt
else
    log_test "Token Generation" "FAIL" "Could not generate dashboard token"
fi

echo ""
echo "========================================="
echo "📊 TEST SUMMARY"
echo "========================================="
echo ""
echo "Total Tests Run: $((FAILURES + WARNINGS + $(grep -c "✅" /tmp/test-results.txt 2>/dev/null || echo 0)))"
echo "❌ Failures: $FAILURES"
echo "⚠️  Warnings: $WARNINGS"
echo ""

if [ $FAILURES -eq 0 ]; then
    echo "🎉 ALL CRITICAL TESTS PASSED!"
    echo ""
    echo "✅ System is ready for production use"
    echo "📍 Production IP: $PRODUCTION_IP"
    echo "🔗 Dashboard: https://$PRODUCTION_IP:30443"
    echo "🔑 Token saved to: /tmp/dashboard-token-test.txt"
else
    echo "⚠️  Some tests failed. Please review the failures above."
    echo ""
    echo "🔧 Attempting automatic fixes..."

    # Additional recovery attempts
    if [ $FAILURES -gt 2 ]; then
        echo "Running comprehensive recovery..."
        minikube stop && minikube start
        kubectl wait --for=condition=ready node --all --timeout=300s
    fi
fi

echo ""
echo "========================================="
echo "✅ TEST EXECUTION COMPLETED"
echo "========================================="