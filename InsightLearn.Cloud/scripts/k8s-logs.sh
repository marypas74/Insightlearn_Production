#!/bin/bash
# Script to view logs from Kubernetes pods

NAMESPACE=${1:-insightlearn}
COMPONENT=${2:-web}

if [ "$COMPONENT" = "all" ]; then
    echo "🔍 Showing logs for all components..."
    kubectl logs -n $NAMESPACE -l app=insightlearn --tail=100 -f
else
    echo "🔍 Showing logs for $COMPONENT component..."
    kubectl logs -n $NAMESPACE -l app=insightlearn,component=$COMPONENT --tail=100 -f
fi
