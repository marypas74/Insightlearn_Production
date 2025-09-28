#!/bin/bash
# Kubernetes deployment script

set -e

echo "🚀 Deploying InsightLearn.Cloud to Kubernetes..."

# Apply namespace
kubectl apply -f kubernetes/namespace.yaml

# Apply configmaps
kubectl apply -f kubernetes/configmaps/

# Apply secrets (make sure to update with real values first)
kubectl apply -f kubernetes/secrets/

# Apply deployments
kubectl apply -f kubernetes/deployments/

# Apply services
kubectl apply -f kubernetes/services/

# Apply ingress
kubectl apply -f kubernetes/ingress.yaml

echo "✅ Deployment complete!"
echo "📊 Checking status..."

kubectl get pods -n insightlearn
kubectl get services -n insightlearn
kubectl get ingress -n insightlearn
