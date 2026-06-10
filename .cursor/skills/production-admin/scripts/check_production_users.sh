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
if ! PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
    print_error "Could not find repository root (git rev-parse failed)"
    exit 1
fi

# Load .env.gcp from repository root
ENV_GCP_FILE="$PROJECT_ROOT/.env.gcp"
if [ -f "$ENV_GCP_FILE" ]; then
    set -a
    source "$ENV_GCP_FILE"
    set +a
else
    print_error ".env.gcp not found at $ENV_GCP_FILE"
    print_status "Create it from the example: cp env.gcp.example .env.gcp"
    exit 1
fi

# Service info
SERVICE_NAME=${SERVICE_NAME:-agrr-production}
REGION=${REGION:-asia-northeast1}

print_header "Production Users Check"

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
# shellcheck source=lib/resolve_production_public_url.sh
source "$LIB_DIR/resolve_production_public_url.sh"

print_status "Resolving public API base URL..."
resolve_production_public_url

if [ -z "$SERVICE_URL" ]; then
    print_error "Could not resolve production public URL."
    print_status "Set PRODUCTION_PUBLIC_URL=https://agrr.net in .env.gcp, or ALLOWED_HOSTS with your public host."
    exit 1
fi

print_status "API base URL: $SERVICE_URL"
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
