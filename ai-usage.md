# AI Usage Documentation


## AI Tools Used

| Tool | Purpose | Usage Context |
|------|---------|---------------|
| Cursor (Composer AI) | Code generation, debugging, architecture design, troubleshooting | Used throughout the entire project- from initial scaffolding to fixing deployment issues |
| Cursor AI Assistant | Code review, error diagnosis, configuration fixes | Used for debugging Kong deployment failures, Terraform errors, and Minikube networking issues |

## Prompts Interaction and History

### Prompt 1: Initial Project Setup Request

**What I asked:**
```
Consider yourself as senior platform engineer and work on the below requirements 

Requirements : Attached in Document@/Users/harshm/Downloads/AI-Native – DevOps Assignment 4.pdf 

Note : We require this setup on Minikube in local environment and not on any other aws or azure environment
```

**What the AI produced:**
- Complete project structure with microservice (FastAPI), Kong Gateway configuration, Helm charts, Terraform, CrowdSec deployment
- Microservice with JWT authentication, SQLite database, and all required endpoints (/login, /verify, /users, /health)
- Kong declarative configuration with JWT plugin, rate limiting, IP whitelisting, and custom Lua plugin
- Helm charts for both user-service and Kong
- Terraform configuration for namespace and network policies
- Deployment scripts (deploy.sh, test-api.sh)
- Comprehensive README.md with architecture diagrams

**What I changed/accepted:**
- Accepted the overall structure and approach
- Accepted FastAPI for microservice 
- Accepted Kong OSS with declarative config approach
- Accepted Helm charts for deployment 
- Accepted CrowdSec for DDoS protection (open-source)

---

### Prompt 2: Terraform Namespace Conflict Error

**What I asked:**
```
@/Users/harshm/.cursor/projects/Users-harshm-Documents-AI-assignment-Ai-Native-DevOps-Assignment-4/terminals/1.txt:7-150 getting error
```

**Error encountered:**
```
Error: namespaces "api-platform" already exists
```

**What the AI produced:**
- Identified that deploy.sh was creating namespace before Terraform tried to create it
- Updated deploy.sh to import existing namespace into Terraform state
- Modified Terraform to handle existing namespaces gracefully
- Added error handling to continue deployment even if Terraform has minor issues

**What I changed/accepted:**
- Accepted the fix - the script now imports namespace if it exists before Terraform apply
- The deployment script now handles this edge case properly

---

### Prompt 3: JWT Authentication Failing - Missing 'iss' Claim

**What I asked:**
After Kong started working, I tested the API and found that `/users` endpoint was returning:
```
{"message":"No mandatory 'iss' in claims"}
```

**What the AI produced:**
- Identified that Kong JWT plugin requires `iss` (issuer) claim in JWT tokens
- Updated microservice to add `iss` claim to JWT tokens during generation
- Added `jwt_secrets` configuration to Kong consumer in declarative config
- Updated Helm values.yaml to include consumer secret matching JWT secret
- Rebuilt user-service image and redeployed

**What I changed/accepted:**
- Accepted the fix - Kong's JWT plugin needs `iss` claim to identify which consumer/credential to use
- The JWT authentication now works correctly for protected endpoints

---

### Prompt 4: Minikube NodePort Not Accessible on macOS

**What I asked:**
```
http://192.168.49.2:31791 not working as per README.md
```

**Error encountered:**
- NodePort IP (192.168.49.2) was not reachable from macOS host
- curl commands were failing with connection errors

**What the AI produced:**
- Identified that Minikube with Docker driver on macOS doesn't expose NodePort IPs directly to host
- Updated README.md to use `kubectl port-forward` instead of NodePort IP
- Updated deploy.sh to show port-forward instructions instead of NodePort URL
- Updated test-api.sh to automatically set up port-forward for testing
- Added alternative methods (minikube service, minikube tunnel) in documentation

**What I changed/accepted:**
- Accepted port-forward approach - this is the standard way to access services in Minikube Docker driver
- Updated all documentation and scripts to use localhost:8000 via port-forward
- This is now the recommended approach in the README

---

## Summary of AI Assistance

The AI assistant (Cursor Composer) was instrumental in:

1. **Initial Architecture**: Designed the complete platform architecture with Kong Gateway, FastAPI microservice, Kubernetes deployment, and DDoS protection
2. **Code Generation**: Generated all initial code files including FastAPI app, Kong configs, Helm charts, Terraform, and deployment scripts
3. **Error Diagnosis**: Quickly identified root causes of deployment failures:
   - Terraform namespace conflicts
   - Kong plugin loading issues
   - JWT authentication configuration problems
   - Minikube networking limitations
4. **Code Fixes**: Provided fixes for all issues encountered:
   - Terraform import logic
   - Custom Kong Docker image with plugin
   - Kong 3.x plugin API migration
   - JWT issuer claim addition
   - Port-forward approach for Minikube
5. **Documentation**: Generated comprehensive README.md, deployment notes, and implementation summary

## Learning Outcomes

Through this project and AI assistance, I learned:
- Kong plugin development and deployment patterns
- Kong 3.x API differences from 2.x
- Minikube networking limitations with Docker driver
- Terraform state management and import strategies
- Kubernetes service access patterns (port-forward vs NodePort vs LoadBalancer)
- JWT authentication configuration in Kong
- Custom Docker image building for Kong plugins

## Tools and Technologies Used

- **AI Tools**: Cursor IDE with Composer AI
- **Languages**: Python (FastAPI), Lua (Kong plugins), YAML (Kubernetes/Helm), HCL (Terraform), Bash (scripts)
- **Technologies**: Kubernetes, Kong Gateway, FastAPI, SQLite, Helm, Terraform, CrowdSec, Minikube, Docker
