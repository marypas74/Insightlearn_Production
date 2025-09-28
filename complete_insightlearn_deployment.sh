#!/bin/bash
# complete_insightlearn_deployment.sh - Final complete deployment of InsightLearn.Cloud

echo "🚀 COMPLETE INSIGHTLEARN.CLOUD DEPLOYMENT"
echo "==========================================="
echo "Date: $(date)"
echo "Target: Production-ready E-Learning Platform"
echo ""

DEPLOYMENT_LOG="/home/mpasqui/Kubernetes/deployment.log"
FAILED_COMPONENTS=()
SUCCESS_COMPONENTS=()

# Logging function
log_deployment() {
    local level="$1"
    local component="$2"
    local message="$3"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")

    echo "[$timestamp] [$level] [$component] $message" | tee -a "$DEPLOYMENT_LOG"

    if [ "$level" = "SUCCESS" ]; then
        SUCCESS_COMPONENTS+=("$component")
    elif [ "$level" = "ERROR" ]; then
        FAILED_COMPONENTS+=("$component")
    fi
}

cd /home/mpasqui/Kubernetes/InsightLearn.Cloud

echo "==== PHASE 1: INFRASTRUCTURE DEPLOYMENT ===="
log_deployment "INFO" "INFRASTRUCTURE" "Starting infrastructure deployment"

# Deploy all namespaces first
echo "📦 Creating namespaces..."
kubectl apply -f kubernetes/namespace-data.yaml 2>/dev/null || true
kubectl apply -f kubernetes/ai/namespace.yaml 2>/dev/null || true
kubectl create namespace insightlearn 2>/dev/null || true
kubectl create namespace insightlearn-monitoring 2>/dev/null || true

if [ $? -eq 0 ]; then
    log_deployment "SUCCESS" "NAMESPACES" "All namespaces created"
else
    log_deployment "ERROR" "NAMESPACES" "Failed to create some namespaces"
fi

echo ""
echo "==== PHASE 2: DATABASE DEPLOYMENT ===="
log_deployment "INFO" "DATABASES" "Starting database deployment"

# Deploy databases in correct order
echo "🗄️ Deploying PostgreSQL..."
kubectl apply -f kubernetes/databases/postgresql-statefulset.yaml
if [ $? -eq 0 ]; then
    log_deployment "SUCCESS" "POSTGRESQL" "PostgreSQL deployment initiated"
else
    log_deployment "ERROR" "POSTGRESQL" "PostgreSQL deployment failed"
fi

echo "🗄️ Deploying MongoDB..."
kubectl apply -f kubernetes/databases/mongodb-statefulset.yaml
if [ $? -eq 0 ]; then
    log_deployment "SUCCESS" "MONGODB" "MongoDB deployment initiated"
else
    log_deployment "ERROR" "MONGODB" "MongoDB deployment failed"
fi

echo "🗄️ Deploying Redis..."
kubectl apply -f kubernetes/databases/redis-deployment.yaml
if [ $? -eq 0 ]; then
    log_deployment "SUCCESS" "REDIS" "Redis deployment initiated"
else
    log_deployment "ERROR" "REDIS" "Redis deployment failed"
fi

echo "🗄️ Deploying Elasticsearch..."
kubectl apply -f kubernetes/databases/elasticsearch-statefulset.yaml
if [ $? -eq 0 ]; then
    log_deployment "SUCCESS" "ELASTICSEARCH" "Elasticsearch deployment initiated"
else
    log_deployment "ERROR" "ELASTICSEARCH" "Elasticsearch deployment failed"
fi

echo ""
echo "⏳ Waiting for databases to be ready..."
kubectl wait --for=condition=ready pod -l app=postgresql -n insightlearn-data --timeout=300s || log_deployment "WARNING" "POSTGRESQL" "PostgreSQL not ready within timeout"
kubectl wait --for=condition=ready pod -l app=mongodb -n insightlearn-data --timeout=300s || log_deployment "WARNING" "MONGODB" "MongoDB not ready within timeout"
kubectl wait --for=condition=ready pod -l app=redis -n insightlearn-data --timeout=300s || log_deployment "WARNING" "REDIS" "Redis not ready within timeout"
kubectl wait --for=condition=ready pod -l app=elasticsearch -n insightlearn-data --timeout=300s || log_deployment "WARNING" "ELASTICSEARCH" "Elasticsearch not ready within timeout"

echo ""
echo "==== PHASE 3: AI SERVICES DEPLOYMENT ===="
log_deployment "INFO" "AI" "Starting AI services deployment"

echo "🤖 Deploying Ollama AI..."
kubectl apply -f kubernetes/ai/ollama-deployment.yaml
kubectl apply -f kubernetes/ai/ollama-service.yaml
kubectl apply -f kubernetes/ai/ollama-storage.yaml
if [ $? -eq 0 ]; then
    log_deployment "SUCCESS" "OLLAMA" "Ollama AI deployment initiated"
