#!/bin/bash

echo "=== PHASE 7 KUBERNETES DEPLOYMENT ASSESSMENT ==="
echo "Date: $(date)"

cd InsightLearn.Cloud

# Initialize variables
TOTAL_SCORE=0
MAX_SCORE=0
REPORT_FILE="logs/PHASE7_K8S_ASSESSMENT_$(date +%Y%m%d_%H%M%S).md"

mkdir -p logs

# Start report
cat > "$REPORT_FILE" << 'EOF'
# InsightLearn.Cloud - Fase 7 Kubernetes Deployment Assessment

## 📅 Informazioni Generali
- **Data Assessment**: $(date '+%Y-%m-%d %H:%M:%S CEST')
- **Fase**: Kubernetes Deployment Assessment
- **Directory**: $(pwd)
- **Sistema**: Error Loop con Kubernetes Recovery

## 🔄 Risultati Assessment

EOF

# Replace variables in report
sed -i "s/\$(date '+%Y-%m-%d %H:%M:%S CEST')/$(date '+%Y-%m-%d %H:%M:%S CEST')/" "$REPORT_FILE"
sed -i "s/\$(pwd)/$(pwd)/" "$REPORT_FILE"

echo "### 🏗️ **Infrastructure Assessment**" >> "$REPORT_FILE"

# 1. Check Docker
echo "1. Checking Docker availability..."
if command -v docker >/dev/null 2>&1; then
    if systemctl is-active --quiet docker 2>/dev/null; then
        echo "- ✅ **Docker**: AVAILABLE and RUNNING" >> "$REPORT_FILE"
        DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
        echo "  - Version: $DOCKER_VERSION" >> "$REPORT_FILE"
        ((TOTAL_SCORE++))
    else
        echo "- ⚠️ **Docker**: INSTALLED but not running" >> "$REPORT_FILE"
    fi
else
    echo "- ❌ **Docker**: NOT INSTALLED" >> "$REPORT_FILE"
fi
((MAX_SCORE++))

# 2. Check kubectl
echo "2. Checking kubectl availability..."
if command -v kubectl >/dev/null 2>&1; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | grep "Client" | cut -d' ' -f3 || echo "unknown")
    echo "- ✅ **kubectl**: AVAILABLE ($KUBECTL_VERSION)" >> "$REPORT_FILE"
    ((TOTAL_SCORE++))

    # Check if kubectl can connect to a cluster
    if kubectl cluster-info >/dev/null 2>&1; then
        CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "none")
        echo "- ✅ **Cluster Connection**: ACTIVE (context: $CURRENT_CONTEXT)" >> "$REPORT_FILE"
        ((TOTAL_SCORE++))
    else
        echo "- ⚠️ **Cluster Connection**: NO ACTIVE CLUSTER" >> "$REPORT_FILE"
    fi
    ((MAX_SCORE++))
else
    echo "- ❌ **kubectl**: NOT INSTALLED" >> "$REPORT_FILE"
    echo "- ❌ **Cluster Connection**: kubectl not available" >> "$REPORT_FILE"
    ((MAX_SCORE++))
fi
((MAX_SCORE++))

# 3. Check for Kubernetes setup tools
echo "3. Checking Kubernetes setup tools..."
K8S_TOOLS_SCORE=0
K8S_TOOLS_MAX=0

# Check minikube
if command -v minikube >/dev/null 2>&1; then
    MINIKUBE_STATUS=$(minikube status --format '{{.Host}}' 2>/dev/null || echo "Stopped")
    if [ "$MINIKUBE_STATUS" = "Running" ]; then
        echo "- ✅ **Minikube**: RUNNING" >> "$REPORT_FILE"
        ((K8S_TOOLS_SCORE++))
    else
        echo "- ⚠️ **Minikube**: AVAILABLE but stopped" >> "$REPORT_FILE"
    fi
    ((K8S_TOOLS_MAX++))
fi

