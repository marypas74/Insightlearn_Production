# 🎓 InsightLearn Kubernetes Production

## 🏭 **AMBIENTE DI PRODUZIONE**

⚠️ **ATTENZIONE**: Questo è l'ambiente di **PRODUZIONE**. Non mischiare con staging!

### 🌟 **Panoramica**

InsightLearn Production è una piattaforma e-learning completa deployata su Kubernetes con:
- **Dashboard Kubernetes**: http://192.168.1.103:8443
- **InsightLearn Platform**: https://192.168.1.103
- **Full High Availability**: 28+ pod attivi
- **Avvio Automatico**: Configurato con systemd

### 🏗️ **Architettura Produzione**

```
📊 DEPLOYMENTS (11):
├── insightlearn-analytics (2 repliche)
├── insightlearn-notifications (1 replica)
├── insightlearn-backend (10 repliche con HPA)
├── insightlearn-frontend (2 repliche)
├── insightlearn-web (2 repliche)
├── insightlearn-api (2 repliche)
├── postgres (1 replica)
├── redis (1 replica)
├── elasticsearch (1 replica)
├── nginx-proxy (1 replica)
└── demo-nginx (2 repliche)

💾 DATABASES:
├── PostgreSQL (dati principali)
├── Redis (cache)
└── Elasticsearch (search)

🔧 SERVICES (11):
├── LoadBalancer/NodePort per accesso esterno
└── ClusterIP per comunicazione interna
```

### 🚀 **Avvio Rapido**

```bash
# Avvio automatico completo
/home/mpasqui/Kubernetes/insightlearn-startup.sh

# Controllo stato
kubectl get pods -n insightlearn

# Accesso
# Dashboard: http://192.168.1.103:8443/#/workloads?namespace=insightlearn
# InsightLearn: https://192.168.1.103
```

### 📋 **Comandi Produzione**

```bash
# Status generale
make status                    # (da InsightLearn/)
kubectl get all -n insightlearn

# Logs
make logs-backend             # Backend logs
make logs-frontend            # Frontend logs
kubectl logs -f deployment/insightlearn-analytics -n insightlearn

# Riavvio servizi
sudo systemctl restart insightlearn

# Backup
kubectl apply -f insightlearn-data-init.yaml  # Re-init data
```

### 🔧 **Configurazione Sistema**

#### Systemd Service
```bash
# Stato servizio
sudo systemctl status insightlearn

# Avvio automatico al boot
sudo systemctl enable insightlearn
```

#### Port Forwarding Produzione
```bash
# Dashboard (automatico)
kubectl port-forward -n kubernetes-dashboard pod/kubernetes-dashboard-xxx 8443:9090

# InsightLearn HTTPS (automatico)
sudo kubectl port-forward -n insightlearn service/nginx-proxy-service 443:443
```

### 📊 **Dati Business**

```json
{
  "platform": "InsightLearn",
  "totalStudents": 7,
  "totalInstructors": 2,
  "totalCourses": 8,
  "totalEnrollments": 7,
  "activeUsers": 5,
  "completionRate": 28.6,
  "environment": "production"
}
```

### 🔐 **Sicurezza**

- ✅ HTTPS con certificati SSL
- ✅ Namespace isolation
- ✅ Secrets management
- ✅ Token-based authentication
- ✅ Network policies

### 📁 **Struttura Repository**

```
/home/mpasqui/Kubernetes/
├── 📋 README.md                          # Questo file
├── 🔧 insightlearn-startup.sh            # Script avvio automatico
├── 📚 CLAUDE.md                          # Guida per Claude Code
├── 📖 GUIDA_AVVIO_AUTOMATICO.md         # Documentazione completa
├── 📊 ACCESSO_RAPIDO.md                  # Info accesso e token
├── ⚙️ insightlearn.service               # Systemd service
├── 🐳 InsightLearn/                      # Applicazione base
├── ☁️ InsightLearn.Cloud/                # Ambiente cloud completo
├── 📝 insightlearn-data-init.yaml       # Inizializzazione dati
├── 🎯 insightlearn-metrics-workloads.yaml # Workload analytics
├── 🔧 configure-persistence.sh          # Setup persistenza
├── 📜 logs/                             # Log di sistema
└── 🚫 .gitignore                        # Esclusioni git
```

### 🆘 **Troubleshooting**

#### Problemi Comuni
```bash
# Pod non in running
kubectl describe pod <pod-name> -n insightlearn

# Port forward non funziona
sudo systemctl restart insightlearn

# Dashboard non accessibile
kubectl -n kubernetes-dashboard create token dashboard-admin

# Applicazione non raggiungibile
curl -I https://192.168.1.103 -k
```

#### Recovery Completo
```bash
# Emergency restart
minikube stop && minikube start
sudo systemctl restart insightlearn

# Logs di debug
tail -f /home/mpasqui/Kubernetes/logs/startup.log
```

### 📞 **Supporto**

- **Documentazione**: `/home/mpasqui/Kubernetes/GUIDA_AVVIO_AUTOMATICO.md`
- **Log Sistema**: `/home/mpasqui/Kubernetes/logs/startup.log`
- **Status Check**: `./run_all_tests.sh`

### ⚠️ **IMPORTANTE**

1. **NON modificare** configurazioni senza backup
2. **NON mischiare** con ambiente staging
3. **SEMPRE verificare** stato prima di deploy
4. **BACKUP database** prima di aggiornamenti
5. **TESTARE** su staging prima di produzione

---

🎯 **Ambiente Produzione InsightLearn - Kubernetes Ready**