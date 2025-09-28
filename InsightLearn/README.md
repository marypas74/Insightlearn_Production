# InsightLearn - E-Learning Platform

Una piattaforma di e-learning moderna costruita con Flask (backend) e vanilla JavaScript (frontend), deployata su Kubernetes.

## Architettura

```
InsightLearn/
├── backend/          # API Flask con SQLAlchemy
├── frontend/         # Interfaccia web HTML/CSS/JS
├── database/         # Script SQL per inizializzazione
├── k8s-manifests/    # File YAML per Kubernetes
└── docs/            # Documentazione

```

## Componenti

### Backend (Flask API)
- **Framework**: Flask con SQLAlchemy ORM
- **Database**: PostgreSQL
- **Endpoints**:
  - `GET /health` - Health check
  - `GET /api/courses` - Lista corsi
  - `POST /api/courses` - Crea nuovo corso
  - `POST /api/enrollments` - Iscrizione a un corso
  - `GET /api/enrollments/{course_id}` - Lista iscritti

### Frontend
- **Tecnologie**: HTML5, CSS3, JavaScript vanilla
- **Features**:
  - Visualizzazione catalogo corsi
  - Aggiunta nuovi corsi
  - Sistema di iscrizione
  - Design responsive

### Database (PostgreSQL)
- **Tabelle**:
  - `courses` - Informazioni sui corsi
  - `enrollments` - Iscrizioni studenti
  - `lessons` - Lezioni per corso
  - `progress_tracking` - Tracciamento progressi

## Deployment

### Prerequisiti
- Docker e Docker Compose
- Kubernetes cluster (Minikube, K3s, o cloud)
- kubectl configurato

### Quick Start con Docker Compose

```bash
# Avvia tutti i servizi
make docker-up

# Accedi all'applicazione
# Frontend: http://localhost
# Backend API: http://localhost:5000

# Ferma i servizi
make docker-down
```

### Deployment su Kubernetes

```bash
# 1. Costruisci le immagini Docker
make build-images

# 2. Deploy su Kubernetes
make deploy-k8s

# 3. Port forward per accesso locale
make port-forward

# Verifica lo stato
make status

# Visualizza i log
make logs-backend
make logs-frontend
make logs-postgres
```

### Accesso all'Applicazione

Con port-forward attivo:
- Frontend: http://localhost:8080
- Backend API: http://localhost:5000/health

Per produzione con Ingress:
- Aggiungi al file `/etc/hosts`: `127.0.0.1 insightlearn.local`
- Accedi a: http://insightlearn.local

## Kubernetes Features

### Auto-scaling
- **HPA (Horizontal Pod Autoscaler)** configurato per frontend e backend
- Scala automaticamente da 2 a 10 pod basandosi su CPU e memoria

### Health Checks
- **Liveness Probes**: Verifica che i pod siano vivi
- **Readiness Probes**: Verifica che i pod siano pronti a ricevere traffico

### Persistenza
- **PersistentVolumeClaim** per PostgreSQL (5Gi)
- I dati del database sono persistenti anche se il pod viene ricreato

### Configurazione
- **ConfigMaps**: Variabili d'ambiente non sensibili
- **Secrets**: Password database (base64 encoded)

## Sviluppo

### Struttura API Backend

```python
# Esempio di endpoint
@app.route('/api/courses', methods=['POST'])
def create_course():
    data = request.json
    course = Course(
        title=data['title'],
        description=data.get('description'),
        instructor=data.get('instructor'),
        duration=data.get('duration')
    )
    db.session.add(course)
    db.session.commit()
    return jsonify({'id': course.id}), 201
```

### Aggiornamento Immagini

```bash
# Dopo modifiche al codice
make build-images

# Aggiorna deployment Kubernetes
kubectl rollout restart deployment insightlearn-backend -n insightlearn
kubectl rollout restart deployment insightlearn-frontend -n insightlearn
```

## Monitoring

```bash
# Visualizza metriche dei pod
kubectl top pods -n insightlearn

# Controlla eventi
kubectl get events -n insightlearn

# Descrivi un pod specifico
kubectl describe pod <pod-name> -n insightlearn
```

## Troubleshooting

### Database Connection Issues
```bash
# Verifica che PostgreSQL sia running
kubectl get pod -l app=postgres -n insightlearn

# Controlla i log
kubectl logs -l app=postgres -n insightlearn
```

### Backend Non Raggiungibile
```bash
# Verifica il pod
kubectl get pod -l app=insightlearn-backend -n insightlearn

# Controlla i log per errori
kubectl logs -l app=insightlearn-backend -n insightlearn --tail=50
```

### Frontend 404 Errors
```bash
# Verifica che il servizio sia esposto
kubectl get service insightlearn-frontend-service -n insightlearn

# Controlla l'ingress
kubectl describe ingress insightlearn-ingress -n insightlearn
```

## Cleanup

```bash
# Rimuovi tutti i componenti da Kubernetes
make delete-k8s

# Pulisci immagini Docker locali
docker rmi insightlearn-backend:latest
docker rmi insightlearn-frontend:latest
```

## Prossimi Passi

1. **Autenticazione**: Implementare JWT per sicurezza API
2. **CI/CD**: Pipeline GitLab/GitHub Actions
3. **Monitoring**: Prometheus + Grafana
4. **Logging**: ELK Stack o Loki
5. **Service Mesh**: Istio per gestione avanzata del traffico
6. **Backup**: Strategia di backup per PostgreSQL
7. **SSL/TLS**: Certificati per HTTPS con cert-manager

## Licenza

MIT License