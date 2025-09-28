# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This Kubernetes repository contains multiple e-learning platform deployments:
- **InsightLearn**: A simpler Flask/JavaScript e-learning platform
- **InsightLearn.Cloud**: A complex production-grade platform with AI services, monitoring, and full infrastructure

## Common Development Commands

### Kubernetes Cluster Management

```bash
# Start Minikube cluster
minikube start

# Check cluster status
minikube status
kubectl cluster-info

# Access Kubernetes Dashboard
minikube tunnel  # Keep running in separate terminal
# Then access: http://localhost:30443
# Token available in RISOLUZIONE_FINALE.md
```

### InsightLearn Deployment

```bash
# Build Docker images locally
cd InsightLearn
make build-images

# Deploy InsightLearn
make deploy-k8s

# Access application
make port-forward
# Frontend: http://localhost:8080
# Backend API: http://localhost:5000

# Check status
make status

# View logs
make logs-backend
make logs-frontend
make logs-postgres

# View built images
docker images | grep insightlearn

# Clean up
make delete-k8s
```

### InsightLearn.Cloud Deployment

```bash
# Complete deployment
cd /home/mpasqui/Kubernetes
./complete_insightlearn_deployment.sh

# Deploy specific components
cd InsightLearn.Cloud
kubectl apply -f kubernetes/namespace-data.yaml
kubectl apply -f kubernetes/databases/
kubectl apply -f kubernetes/deployments/
kubectl apply -f kubernetes/services/
kubectl apply -f kubernetes/ai/
kubectl apply -f kubernetes/monitoring/

# Check AI services
kubectl get pods -n insightlearn-ai

# Check monitoring stack
kubectl get pods -n insightlearn-monitoring
```

## Architecture

### InsightLearn (Simple Version)
- **Backend**: Flask API with SQLAlchemy ORM
- **Frontend**: Vanilla HTML/CSS/JavaScript
- **Database**: PostgreSQL
- **Deployment**: Basic Kubernetes with HPA

### InsightLearn.Cloud (Production Version)
- **Microservices**: API Gateway, Content Service, Payment Service, Analytics Service
- **Databases**: PostgreSQL (main), MongoDB (content), Redis (cache), Elasticsearch (search)
- **AI Services**: ML recommendation engines, content analysis, natural language processing
- **Analytics Services**: Real-time data processing, user behavior tracking, reporting dashboards
- **Content Services**: Course content management, video streaming, document processing
- **Payment Services**: Stripe integration, transaction processing, invoice management
- **Monitoring**: Prometheus metrics, Grafana dashboards, ELK Stack logging
- **Infrastructure**: Multi-namespace deployment with Ingress, HPA, and service mesh

## Monitoring and Observability

### Prometheus and Grafana
```bash
# Access Prometheus (if deployed)
kubectl port-forward -n insightlearn-monitoring service/prometheus 9090:9090
# Then access: http://localhost:9090

# Access Grafana (if deployed)
kubectl port-forward -n insightlearn-monitoring service/grafana 3000:3000
# Then access: http://localhost:3000

# Check monitoring stack status
kubectl get pods -n insightlearn-monitoring
```

### Logging and Metrics
```bash
# View ELK Stack components
kubectl get pods -n insightlearn-monitoring | grep -E "elasticsearch|logstash|kibana"

# Access Kibana for log analysis
kubectl port-forward -n insightlearn-monitoring service/kibana 5601:5601

# Check application metrics
kubectl top pods --all-namespaces
kubectl top nodes
```

## Key Files and Scripts

### Deployment Scripts
- `complete_insightlearn_deployment.sh`: Full InsightLearn.Cloud deployment
- `phase*_verification.sh`: Various verification and testing scripts
- `access-dashboard.sh`: Helper for Kubernetes dashboard access
- `run_all_tests.sh`: Complete test suite
- `immediate_dashboard_fix.sh`: Emergency dashboard access fix

### Configuration
- `InsightLearn/Makefile`: Main commands for InsightLearn deployment
- `InsightLearn.Cloud/kubernetes/`: All Kubernetes manifests for production deployment
- `InsightLearn.Cloud/kubernetes/ai/`: AI services configuration
- `InsightLearn.Cloud/kubernetes/monitoring/`: Monitoring stack configuration
- `RISOLUZIONE_FINALE.md`: Dashboard access troubleshooting and tokens

## Testing and Verification

### Comprehensive Testing
```bash
# Run complete test suite
./run_all_tests.sh

# Final deployment verification
./phase10_final_verification.sh

# Simple verification scripts
./simple_phase4_verification.sh
./simple_phase5_verification.sh

# Advanced verification with retry loops
./phase6_verification_with_retry_loop.sh
./phase8_verification_with_test_error_loop.sh
```

