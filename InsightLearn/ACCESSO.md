# 🚀 Guida all'Accesso di InsightLearn

## ✅ InsightLearn è ora ATTIVO e accessibile!

### 📍 ACCESSO PRINCIPALE

**🌐 HTTP (consigliato per sviluppo):**
- Frontend: http://localhost:8080
- Backend API: http://localhost:8080/api
- Health check: http://localhost:8080/health

**🔐 HTTPS (certificato self-signed):**
- Frontend: https://localhost:8443
- Backend API: https://localhost:8443/api
- Health check: https://localhost:8443/health

### 📱 ACCESSO DA RETE LOCALE (192.168.1.103)

Per accedere da altri dispositivi nella rete:

1. **Aggiungi al file `/etc/hosts` degli altri dispositivi:**
   ```
   192.168.1.103 localhost
   ```

2. **Accedi tramite:**
   - HTTP: http://localhost:8080 (dal dispositivo remoto)
   - HTTPS: https://localhost:8443 (dal dispositivo remoto)

### 🛠️ Comandi di Controllo

```bash
# Verifica stato dei servizi
kubectl get pods -n insightlearn

# Visualizza logs del backend
kubectl logs -f -l app=insightlearn-backend -n insightlearn

# Visualizza logs del frontend
kubectl logs -f -l app=insightlearn-frontend -n insightlearn

# Riavvia i servizi
kubectl rollout restart deployment insightlearn-backend -n insightlearn
kubectl rollout restart deployment insightlearn-frontend -n insightlearn
```

### 🔧 Port Forwarding Attivi

I seguenti port forward sono attualmente attivi:
- `8080:80` - HTTP tramite Ingress
- `8443:443` - HTTPS tramite Ingress
- `5001:5000` - Accesso diretto al backend

### ⚠️ Note Importanti

1. **Certificato HTTPS:** Il certificato è self-signed, il browser mostrerà un avviso
   - Clicca "Avanzate" → "Procedi verso localhost (non sicuro)"

2. **Database:** PostgreSQL è configurato e funzionante con dati di esempio

3. **Auto-scaling:** Configurato HPA per scalare automaticamente i pod

### 🎯 Test dell'Applicazione

1. **Visita il frontend:** http://localhost:8080
2. **Verifica l'API:** http://localhost:8080/health
3. **Testa le funzionalità:**
   - Visualizza i corsi esistenti
   - Aggiungi un nuovo corso
   - Iscriviti a un corso

### 🛑 Per Fermare i Servizi

```bash
# Ferma i port forward
pkill -f "kubectl port-forward"

# (Opzionale) Rimuovi tutto il deployment
kubectl delete namespace insightlearn

# (Opzionale) Ferma Minikube
minikube stop
```

---

## 🎉 L'applicazione è pronta all'uso!

Accedi a **http://localhost:8080** per iniziare a usare InsightLearn!