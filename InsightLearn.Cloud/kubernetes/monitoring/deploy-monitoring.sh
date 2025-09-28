#!/bin/bash

# InsightLearn Monitoring Stack Deployment Script
# This script deploys the complete monitoring and logging infrastructure

set -e

echo "=================================="
echo "InsightLearn Monitoring Deployment"
echo "=================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we can connect to the cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    print_warning "Make sure your kubeconfig is configured correctly"
    exit 1
fi

print_status "Connected to Kubernetes cluster"
kubectl cluster-info | head -1

echo ""
print_header "Deploying Monitoring Infrastructure"

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
print_status "Working from directory: $SCRIPT_DIR"

# Deploy monitoring components in order
declare -a DEPLOYMENT_ORDER=(
    "00-namespace-monitoring.yaml:Namespace and RBAC"
    "01-prometheus-enhanced.yaml:Prometheus Server"
    "02-alertmanager.yaml:AlertManager"
    "03-grafana.yaml:Grafana Dashboards"
    "05-servicemonitors.yaml:Service Monitors"
    "04-elk-stack.yaml:ELK Logging Stack"
    "06-dotnet-monitoring.yaml:.NET Application Monitoring"
    "07-enhanced-health-checks.yaml:Enhanced Health Checks"
    "08-monitoring-ingress.yaml:Monitoring Ingress"
    "09-deployment-verification.yaml:Verification Tools"
)

echo ""
for item in "${DEPLOYMENT_ORDER[@]}"; do
    IFS=':' read -r file description <<< "$item"

    if [ -f "$SCRIPT_DIR/$file" ]; then
        print_status "Deploying $description ($file)..."
        if kubectl apply -f "$SCRIPT_DIR/$file"; then
            print_status "✓ Successfully deployed $description"
        else
            print_error "✗ Failed to deploy $description"
            exit 1
        fi
        echo ""
    else
        print_warning "File not found: $file"
    fi
done

print_header "Waiting for Monitoring Services to Start"

# Wait for critical services to be ready
print_status "Waiting for Prometheus to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n insightlearn-monitoring

print_status "Waiting for Grafana to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/grafana -n insightlearn-monitoring

print_status "Waiting for AlertManager to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/alertmanager -n insightlearn-monitoring

print_status "Waiting for Kibana to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/kibana -n insightlearn-monitoring

echo ""
print_header "Running Deployment Verification"

# Run the verification job
print_status "Starting monitoring verification job..."
kubectl delete job monitoring-verification -n insightlearn-monitoring --ignore-not-found=true
kubectl apply -f "$SCRIPT_DIR/09-deployment-verification.yaml"

# Wait for verification job to complete
print_status "Waiting for verification to complete..."
kubectl wait --for=condition=complete --timeout=300s job/monitoring-verification -n insightlearn-monitoring

# Show verification results
print_status "Verification Results:"
echo ""
kubectl logs job/monitoring-verification -n insightlearn-monitoring

echo ""
print_header "Deployment Summary"

# Show deployed services
print_status "Monitoring Services Status:"
kubectl get pods -n insightlearn-monitoring -o wide

echo ""
print_status "Service Endpoints:"
kubectl get services -n insightlearn-monitoring

echo ""
print_header "Access Information"

echo -e "${GREEN}🎉 Monitoring Stack Deployed Successfully! 🎉${NC}"
echo ""
echo "Access URLs:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🌐 External Access (configure /etc/hosts or use ingress):"
echo "   Prometheus:    http://prometheus.insightlearn.local"
echo "   Grafana:       http://grafana.insightlearn.local"
echo "   AlertManager:  http://alertmanager.insightlearn.local"
echo "   Kibana:        http://kibana.insightlearn.local"
echo "   Health:        http://health.insightlearn.local"
echo ""
echo "🏠 Local Access (port forwarding):"
echo "   kubectl port-forward -n insightlearn-monitoring svc/prometheus 9090:9090"
echo "   kubectl port-forward -n insightlearn-monitoring svc/grafana 3000:3000"
echo "   kubectl port-forward -n insightlearn-monitoring svc/alertmanager 9093:9093"
echo "   kubectl port-forward -n insightlearn-monitoring svc/kibana 5601:5601"
echo "   kubectl port-forward -n insightlearn svc/insightlearn-health-dashboard 8080:8080"
echo ""
echo "🔐 Default Credentials:"
echo "   Username: admin"
echo "   Password: InsightLearn2024!"
echo ""
echo "📚 Add to /etc/hosts for local development:"
echo "   127.0.0.1 prometheus.insightlearn.local"
echo "   127.0.0.1 grafana.insightlearn.local"
echo "   127.0.0.1 alertmanager.insightlearn.local"
echo "   127.0.0.1 kibana.insightlearn.local"
echo "   127.0.0.1 health.insightlearn.local"
echo ""
print_header "Next Steps"
echo ""
echo "1. Configure your application services to expose metrics endpoints"
echo "2. Import additional Grafana dashboards for specific use cases"
echo "3. Customize alert rules based on your operational requirements"
echo "4. Set up notification channels (email, Slack, etc.) in AlertManager"
echo "5. Configure log retention policies based on your storage requirements"
echo ""
echo "For detailed documentation, see:"
echo "📖 $SCRIPT_DIR/README.md"
echo ""
print_status "Deployment completed successfully!"