#!/bin/bash
# full_deployment_expert_team.sh - Deploy complete InsightLearn.Cloud with all experts

echo "🚀 ACTIVATING ALL EXPERTS FOR COMPLETE DEPLOYMENT"
echo "================================================="
echo "Target: Full InsightLearn.Cloud E-Learning Platform"
echo "Date: $(date)"
echo ""

# Configurazioni
NAMESPACE="insightlearn"
MONITORING_NS="insightlearn-monitoring"
DB_NAMESPACE="insightlearn-data"
AI_NAMESPACE="insightlearn-ai"

# Funzione di logging
log_expert() {
    local expert="$1"
    local action="$2"
    echo "👨‍💻 [$expert EXPERT] $action"
}

echo "==== EXPERT TEAM ACTIVATION ===="
echo "🧑‍💼 Infrastructure Expert: Kubernetes & Networking"
echo "🗄️  Database Expert: PostgreSQL, MongoDB, Redis, Elasticsearch"
echo "🔧 Backend Expert: .NET 8 Web API, Microservices"
echo "🎨 Frontend Expert: Blazor, UI Components, PWA"
echo "🤖 AI Expert: Ollama, Machine Learning Services"
echo "🔐 Security Expert: Authentication, Authorization, SSL"
echo "📊 DevOps Expert: CI/CD, Monitoring, Logging"
echo "🏗️  Architecture Expert: Service Mesh, Load Balancing"
echo ""

cd /home/mpasqui/Kubernetes/InsightLearn.Cloud

# ==============================================
# 🧑‍💼 INFRASTRUCTURE EXPERT - Namespaces & Base
# ==============================================
log_expert "INFRASTRUCTURE" "Creating production namespaces..."

kubectl create namespace $NAMESPACE 2>/dev/null || true
kubectl create namespace $MONITORING_NS 2>/dev/null || true
kubectl create namespace $DB_NAMESPACE 2>/dev/null || true
kubectl create namespace $AI_NAMESPACE 2>/dev/null || true

log_expert "INFRASTRUCTURE" "Deploying persistent volumes..."
cat > kubernetes/storage/persistent-volumes.yaml << 'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgres-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  hostPath:
    path: /mnt/data/postgres
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mongodb-pv
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  hostPath:
    path: /mnt/data/mongodb
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: redis-pv
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  hostPath:
    path: /mnt/data/redis
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: elasticsearch-pv
spec:
  capacity:
    storage: 15Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  hostPath:
    path: /mnt/data/elasticsearch
EOF

mkdir -p kubernetes/storage
kubectl apply -f kubernetes/storage/persistent-volumes.yaml

# ==============================================
# 🗄️ DATABASE EXPERT - Complete Data Stack
# ==============================================
log_expert "DATABASE" "Deploying PostgreSQL with Entity Framework..."
cat > kubernetes/databases/postgresql.yaml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresql
  namespace: insightlearn-data
spec:
  serviceName: "postgresql"
  replicas: 1
  selector:
    matchLabels:
      app: postgresql
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      containers:
      - name: postgresql
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: "insightlearn"
        - name: POSTGRES_USER
          value: "insightlearn"
        - name: POSTGRES_PASSWORD
          value: "InsightLearn2024!"
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        volumeMounts:
        - name: postgresql-storage
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
  volumeClaimTemplates:
  - metadata:
      name: postgresql-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: local-storage
      resources:
        requests:
          storage: 10Gi
---
apiVersion: v1
kind: Service
metadata:
  name: postgresql
  namespace: insightlearn-data
spec:
  selector:
    app: postgresql
  ports:
    - port: 5432
      targetPort: 5432
EOF

log_expert "DATABASE" "Deploying MongoDB for document storage..."
cat > kubernetes/databases/mongodb.yaml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
  namespace: insightlearn-data
spec:
  serviceName: "mongodb"
  replicas: 1
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      containers:
      - name: mongodb
        image: mongo:7.0
        ports:
        - containerPort: 27017
        env:
        - name: MONGO_INITDB_ROOT_USERNAME
          value: "insightlearn"
        - name: MONGO_INITDB_ROOT_PASSWORD
          value: "InsightLearn2024!"
        - name: MONGO_INITDB_DATABASE
          value: "insightlearn"
        volumeMounts:
        - name: mongodb-storage
          mountPath: /data/db
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
  volumeClaimTemplates:
  - metadata:
      name: mongodb-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: local-storage
      resources:
        requests:
          storage: 20Gi
---
apiVersion: v1
kind: Service
metadata:
  name: mongodb
  namespace: insightlearn-data
spec:
  selector:
    app: mongodb
  ports:
    - port: 27017
      targetPort: 27017
EOF

log_expert "DATABASE" "Deploying Redis for caching..."
cat > kubernetes/databases/redis.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: insightlearn-data
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        command:
          - redis-server
          - "--requirepass"
          - "InsightLearn2024!"
          - "--appendonly"
          - "yes"
        volumeMounts:
        - name: redis-storage
          mountPath: /data
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
      volumes:
      - name: redis-storage
        persistentVolumeClaim:
          claimName: redis-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: redis-pvc
  namespace: insightlearn-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-storage
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: insightlearn-data
spec:
  selector:
    app: redis
  ports:
    - port: 6379
      targetPort: 6379
EOF

