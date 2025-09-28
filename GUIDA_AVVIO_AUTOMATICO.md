# 🚀 GUIDA AVVIO AUTOMATICO INSIGHTLEARN

## 📋 Cosa è stato configurato

Ho creato un sistema completo di avvio automatico che ripristina tutta la configurazione InsightLearn al riavvio del server.

## 🔧 File creati:

### 1. Script di Avvio Principale
- **File**: `/home/mpasqui/Kubernetes/insightlearn-startup.sh`
- **Funzione**: Avvia automaticamente tutto il sistema InsightLearn
- **Cosa fa**:
  - Avvia Minikube se non è running
  - Deploy di tutti i componenti InsightLearn
  - Configura port forwarding per dashboard e applicazione
  - Genera token di accesso dashboard
  - Salva informazioni di accesso

### 2. Servizio Systemd
- **File**: `/tmp/insightlearn.service`
- **Funzione**: Configura l'avvio automatico del sistema

### 3. Script di Installazione
- **File**: `/home/mpasqui/Kubernetes/install-service.sh`
- **Funzione**: Guida per installare il servizio systemd

### 4. Configurazione Persistenza
- **File**: `/home/mpasqui/Kubernetes/configure-persistence.sh`
- **Funzione**: Configura storage persistente per i database

## 🔧 INSTALLAZIONE (da eseguire una volta)

### Passo 1: Installa il servizio systemd
```bash
cd /home/mpasqui/Kubernetes

# Copia il servizio
sudo mv /tmp/insightlearn.service /etc/systemd/system/

# Ricarica systemd
sudo systemctl daemon-reload

# Abilita avvio automatico
sudo systemctl enable insightlearn

# Avvia il servizio
sudo systemctl start insightlearn
```

### Passo 2: Configura persistenza (opzionale)
```bash
./configure-persistence.sh
kubectl apply -f persistent-volumes.yaml
```

## 🎯 UTILIZZO

### Avvio Manuale
```bash
# Avvia tutto il sistema
/home/mpasqui/Kubernetes/insightlearn-startup.sh
```

### Controllo Servizio
```bash
# Stato del servizio
sudo systemctl status insightlearn

# Riavvio del servizio
sudo systemctl restart insightlearn

# Stop del servizio
sudo systemctl stop insightlearn

# Log del servizio
sudo journalctl -u insightlearn -f
```

### Log di Sistema
```bash
# Log dettagliato di avvio
tail -f /home/mpasqui/Kubernetes/logs/startup.log
```

## 📊 DOPO IL RIAVVIO

Dopo ogni riavvio del server, il sistema:

1. **Avvia automaticamente** Minikube
2. **Deploy automatico** di tutti i componenti InsightLearn
3. **Configura automaticamente** i port forwarding:
   - Dashboard: http://192.168.1.103:8443
   - InsightLearn: https://192.168.1.103
4. **Genera automaticamente** il token di accesso
5. **Salva** tutte le informazioni in `/home/mpasqui/Kubernetes/ACCESSO_RAPIDO.md`

## 🎯 URL di Accesso (sempre gli stessi)

- **Dashboard Kubernetes**: http://192.168.1.103:8443/#/workloads?namespace=insightlearn
- **InsightLearn HTTPS**: https://192.168.1.103
- **InsightLearn HTTP**: http://192.168.1.103

## 📋 File di Accesso Rapido

Dopo ogni avvio, controlla il file:
```bash
cat /home/mpasqui/Kubernetes/ACCESSO_RAPIDO.md
```

Contiene:
- URL di accesso
- Token dashboard aggiornato
- Stato del sistema
- Comandi utili

## 🔄 Test del Sistema

Per testare che tutto funzioni al riavvio:

```bash
# Simula riavvio (solo per test)
sudo systemctl stop insightlearn
minikube stop

# Riavvia
sudo systemctl start insightlearn

# Controlla log
tail -f /home/mpasqui/Kubernetes/logs/startup.log
```

## ⚠️ Note Importanti

1. **Il primo avvio** può richiedere 5-10 minuti
2. **I dati del database** sono persistenti se configurato
3. **I port forward** sono automatici
4. **Il token dashboard** viene rigenerato ogni 24h
5. **Tutto è completamente automatico** dopo l'installazione iniziale

## 🆘 Risoluzione Problemi

Se qualcosa non funziona:

```bash
# Controlla stato servizio
sudo systemctl status insightlearn

# Controlla log errori
sudo journalctl -u insightlearn --no-pager

# Riavvio manuale
sudo systemctl restart insightlearn

# Avvio manuale per debug
/home/mpasqui/Kubernetes/insightlearn-startup.sh
```

## ✅ Risultato Finale

Dopo l'installazione, **ogni riavvio del server** ripristinerà automaticamente:
- ✅ Minikube running
- ✅ Tutti i 28+ pod InsightLearn
- ✅ Dashboard accessibile su porta 8443
- ✅ InsightLearn accessibile su porta 443
- ✅ Tutti i dati e configurazioni
- ✅ Token di accesso aggiornato