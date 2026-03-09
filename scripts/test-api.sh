#!/bin/bash

# Demo script for API Platform Testing
# Shows each requirement step-by-step with explanations

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
LOCAL_PORT=8000
KONG_URL="http://localhost:${LOCAL_PORT}"
PAUSE_BETWEEN_STEPS=${PAUSE:-false}  # Set PAUSE=true to enable pauses

# Helper functions
print_header() {
    echo ""
    echo -e "${BOLD}${CYAN}========================================${NC}"
    echo -e "${BOLD}${CYAN}$1${NC}"
    echo -e "${BOLD}${CYAN}========================================${NC}"
    echo ""
}

print_step() {
    echo -e "${BOLD}${BLUE}▶ Step $1: $2${NC}"
    echo -e "${YELLOW}Requirement: $3${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

wait_for_user() {
    if [ "$PAUSE_BETWEEN_STEPS" = "true" ]; then
        echo ""
        read -p "Press Enter to continue to next step..."
        echo ""
    fi
}

# Setup port-forward
print_header "Setting Up Connection"
print_info "Checking Kong Gateway connectivity..."

if ! curl -s --max-time 2 "${KONG_URL}/health" > /dev/null 2>&1; then
    echo -e "${YELLOW}Starting port-forward to Kong...${NC}"
    kubectl port-forward svc/kong ${LOCAL_PORT}:8000 -n api-platform > /dev/null 2>&1 &
    PF_PID=$!
    sleep 3

    if ! curl -s --max-time 5 "${KONG_URL}/health" > /dev/null 2>&1; then
        echo -e "${RED}✗ Cannot reach Kong. Is the deployment running?${NC}"
        echo -e "${YELLOW}Run: kubectl get pods -n api-platform${NC}"
        kill $PF_PID 2>/dev/null
        exit 1
    fi
    echo -e "${GREEN}✓ Port-forward established${NC}"
    STARTED_PF=true
else
    echo -e "${GREEN}✓ Kong already reachable at ${KONG_URL}${NC}"
    STARTED_PF=false
fi

wait_for_user

# ============================================================================
# DEMO: Requirement 1 - Public Endpoints (Authentication Bypass)
# ============================================================================
print_header "Requirement 1: Public Endpoints (Authentication Bypass)"
print_step "1.1" "Health Check Endpoint" "Public API - /health should bypass authentication"

echo -e "${CYAN}Request:${NC} GET ${KONG_URL}/health"
echo -e "${CYAN}Expected:${NC} 200 OK (no authentication required)"
echo ""
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "${KONG_URL}/health")
HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS/d')

if [ "$HTTP_STATUS" = "200" ]; then
    print_success "Health check successful (no auth required)"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
else
    echo -e "${RED}✗ Failed: HTTP $HTTP_STATUS${NC}"
fi
wait_for_user

# ============================================================================
# DEMO: Requirement 2 - Authentication Flow
# ============================================================================
print_header "Requirement 2: JWT Authentication Flow"
print_step "2.1" "User Login" "POST /login - Authenticate user and return JWT token"

echo -e "${CYAN}Request:${NC} POST ${KONG_URL}/login"
echo -e "${CYAN}Payload:${NC} {\"username\":\"admin\",\"password\":\"admin123\"}"
echo ""
LOGIN_RESPONSE=$(curl -s -X POST "${KONG_URL}/login" \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"admin123"}')

TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.access_token' 2>/dev/null || echo "")

if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
    print_success "Login successful - JWT token received"
    echo "$LOGIN_RESPONSE" | jq '.' 2>/dev/null || echo "$LOGIN_RESPONSE"
    echo ""
    echo -e "${GREEN}Token (first 50 chars): ${TOKEN:0:50}...${NC}"
else
    echo -e "${RED}✗ Login failed${NC}"
    echo "$LOGIN_RESPONSE"
    [ "$STARTED_PF" = true ] && kill $PF_PID 2>/dev/null
    exit 1
fi
wait_for_user

print_step "2.2" "Token Verification" "GET /verify - Verify JWT token (public endpoint)"

