# Secure API Platform using Kong on Kubernetes

A self-managed internal API platform built on Kubernetes with Kong API Gateway, featuring JWT authentication, rate limiting, IP whitelisting, and DDoS protection.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [API Request Flow](#api-request-flow)
- [JWT Authentication Flow](#jwt-authentication-flow)
- [Authentication Bypass Strategy](#authentication-bypass-strategy)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Testing](#testing)
- [Project Structure](#project-structure)
- [Configuration](#configuration)
- [DDoS Protection](#ddos-protection)

## Architecture Overview

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │
       │ HTTP Request
       ▼
┌─────────────────────────────────────┐
│         Kong API Gateway            │
│  ┌───────────────────────────────┐ │
│  │  Rate Limiting (IP-based)     │ │
│  │  IP Whitelisting              │ │
│  │  JWT Authentication            │ │
│  │  Custom Lua Plugin            │ │
│  │  DDoS Protection (CrowdSec)    │ │
│  └───────────────────────────────┘ │
└──────┬─────────────────────────────┘
       │
       │ Forwarded Request
       ▼
┌─────────────────────────────────────┐
│      User Service (FastAPI)         │
│  ┌───────────────────────────────┐ │
│  │  /login (Public)              │ │
│  │  /verify (Public)             │ │
│  │  /health (Public)             │ │
│  │  /users (Protected - JWT)     │ │
│  └───────────────────────────────┘ │
│  ┌───────────────────────────────┐ │
│  │  SQLite Database              │ │
│  │  (Persistent Volume)          │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

### Components

1. **Kong API Gateway**: Handles routing, authentication, rate limiting, and security
2. **User Service**: FastAPI microservice providing user management and authentication
3. **SQLite Database**: Local file-based database for user storage
4. **CrowdSec**: DDoS protection and threat intelligence
5. **Kubernetes**: Container orchestration platform (Minikube for local development)

## API Request Flow

### Public Endpoints (No Authentication)

```
Client → Kong Gateway → User Service
         (Rate Limit)    (No Auth Check)
         (IP Filter)
```

**Example: Health Check**
```bash
curl http://<kong-url>/health
```

### Protected Endpoints (JWT Required)

```
Client → Kong Gateway → User Service
         (Rate Limit)    (JWT Validation)
         (IP Filter)     (Return Data)
         (JWT Check)
```

**Example: Get Users**
```bash
curl -H "Authorization: Bearer <token>" http://<kong-url>/users
```

## JWT Authentication Flow

```
┌─────────┐                    ┌──────────┐                    ┌─────────────┐
│ Client  │                    │   Kong   │                    │User Service │
└────┬────┘                    └────┬─────┘                    └──────┬──────┘
     │                               │                                 │
     │ 1. POST /login                │                                 │
     │    {username, password}      │                                 │
     ├───────────────────────────────>│                                 │
     │                               ├─────────────────────────────────>│
     │                               │                                 │
     │                               │ 2. Validate credentials         │
     │                               │    against SQLite                │
     │                               │                                 │
     │                               │ 3. Return JWT token             │
     │                               │<─────────────────────────────────┤
     │                               │                                 │
     │ 4. Return JWT                 │                                 │
     │<───────────────────────────────┤                                 │
     │                               │                                 │
     │ 5. GET /users                 │                                 │
     │    Authorization: Bearer <JWT>│                                 │
     ├───────────────────────────────>│                                 │
     │                               │                                 │
     │                               │ 6. Validate JWT                │
     │                               │    (Check signature, expiry)    │
     │                               │                                 │
     │                               │ 7. Forward request              │
     │                               ├─────────────────────────────────>│
     │                               │                                 │
     │                               │ 8. Return user data             │
     │                               │<─────────────────────────────────┤
     │                               │                                 │
     │ 9. Return response            │                                 │
     │<───────────────────────────────┤                                 │
```

### Steps:

1. **Login**: Client sends credentials to `/login` endpoint
2. **Validation**: User service validates credentials against SQLite database
3. **Token Generation**: JWT token is generated with username and expiration
4. **Token Return**: JWT token is returned to client
5. **Protected Request**: Client includes JWT in `Authorization` header
6. **JWT Validation**: Kong validates JWT signature and expiration
7. **Request Forwarding**: Validated request is forwarded to user service
8. **Response**: User service returns requested data
9. **Final Response**: Kong returns response to client

## Authentication Bypass Strategy

Certain endpoints are configured to bypass JWT authentication:

### Public Routes (No JWT Required)

- `/health` - Health check endpoint
- `/verify` - Token verification endpoint (needs token but doesn't require Kong JWT plugin)

### Implementation

Kong configuration uses **separate routes** for public and protected endpoints:

```yaml
routes:
  # Public routes - NO JWT plugin attached
  - name: health-route
    paths:
      - /health
  
  - name: verify-route
    paths:
      - /verify
  
  # Protected route - JWT plugin attached
  - name: users-route
    paths:
      - /users
```

**Key Points:**
- Public routes have rate limiting and IP filtering but **no JWT plugin**
- Protected routes have JWT plugin enabled
- This ensures `/health` and `/verify` are accessible without authentication
- `/verify` endpoint can still receive tokens for validation but doesn't require Kong-level JWT validation

## Features

### ✅ JWT Authentication
- JWT-based authentication using Kong JWT plugin
- Token validation with expiration checking
- Secure token generation using HS256 algorithm

### ✅ Rate Limiting
- IP-based rate limiting: 10 requests per minute per IP
- Configurable limits via Helm values
- Prevents API abuse and DDoS attacks

### ✅ IP Whitelisting
- Configurable CIDR-based IP filtering
- Gateway-level traffic control
- Default: Allow all (0.0.0.0/0) - configurable for production

### ✅ Custom Kong Lua Plugin
- Request ID injection (`X-Request-ID` header)
- Structured request logging
- Customizable via plugin configuration

### ✅ DDoS Protection
- **CrowdSec** integration for threat detection
- Behavioral analysis and IP reputation
- Automatic blocking of malicious traffic

### ✅ SQLite Database
- Local file-based database
- Auto-initialization on service startup
- Persistent storage via Kubernetes PVC

### ✅ Helm Charts
- Parameterized Helm charts for easy deployment
- Separate charts for user-service and Kong
- Environment-specific configuration via values.yaml

### ✅ Infrastructure as Code
- Terraform for Kubernetes infrastructure
- Declarative Kubernetes resources
- Version-controlled configuration

## Prerequisites

- **Minikube** (v1.28+)
- **kubectl** (v1.28+)
- **Helm** (v3.12+)
- **Docker** (for building images)
- **Terraform** (optional, for infrastructure provisioning)
- **curl** and **jq** (for testing)

## Quick Start

### 1. Start Minikube

```bash
minikube start
```

### 2. Deploy the Platform

```bash
cd scripts
./deploy.sh
```

This script will:
- Build the user-service Docker image
- Create the `api-platform` namespace
- Deploy user-service using Helm
- Deploy Kong Gateway using Helm
- Wait for all services to be ready

### 3. Access Kong Gateway

> **Important:** Minikube with the Docker driver on macOS cannot expose NodePort IPs directly to the host. Use **port-forward** to access the services.

**Start port-forward (run in a separate terminal):**

```bash
kubectl port-forward svc/kong 8000:8000 -n api-platform
```

Kong is now accessible at `http://localhost:8000`.

**Alternative methods:**

```bash
# Option 2: minikube service (opens a tunnel, keep terminal open)
minikube service kong -n api-platform

# Option 3: minikube tunnel (exposes LoadBalancer IPs, keep terminal open)
minikube tunnel
```

### 4. Test the API

```bash
cd scripts
./test-api.sh
```

Or manually (with port-forward running):

```bash
# Health check (public)
curl http://localhost:8000/health

# Login
curl -X POST http://localhost:8000/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# Get users (protected - requires JWT)
TOKEN="<token-from-login>"
curl -H "Authorization: Bearer ${TOKEN}" http://localhost:8000/users
```

## Testing

### Test Rate Limiting

```bash
# Send 15 requests quickly (limit is 10/minute)
for i in {1..15}; do
  curl -s -o /dev/null -w "Request $i: HTTP %{http_code}\n" http://localhost:8000/health
done
```

Expected: After 10 requests, you should see HTTP 429 (Too Many Requests)

### Test IP Whitelisting

Update `helm/kong/values.yaml`:

```yaml
kongConfig:
  ipWhitelist:
    allow:
      - "192.168.1.0/24"  # Only allow specific subnet
```

Redeploy:
```bash
helm upgrade kong ./helm/kong -n api-platform
```

### Test JWT Authentication

```bash
# Without token (should fail)
curl http://localhost:8000/users
# Expected: 401 Unauthorized

# With invalid token (should fail)
curl -H "Authorization: Bearer invalid-token" http://localhost:8000/users
# Expected: 401 Unauthorized

# With valid token (should succeed)
TOKEN=$(curl -s -X POST http://localhost:8000/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' | jq -r '.access_token')
curl -H "Authorization: Bearer ${TOKEN}" http://localhost:8000/users
# Expected: 200 OK with user list
```

### Test Authentication Bypass

```bash
# /health should work without authentication
curl http://localhost:8000/health
# Expected: 200 OK

# /verify should work without Kong JWT validation
curl http://localhost:8000/verify -H "Authorization: Bearer <token>"
# Expected: 200 OK with token validation result
```

### Test DDoS Protection

CrowdSec monitors traffic patterns and blocks suspicious IPs. To test:

```bash
# Generate high-volume traffic
for i in {1..100}; do
  curl -s http://localhost:8000/health &
done
wait

# Check CrowdSec logs
kubectl logs -f daemonset/crowdsec -n api-platform
```

## Project Structure

```
.
├── microservice/
│   ├── app/
│   │   ├── main.py              # FastAPI application
│   │   └── requirements.txt      # Python dependencies
│   └── Dockerfile               # Container image definition
├── helm/
│   ├── user-service/            # Helm chart for user service
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   └── kong/                    # Helm chart for Kong Gateway
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
├── kong/
│   ├── kong.yaml                # Kong declarative configuration
│   └── plugins/
│       ├── custom-lua-plugin.lua # Custom Lua plugin
│       └── schema.lua           # Plugin schema
├── k8s/
│   └── crowdsec-deployment.yaml # CrowdSec DDoS protection
├── terraform/
│   ├── main.tf                  # Infrastructure definition
│   ├── variables.tf
│   └── outputs.tf
├── scripts/
│   ├── deploy.sh                # Deployment script
│   └── test-api.sh              # API testing script
├── README.md                    # This file
└── .gitignore
```

## Configuration

### User Service Configuration

Edit `helm/user-service/values.yaml`:

```yaml
env:
  JWT_SECRET: "your-secret-key-change-in-production"
  DB_PATH: "/app/data/users.db"

replicaCount: 2
resources:
  limits:
    cpu: 500m
    memory: 512Mi
```

### Kong Configuration

Edit `helm/kong/values.yaml`:

```yaml
kongConfig:
  rateLimiting:
    minute: 10      # Requests per minute per IP
    hour: 100       # Requests per hour per IP
  
  ipWhitelist:
    allow:
      - "192.168.1.0/24"  # Allowed CIDR ranges
  
  jwt:
    secret_is_base64: false
    claims_to_verify:
      - exp
```

### Custom Lua Plugin

The custom Lua plugin can be configured in Kong:

```yaml
plugins:
  - name: custom-lua-plugin
    config:
      inject_header: true
      header_name: "X-Request-ID"
      log_requests: true
```

## DDoS Protection

### Solution Choice: CrowdSec

**Why CrowdSec?**

1. **Open-source and Self-managed**: Fully self-hosted, no external dependencies
2. **Kubernetes-Native**: Designed for containerized environments
3. **Behavioral Analysis**: Uses machine learning to detect anomalies
4. **Community Intelligence**: Shares threat intelligence across deployments
5. **Kong Integration**: Has official Kong bouncer plugin

### How It Works

```
Traffic → Kong Gateway → CrowdSec Agent → Threat Detection
                                    │
                                    ├─→ Block malicious IPs
                                    └─→ Update IP reputation
```

1. **CrowdSec Agent** (DaemonSet) monitors Kong access logs
2. **Behavioral Analysis** detects suspicious patterns (high request rate, unusual paths, etc.)
3. **IP Reputation** is updated based on detected threats
4. **Kong Bouncer** blocks IPs flagged by CrowdSec
5. **Community Sharing** (optional) shares threat intelligence

### Integration with Kong

CrowdSec integrates with Kong via:
- **Kong Bouncer Plugin**: Blocks IPs based on CrowdSec decisions
- **Log Monitoring**: Analyzes Kong access logs for patterns
- **API Integration**: Kong queries CrowdSec API for IP status

### Deployment

CrowdSec is deployed via Kubernetes manifests:

```bash
kubectl apply -f k8s/crowdsec-deployment.yaml
```

### Monitoring

Check CrowdSec logs:

```bash
kubectl logs -f daemonset/crowdsec -n api-platform
```

View detected threats:

```bash
kubectl exec -it deployment/crowdsec-bouncer -n api-platform -- cscli decisions list
```

## Troubleshooting

### Services Not Starting

```bash
# Check pod status
kubectl get pods -n api-platform

# Check logs
kubectl logs -f deployment/user-service -n api-platform
kubectl logs -f deployment/kong -n api-platform

# Check events
kubectl get events -n api-platform --sort-by='.lastTimestamp'
```

### Kong Not Routing Requests

```bash
# Check Kong configuration
kubectl exec -it deployment/kong -n api-platform -- kong config -c /kong/kong.yaml

# Check Kong admin API
KONG_ADMIN_PORT=$(kubectl get svc kong -n api-platform -o jsonpath='{.spec.ports[?(@.name=="admin")].nodePort}')
curl http://$(minikube ip):${KONG_ADMIN_PORT}/routes
```

### Database Issues

```bash
# Check PVC
kubectl get pvc -n api-platform

# Access database (if needed)
kubectl exec -it deployment/user-service -n api-platform -- sqlite3 /app/data/users.db "SELECT * FROM users;"
```

## Security Considerations

1. **JWT Secret**: Change default JWT secret in production
2. **IP Whitelisting**: Configure appropriate CIDR ranges for production
3. **Rate Limits**: Adjust based on expected traffic patterns
4. **Database**: SQLite is suitable for development; consider PostgreSQL for production
5. **Secrets Management**: Use Kubernetes Secrets or external secret managers
6. **Network Policies**: Implement network policies for additional security
7. **TLS/HTTPS**: Enable TLS termination at Kong for production

## License

This project is for educational/assignment purposes.

## Author

Built as part of AI-Native DevOps Assignment 4
