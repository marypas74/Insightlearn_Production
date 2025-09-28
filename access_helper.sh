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