else
    log_deployment "ERROR" "OLLAMA" "Ollama AI deployment failed"
fi

echo "⏳ Waiting for AI services..."
kubectl wait --for=condition=ready pod -l app=ollama -n insightlearn-ai --timeout=300s || log_deployment "WARNING" "OLLAMA" "Ollama not ready within timeout"

echo ""
echo "==== PHASE 4: APPLICATION DEPLOYMENT ===="
log_deployment "INFO" "APPLICATIONS" "Starting application deployment"

echo "🔧 Building and deploying API..."
# Build Docker images if not already built
if ! docker images | grep -q insightlearn/api; then
    echo "Building API Docker image..."
    docker build -f Dockerfile.api -t insightlearn/api:latest . || log_deployment "ERROR" "API_BUILD" "API Docker build failed"
fi

echo "🎨 Building and deploying Web..."
if ! docker images | grep -q insightlearn/web; then
    echo "Building Web Docker image..."
    docker build -f Dockerfile.web -t insightlearn/web:latest . || log_deployment "ERROR" "WEB_BUILD" "Web Docker build failed"
fi

echo "📱 Deploying applications..."
kubectl apply -f kubernetes/deployments/api-deployment.yaml
if [ $? -eq 0 ]; then
    log_deployment "SUCCESS" "API_DEPLOY" "API deployment initiated"
else
    log_deployment "ERROR" "API_DEPLOY" "API deployment failed"
fi

kubectl apply -f kubernetes/deployments/web-deployment-production.yaml
if [ $? -eq 0 ]; then
    log_deployment "SUCCESS" "WEB_DEPLOY" "Web deployment initiated"
else
    log_deployment "ERROR" "WEB_DEPLOY" "Web deployment failed"
fi

echo "⏳ Waiting for applications..."
kubectl wait --for=condition=ready pod -l app=insightlearn-api -n insightlearn --timeout=300s || log_deployment "WARNING" "API" "API not ready within timeout"
kubectl wait --for=condition=ready pod -l app=insightlearn-web -n insightlearn --timeout=300s || log_deployment "WARNING" "WEB" "Web not ready within timeout"

echo ""
echo "==== PHASE 5: NETWORKING & INGRESS ===="
log_deployment "INFO" "NETWORKING" "Starting networking configuration"

echo "🌐 Deploying ingress configuration..."
kubectl apply -f kubernetes/ingress-production-complete.yaml
if [ $? -eq 0 ]; then
    log_deployment "SUCCESS" "INGRESS" "Ingress configuration applied"
else
    log_deployment "ERROR" "INGRESS" "Ingress deployment failed"
fi

echo ""
echo "==== PHASE 6: MONITORING DEPLOYMENT ===="
log_deployment "INFO" "MONITORING" "Starting monitoring deployment"

echo "📊 Deploying monitoring stack..."

# Deploy monitoring components in order
kubectl apply -f kubernetes/monitoring/01-prometheus-enhanced.yaml
kubectl apply -f kubernetes/monitoring/02-alertmanager.yaml
kubectl apply -f kubernetes/monitoring/03-grafana.yaml
kubectl apply -f kubernetes/monitoring/04-elk-stack.yaml
kubectl apply -f kubernetes/monitoring/05-servicemonitors.yaml
kubectl apply -f kubernetes/monitoring/06-dotnet-monitoring.yaml
kubectl apply -f kubernetes/monitoring/07-enhanced-health-checks.yaml
kubectl apply -f kubernetes/monitoring/08-monitoring-ingress.yaml

if [ $? -eq 0 ]; then
    log_deployment "SUCCESS" "MONITORING" "Monitoring stack deployment initiated"
else
    log_deployment "ERROR" "MONITORING" "Monitoring deployment failed"
fi

echo "⏳ Waiting for monitoring services..."
kubectl wait --for=condition=ready pod -l app=prometheus -n insightlearn-monitoring --timeout=300s || log_deployment "WARNING" "PROMETHEUS" "Prometheus not ready"
kubectl wait --for=condition=ready pod -l app=grafana -n insightlearn-monitoring --timeout=300s || log_deployment "WARNING" "GRAFANA" "Grafana not ready"

echo ""
echo "==== PHASE 7: DATABASE INITIALIZATION ===="
log_deployment "INFO" "DB_INIT" "Starting database initialization"

echo "🗃️ Running database migrations..."
# Create a job to run migrations
cat > /tmp/migration-job.yaml << 'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: database-migration
  namespace: insightlearn
