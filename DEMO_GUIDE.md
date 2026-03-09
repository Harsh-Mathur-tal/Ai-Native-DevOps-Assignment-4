# Demo Guide - API Platform Testing

This guide helps you run a step-by-step demo showing all assignment requirements.

## Quick Start

### Option 1: Run with pauses (Recommended for live demo)

```bash
cd scripts
PAUSE=true ./test-api.sh
```

This will pause after each step, allowing you to explain what's happening.

### Option 2: Run continuously (For recording)

```bash
cd scripts
./test-api.sh
```

## Demo Flow

The script demonstrates all requirements in this order:

### 1. **Setup** (Automatic)
- Establishes port-forward connection to Kong
- Verifies connectivity

### 2. **Requirement 1: Public Endpoints**
- Tests `/health` endpoint (no authentication required)
- Shows authentication bypass working

### 3. **Requirement 2: JWT Authentication Flow**
- **Step 2.1**: Login (`POST /login`)
  - Shows JWT token generation
  - Displays token received
- **Step 2.2**: Token Verification (`GET /verify`)
  - Shows token validation
  - Demonstrates public endpoint that accepts tokens

### 4. **Requirement 3: Protected Endpoints**
- **Step 3.1**: Access `/users` WITH JWT token
  - Shows successful access with authentication
  - Returns user list
- **Step 3.2**: Access `/users` WITHOUT JWT token
  - Shows 401 Unauthorized response
  - Demonstrates JWT requirement enforced

### 5. **Requirement 4: Rate Limiting**
- Sends 15 requests quickly
- Shows rate limit triggering (429 response)
- Demonstrates IP-based rate limiting (10 req/min)

### 6. **Requirement 5: Custom Kong Lua Plugin**
- Checks response headers
- Shows `X-Request-ID` header injection
- Shows `X-Kong-Custom-Plugin` header
- Demonstrates custom Lua logic working

### 7. **Requirement 6: IP Whitelisting**
- Shows current configuration
- Explains how to configure CIDR ranges
- Demonstrates configurable IP filtering

### 8. **Requirement 7: DDoS Protection**
- Shows CrowdSec deployment status
- Explains integration approach
- Provides commands to check logs

## What to Highlight During Demo

### Architecture Points
- **Kong Gateway** as API gateway layer
- **Microservice** (FastAPI) handling business logic
- **SQLite** database for user storage
- **Kubernetes** for orchestration

### Security Features
- JWT authentication with token validation
- Rate limiting preventing abuse
- IP whitelisting for access control
- DDoS protection via CrowdSec

### Custom Implementation
- Custom Lua plugin for request tracking
- Structured logging
- Header injection for tracing

## Troubleshooting

### Port-forward already in use

If you get "address already in use" error:

```bash
# Find and kill existing port-forward
lsof -ti:8000 | xargs kill -9

# Or use a different port
LOCAL_PORT=8001 ./test-api.sh
```

### Kong not accessible

```bash
# Check if Kong is running
kubectl get pods -n api-platform

# Check Kong logs
kubectl logs -f deployment/kong -n api-platform

# Restart port-forward manually
kubectl port-forward svc/kong 8000:8000 -n api-platform
```

### Rate limit not triggering

Rate limits reset every minute. If you've already hit the limit:

```bash
# Wait 60 seconds, or
# Test from a different IP (if possible)
```

## Demo Tips

1. **Before starting**: Ensure all pods are running
   ```bash
   kubectl get pods -n api-platform
   ```

2. **Use PAUSE=true**: This gives you time to explain each step

3. **Show the code**: When demonstrating custom plugin, show:
   ```bash
   cat kong/plugins/custom-lua-plugin/handler.lua
   ```

4. **Show Kong config**: When explaining routes:
   ```bash
   kubectl get configmap kong-config -n api-platform -o yaml | grep -A 20 routes
   ```

5. **Show Helm values**: When explaining configuration:
   ```bash
   cat helm/kong/values.yaml | grep -A 10 kongConfig
   ```

## Expected Output Summary

```
✓ Health check successful (no auth required)
✓ Login successful - JWT token received
✓ Token verification successful
✓ Protected endpoint accessed successfully with JWT
✓ Correctly rejected - 401 Unauthorized (JWT required)
✓ Rate limiting working correctly - 429 returned
✓ X-Request-ID header present
✓ X-Kong-Custom-Plugin header present
```

## Time Estimate

- **Full demo with pauses**: ~10-15 minutes
- **Quick demo without pauses**: ~2-3 minutes

## Next Steps After Demo

1. Show project structure:
   ```bash
   tree -L 3 -I 'node_modules|.git'
   ```

2. Show deployment:
   ```bash
   kubectl get all -n api-platform
   ```

3. Show logs:
   ```bash
   kubectl logs -f deployment/kong -n api-platform
   ```

4. Show Helm releases:
   ```bash
   helm list -n api-platform
   ```
