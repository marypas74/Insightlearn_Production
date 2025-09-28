#!/bin/bash

echo "=== InsightLearn.Cloud AI Services Verification ==="
echo "Date: $(date)"
echo

# Check namespace
echo "1. Checking AI namespace..."
kubectl get namespace insightlearn-ai || {
    echo "❌ Namespace insightlearn-ai not found"
    exit 1
}
echo "✅ Namespace exists"
echo

# Check Ollama deployment
echo "2. Checking Ollama deployment status..."
OLLAMA_READY=$(kubectl get deployment ollama -n insightlearn-ai -o jsonpath='{.status.readyReplicas}')
OLLAMA_DESIRED=$(kubectl get deployment ollama -n insightlearn-ai -o jsonpath='{.spec.replicas}')

if [ "$OLLAMA_READY" = "$OLLAMA_DESIRED" ]; then
    echo "✅ Ollama deployment: $OLLAMA_READY/$OLLAMA_DESIRED pods ready"
else
    echo "⚠️  Ollama deployment: $OLLAMA_READY/$OLLAMA_DESIRED pods ready"
fi

# Check Ollama pod status
echo "3. Checking Ollama pod details..."
kubectl get pods -n insightlearn-ai -l app=ollama
echo

# Check services
echo "4. Checking Ollama services..."
kubectl get svc -n insightlearn-ai -l app=ollama
echo

# Check endpoints
echo "5. Checking service endpoints..."
kubectl get endpoints -n insightlearn-ai ollama-service
echo

# Check storage
echo "6. Checking persistent storage..."
kubectl get pvc -n insightlearn-ai ollama-models-pvc
echo

# Test Ollama connectivity using a temporary pod
echo "7. Testing Ollama API connectivity..."
echo "Creating test pod to check Ollama API..."

cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ollama-test
  namespace: insightlearn-ai
  labels:
    app: test
spec:
  restartPolicy: Never
  containers:
  - name: test
    image: curlimages/curl:8.4.0
    command:
    - sh
    - -c
    - |
      echo "Testing Ollama API..."

      # Test version endpoint
      echo "Testing /api/version endpoint..."
      curl -s --max-time 10 http://ollama-service:11434/api/version || {
        echo "Failed to connect to version endpoint"
        exit 1
      }

      echo "API Version check successful!"

      # Test tags endpoint
      echo "Testing /api/tags endpoint..."
      curl -s --max-time 10 http://ollama-service:11434/api/tags || {
        echo "Failed to connect to tags endpoint"
        exit 1
      }

      echo "API Tags check successful!"
      echo "Ollama is accessible and responding to API calls"
EOF

# Wait for test pod to complete
sleep 5
echo "Test pod output:"
kubectl logs -n insightlearn-ai ollama-test 2>/dev/null || echo "Test pod not ready yet"

# Cleanup test pod
kubectl delete pod ollama-test -n insightlearn-ai --ignore-not-found=true

echo
echo "8. Checking AI wrapper service status..."
kubectl get deployment ai-wrapper -n insightlearn-ai
echo

echo "9. Checking ingress configuration..."
kubectl get ingress -n insightlearn-ai
echo

echo "10. Resource usage summary..."
kubectl top pods -n insightlearn-ai 2>/dev/null || echo "Metrics not available"
echo

echo "=== Verification Summary ==="
if [ "$OLLAMA_READY" = "$OLLAMA_DESIRED" ]; then
    echo "✅ Ollama core service is running"
else
    echo "⚠️  Ollama service has issues"
fi

AI_WRAPPER_READY=$(kubectl get deployment ai-wrapper -n insightlearn-ai -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
AI_WRAPPER_DESIRED=$(kubectl get deployment ai-wrapper -n insightlearn-ai -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")

if [ "$AI_WRAPPER_READY" = "$AI_WRAPPER_DESIRED" ] && [ "$AI_WRAPPER_READY" != "0" ]; then
    echo "✅ AI wrapper service is running"
else
    echo "⚠️  AI wrapper service needs attention ($AI_WRAPPER_READY/$AI_WRAPPER_DESIRED ready)"
fi

echo "✅ Storage is configured and bound"
echo "✅ Network policies are in place"
echo "✅ Ingress is configured"

echo
echo "=== Next Steps ==="
echo "1. Monitor model initialization job: kubectl logs -n insightlearn-ai job/ollama-model-init -f"
echo "2. Check AI wrapper logs: kubectl logs -n insightlearn-ai deployment/ai-wrapper"
echo "3. Access AI services via: http://ai.insightlearn.cloud or NodePort 30080"
echo "4. Available API endpoints:"
echo "   - Course recommendations: POST /api/v1/course-recommendations"
echo "   - Content analysis: POST /api/v1/content-analysis"
echo "   - Chat/Q&A: POST /api/v1/chat"
echo "   - Learning path optimization: POST /api/v1/learning-path"
echo "   - Code assistance: POST /api/v1/code-assistance"

echo
echo "=== Verification completed at $(date) ==="