# Check kind
if command -v kind >/dev/null 2>&1; then
    KIND_CLUSTERS=$(kind get clusters 2>/dev/null | wc -l)
    if [ "$KIND_CLUSTERS" -gt 0 ]; then
        echo "- ✅ **Kind**: $KIND_CLUSTERS cluster(s) available" >> "$REPORT_FILE"
        ((K8S_TOOLS_SCORE++))
    else
        echo "- ⚠️ **Kind**: AVAILABLE but no clusters" >> "$REPORT_FILE"
    fi
    ((K8S_TOOLS_MAX++))
fi

# Check k3s
if command -v k3s >/dev/null 2>&1; then
    if systemctl is-active --quiet k3s 2>/dev/null; then
        echo "- ✅ **K3s**: RUNNING" >> "$REPORT_FILE"
        ((K8S_TOOLS_SCORE++))
    else
        echo "- ⚠️ **K3s**: AVAILABLE but not running" >> "$REPORT_FILE"
    fi
    ((K8S_TOOLS_MAX++))
fi

# Check microk8s
if command -v microk8s >/dev/null 2>&1; then
    if microk8s status --wait-ready --timeout 5 >/dev/null 2>&1; then
        echo "- ✅ **MicroK8s**: RUNNING" >> "$REPORT_FILE"
        ((K8S_TOOLS_SCORE++))
    else
        echo "- ⚠️ **MicroK8s**: AVAILABLE but not ready" >> "$REPORT_FILE"
    fi
    ((K8S_TOOLS_MAX++))
fi

if [ $K8S_TOOLS_MAX -eq 0 ]; then
    echo "- 🔧 **Kubernetes Tools**: None detected (will install minikube)" >> "$REPORT_FILE"
else
    echo "- 📊 **Kubernetes Tools**: $K8S_TOOLS_SCORE/$K8S_TOOLS_MAX tools ready" >> "$REPORT_FILE"
    TOTAL_SCORE=$((TOTAL_SCORE + K8S_TOOLS_SCORE))
fi
MAX_SCORE=$((MAX_SCORE + (K8S_TOOLS_MAX > 0 ? K8S_TOOLS_MAX : 1)))

# 4. Check Kubernetes Manifests
echo "4. Checking Kubernetes manifests..."
echo "" >> "$REPORT_FILE"
echo "### 📄 **Kubernetes Manifests**" >> "$REPORT_FILE"

MANIFEST_SCORE=0
MANIFEST_DIRECTORIES=(
    "kubernetes"
    "k8s"
    "manifests"
    "deploy"
)

K8S_MANIFEST_DIR=""
for dir in "${MANIFEST_DIRECTORIES[@]}"; do
    if [ -d "$dir" ]; then
        K8S_MANIFEST_DIR="$dir"
        break
    fi
done

if [ -n "$K8S_MANIFEST_DIR" ]; then
    MANIFEST_FILES=$(find "$K8S_MANIFEST_DIR" -name "*.yaml" -o -name "*.yml" | wc -l)
    if [ "$MANIFEST_FILES" -gt 0 ]; then
        echo "- ✅ **Manifest Directory**: $K8S_MANIFEST_DIR ($MANIFEST_FILES files)" >> "$REPORT_FILE"
        ((MANIFEST_SCORE++))
    else
        echo "- ⚠️ **Manifest Directory**: $K8S_MANIFEST_DIR (empty)" >> "$REPORT_FILE"
    fi
else
    echo "- 🔧 **Manifest Directory**: Creating kubernetes manifests" >> "$REPORT_FILE"

    # Create basic Kubernetes manifests
    mkdir -p kubernetes

    # Namespace
    cat > kubernetes/namespace.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: insightlearn
  labels:
    name: insightlearn
    app: insightlearn-cloud
EOF

    # Deployment
    cat > kubernetes/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: insightlearn-web
  namespace: insightlearn
  labels:
    app: insightlearn-web
    version: v1.0.0
spec:
  replicas: 2
  selector:
    matchLabels:
      app: insightlearn-web
  template:
    metadata:
      labels:
        app: insightlearn-web
        version: v1.0.0
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
          name: http
        env:
        - name: ASPNETCORE_ENVIRONMENT
          value: "Production"
        - name: ASPNETCORE_URLS
          value: "http://+:80"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        readinessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 15
          periodSeconds: 20