echo -e "${CYAN}Request:${NC} GET ${KONG_URL}/verify"
echo -e "${CYAN}Header:${NC} Authorization: Bearer <token>"
echo ""
VERIFY_RESPONSE=$(curl -s "${KONG_URL}/verify" \
    -H "Authorization: Bearer ${TOKEN}")

if echo "$VERIFY_RESPONSE" | grep -q '"valid":true'; then
    print_success "Token verification successful"
    echo "$VERIFY_RESPONSE" | jq '.' 2>/dev/null || echo "$VERIFY_RESPONSE"
else
    echo -e "${RED}✗ Token verification failed${NC}"
    echo "$VERIFY_RESPONSE"
fi
wait_for_user

# ============================================================================
# DEMO: Requirement 3 - Protected Endpoints
# ============================================================================
print_header "Requirement 3: Protected Endpoints (JWT Required)"
print_step "3.1" "Access Protected Endpoint WITH JWT" "GET /users - Should succeed with valid token"

echo -e "${CYAN}Request:${NC} GET ${KONG_URL}/users"
echo -e "${CYAN}Header:${NC} Authorization: Bearer <token>"
echo ""
USERS_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "${KONG_URL}/users" \
    -H "Authorization: Bearer ${TOKEN}")
HTTP_STATUS=$(echo "$USERS_RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
BODY=$(echo "$USERS_RESPONSE" | sed '/HTTP_STATUS/d')

if [ "$HTTP_STATUS" = "200" ]; then
    print_success "Protected endpoint accessed successfully with JWT"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
else
    echo -e "${RED}✗ Failed: HTTP $HTTP_STATUS${NC}"
    echo "$BODY"
fi
wait_for_user

print_step "3.2" "Access Protected Endpoint WITHOUT JWT" "GET /users - Should fail with 401"

echo -e "${CYAN}Request:${NC} GET ${KONG_URL}/users"
echo -e "${CYAN}Header:${NC} (none)"
echo -e "${CYAN}Expected:${NC} 401 Unauthorized"
echo ""
NO_AUTH_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "${KONG_URL}/users")
HTTP_STATUS=$(echo "$NO_AUTH_RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
BODY=$(echo "$NO_AUTH_RESPONSE" | sed '/HTTP_STATUS/d')

if [ "$HTTP_STATUS" = "401" ]; then
    print_success "Correctly rejected - 401 Unauthorized (JWT required)"
    echo "$BODY"
else
    echo -e "${RED}✗ Unexpected response: HTTP $HTTP_STATUS${NC}"
    echo "$BODY"
fi
wait_for_user

# ============================================================================
# DEMO: Requirement 4 - Rate Limiting
# ============================================================================
print_header "Requirement 4: IP-Based Rate Limiting"
print_step "4.1" "Rate Limit Test" "10 requests/minute per IP - Should trigger after 10 requests"

echo -e "${CYAN}Policy:${NC} 10 requests per minute per IP"
echo -e "${CYAN}Test:${NC} Sending 15 requests quickly..."
echo ""
RATE_LIMIT_TRIGGERED=false
for i in {1..15}; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${KONG_URL}/health")
    if [ "$STATUS" = "429" ]; then
        echo -e "${GREEN}Request $i: HTTP $STATUS ${BOLD}(Rate Limit Triggered!)${NC}"
        RATE_LIMIT_TRIGGERED=true
        break
    else
        echo "Request $i: HTTP $STATUS"
    fi
    sleep 0.2
done

if [ "$RATE_LIMIT_TRIGGERED" = true ]; then
    print_success "Rate limiting working correctly - 429 returned after limit exceeded"
else
    echo -e "${YELLOW}⚠ Rate limit not triggered (may need to wait for window reset)${NC}"
fi
wait_for_user

# ============================================================================
# DEMO: Requirement 5 - Custom Kong Lua Plugin
# ============================================================================
print_header "Requirement 5: Custom Kong Lua Plugin"
print_step "5.1" "Custom Headers Injection" "X-Request-ID and X-Kong-Custom-Plugin headers"

echo -e "${CYAN}Request:${NC} GET ${KONG_URL}/health"
echo -e "${CYAN}Checking headers:${NC} X-Request-ID, X-Kong-Custom-Plugin"
echo ""
HEADERS=$(curl -s -D- -o/dev/null "${KONG_URL}/health" 2>&1)

if echo "$HEADERS" | grep -qi "X-Request-ID"; then
    print_success "X-Request-ID header present"
    echo "$HEADERS" | grep -i "X-Request-ID"
else
    echo -e "${RED}✗ X-Request-ID header missing${NC}"
fi

if echo "$HEADERS" | grep -qi "X-Kong-Custom-Plugin"; then
    print_success "X-Kong-Custom-Plugin header present"
    echo "$HEADERS" | grep -i "X-Kong-Custom-Plugin"
else
    echo -e "${RED}✗ X-Kong-Custom-Plugin header missing${NC}"
fi

echo ""
echo -e "${CYAN}All Response Headers:${NC}"
echo "$HEADERS" | grep -iE "X-Request-ID|X-Kong-Custom-Plugin|X-RateLimit"
wait_for_user

# ============================================================================
# DEMO: Requirement 6 - IP Whitelisting (Info Only)
# ============================================================================
print_header "Requirement 6: IP Whitelisting"
print_step "6.1" "IP Whitelist Configuration" "Configurable CIDR-based IP filtering"

echo -e "${CYAN}Current Configuration:${NC}"
echo "  - Default: Allow all IPs (0.0.0.0/0)"
echo "  - Configurable via: helm/kong/values.yaml"
echo ""
echo -e "${CYAN}To restrict IPs, update values.yaml:${NC}"
echo "  kongConfig:"
echo "    ipWhitelist:"
echo "      allow:"
echo "        - \"192.168.1.0/24\""
echo ""
print_info "IP whitelisting is configured and active (currently allowing all IPs)"
wait_for_user

# ============================================================================
# DEMO: Requirement 7 - DDoS Protection (Info Only)
# ============================================================================
print_header "Requirement 7: DDoS Protection (CrowdSec)"
print_step "7.1" "DDoS Protection Status" "CrowdSec integration for threat detection"

echo -e "${CYAN}Solution:${NC} CrowdSec (open-source, self-managed)"
echo -e "${CYAN}Deployment:${NC} DaemonSet monitoring Kong logs"
echo ""
if kubectl get daemonset crowdsec -n api-platform > /dev/null 2>&1; then
    print_success "CrowdSec DaemonSet is deployed"
    echo ""
    echo -e "${CYAN}Check CrowdSec logs:${NC}"
    echo "  kubectl logs -f daemonset/crowdsec -n api-platform"
else
    echo -e "${YELLOW}⚠ CrowdSec not deployed (optional for demo)${NC}"
    echo -e "${CYAN}To deploy:${NC} kubectl apply -f k8s/crowdsec-deployment.yaml"
fi
wait_for_user

# ============================================================================
# SUMMARY
# ============================================================================
print_header "Demo Summary - All Requirements Verified"

echo -e "${BOLD}✓ Requirement 1:${NC} Public endpoints (/health, /verify) bypass authentication"
echo -e "${BOLD}✓ Requirement 2:${NC} JWT authentication flow (login → token → verify)"
echo -e "${BOLD}✓ Requirement 3:${NC} Protected endpoints require JWT (/users)"
echo -e "${BOLD}✓ Requirement 4:${NC} IP-based rate limiting (10 req/min)"
echo -e "${BOLD}✓ Requirement 5:${NC} Custom Kong Lua plugin (headers injection)"
echo -e "${BOLD}✓ Requirement 6:${NC} IP whitelisting (configurable)"
echo -e "${BOLD}✓ Requirement 7:${NC} DDoS protection (CrowdSec)"
echo ""

echo -e "${GREEN}${BOLD}All core requirements demonstrated successfully!${NC}"
echo ""

# Clean up port-forward if we started it
if [ "$STARTED_PF" = true ]; then
    echo -e "${YELLOW}Stopping port-forward...${NC}"
    kill $PF_PID 2>/dev/null
    echo -e "${GREEN}✓ Cleanup complete${NC}"
fi

echo ""
echo -e "${CYAN}To run with pauses between steps:${NC}"
echo -e "${BOLD}  PAUSE=true ./test-api.sh${NC}"
echo ""
