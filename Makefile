.PHONY: help deploy test clean build minikube-start minikube-stop

help:
	@echo "Available targets:"
	@echo "  minikube-start  - Start Minikube cluster"
	@echo "  minikube-stop   - Stop Minikube cluster"
	@echo "  build          - Build Docker images"
	@echo "  deploy         - Deploy all components to Minikube"
	@echo "  test           - Run API tests"
	@echo "  clean          - Clean up deployments"
	@echo "  logs           - View logs from all services"

minikube-start:
	@echo "Starting Minikube..."
	minikube start

minikube-stop:
	@echo "Stopping Minikube..."
	minikube stop

build:
	@echo "Building Docker images..."
	eval $$(minikube docker-env) && \
	cd microservice && \
	docker build -t user-service:latest .

deploy: build
	@echo "Deploying to Minikube..."
	./scripts/deploy.sh

test:
	@echo "Running API tests..."
	./scripts/test-api.sh

clean:
	@echo "Cleaning up deployments..."
	helm uninstall user-service -n api-platform || true
	helm uninstall kong -n api-platform || true
	kubectl delete namespace api-platform || true

logs:
	@echo "Viewing logs..."
	@echo "User Service logs:"
	kubectl logs -f deployment/user-service -n api-platform &
	@echo "Kong logs:"
	kubectl logs -f deployment/kong -n api-platform

status:
	@echo "Checking deployment status..."
	kubectl get pods -n api-platform
	kubectl get svc -n api-platform
