#!/bin/bash

# Check Production Users via Backdoor API
# This script lists all users in production environment

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

print_header "Production Users Check"

# Get service URL
print_status "Getting service URL..."
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --project $PROJECT_ID --format 'value(status.url)' 2>/dev/null || echo "")

if [ -z "$SERVICE_URL" ]; then
    print_error "Could not get service URL. Is the service deployed?"
    print_status "Trying to get project ID from gcloud config..."
    PROJECT_ID_FROM_CONFIG=$(gcloud config get-value project 2>/dev/null || echo "")
    if [ -n "$PROJECT_ID_FROM_CONFIG" ]; then
        print_status "Using project from gcloud config: $PROJECT_ID_FROM_CONFIG"
        PROJECT_ID="$PROJECT_ID_FROM_CONFIG"
        SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --project $PROJECT_ID --format 'value(status.url)' 2>/dev/null || echo "")
    fi
    
    if [ -z "$SERVICE_URL" ]; then
        print_error "Still could not get service URL."
        print_status "Please check:"
        echo "  1. Service is deployed: gcloud run services list --region $REGION"
        echo "  2. Project ID is correct: $PROJECT_ID"
        echo "  3. Service name is correct: $SERVICE_NAME"
        exit 1
    fi
fi

print_status "Service URL: $SERVICE_URL"
echo ""

# Check if backdoor token is configured
if [ -z "$AGRR_BACKDOOR_TOKEN" ]; then
    print_error "AGRR_BACKDOOR_TOKEN not set in .env.gcp"
    print_status "To check users, you need to set AGRR_BACKDOOR_TOKEN in .env.gcp"
    exit 1
fi

# Get users list
print_header "Fetching Users List"

USERS_RESPONSE=$(curl -s -H "X-Backdoor-Token: $AGRR_BACKDOOR_TOKEN" "$SERVICE_URL/api/v1/backdoor/users")

if echo "$USERS_RESPONSE" | grep -q '"users"'; then
    print_status "Users retrieved successfully!"
    echo ""
    
    # Pretty print JSON
    if command -v python3 &> /dev/null; then
        echo "$USERS_RESPONSE" | python3 -m json.tool
    else
        echo "$USERS_RESPONSE"
    fi
else
    print_error "Failed to get users:"
    echo "$USERS_RESPONSE"
    exit 1
fi

print_header "Complete"
echo ""
print_status "To get database statistics:"
echo "  curl -H 'X-Backdoor-Token: YOUR_TOKEN' $SERVICE_URL/api/v1/backdoor/db/stats"
echo ""
