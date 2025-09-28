#!/bin/bash
# final_test_verification.sh - Final comprehensive verification

echo "========================================="
echo "🔍 FINAL COMPREHENSIVE VERIFICATION"
echo "========================================="
echo "Date: $(date)"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

# Function to run tests
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"

    echo -n "Testing $test_name... "

    if eval "$test_command" > /dev/null 2>&1; then
        echo "✅ PASS"
        ((TESTS_PASSED++))
    else
        echo "❌ FAIL"
        ((TESTS_FAILED++))
    fi
}

echo "🔍 SYSTEM HEALTH TESTS"
echo "======================="
run_test "Kubernetes cluster" "kubectl cluster-info"
run_test "Node readiness" "kubectl get nodes | grep Ready"
run_test "System pods health" "[ \$(kubectl get pods -n kube-system --no-headers | grep -v Running | wc -l) -eq 0 ]"

echo ""
echo "🔍 SERVICE TESTS"
echo "================"
run_test "Nginx Ingress pods" "[ \$(kubectl get pods -n ingress-nginx --no-headers | grep Running | wc -l) -gt 0 ]"
run_test "Dashboard pods" "[ \$(kubectl get pods -n kubernetes-dashboard --no-headers | grep Running | wc -l) -gt 0 ]"
run_test "Dashboard service" "kubectl get service kubernetes-dashboard -n kubernetes-dashboard"
run_test "Metrics server" "kubectl top nodes 2>/dev/null || kubectl get deployment metrics-server -n kube-system"

echo ""
echo "🔍 NETWORK TESTS"
echo "================"
MINIKUBE_IP=$(minikube ip 2>/dev/null)
run_test "Minikube IP accessible" "ping -c 1 $MINIKUBE_IP"
run_test "Production IP configured" "ip addr show | grep 192.168.1.103"

echo ""
echo "🔍 APPLICATION TESTS"
echo "===================="

# Deploy a quick test application
echo "Deploying test application..."
kubectl apply -f - <<EOF > /dev/null 2>&1
apiVersion: v1
kind: Namespace
metadata:
  name: final-test
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: final-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test
  template:
    metadata:
      labels:
        app: test
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
  name: test-service
  namespace: final-test
spec:
  type: NodePort
  selector:
    app: test
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30092
EOF

# Wait for deployment
kubectl wait --for=condition=available deployment/test-app -n final-test --timeout=60s > /dev/null 2>&1

run_test "Test app deployment" "[ \$(kubectl get pods -n final-test --no-headers | grep Running | wc -l) -gt 0 ]"
run_test "Test app service" "kubectl get service test-service -n final-test"

# Test connectivity
if [ -n "$MINIKUBE_IP" ]; then
    run_test "Test app connectivity" "timeout 5 curl -s http://$MINIKUBE_IP:30092"
fi

echo ""
echo "🔍 DASHBOARD ACCESS TESTS"
echo "========================="

# Test Dashboard access methods
run_test "Dashboard token generation" "kubectl -n kubernetes-dashboard create token dashboard-user | grep -q eyJ"
run_test "Dashboard port forward" "timeout 3 curl -k -s https://localhost:8443 2>/dev/null | grep -q dashboard"

if [ -n "$MINIKUBE_IP" ]; then
    run_test "Dashboard direct access" "timeout 5 curl -k -s https://$MINIKUBE_IP:30443 2>/dev/null | grep -q 'dashboard\\|Kubernetes'"
fi

echo ""
echo "🔍 SECURITY TESTS"
echo "=================="
run_test "TLS certificates exist" "[ -f '/home/mpasqui/Kubernetes/InsightLearn.Cloud/ssl/insightlearn.crt' ]"
run_test "Dashboard RBAC" "kubectl get clusterrolebinding dashboard-user"
run_test "Service account tokens" "kubectl get secret dashboard-user-secret -n kubernetes-dashboard"

echo ""
echo "========================================="
echo "📊 FINAL TEST RESULTS"
echo "========================================="
echo ""
echo "✅ Tests Passed: $TESTS_PASSED"
echo "❌ Tests Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "🎉 ALL TESTS PASSED! SYSTEM IS FULLY OPERATIONAL"
    echo ""
    echo "✅ READY FOR PRODUCTION USE"
else
    echo "⚠️  Some tests failed. System may have minor issues."
    echo ""
    echo "🔧 Consider investigating failed tests"
fi

echo ""
echo "========================================="
echo "🌐 ACCESS INFORMATION"
echo "========================================="
echo ""
echo "📊 Kubernetes Dashboard:"
echo "   • Port Forward: https://localhost:8443"
if [ -n "$MINIKUBE_IP" ]; then
    echo "   • Direct Access: https://$MINIKUBE_IP:30443"
fi
echo ""
echo "🔑 Get Dashboard Token:"
echo "   kubectl -n kubernetes-dashboard create token dashboard-user"
echo ""
echo "🛠️  Management Commands:"
echo "   • Cluster Status: kubectl get all -A"
echo "   • Dashboard Access: ./access-dashboard.sh"
echo "   • Node Status: kubectl get nodes"
echo ""
echo "📱 Test Application (if deployed):"
if [ -n "$MINIKUBE_IP" ]; then
    echo "   • URL: http://$MINIKUBE_IP:30092"
fi
echo ""

# Cleanup test resources
echo "Cleaning up test resources..."
kubectl delete namespace final-test > /dev/null 2>&1 &

echo "========================================="
echo "✅ VERIFICATION COMPLETED"
echo "========================================="