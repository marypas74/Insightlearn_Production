#!/bin/bash
# phase10_step2_nginx_ingress.sh

source ../production_command_executor.sh

echo "=== [$(date)] FASE 10 STEP 2: Nginx Ingress Configuration ===" | tee -a "$BASE_LOG_DIR/phase10_step2.log"

# Installa Nginx Ingress Controller
execute_production_command \
    "kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/baremetal/deploy.yaml" \
    "Install Nginx Ingress Controller" \
    "NGINX" \
    "true"

# Attendi che ingress controller sia ready
execute_production_command \
    "kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s" \
    "Wait for Nginx Ingress Controller ready" \
    "NGINX" \
    "true"

# Crea certificato SSL self-signed per production
execute_production_command \
    "mkdir -p ssl" \
    "Create SSL directory" \
    "SSL"

execute_production_command \
    "openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ssl/insightlearn.key \
        -out ssl/insightlearn.crt \
        -subj \"/C=IT/ST=Lombardy/L=Ponte San Pietro/O=InsightLearn/OU=Cloud/CN=192.168.1.103/subjectAltName=IP:192.168.1.103\"" \
    "Generate SSL certificate for production IP" \
    "SSL" \
    "true"

# Crea Kubernetes secret per SSL
execute_production_command \
    "kubectl create secret tls insightlearn-tls-secret \
        --cert=ssl/insightlearn.crt \
        --key=ssl/insightlearn.key \
        -n insightlearn --dry-run=client -o yaml | kubectl apply -f -" \
    "Create TLS secret in Kubernetes" \
    "SSL" \
    "true"

# Configura Nginx Ingress per production
execute_production_command \
    "cat > kubernetes/ingress-production.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: insightlearn-production-ingress
  namespace: insightlearn
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: \"true\"
    nginx.ingress.kubernetes.io/force-ssl-redirect: \"true\"
    nginx.ingress.kubernetes.io/proxy-body-size: \"100m\"
    nginx.ingress.kubernetes.io/proxy-read-timeout: \"300\"
    nginx.ingress.kubernetes.io/proxy-send-timeout: \"300\"
    nginx.ingress.kubernetes.io/client-max-body-size: \"100m\"
    nginx.ingress.kubernetes.io/rewrite-target: /
    # Rate limiting per production
    nginx.ingress.kubernetes.io/rate-limit: \"100\"
    nginx.ingress.kubernetes.io/rate-limit-window: \"1m\"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - \"192.168.1.103\"
    secretName: insightlearn-tls-secret
  rules:
  - host: \"192.168.1.103\"
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: insightlearn-api-service
            port:
              number: 80
      - path: /health
        pathType: Prefix
        backend:
          service:
            name: insightlearn-api-service
            port:
              number: 80
      - path: /metrics
        pathType: Prefix
        backend:
          service:
            name: prometheus
            port:
              number: 9090
      - path: /
        pathType: Prefix
        backend:
          service:
            name: insightlearn-web-service
            port:
              number: 80
EOF" \
    "Create production ingress configuration" \
    "NGINX" \
    "true"

# Configura NodePort per accesso esterno
execute_production_command \
    "kubectl patch service ingress-nginx-controller -n ingress-nginx -p '{\"spec\":{\"type\":\"NodePort\",\"ports\":[{\"name\":\"http\",\"nodePort\":30080,\"port\":80,\"protocol\":\"TCP\",\"targetPort\":\"http\"},{\"name\":\"https\",\"nodePort\":30443,\"port\":443,\"protocol\":\"TCP\",\"targetPort\":\"https\"}]}}'" \
    "Configure NodePort for external access" \
    "NGINX" \
    "true"

# Applica ingress production
execute_production_command \
    "kubectl apply -f kubernetes/ingress-production.yaml" \
    "Apply production ingress" \
    "NGINX" \
    "true"

production_log "SUCCESS" "STEP_10_2" "Nginx Ingress configuration completata"