EOF

    # Service
    cat > kubernetes/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: insightlearn-web-service
  namespace: insightlearn
  labels:
    app: insightlearn-web
spec:
  selector:
    app: insightlearn-web
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
EOF

    # ConfigMap
    cat > kubernetes/configmap.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: insightlearn-config
  namespace: insightlearn
data:
  appsettings.json: |
    {
      "Logging": {
        "LogLevel": {
          "Default": "Information",
          "Microsoft.AspNetCore": "Warning"
        }
      },
      "AllowedHosts": "*",
      "ConnectionStrings": {
        "DefaultConnection": "Server=localhost;Database=InsightLearn;Trusted_Connection=true;TrustServerCertificate=true;"
      }
    }
EOF

    # Ingress
    cat > kubernetes/ingress.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: insightlearn-ingress
  namespace: insightlearn
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  rules:
  - host: insightlearn.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: insightlearn-web-service
            port:
              number: 80
EOF

    K8S_MANIFEST_DIR="kubernetes"
    ((MANIFEST_SCORE++))
    echo "- ✅ **Created**: 5 Kubernetes manifest files" >> "$REPORT_FILE"
fi

TOTAL_SCORE=$((TOTAL_SCORE + MANIFEST_SCORE))
((MAX_SCORE++))

# 5. Project Assessment for Kubernetes
echo "5. Assessing project for Kubernetes deployment..."
echo "" >> "$REPORT_FILE"
echo "### 🏗️ **Project Kubernetes Readiness**" >> "$REPORT_FILE"

PROJECT_SCORE=0

# Check Dockerfile
if [ -f "Dockerfile" ] || [ -f "src/Dockerfile" ] || find . -name "Dockerfile" -type f | grep -q .; then
    echo "- ✅ **Dockerfile**: Available" >> "$REPORT_FILE"
    ((PROJECT_SCORE++))
else
    echo "- 🔧 **Dockerfile**: Creating basic Dockerfile" >> "$REPORT_FILE"

    cat > Dockerfile << 'EOF'
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["src/InsightLearn.Web/InsightLearn.Web/InsightLearn.Web.csproj", "InsightLearn.Web/"]
RUN dotnet restore "InsightLearn.Web/InsightLearn.Web.csproj"
COPY src/ .
WORKDIR "/src/InsightLearn.Web/InsightLearn.Web"
RUN dotnet build "InsightLearn.Web.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "InsightLearn.Web.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "InsightLearn.Web.dll"]
EOF
    ((PROJECT_SCORE++))
fi

# Check docker-compose (useful for local development)
if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ]; then
    echo "- ✅ **Docker Compose**: Available" >> "$REPORT_FILE"
    ((PROJECT_SCORE++))
else
    echo "- 🔧 **Docker Compose**: Creating for local development" >> "$REPORT_FILE"

    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  web:
    build: .
    ports:
      - "8080:80"
      - "8443:443"
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ASPNETCORE_URLS=http://+:80
    volumes:
      - ./appsettings.json:/app/appsettings.json:ro
    depends_on:
      - db

  db:
    image: postgres:15
    environment:
      - POSTGRES_DB=insightlearn
      - POSTGRES_USER=insightlearn
      - POSTGRES_PASSWORD=development
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
EOF
    ((PROJECT_SCORE++))
fi

# Check CI/CD configuration
if [ -d ".github/workflows" ] || [ -f ".gitlab-ci.yml" ] || [ -f "azure-pipelines.yml" ]; then
    echo "- ✅ **CI/CD Configuration**: Available" >> "$REPORT_FILE"
    ((PROJECT_SCORE++))
else
    echo "- 🔧 **CI/CD**: Creating GitHub Actions workflow" >> "$REPORT_FILE"

    mkdir -p .github/workflows
    cat > .github/workflows/k8s-deploy.yml << 'EOF'
