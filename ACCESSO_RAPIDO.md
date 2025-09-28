# 🎓 ACCESSO RAPIDO INSIGHTLEARN

## 🌐 URL di Accesso
- **Dashboard Kubernetes**: http://192.168.1.103:8443/#/workloads?namespace=insightlearn
- **InsightLearn HTTPS**: https://192.168.1.103
- **Accesso Diretto**: https://192.168.49.2:30443 (via Minikube)

## 🔑 Token Dashboard (valido 24h)
```
# Token generato automaticamente al startup
# Vedi: kubectl -n kubernetes-dashboard create token dashboard-admin --duration=24h
```

## 📊 Stato Sistema
- Pods: 28+
- Deployments: 11
- Services: 11
- Ultimo avvio: $(date)

## 🚀 Comandi Utili
```bash
# Verifica stato
kubectl get pods -n insightlearn

# Riavvio servizi
sudo systemctl restart insightlearn

# Log di sistema
tail -f /home/mpasqui/Kubernetes/logs/startup.log
```

## ✅ Port Forward Attivi
```bash
# Dashboard Kubernetes
kubectl port-forward -n kubernetes-dashboard pod/kubernetes-dashboard-8694d4445c-m75wg 8443:9090 --address='0.0.0.0'

# InsightLearn HTTPS
sudo kubectl port-forward -n insightlearn service/nginx-proxy-service 443:443 --address='0.0.0.0'
```