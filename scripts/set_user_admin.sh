#!/bin/bash

# Set a user as admin via Backdoor API
# Usage: ./scripts/set_user_admin.sh <user_id> [true|false]

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

# Check arguments
if [ $# -lt 1 ]; then
    print_error "Usage: $0 <user_id> [true|false]"
    echo ""
    echo "Examples:"
    echo "  $0 3 true    # Set user ID 3 as admin"
    echo "  $0 3 false   # Remove admin from user ID 3"
    exit 1
fi

USER_ID=$1
ADMIN_VALUE=${2:-true}

# Convert to boolean
if [ "$ADMIN_VALUE" = "true" ] || [ "$ADMIN_VALUE" = "1" ] || [ "$ADMIN_VALUE" = "yes" ]; then
    ADMIN_VALUE="true"
    ACTION="set as admin"
else
    ADMIN_VALUE="false"
    ACTION="remove admin"
fi

# Service info
SERVICE_NAME=${SERVICE_NAME:-agrr-production}
REGION=${REGION:-asia-northeast1}

print_header "Set User Admin Status"

# Get service URL
print_status "Getting service URL..."
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --project $PROJECT_ID --format 'value(status.url)' 2>/dev/null || echo "")

if [ -z "$SERVICE_URL" ]; then
    print_error "Could not get service URL. Is the service deployed?"
    exit 1
fi

print_status "Service URL: $SERVICE_URL"
echo ""

# Check if backdoor token is configured
if [ -z "$AGRR_BACKDOOR_TOKEN" ]; then
    print_error "AGRR_BACKDOOR_TOKEN not set in .env.gcp"
    exit 1
fi

# First, get current user info
print_status "Fetching current user information..."
USER_INFO=$(curl -s -H "X-Backdoor-Token: $AGRR_BACKDOOR_TOKEN" "$SERVICE_URL/api/v1/backdoor/users")

# Check if user exists in the list
if ! echo "$USER_INFO" | grep -q "\"id\":$USER_ID"; then
    print_error "User ID $USER_ID not found in users list"
    print_status "Available users:"
    echo "$USER_INFO" | python3 -m json.tool 2>/dev/null | grep -A 10 "\"id\":"
    exit 1
fi

# Extract current user info
CURRENT_EMAIL=$(echo "$USER_INFO" | python3 -c "import sys, json; data=json.load(sys.stdin); user=next((u for u in data['users'] if u['id']==$USER_ID), None); print(user['email'] if user else '')" 2>/dev/null || echo "")
CURRENT_NAME=$(echo "$USER_INFO" | python3 -c "import sys, json; data=json.load(sys.stdin); user=next((u for u in data['users'] if u['id']==$USER_ID), None); print(user['name'] if user else '')" 2>/dev/null || echo "")
CURRENT_ADMIN=$(echo "$USER_INFO" | python3 -c "import sys, json; data=json.load(sys.stdin); user=next((u for u in data['users'] if u['id']==$USER_ID), None); print('true' if user and user.get('admin') else 'false')" 2>/dev/null || echo "false")

print_status "User Information:"
echo "  ID: $USER_ID"
echo "  Email: $CURRENT_EMAIL"
echo "  Name: $CURRENT_NAME"
echo "  Current Admin: $CURRENT_ADMIN"
echo "  New Admin: $ADMIN_VALUE"
echo ""

if [ "$CURRENT_ADMIN" = "$ADMIN_VALUE" ]; then
    print_warning "User is already $([ "$ADMIN_VALUE" = "true" ] && echo "an admin" || echo "not an admin")"
    exit 0
fi

# Confirm
read -p "Are you sure you want to $ACTION for user ID $USER_ID ($CURRENT_EMAIL)? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Operation cancelled."
    exit 0
fi

# Update user
print_status "Updating user..."
UPDATE_RESPONSE=$(curl -s -X PATCH \
  -H "X-Backdoor-Token: $AGRR_BACKDOOR_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"user\": {\"admin\": $ADMIN_VALUE}}" \
  "$SERVICE_URL/api/v1/backdoor/users/$USER_ID")

if echo "$UPDATE_RESPONSE" | grep -q '"success":true'; then
    print_status "✅ User updated successfully!"
    echo ""
    
    if command -v python3 &> /dev/null; then
        echo "$UPDATE_RESPONSE" | python3 -m json.tool
    else
        echo "$UPDATE_RESPONSE"
    fi
else
    print_error "Failed to update user:"
    echo "$UPDATE_RESPONSE"
    exit 1
fi

print_header "Complete"