### Status Checks
```bash
# Check pod status across all namespaces
kubectl get pods --all-namespaces

# Check services across all namespaces
kubectl get services --all-namespaces

# InsightLearn specific status
cd InsightLearn && make status

# Check deployments and HPA
kubectl get deployments --all-namespaces
kubectl get hpa --all-namespaces
```

### Specialized Verification
```bash
# Kubernetes cluster assessment
./phase7_k8s_assessment.sh

# Monitoring setup verification
./phase9_verification.sh

# Network and connectivity tests
./fix_connectivity_issues.sh
```

## Development Workflows

### Local Development (Docker Compose)
```bash
# Quick local development setup
cd InsightLearn
make docker-up

# Monitor logs in real-time
make logs-backend &
make logs-frontend &

# Access applications
# Frontend: http://localhost
# Backend API: http://localhost:5000

# Stop services
make docker-down
```

### Kubernetes Development
```bash
# Full K8s development cycle
cd InsightLearn
make build-images          # Build Docker images
make deploy-k8s           # Deploy to Kubernetes
make port-forward         # Access services locally
make status               # Check deployment status

# Iterate on changes
make delete-k8s           # Clean up
# Make code changes
make build-images         # Rebuild
make deploy-k8s           # Redeploy
```

### Production Deployment Workflow
```bash
# Complete production deployment
cd /home/mpasqui/Kubernetes
./complete_insightlearn_deployment.sh

# Monitor deployment progress
kubectl get pods --all-namespaces -w

# Verify all services are running
./run_all_tests.sh

# Access applications via dashboard
./access-dashboard.sh
```

## Common Issues and Solutions

### Dashboard Access Issues

#### Primary Solutions (choose one):
```bash
# SOLUTION 1: Minikube Tunnel (Recommended)
sudo minikube tunnel
# Then access: http://localhost:30443

# SOLUTION 2: Port Forwarding
kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443
# Then access: https://localhost:8443

# SOLUTION 3: Kubectl Proxy
kubectl proxy
# Then access: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

# SOLUTION 4: Direct Minikube IP
minikube ip  # Get the IP
firefox http://$(minikube ip):30443
```

#### Authentication Token:
```bash
# Generate new dashboard token
kubectl -n kubernetes-dashboard create token dashboard-user

# Or use stored token from RISOLUZIONE_FINALE.md
```

### Deployment Failures
- Check namespace exists: `kubectl get namespaces`
- Verify images are built: `docker images | grep insightlearn`
- Check pod logs: `kubectl logs -n <namespace> <pod-name>`

### Network Connectivity
- Minikube runs in isolated network (192.168.49.x)
- Use port-forward or tunnel for local access
- Never access via host IP (192.168.1.x) directly
- Services are not exposed on host network by default

### Image Pull Issues
```bash
# Check if images exist locally
docker images | grep insightlearn

# Rebuild images if missing
cd InsightLearn && make build-images

# Load images into Minikube
minikube image load insightlearn-backend:latest
minikube image load insightlearn-frontend:latest
```

### Pod Startup Failures
```bash
# Check pod events for detailed error info
kubectl describe pod <pod-name> -n <namespace>

# Check pod logs with previous container logs
kubectl logs <pod-name> -n <namespace> --previous

# Force pod restart
kubectl delete pod <pod-name> -n <namespace>
```

## Emergency Procedures

### Complete Cluster Recovery
```bash
# Emergency cluster restart
minikube stop
minikube start

# Verify cluster is healthy
kubectl cluster-info
kubectl get nodes

# Redeploy everything
./complete_insightlearn_deployment.sh
```

### Dashboard Access Emergency Fix
```bash
# Quick dashboard fix
./immediate_dashboard_fix.sh

# Or manual recovery
minikube stop
minikube start
./access-dashboard.sh
```

### Force Application Redeploy
```bash
# InsightLearn force redeploy
cd InsightLearn
make delete-k8s
make build-images
make deploy-k8s

# InsightLearn.Cloud force redeploy
cd /home/mpasqui/Kubernetes
kubectl delete namespace insightlearn --force --grace-period=0
./complete_insightlearn_deployment.sh
```

### Resource Cleanup
```bash
# Clean up all InsightLearn resources
make delete-k8s

# Clean up all namespaces (careful!)
kubectl delete namespace insightlearn --force
kubectl delete namespace insightlearn-monitoring --force
kubectl delete namespace insightlearn-ai --force

# Clean up Docker images
docker rmi $(docker images | grep insightlearn | awk '{print $3}')
```

### Diagnostic Commands
```bash
# Get comprehensive cluster status
kubectl get all --all-namespaces

# Check cluster events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Check resource usage
kubectl top pods --all-namespaces
kubectl top nodes

# Export all configurations for backup
kubectl get all --all-namespaces -o yaml > cluster-backup.yaml
```