.PHONY: help build-images push-images deploy-k8s delete-k8s port-forward docker-up docker-down

help:
	@echo "Available commands:"
	@echo "  make build-images    - Build Docker images for frontend and backend"
	@echo "  make push-images     - Push images to registry (update registry URL first)"
	@echo "  make deploy-k8s      - Deploy all resources to Kubernetes"
	@echo "  make delete-k8s      - Delete all resources from Kubernetes"
	@echo "  make port-forward    - Port forward services for local access"
	@echo "  make docker-up       - Start services with Docker Compose"
	@echo "  make docker-down     - Stop Docker Compose services"

build-images:
	@echo "Building backend image..."
	docker build -t insightlearn-backend:latest ./backend
	@echo "Building frontend image..."
	docker build -t insightlearn-frontend:latest ./frontend

push-images:
	@echo "Tagging and pushing images..."
	# Update with your registry URL
	# docker tag insightlearn-backend:latest your-registry/insightlearn-backend:latest
	# docker tag insightlearn-frontend:latest your-registry/insightlearn-frontend:latest
	# docker push your-registry/insightlearn-backend:latest
	# docker push your-registry/insightlearn-frontend:latest

deploy-k8s:
	@echo "Creating namespace..."
	kubectl apply -f k8s-manifests/namespace.yaml
	@echo "Deploying PostgreSQL..."
	kubectl apply -f k8s-manifests/postgresql.yaml
	@echo "Waiting for PostgreSQL to be ready..."
	kubectl wait --for=condition=ready pod -l app=postgres -n insightlearn --timeout=120s
	@echo "Deploying backend..."
	kubectl apply -f k8s-manifests/backend.yaml
	@echo "Deploying frontend..."
	kubectl apply -f k8s-manifests/frontend.yaml
	@echo "Creating ingress..."
	kubectl apply -f k8s-manifests/ingress.yaml
	@echo "Deployment complete!"
	@echo "Run 'make port-forward' to access the application locally"

delete-k8s:
	@echo "Deleting all InsightLearn resources..."
	kubectl delete -f k8s-manifests/ingress.yaml --ignore-not-found
	kubectl delete -f k8s-manifests/frontend.yaml --ignore-not-found
	kubectl delete -f k8s-manifests/backend.yaml --ignore-not-found
	kubectl delete -f k8s-manifests/postgresql.yaml --ignore-not-found
	kubectl delete namespace insightlearn --ignore-not-found
	@echo "Cleanup complete!"

port-forward:
	@echo "Port forwarding services..."
	@echo "Frontend will be available at: http://localhost:8080"
	@echo "Backend API will be available at: http://localhost:5000"
	@echo "Press Ctrl+C to stop"
	kubectl port-forward -n insightlearn service/insightlearn-frontend-service 8080:80 &
	kubectl port-forward -n insightlearn service/insightlearn-backend-service 5000:5000

docker-up:
	@echo "Starting services with Docker Compose..."
	docker-compose up -d
	@echo "Services started!"
	@echo "Frontend: http://localhost"
	@echo "Backend API: http://localhost:5000"

docker-down:
	@echo "Stopping Docker Compose services..."
	docker-compose down
	@echo "Services stopped!"

logs-backend:
	kubectl logs -f -l app=insightlearn-backend -n insightlearn

logs-frontend:
	kubectl logs -f -l app=insightlearn-frontend -n insightlearn

logs-postgres:
	kubectl logs -f -l app=postgres -n insightlearn

status:
	@echo "=== InsightLearn Kubernetes Status ==="
	@echo "Pods:"
	kubectl get pods -n insightlearn
	@echo "\nServices:"
	kubectl get services -n insightlearn
	@echo "\nDeployments:"
	kubectl get deployments -n insightlearn
	@echo "\nHPA:"
	kubectl get hpa -n insightlearn