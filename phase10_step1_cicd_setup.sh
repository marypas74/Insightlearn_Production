#!/bin/bash
# phase10_step1_cicd_setup.sh

source production_command_executor.sh

echo "=== [$(date)] FASE 10 STEP 1: CI/CD Pipeline Setup ===" | tee -a "$BASE_LOG_DIR/phase10_step1.log"

cd InsightLearn.Cloud

# Crea GitHub Actions directory
execute_production_command \
    "mkdir -p .github/workflows" \
    "Create GitHub Actions directory" \
    "CICD"

# Crea main CI/CD pipeline
execute_production_command \
    "cat > .github/workflows/production-deploy.yml << 'EOF'
name: InsightLearn.Cloud Production Deploy

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

env:
  REGISTRY: ghcr.io
  IMAGE_NAME_WEB: insightlearn/web
  IMAGE_NAME_API: insightlearn/api
  PRODUCTION_IP: 192.168.1.103
  KUBE_NAMESPACE: insightlearn

jobs:
  test:
    runs-on: ubuntu-latest
    name: Run Tests

    steps:
    - uses: actions/checkout@v4

    - name: Setup .NET
      uses: actions/setup-dotnet@v3
      with:
        dotnet-version: 8.0.x

    - name: Restore dependencies
      run: dotnet restore

    - name: Build solution
      run: dotnet build --configuration Release --no-restore

    - name: Run unit tests
      run: dotnet test --no-build --verbosity normal --collect:\"XPlat Code Coverage\"

    - name: Code coverage report
      uses: codecov/codecov-action@v3
      with:
        files: coverage.cobertura.xml

  build-and-push:
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main'

    permissions:
      contents: read
      packages: write

    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Log in to Container Registry
      uses: docker/login-action@v3
      with:
        registry: \${{ env.REGISTRY }}
        username: \${{ github.actor }}
        password: \${{ secrets.GITHUB_TOKEN }}

    - name: Build and push Web image
      uses: docker/build-push-action@v5
      with:
        context: .
        file: ./docker/Dockerfile.web
        push: true
        tags: |
          \${{ env.REGISTRY }}/\${{ env.IMAGE_NAME_WEB }}:latest
          \${{ env.REGISTRY }}/\${{ env.IMAGE_NAME_WEB }}:\${{ github.sha }}
        labels: |
          org.opencontainers.image.source=\${{ github.repositoryUrl }}
          org.opencontainers.image.revision=\${{ github.sha }}

    - name: Build and push API image
      uses: docker/build-push-action@v5
      with:
        context: .
        file: ./docker/Dockerfile.api
        push: true
        tags: |
          \${{ env.REGISTRY }}/\${{ env.IMAGE_NAME_API }}:latest
          \${{ env.REGISTRY }}/\${{ env.IMAGE_NAME_API }}:\${{ github.sha }}

  deploy-production:
    runs-on: self-hosted
    needs: build-and-push
    if: github.ref == 'refs/heads/main'

    environment: production

    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup production environment
      run: |
        echo \"Setting up production deployment for commit \${{ github.sha }}\"

        # Update image tags in manifests
        sed -i \"s|image: insightlearn/web:latest|image: ghcr.io/insightlearn/web:\${{ github.sha }}|g\" kubernetes/deployments/web-deployment.yaml
        sed -i \"s|image: insightlearn/api:latest|image: ghcr.io/insightlearn/api:\${{ github.sha }}|g\" kubernetes/deployments/web-deployment.yaml

    - name: Deploy to Kubernetes
      run: |
        # Apply all manifests
        kubectl apply -f kubernetes/namespace.yaml
        kubectl apply -f kubernetes/configmaps/
        kubectl apply -f kubernetes/secrets/
        kubectl apply -f kubernetes/deployments/
        kubectl apply -f kubernetes/services/
        kubectl apply -f kubernetes/ingress.yaml

        # Wait for rollout
        kubectl rollout status deployment/insightlearn-web -n insightlearn --timeout=600s
        kubectl rollout status deployment/insightlearn-api -n insightlearn --timeout=600s

    - name: Verify deployment
      run: |
        kubectl get pods -n insightlearn
        kubectl get services -n insightlearn
        kubectl get ingress -n insightlearn

        # Health check
        sleep 30
        curl -f http://\${{ env.PRODUCTION_IP }}/health || exit 1

    - name: Notify deployment success
      run: |
        echo \"🚀 Production deployment successful!\"
        echo \"✅ Web: https://\${{ env.PRODUCTION_IP }}\"
        echo \"📊 Dashboard: https://\${{ env.PRODUCTION_IP }}:30443\"
EOF" \
    "Create main CI/CD pipeline" \
    "CICD" \
    "true"

# Crea workflow per backup automatico
execute_production_command \
    "cat > .github/workflows/backup.yml << 'EOF'
name: Production Backup

on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM
  workflow_dispatch:

jobs:
  backup:
    runs-on: self-hosted

    steps:
    - name: Backup Kubernetes manifests
      run: |
        BACKUP_DIR=\"backups/\$(date +%Y%m%d_%H%M%S)\"
        mkdir -p \$BACKUP_DIR

        # Backup current manifests
        kubectl get all -n insightlearn -o yaml > \$BACKUP_DIR/insightlearn-resources.yaml
        kubectl get all -n insightlearn-monitoring -o yaml > \$BACKUP_DIR/monitoring-resources.yaml

        # Backup secrets (without values)
        kubectl get secrets -n insightlearn -o yaml | sed 's/data:/data: {}/' > \$BACKUP_DIR/secrets-structure.yaml

        echo \"✅ Backup completed in \$BACKUP_DIR\"

    - name: Cleanup old backups
      run: |
        find backups/ -type d -mtime +30 -exec rm -rf {} + || true
        echo \"✅ Old backups cleaned up\"
EOF" \
    "Create backup workflow" \
    "CICD"

production_log "SUCCESS" "STEP_10_1" "CI/CD pipeline setup completato"