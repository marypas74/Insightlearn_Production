#!/bin/bash
# Script per configurare la persistenza di Minikube e InsightLearn

echo "💾 Configurazione persistenza Minikube..."

# Crea directory per dati persistenti
mkdir -p /home/mpasqui/.minikube-persistent/{postgres,redis,elasticsearch}

# Configura Minikube per usare storage persistente
minikube addons enable default-storageclass
minikube addons enable storage-provisioner

echo "✅ Persistenza configurata"

# Aggiorna i deployment per usare PersistentVolumes
cat > /home/mpasqui/Kubernetes/persistent-volumes.yaml << 'EOF'
---
# PersistentVolume per PostgreSQL
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgres-pv
  namespace: insightlearn
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: standard
  hostPath:
    path: /home/mpasqui/.minikube-persistent/postgres
---
# PersistentVolume per Redis
apiVersion: v1
kind: PersistentVolume
metadata:
  name: redis-pv
  namespace: insightlearn
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: standard
  hostPath:
    path: /home/mpasqui/.minikube-persistent/redis
---
# PersistentVolume per Elasticsearch
apiVersion: v1
kind: PersistentVolume
metadata:
  name: elasticsearch-pv
  namespace: insightlearn
spec:
  capacity:
    storage: 3Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: standard
  hostPath:
    path: /home/mpasqui/.minikube-persistent/elasticsearch
EOF

echo "📁 File di persistenza creato: persistent-volumes.yaml"