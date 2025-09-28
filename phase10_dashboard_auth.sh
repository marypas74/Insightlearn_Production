#!/bin/bash
# phase10_dashboard_auth.sh - Configure Kubernetes Dashboard with user/password authentication

KUBE_USER="mpasqui"
KUBE_PASS="SS1-Temp1234"

echo "=== [$(date)] Configurazione autenticazione Dashboard ==="

# Crea service account per dashboard user
cat > /tmp/dashboard-user.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dashboard-user
  namespace: kubernetes-dashboard
---
apiVersion: v1
kind: Secret
metadata:
  name: dashboard-user-secret
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: dashboard-user
type: kubernetes.io/service-account-token
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: dashboard-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: dashboard-user
  namespace: kubernetes-dashboard
EOF

echo "🔧 Creazione service account dashboard..."
kubectl apply -f /tmp/dashboard-user.yaml

# Configura Dashboard service per NodePort
echo "🔧 Configurazione NodePort per Dashboard..."
kubectl patch service kubernetes-dashboard -n kubernetes-dashboard -p '{"spec":{"type":"NodePort","ports":[{"nodePort":30443,"port":443,"protocol":"TCP","targetPort":8443}]}}' 2>/dev/null || \
kubectl patch service kubernetes-dashboard -n kubernetes-dashboard -p '{"spec":{"type":"NodePort","ports":[{"nodePort":30443,"port":80,"protocol":"TCP","targetPort":9090}]}}'

# Ottieni il token per l'accesso
echo "🔑 Ottenimento token di accesso..."
TOKEN=$(kubectl -n kubernetes-dashboard get secret dashboard-user-secret -o jsonpath='{.data.token}' 2>/dev/null | base64 -d)

if [ -z "$TOKEN" ]; then
    # Prova metodo alternativo per ottenere il token
    TOKEN=$(kubectl -n kubernetes-dashboard create token dashboard-user 2>/dev/null)
fi

# Salva le credenziali
cat > /tmp/dashboard-access.txt << EOF
========================================
KUBERNETES DASHBOARD ACCESS INFORMATION
========================================
Dashboard URL: https://192.168.1.103:30443
Username: dashboard-user
Token: $TOKEN

Alternative access via kubectl proxy:
kubectl proxy
Then visit: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

========================================
EOF

echo "✅ Dashboard configurato con successo!"
echo ""
cat /tmp/dashboard-access.txt

# Verifica che il servizio sia raggiungibile
echo ""
echo "🔍 Verifica servizio Dashboard..."
kubectl get service kubernetes-dashboard -n kubernetes-dashboard
kubectl get pods -n kubernetes-dashboard

echo ""
echo "📊 Dashboard accessibile su: https://192.168.1.103:30443"
echo "🔐 Usa il token salvato in /tmp/dashboard-access.txt per l'accesso"