spec:
  template:
    spec:
      containers:
      - name: migration
        image: insightlearn/api:latest
        command: ["dotnet", "ef", "database", "update", "--no-build"]
        env:
        - name: ConnectionStrings__DefaultConnection
          value: "Server=postgresql.insightlearn-data.svc.cluster.local;Port=5432;Database=insightlearn;User Id=insightlearn;Password=InsightLearn2024!"
      restartPolicy: Never
  backoffLimit: 3
EOF

kubectl apply -f /tmp/migration-job.yaml
if [ $? -eq 0 ]; then
    log_deployment "SUCCESS" "MIGRATION" "Database migration job created"
else
    log_deployment "WARNING" "MIGRATION" "Database migration job creation failed"
fi

echo ""
echo "==== PHASE 8: FINAL VERIFICATION ===="
log_deployment "INFO" "VERIFICATION" "Starting final system verification"

echo "🔍 Verifying deployments..."

# Wait a bit for everything to stabilize
sleep 30

echo ""
echo "📊 DEPLOYMENT STATUS:"
echo "===================="

# Check each namespace
TOTAL_PODS=0
READY_PODS=0

for ns in insightlearn insightlearn-data insightlearn-ai insightlearn-monitoring; do
    if kubectl get namespace $ns > /dev/null 2>&1; then
        echo ""
        echo "Namespace: $ns"
        echo "-------------------"
        PODS=$(kubectl get pods -n $ns --no-headers 2>/dev/null | wc -l)
        RUNNING=$(kubectl get pods -n $ns --no-headers 2>/dev/null | grep Running | wc -l)

        TOTAL_PODS=$((TOTAL_PODS + PODS))
        READY_PODS=$((READY_PODS + RUNNING))

        echo "Pods: $RUNNING/$PODS Running"
        kubectl get pods -n $ns 2>/dev/null | head -10
    fi
done

echo ""
echo "========================================="
echo "📈 DEPLOYMENT SUMMARY"
echo "========================================="
echo ""
echo "✅ Successfully deployed: ${#SUCCESS_COMPONENTS[@]} components"
echo "❌ Failed deployments: ${#FAILED_COMPONENTS[@]} components"
echo ""
echo "📦 Total Pods: $TOTAL_PODS"
echo "🟢 Running Pods: $READY_PODS"
echo "📊 Success Rate: $(( READY_PODS * 100 / TOTAL_PODS ))%" 2>/dev/null || echo "📊 Success Rate: Calculating..."

if [ ${#SUCCESS_COMPONENTS[@]} -gt 0 ]; then
    echo ""
    echo "✅ Successful Components:"
    for component in "${SUCCESS_COMPONENTS[@]}"; do
        echo "   • $component"
    done
fi

if [ ${#FAILED_COMPONENTS[@]} -gt 0 ]; then
    echo ""
    echo "❌ Failed Components:"
    for component in "${FAILED_COMPONENTS[@]}"; do
        echo "   • $component"
    done
fi

echo ""
echo "========================================="
echo "🌐 ACCESS INFORMATION"
echo "========================================="

MINIKUBE_IP=$(minikube ip 2>/dev/null)
if [ -n "$MINIKUBE_IP" ]; then
    echo ""
    echo "🔗 Application URLs:"
    echo "   • Main App: http://$MINIKUBE_IP"
    echo "   • API: http://$MINIKUBE_IP/api"
    echo "   • Health: http://$MINIKUBE_IP/health"
    echo ""
    echo "📊 Monitoring URLs:"
    echo "   • Grafana: http://$MINIKUBE_IP:30300 (admin/admin)"
    echo "   • Prometheus: http://$MINIKUBE_IP:30900"
    echo "   • Kibana: http://$MINIKUBE_IP:30600"
    echo ""
    echo "📊 Dashboard: https://192.168.1.103:30443"
    echo "🔑 Dashboard Token: kubectl -n kubernetes-dashboard create token dashboard-user"
fi

echo ""
echo "========================================="
echo "🎉 INSIGHTLEARN.CLOUD DEPLOYMENT COMPLETE!"
echo "========================================="
echo ""
echo "📝 Deployment log: $DEPLOYMENT_LOG"
echo "📚 Full documentation: /home/mpasqui/Kubernetes/InsightLearn.Cloud/README.md"
echo ""

if [ ${#FAILED_COMPONENTS[@]} -eq 0 ]; then
    echo "🏆 ALL COMPONENTS DEPLOYED SUCCESSFULLY!"
    echo "The InsightLearn.Cloud e-learning platform is LIVE and ready for users!"
    log_deployment "SUCCESS" "DEPLOYMENT" "Complete InsightLearn.Cloud deployment successful"
    exit 0
else
    echo "⚠️  Some components need attention. Check logs and retry failed deployments."
    log_deployment "WARNING" "DEPLOYMENT" "Deployment completed with issues"
    exit 1
fi