#!/bin/bash
# phase9_step1_prometheus_setup.sh

source advanced_command_executor.sh

echo "=== [$(date)] FASE 9 STEP 1: Prometheus e Grafana Setup ===" | tee -a "$BASE_LOG_DIR/phase9_step1.log"

cd InsightLearn.Cloud

# Crea namespace per monitoring
execute_command_with_retry \
    "kubectl create namespace insightlearn-monitoring --dry-run=client -o yaml | kubectl apply -f -" \
    "Create monitoring namespace" \
    "KUBERNETES"

# Crea directory per monitoring
execute_command_with_retry \
    "mkdir -p kubernetes/monitoring" \
    "Create monitoring directory" \
    "FILESYSTEM"

# Crea Prometheus ConfigMap
execute_command_with_retry \
    "cat > kubernetes/monitoring/prometheus-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: insightlearn-monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    rule_files:
      - '/etc/prometheus/rules/*.yml'

    alerting:
      alertmanagers:
        - static_configs:
            - targets:
              - alertmanager:9093

    scrape_configs:
      # Prometheus self-monitoring
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']

      # Kubernetes API server
      - job_name: 'kubernetes-apiservers'
        kubernetes_sd_configs:
          - role: endpoints
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
          - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
            action: keep
            regex: default;kubernetes;https

      # Kubernetes nodes
      - job_name: 'kubernetes-nodes'
        kubernetes_sd_configs:
          - role: node
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
          - action: labelmap
            regex: __meta_kubernetes_node_label_(.+)

      # Kubernetes pods
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: \${1}:\${2}
            target_label: __address__
          - action: labelmap
            regex: __meta_kubernetes_pod_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: kubernetes_namespace
          - source_labels: [__meta_kubernetes_pod_name]
            action: replace
            target_label: kubernetes_pod_name

      # InsightLearn specific services
      - job_name: 'insightlearn-web'
        kubernetes_sd_configs:
          - role: endpoints
            namespaces:
              names:
                - insightlearn
        relabel_configs:
          - source_labels: [__meta_kubernetes_service_name]
            action: keep
            regex: insightlearn-web-service

      - job_name: 'insightlearn-api'
        kubernetes_sd_configs:
          - role: endpoints
            namespaces:
              names:
                - insightlearn
        relabel_configs:
          - source_labels: [__meta_kubernetes_service_name]
            action: keep
            regex: insightlearn-api-service

      # Database monitoring
      - job_name: 'sqlserver'
        static_configs:
          - targets: ['sqlserver-exporter:9399']

      - job_name: 'mongodb'
        static_configs:
          - targets: ['mongodb-exporter:9216']

      - job_name: 'redis'
        static_configs:
          - targets: ['redis-exporter:9121']

      - job_name: 'elasticsearch'
        static_configs:
          - targets: ['elasticsearch-exporter:9114']
EOF" \
    "Create Prometheus configuration" \
    "CONFIG"

# Crea ServiceAccount per Prometheus
execute_command_with_retry \
    "cat > kubernetes/monitoring/prometheus-rbac.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: insightlearn-monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: ['']
  resources:
  - nodes
  - nodes/proxy
  - services
  - endpoints
  - pods
  verbs: ['get', 'list', 'watch']
- apiGroups:
  - extensions
  resources:
  - ingresses
  verbs: ['get', 'list', 'watch']
- nonResourceURLs: ['/metrics']
  verbs: ['get']
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: insightlearn-monitoring
EOF" \
    "Create Prometheus RBAC configuration" \
    "RBAC"

# Crea Prometheus Deployment
execute_command_with_retry \
    "cat > kubernetes/monitoring/prometheus-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: insightlearn-monitoring
  labels:
    app: prometheus
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      serviceAccountName: prometheus
      containers:
      - name: prometheus
        image: prom/prometheus:v2.45.0
        ports:
        - containerPort: 9090
        args:
          - '--config.file=/etc/prometheus/prometheus.yml'
          - '--storage.tsdb.path=/prometheus/'
          - '--web.console.libraries=/etc/prometheus/console_libraries'
          - '--web.console.templates=/etc/prometheus/consoles'
          - '--storage.tsdb.retention.time=30d'
          - '--web.enable-lifecycle'
          - '--web.enable-admin-api'
        volumeMounts:
        - name: prometheus-config
          mountPath: /etc/prometheus/
        - name: prometheus-storage
          mountPath: /prometheus/
        resources:
          requests:
            memory: '512Mi'
            cpu: '250m'
          limits:
            memory: '1Gi'
            cpu: '500m'
        livenessProbe:
          httpGet:
            path: /-/healthy
            port: 9090
          initialDelaySeconds: 30
          timeoutSeconds: 30
        readinessProbe:
          httpGet:
            path: /-/ready
            port: 9090
          initialDelaySeconds: 30
          timeoutSeconds: 30
      volumes:
      - name: prometheus-config
        configMap:
          name: prometheus-config
      - name: prometheus-storage
        persistentVolumeClaim:
          claimName: prometheus-storage
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-storage
  namespace: insightlearn-monitoring
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: insightlearn-monitoring
  labels:
    app: prometheus
spec:
  ports:
  - port: 9090
    targetPort: 9090
    protocol: TCP
  selector:
    app: prometheus
  type: ClusterIP
EOF" \
    "Create Prometheus deployment manifest" \
    "MANIFEST"

structured_log "SUCCESS" "STEP_9_1" "Prometheus e Grafana setup completato"