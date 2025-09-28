#!/bin/bash
echo "🌐 Kubernetes Dashboard Access Helper"
echo "====================================="
echo ""

# Method 1: Direct NodePort access
MINIKUBE_IP=$(minikube ip 2>/dev/null)
if [ -n "$MINIKUBE_IP" ]; then
    echo "Method 1: Direct NodePort Access"
    echo "URL: https://$MINIKUBE_IP:30443"
    echo ""
fi

# Method 2: Port forwarding
echo "Method 2: Port Forwarding (Recommended)"
echo "Starting port forward..."
pkill -f "kubectl port-forward.*kubernetes-dashboard" 2>/dev/null
kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443 &
echo "URL: https://localhost:8443"
echo ""

# Method 3: Kubectl proxy
echo "Method 3: Kubectl Proxy"
echo "Run: kubectl proxy"
echo "URL: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
echo ""

# Generate token
echo "🔑 Dashboard Token:"
echo "=================="
kubectl -n kubernetes-dashboard create token dashboard-user
echo ""
echo "Copy the token above and use it to login to the Dashboard"
