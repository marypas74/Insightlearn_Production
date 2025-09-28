# InsightLearn.Cloud Monitoring & Logging Infrastructure

This directory contains a complete monitoring and logging solution for the InsightLearn.Cloud platform, deployed on Kubernetes.

## 📋 Overview

The monitoring stack includes:
- **Prometheus** - Metrics collection and alerting
- **Grafana** - Data visualization and dashboards
- **AlertManager** - Alert routing and notifications
- **ELK Stack** - Centralized logging (Elasticsearch, Fluentd, Kibana)
- **Custom Health Checks** - Application and dependency monitoring
- **ServiceMonitors** - Automatic service discovery and metrics collection

## 🚀 Quick Deployment

Deploy all monitoring components:

```bash
# Apply all monitoring configurations
kubectl apply -f /home/mpasqui/Kubernetes/InsightLearn.Cloud/kubernetes/monitoring/

# Verify deployment
kubectl get pods -n insightlearn-monitoring
kubectl get services -n insightlearn-monitoring
```

## 🔧 Components

### 1. Core Monitoring Services

| Service | File | Description |
|---------|------|-------------|
| Namespace & RBAC | `00-namespace-monitoring.yaml` | Monitoring namespace and permissions |
| Prometheus | `01-prometheus-enhanced.yaml` | Metrics collection server with enhanced config |
| AlertManager | `02-alertmanager.yaml` | Alert routing and notification system |
| Grafana | `03-grafana.yaml` | Visualization dashboards |

### 2. Logging Stack

| Service | File | Description |
|---------|------|-------------|
| ELK Stack | `04-elk-stack.yaml` | Fluentd, Kibana, and log retention policies |

### 3. Service Discovery & Monitoring

| Service | File | Description |
|---------|------|-------------|
| ServiceMonitors | `05-servicemonitors.yaml` | Automatic metrics collection from all services |
| .NET Monitoring | `06-dotnet-monitoring.yaml` | Application-specific monitoring for .NET services |

### 4. Health Checks & Verification

| Service | File | Description |
|---------|------|-------------|
| Enhanced Health Checks | `07-enhanced-health-checks.yaml` | Comprehensive health monitoring |
| Monitoring Ingress | `08-monitoring-ingress.yaml` | External access configuration |
| Verification | `09-deployment-verification.yaml` | Deployment verification and status dashboard |

## 🌐 Access URLs

### External Access (via Ingress)
- **Prometheus**: http://prometheus.insightlearn.local
- **Grafana**: http://grafana.insightlearn.local
- **AlertManager**: http://alertmanager.insightlearn.local
- **Kibana**: http://kibana.insightlearn.local
- **Health Dashboard**: http://health.insightlearn.local

### Local Access (via Port Forward)
```bash
# Prometheus
kubectl port-forward -n insightlearn-monitoring svc/prometheus 9090:9090

# Grafana
kubectl port-forward -n insightlearn-monitoring svc/grafana 3000:3000

# AlertManager
kubectl port-forward -n insightlearn-monitoring svc/alertmanager 9093:9093

# Kibana
kubectl port-forward -n insightlearn-monitoring svc/kibana 5601:5601

# Health Dashboard
kubectl port-forward -n insightlearn svc/insightlearn-health-dashboard 8080:8080
```

## 🔐 Authentication

### Default Credentials
- **Monitoring Tools** (Prometheus, AlertManager): `admin / InsightLearn2024!`
- **Grafana**: `admin / InsightLearn2024!`
- **Health Dashboard**: No authentication required

### Host File Configuration
Add to `/etc/hosts` for local development:
```
127.0.0.1 prometheus.insightlearn.local
127.0.0.1 grafana.insightlearn.local
127.0.0.1 alertmanager.insightlearn.local
127.0.0.1 kibana.insightlearn.local
127.0.0.1 health.insightlearn.local
```

## 📊 Monitoring Features

### Prometheus Configuration
- **Scrape Intervals**: 15-30 seconds
- **Retention**: 30 days / 10GB
- **Service Discovery**: Automatic Kubernetes service discovery
- **Custom Metrics**: Application-specific business metrics

### Grafana Dashboards
1. **Kubernetes Overview** - Cluster-level metrics
2. **Application Metrics** - API performance and usage
3. **Database Performance** - Database-specific monitoring
4. **Custom Business Metrics** - User registrations, course views, AI requests

