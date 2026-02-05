#!/bin/bash

# Check Production Backdoor API Status
# This script helps verify backdoor API configuration in production

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${BLUE}========================================${NC}"; echo -e "${BLUE}$1${NC}"; echo -e "${BLUE}========================================${NC}"; }

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load .env.gcp if exists
ENV_GCP_FILE="$PROJECT_ROOT/.env.gcp"
if [ -f "$ENV_GCP_FILE" ]; then
    set -a
    source "$ENV_GCP_FILE"
    set +a
else
    print_error ".env.gcp not found"
    exit 1
fi

# Service info
SERVICE_NAME=${SERVICE_NAME:-agrr-production}
REGION=${REGION:-asia-northeast1}

print_header "Production Backdoor Status Check"

# Get service URL
print_status "Getting service URL..."
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --format 'value(status.url)' 2>/dev/null || echo "")
BACKDOOR_TOKEN_SERVICE=$(gcloud run services describe $SERVICE_NAME --region $REGION --format 'value(spec.template.spec.containers[0].env[?(@.name=="AGRR_BACKDOOR_TOKEN")].value)' 2>/dev/null || echo "")

if [ -z "$SERVICE_URL" ]; then
    print_error "Could not get service URL. Is the service deployed?"
    exit 1
fi

print_status "Service URL: $SERVICE_URL"

# Check current status
print_header "Checking Current Status"

if [ -n "$BACKDOOR_TOKEN_SERVICE" ]; then
    print_status "Cloud Run has AGRR_BACKDOOR_TOKEN configured (masked in output)."
else
    print_warning "Cloud Run is missing AGRR_BACKDOOR_TOKEN."
fi

BACKDOOR_TOKEN_TO_USE=${AGRR_BACKDOOR_TOKEN:-$BACKDOOR_TOKEN_SERVICE}

if [ -z "$BACKDOOR_TOKEN_TO_USE" ]; then
    print_warning "No backdoor token is available locally or on Cloud Run."
    print_status "Enable the token and redeploy, then rerun this script."
    BACKDOOR_ENABLED=false
else
    print_status "Testing backdoor status endpoint with token..."
    STATUS_RESPONSE=$(curl -s -H "X-Backdoor-Token: $BACKDOOR_TOKEN_TO_USE" "$SERVICE_URL/api/v1/backdoor/status" 2>&1)

    if echo "$STATUS_RESPONSE" | grep -q '"timestamp"'; then
        print_status "Backdoor API is ENABLED and responding via status endpoint."
        BACKDOOR_ENABLED=true
    elif echo "$STATUS_RESPONSE" | grep -q "Backdoor is not enabled"; then
        print_warning "Backdoor API is reporting it is not enabled yet."
        BACKDOOR_ENABLED=false
    elif echo "$STATUS_RESPONSE" | grep -q "Invalid authentication token"; then
        print_error "Backdoor token mismatch (invalid token)."
        BACKDOOR_ENABLED=invalid_token
    else
        print_error "Unexpected response when hitting /backdoor/status:"
        echo "$STATUS_RESPONSE"
        BACKDOOR_ENABLED=unknown
    fi
fi

# Check if token is configured locally
print_header "Checking Local Configuration"
if [ -z "$AGRR_BACKDOOR_TOKEN" ]; then
    print_warning "AGRR_BACKDOOR_TOKEN not set in .env.gcp"
    print_status "To enable backdoor:"
    echo ""
    echo "1. Generate a token:"
    echo "   ruby -e \"require 'securerandom'; puts SecureRandom.hex(32)\""
    echo ""
    echo "2. Add to .env.gcp:"
    echo "   AGRR_BACKDOOR_TOKEN='your-token-here'"
    echo ""
    echo "3. Deploy to production:"
    echo "   ./scripts/gcp-deploy.sh deploy"
else
    print_status "Token configured locally: ${AGRR_BACKDOOR_TOKEN:0:20}..."
    
    # Test with token
    if [ "$BACKDOOR_ENABLED" = "false" ]; then
        print_warning "Backdoor not enabled in production yet. Deploy first."
    else
        print_header "Testing With Token"
        STATUS_RESPONSE=$(curl -s -H "X-Backdoor-Token: $AGRR_BACKDOOR_TOKEN" "$SERVICE_URL/api/v1/backdoor/status")
        
        if echo "$STATUS_RESPONSE" | grep -q '"timestamp"'; then
            print_status "✓ Backdoor API is working!"
            echo ""
            echo "$STATUS_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$STATUS_RESPONSE"
        else
            print_error "Failed to get status:"
            echo "$STATUS_RESPONSE"
        fi
    fi
fi

print_header "Complete"
echo ""
print_status "Backdoor Health Endpoint:"
echo "  curl $SERVICE_URL/api/v1/backdoor/health"
echo ""
print_status "Backdoor Status Endpoint:"
if [ -n "$AGRR_BACKDOOR_TOKEN" ]; then
    echo "  curl -H 'X-Backdoor-Token: YOUR_TOKEN' $SERVICE_URL/api/v1/backdoor/status"
else
    echo "  (Token not configured)"
fi