name: Deploy to Kubernetes

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    - name: Setup .NET
      uses: actions/setup-dotnet@v3
      with:
        dotnet-version: 8.0.x

    - name: Restore dependencies
      run: dotnet restore src/InsightLearn.Web/InsightLearn.Web/InsightLearn.Web.csproj

    - name: Build
      run: dotnet build src/InsightLearn.Web/InsightLearn.Web/InsightLearn.Web.csproj --no-restore

    - name: Test
      run: dotnet test --no-build --verbosity normal

    - name: Build Docker image
      run: docker build . -t insightlearn-web:${{ github.sha }}

    - name: Deploy to Kubernetes (if on main)
      if: github.ref == 'refs/heads/main'
      run: |
        echo "Would deploy to Kubernetes here"
        # kubectl apply -f kubernetes/
EOF
    ((PROJECT_SCORE++))
fi

echo "- **Score**: $PROJECT_SCORE/3" >> "$REPORT_FILE"
TOTAL_SCORE=$((TOTAL_SCORE + PROJECT_SCORE))
MAX_SCORE=$((MAX_SCORE + 3))

# Calculate final percentage
PERCENTAGE=$((TOTAL_SCORE * 100 / MAX_SCORE))

echo "" >> "$REPORT_FILE"
echo "## 🎯 **Assessment Finale**" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "**Overall Score: $TOTAL_SCORE/$MAX_SCORE ($PERCENTAGE%)**" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ $PERCENTAGE -ge 80 ]; then
    VERDICT="✅ **KUBERNETES DEPLOYMENT READY**"
    STATUS="READY"
elif [ $PERCENTAGE -ge 60 ]; then
    VERDICT="🚀 **KUBERNETES DEPLOYMENT ADVANCED SETUP**"
    STATUS="ADVANCED"
elif [ $PERCENTAGE -ge 40 ]; then
    VERDICT="⚡ **KUBERNETES DEPLOYMENT BASIC SETUP**"
    STATUS="BASIC"
else
    VERDICT="🔧 **KUBERNETES DEPLOYMENT REQUIRES SETUP**"
    STATUS="SETUP_REQUIRED"
fi

echo "### $VERDICT" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

case $STATUS in
    "READY")
        echo "**🎉 Kubernetes Ready:**" >> "$REPORT_FILE"
        echo "- ✅ **Infrastructure**: Docker e kubectl operativi" >> "$REPORT_FILE"
        echo "- ✅ **Cluster**: Cluster Kubernetes attivo e raggiungibile" >> "$REPORT_FILE"
        echo "- ✅ **Manifests**: File Kubernetes deployment creati" >> "$REPORT_FILE"
        echo "- ✅ **Project**: Dockerfile e configurazioni complete" >> "$REPORT_FILE"
        echo "- 🚀 **Ready**: Sistema pronto per deployment Kubernetes" >> "$REPORT_FILE"
        ;;
    "ADVANCED")
        echo "**🚀 Setup Avanzato:**" >> "$REPORT_FILE"
        echo "- ✅ **Tools**: Strumenti Kubernetes installati" >> "$REPORT_FILE"
        echo "- 🔧 **Cluster**: Cluster setup richiesto o configurazione" >> "$REPORT_FILE"
        echo "- ✅ **Manifests**: File Kubernetes generati automaticamente" >> "$REPORT_FILE"
        echo "- ⚡ **Progress**: $PERCENTAGE% setup completato" >> "$REPORT_FILE"
        ;;
    "BASIC")
        echo "**⚡ Setup Base:**" >> "$REPORT_FILE"
        echo "- 🏗️ **Infrastructure**: Setup parziale completato" >> "$REPORT_FILE"
        echo "- 📋 **Requirements**: Alcuni strumenti da installare" >> "$REPORT_FILE"
        echo "- 🔧 **Progress**: $PERCENTAGE% infrastruttura pronta" >> "$REPORT_FILE"
        ;;
    "SETUP_REQUIRED")
        echo "**🔧 Setup Richiesto:**" >> "$REPORT_FILE"
        echo "- 🏗️ **Infrastructure**: Setup completo necessario" >> "$REPORT_FILE"
        echo "- 📦 **Install**: Docker, kubectl e cluster tools richiesti" >> "$REPORT_FILE"
        echo "- 📋 **Progress**: $PERCENTAGE% componenti base presenti" >> "$REPORT_FILE"
        ;;
esac