### Alert Rules
- **Infrastructure**: High CPU, memory, disk usage
- **Application**: High response times, error rates
- **Database**: Connection issues, performance degradation
- **AI Services**: Service availability and response times

### Logging Features
- **Centralized Collection**: All application and system logs
- **Log Retention**: 30-day retention with automatic cleanup
- **Structured Logging**: JSON format with metadata enrichment
- **Real-time Analysis**: Kibana dashboards for log exploration

## 🔍 Health Monitoring

### Application Health Checks
- **Liveness Probes**: Service restart triggers
- **Readiness Probes**: Traffic routing control
- **Startup Probes**: Graceful startup handling
- **Custom Health Endpoints**: Business logic validation

### Dependency Monitoring
- **Database Connections**: PostgreSQL, MongoDB, Redis, Elasticsearch
- **AI Services**: Ollama service availability
- **External APIs**: Third-party service monitoring
- **Infrastructure**: Disk space, memory usage

## 🚨 Alerting Configuration

### Alert Channels
- **Email Notifications**: Configured for different severity levels
- **Webhook Integration**: Custom notification endpoints
- **Alert Grouping**: Intelligent alert consolidation
- **Escalation Policies**: Different rules for critical vs warning alerts

### Alert Types
- **Critical**: Database outages, API failures (5-15 min response)
- **Warning**: Performance degradation (1 hour response)
- **Info**: Maintenance notifications

## 📈 Custom Metrics

### Business Metrics
- `user_registrations_total` - Total user sign-ups
- `course_views_total` - Course engagement tracking
- `ai_requests_total` - AI service usage
- `active_users_current` - Current active user sessions

### Technical Metrics
- `http_requests_total` - API request rates
- `http_request_duration_seconds` - Response time histograms
- `database_queries_duration_seconds` - Database performance
- `cache_hit_ratio` - Redis cache efficiency

## 🛠️ Troubleshooting

### Common Issues

1. **Services Not Starting**
   ```bash
   kubectl describe pod -n insightlearn-monitoring <pod-name>
   kubectl logs -n insightlearn-monitoring <pod-name>
   ```

2. **Metrics Not Collecting**
   ```bash
   # Check Prometheus targets
   kubectl port-forward -n insightlearn-monitoring svc/prometheus 9090:9090
   # Visit http://localhost:9090/targets
   ```

3. **Alerts Not Firing**
   ```bash
   # Check AlertManager configuration
   kubectl logs -n insightlearn-monitoring deployment/alertmanager
   ```

4. **Logs Not Appearing**
   ```bash
   # Check Fluentd status
   kubectl logs -n insightlearn-monitoring daemonset/fluentd
   ```

### Verification Commands
```bash
# Run monitoring verification job
kubectl apply -f 09-deployment-verification.yaml

# Check verification results
kubectl logs -n insightlearn-monitoring job/monitoring-verification

# Check all monitoring services
kubectl get all -n insightlearn-monitoring
```

## 📝 Configuration Customization

### Environment Variables
Update the ConfigMaps to customize:
- Alert thresholds and rules
- Retention policies
- Dashboard configurations
- Notification channels

### Scaling
Adjust replicas and resources in deployment files:
- Prometheus: Scale for high metric volume
- Grafana: Scale for multiple users
- Fluentd: Automatically scales with nodes

## 🔄 Maintenance

### Regular Tasks
1. **Monitor Disk Usage**: Prometheus and Elasticsearch storage
2. **Update Dashboards**: Add new panels for new services
3. **Review Alerts**: Adjust thresholds based on patterns
4. **Log Cleanup**: Verify automatic retention policies

### Backup Considerations
- **Grafana Dashboards**: Export important dashboards
- **Prometheus Data**: Consider long-term storage solutions
- **Configuration**: Backup ConfigMaps and Secrets

## 🎯 Next Steps

1. **Custom Dashboards**: Create business-specific visualizations
2. **Advanced Alerting**: Implement ML-based anomaly detection
3. **Cost Monitoring**: Add resource cost tracking
4. **Security Monitoring**: Integrate security event monitoring
5. **Performance Optimization**: Tune retention and scrape intervals

---

For support or questions, refer to the individual component documentation or check the logs using the commands provided above.