log_expert "DATABASE" "Deploying Elasticsearch for search..."
cat > kubernetes/databases/elasticsearch.yaml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: elasticsearch
  namespace: insightlearn-data
spec:
  serviceName: "elasticsearch"
  replicas: 1
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      containers:
      - name: elasticsearch
        image: elasticsearch:8.11.0
        ports:
        - containerPort: 9200
        - containerPort: 9300
        env:
        - name: discovery.type
          value: "single-node"
        - name: ES_JAVA_OPTS
          value: "-Xms512m -Xmx512m"
        - name: xpack.security.enabled
          value: "false"
        volumeMounts:
        - name: elasticsearch-storage
          mountPath: /usr/share/elasticsearch/data
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
  volumeClaimTemplates:
  - metadata:
      name: elasticsearch-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: local-storage
      resources:
        requests:
          storage: 15Gi
---
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch
  namespace: insightlearn-data
spec:
  selector:
    app: elasticsearch
  ports:
    - port: 9200
      targetPort: 9200
    - port: 9300
      targetPort: 9300
EOF

# Deploy databases
mkdir -p kubernetes/databases
kubectl apply -f kubernetes/databases/postgresql.yaml
kubectl apply -f kubernetes/databases/mongodb.yaml
kubectl apply -f kubernetes/databases/redis.yaml
kubectl apply -f kubernetes/databases/elasticsearch.yaml

# ==============================================
# 🤖 AI EXPERT - Ollama & ML Services
# ==============================================
log_expert "AI" "Deploying Ollama AI services..."
cat > kubernetes/ai/ollama.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama
  namespace: insightlearn-ai
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama
  template:
    metadata:
      labels:
        app: ollama
    spec:
      containers:
      - name: ollama
        image: ollama/ollama:latest
        ports:
        - containerPort: 11434
        env:
        - name: OLLAMA_HOST
          value: "0.0.0.0"
        volumeMounts:
        - name: ollama-data
          mountPath: /root/.ollama
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
        livenessProbe:
          httpGet:
            path: /
            port: 11434
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 11434
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: ollama-data
        persistentVolumeClaim:
          claimName: ollama-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ollama-pvc
  namespace: insightlearn-ai
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
  name: ollama
  namespace: insightlearn-ai
spec:
  selector:
    app: ollama
  ports:
    - port: 11434
      targetPort: 11434
  type: ClusterIP
EOF

mkdir -p kubernetes/ai
kubectl apply -f kubernetes/ai/ollama.yaml

# ==============================================
# 🔧 BACKEND EXPERT - Enhanced API Services
# ==============================================
log_expert "BACKEND" "Creating production-ready API deployment..."
cat > kubernetes/deployments/api-deployment-production.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: insightlearn-api
  namespace: insightlearn
  labels:
    app: insightlearn-api
    version: "1.0.0"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: insightlearn-api
  template:
    metadata:
      labels:
        app: insightlearn-api
        version: "1.0.0"
    spec:
      containers:
      - name: api
        image: insightlearn/api:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 8443
          name: https
        env:
        - name: ASPNETCORE_ENVIRONMENT
          value: "Production"
        - name: ASPNETCORE_URLS
          value: "http://+:8080"
        - name: ConnectionStrings__DefaultConnection
          value: "Server=postgresql.insightlearn-data.svc.cluster.local;Port=5432;Database=insightlearn;User Id=insightlearn;Password=InsightLearn2024!"
        - name: ConnectionStrings__MongoDb
          value: "mongodb://insightlearn:InsightLearn2024!@mongodb.insightlearn-data.svc.cluster.local:27017/insightlearn"
        - name: ConnectionStrings__Redis
          value: "redis.insightlearn-data.svc.cluster.local:6379,password=InsightLearn2024!"
        - name: ConnectionStrings__Elasticsearch
          value: "http://elasticsearch.insightlearn-data.svc.cluster.local:9200"
        - name: AI__OllamaUrl
          value: "http://ollama.insightlearn-ai.svc.cluster.local:11434"
        - name: JWT__SecretKey
          value: "SuperSecretKeyForJWTTokensInsightLearnPlatform2024"
        - name: JWT__Issuer
          value: "InsightLearn.Cloud"
        - name: JWT__Audience
          value: "InsightLearn.Users"
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 3
          timeoutSeconds: 5
        volumeMounts:
        - name: appsettings
          mountPath: /app/appsettings.Production.json
          subPath: appsettings.Production.json
        - name: video-storage
          mountPath: /app/videos
      volumes:
      - name: appsettings
        configMap:
          name: api-config
      - name: video-storage
        persistentVolumeClaim:
          claimName: video-storage-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: video-storage-pvc
  namespace: insightlearn
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 100Gi
---
apiVersion: v1
kind: Service
metadata:
  name: insightlearn-api-service
  namespace: insightlearn
  labels:
    app: insightlearn-api
spec:
  selector:
    app: insightlearn-api
  ports:
    - name: http
      port: 80
      targetPort: 8080
      protocol: TCP
  type: ClusterIP
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: insightlearn-api-hpa
  namespace: insightlearn
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: insightlearn-api
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
EOF

kubectl apply -f kubernetes/deployments/api-deployment-production.yaml

echo "✅ Expert team deployment initiated!"
echo "🔄 All services deploying in background..."
echo ""
echo "📊 Monitor deployment progress:"
echo "kubectl get pods -A -w"
echo ""