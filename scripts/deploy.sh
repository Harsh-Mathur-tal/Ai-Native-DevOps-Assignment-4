#!/bin/bash

set -e

echo "=========================================="
echo "Deploying API Platform to Minikube"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Minikube is running
if ! minikube status > /dev/null 2>&1; then
    echo -e "${YELLOW}Minikube is not running. Starting Minikube...${NC}"
    minikube start
fi

# Set Minikube docker environment
echo -e "${GREEN}Setting up Minikube Docker environment...${NC}"
eval $(minikube docker-env)

# Build Docker image for user-service
echo -e "${GREEN}Building user-service Docker image...${NC}"
cd ../microservice
docker build -t user-service:latest .
cd ../scripts

# Build custom Kong Docker image (includes custom Lua plugin)
echo -e "${GREEN}Building custom Kong Docker image...${NC}"
cd ../kong
docker build -t kong-custom:latest .
cd ../scripts

# Ensure namespace exists first
echo -e "${GREEN}Ensuring namespace exists...${NC}"
kubectl create namespace api-platform --dry-run=client -o yaml | kubectl apply -f -

# Apply Terraform (if available) - this will manage network policies and other resources
if command -v terraform &> /dev/null; then
    echo -e "${GREEN}Applying Terraform configuration...${NC}"
    cd ../terraform
    # Initialize if needed
    if [ ! -d ".terraform" ]; then
        terraform init
    fi
    
    # Import existing namespace into Terraform state if it exists
    if kubectl get namespace api-platform > /dev/null 2>&1; then
        echo -e "${YELLOW}Importing existing namespace into Terraform state...${NC}"
        terraform import kubernetes_namespace.api_platform api-platform 2>/dev/null || {
            echo -e "${YELLOW}Namespace import skipped (may already be in state)${NC}"
        }
    fi
    
    # Apply Terraform (will create/update resources)
    set +e  # Temporarily disable exit on error for Terraform
    terraform apply -auto-approve
    TERRAFORM_EXIT=$?
    set -e  # Re-enable exit on error
    
    if [ $TERRAFORM_EXIT -ne 0 ]; then
        echo -e "${YELLOW}Terraform apply completed with warnings, continuing deployment...${NC}"
    fi
    cd ../scripts
else
    echo -e "${YELLOW}Terraform not found, skipping infrastructure provisioning...${NC}"
fi

# Deploy user-service using Helm
echo -e "${GREEN}Deploying user-service with Helm...${NC}"
cd ..
helm upgrade --install user-service ./helm/user-service \
    --namespace api-platform \
    --set image.repository=user-service \
    --set image.tag=latest \
    --set image.pullPolicy=IfNotPresent \
    --set env.JWT_SECRET="your-secret-key-change-in-production"

# Deploy Kong using Helm (uses kong-custom image with Lua plugin baked in)
echo -e "${GREEN}Deploying Kong Gateway with Helm...${NC}"
helm upgrade --install kong ./helm/kong \
    --namespace api-platform \
    --set image.repository=kong-custom \
    --set image.tag=latest \
    --set image.pullPolicy=IfNotPresent \
    --set service.type=NodePort

# Wait for deployments to be ready
echo -e "${GREEN}Waiting for deployments to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/user-service -n api-platform || true
kubectl wait --for=condition=available --timeout=300s deployment/kong -n api-platform || true

echo ""
echo -e "${GREEN}=========================================="
echo "Deployment Complete!"
echo "==========================================${NC}"
echo ""
echo -e "${YELLOW}NOTE: Minikube with Docker driver on macOS cannot expose NodePort IPs directly.${NC}"
echo -e "${YELLOW}Use one of these methods to access Kong:${NC}"
echo ""
echo "Option 1 — Port Forward (recommended for testing):"
echo "  kubectl port-forward svc/kong 8000:8000 -n api-platform"
echo "  Then use: http://localhost:8000"
echo ""
echo "Option 2 — Minikube Service (opens tunnel, keep terminal open):"
echo "  minikube service kong -n api-platform"
echo ""
echo "Option 3 — Minikube Tunnel (exposes LoadBalancer, keep terminal open):"
echo "  minikube tunnel"
echo ""
echo "Test the API (after port-forward):"
echo "  Health Check:  curl http://localhost:8000/health"
echo "  Login:         curl -X POST http://localhost:8000/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin123\"}'"
echo "  Get Users:     curl http://localhost:8000/users -H 'Authorization: Bearer <token>'"
echo ""
echo "To view logs:"
echo "  kubectl logs -f deployment/user-service -n api-platform"
echo "  kubectl logs -f deployment/kong -n api-platform"
echo ""
