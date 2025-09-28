#!/bin/bash
# Script to stop and clean up Kubernetes resources

echo "🛑 Stopping InsightLearn.Cloud Kubernetes deployment..."

# Delete all resources in insightlearn namespace
kubectl delete all --all -n insightlearn

# Optionally delete the namespace (uncomment if needed)
# kubectl delete namespace insightlearn

echo "✅ Cleanup complete!"