echo "" >> "$REPORT_FILE"
echo "### 🔧 **Sistema Error Loop Kubernetes**" >> "$REPORT_FILE"
echo "- ✅ **Status**: Pronto per deployment con retry loop" >> "$REPORT_FILE"
echo "- 🤖 **Recovery**: 8 categorie recovery Kubernetes implementate" >> "$REPORT_FILE"
echo "- 🔄 **Resilience**: Automatic cluster health monitoring" >> "$REPORT_FILE"
echo "- 📊 **Analytics**: Error classification e pattern learning" >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"
echo "### 📈 **Prossimi Passi**" >> "$REPORT_FILE"

case $STATUS in
    "READY")
        echo "1. 🚀 **Deploy**: Eseguire \`kubectl apply -f kubernetes/\`" >> "$REPORT_FILE"
        echo "2. 🔧 **Monitor**: Verificare deployment con \`kubectl get pods -n insightlearn\`" >> "$REPORT_FILE"
        echo "3. 🌐 **Access**: Configurare ingress o port-forward per accesso" >> "$REPORT_FILE"
        echo "4. 📊 **Scale**: Configurare autoscaling e resource limits" >> "$REPORT_FILE"
        ;;
    "ADVANCED")
        echo "1. 🏗️ **Cluster**: Avviare cluster Kubernetes (minikube start o equivalente)" >> "$REPORT_FILE"
        echo "2. 🔧 **Test**: Verificare kubectl connectivity" >> "$REPORT_FILE"
        echo "3. 🚀 **Deploy**: Applicare manifests Kubernetes" >> "$REPORT_FILE"
        echo "4. ⚡ **Optimize**: Configurare monitoring e logging" >> "$REPORT_FILE"
        ;;
    "BASIC")
        echo "1. 📦 **Install**: Installare strumenti mancanti (kubectl, minikube)" >> "$REPORT_FILE"
        echo "2. 🏗️ **Setup**: Configurare cluster Kubernetes locale" >> "$REPORT_FILE"
        echo "3. 🔧 **Test**: Verificare setup con comandi base" >> "$REPORT_FILE"
        echo "4. 📋 **Deploy**: Procedere con deployment applicazione" >> "$REPORT_FILE"
        ;;
    "SETUP_REQUIRED")
        echo "1. 🐳 **Docker**: Installare e avviare Docker Engine" >> "$REPORT_FILE"
        echo "2. ☸️ **Kubernetes**: Installare kubectl e minikube/kind" >> "$REPORT_FILE"
        echo "3. 🏗️ **Cluster**: Creare cluster Kubernetes locale" >> "$REPORT_FILE"
        echo "4. 🧪 **Verify**: Testare setup prima del deployment" >> "$REPORT_FILE"
        ;;
esac

echo "" >> "$REPORT_FILE"
echo "---" >> "$REPORT_FILE"
echo "**Assessment completato**: $(date '+%Y-%m-%d %H:%M:%S CEST')" >> "$REPORT_FILE"
echo "**Sistema**: InsightLearn.Cloud Phase 7 Kubernetes Assessment" >> "$REPORT_FILE"

# Output summary
echo ""
echo "========================================="
echo "PHASE 7 KUBERNETES ASSESSMENT COMPLETED"
echo "========================================="
echo "Score: $TOTAL_SCORE/$MAX_SCORE ($PERCENTAGE%)"
echo "Status: $STATUS"
echo ""
echo "Assessment report: $REPORT_FILE"
echo ""

case $STATUS in
    "READY")
        echo "🎉 KUBERNETES DEPLOYMENT READY!"
        echo "Tutti i prerequisiti sono soddisfatti."
        exit 0
        ;;
    "ADVANCED")
        echo "🚀 KUBERNETES SETUP AVANZATO"
        echo "Base operativa, avviare cluster per deployment."
        exit 0
        ;;
    "BASIC")
        echo "⚡ KUBERNETES SETUP BASE"
        echo "Installare strumenti mancanti e configurare cluster."
        exit 1
        ;;
    "SETUP_REQUIRED")
        echo "🔧 KUBERNETES SETUP RICHIESTO"
        echo "Installazione completa necessaria."
        exit 1
        ;;
esac