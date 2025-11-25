#!/bin/bash

# ⚠️⚠️⚠️ WARNING: DANGEROUS OPERATION ⚠️⚠️⚠️
# This script will CLEAR ALL DATA from the production database
# This action is IRREVERSIBLE and will DELETE ALL:
#   - Users
#   - Farms
#   - Fields
#   - Crops
#   - Cultivation Plans
#   - All other application data
#
# Litestream backups may exist, but restoring from backup is not automatic
#
# USE AT YOUR OWN RISK!

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
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
    print_error ".env.gcp not found. Please create it from env.gcp.example"
    exit 1
fi

# Service info
SERVICE_NAME=${SERVICE_NAME:-agrr-production}
REGION=${REGION:-asia-northeast1}
PROJECT_ID=${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}

if [ -z "$PROJECT_ID" ]; then
    print_error "PROJECT_ID not set. Set in .env.gcp or run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

print_header "${RED}⚠️  PRODUCTION DATABASE CLEAR OPERATION ⚠️${NC}"
echo ""
print_error "${BOLD}THIS WILL DELETE ALL DATA IN PRODUCTION DATABASE${NC}"
echo ""
print_warning "This operation will:"
echo "  - Delete ALL users (except anonymous users)"
echo "  - Delete ALL farms"
echo "  - Delete ALL fields"
echo "  - Delete ALL crops"
echo "  - Delete ALL cultivation plans"
echo "  - Delete ALL other application data"
echo ""
print_warning "This action is IRREVERSIBLE!"
echo ""
print_warning "Litestream may have backups in GCS bucket: ${GCS_BUCKET:-NOT SET}"
print_warning "But restoring from backup requires manual intervention"
echo ""

# Final confirmation
echo -e "${RED}${BOLD}Type 'CLEAR PRODUCTION DB' (exactly) to confirm:${NC}"
read -r confirmation

if [ "$confirmation" != "CLEAR PRODUCTION DB" ]; then
    print_status "Operation cancelled."
    exit 0
fi

print_header "Clearing Production Database"

# Get service URL
print_status "Getting service URL..."
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --project $PROJECT_ID --format 'value(status.url)' 2>/dev/null || echo "")

if [ -z "$SERVICE_URL" ]; then
    print_error "Could not get service URL. Is the service deployed?"
    exit 1
fi

print_status "Service URL: $SERVICE_URL"

# Check if backdoor is enabled
print_status "Checking backdoor access..."
if [ -z "$AGRR_BACKDOOR_TOKEN" ]; then
    print_error "AGRR_BACKDOOR_TOKEN not set in .env.gcp"
    print_error "Cannot access production database without backdoor token"
    exit 1
fi

# Method 1: Use Cloud Run Jobs (if available) or direct container execution
print_header "Executing Database Clear"

print_warning "Attempting to clear database via Cloud Run container execution..."

# Create a temporary script that will be executed in the container
# We'll use gcloud run jobs or direct container execution
# Since Cloud Run services don't support interactive commands easily,
# we'll use a one-off job execution

# Check if we can use Cloud Run Jobs
if gcloud run jobs list --region $REGION --project $PROJECT_ID &>/dev/null; then
    print_status "Using Cloud Run Jobs to execute database clear..."
    
    # Create a temporary job that clears the database
    JOB_NAME="clear-db-$(date +%s)"
    
    # Create job spec
    cat > /tmp/clear-db-job.yaml <<EOF
apiVersion: run.googleapis.com/v1
kind: Job
metadata:
  name: $JOB_NAME
  namespace: '$PROJECT_ID'
spec:
  template:
    spec:
      template:
        spec:
          containers:
          - image: $REGION-docker.pkg.dev/$PROJECT_ID/agrr/agrr:latest
            command:
            - /bin/bash
            - -c
            - |
              cd /app
              bundle exec rails runner "
                ActiveRecord::Base.connection.execute('DELETE FROM users WHERE is_anonymous = 0');
                ActiveRecord::Base.connection.execute('DELETE FROM sessions');
                ActiveRecord::Base.connection.execute('DELETE FROM farms');
                ActiveRecord::Base.connection.execute('DELETE FROM fields');
                ActiveRecord::Base.connection.execute('DELETE FROM crops');
                ActiveRecord::Base.connection.execute('DELETE FROM cultivation_plans');
                ActiveRecord::Base.connection.execute('DELETE FROM interaction_rules');
                ActiveRecord::Base.connection.execute('DELETE FROM pesticides');
                ActiveRecord::Base.connection.execute('DELETE FROM pests');
                ActiveRecord::Base.connection.execute('DELETE FROM fertilizes');
                ActiveRecord::Base.connection.execute('DELETE FROM agricultural_tasks');
                puts 'Database cleared successfully';
              "
            env:
            - name: RAILS_ENV
              value: production
            - name: DATABASE_URL
              value: sqlite3:/tmp/production.sqlite3
EOF
    
    print_error "Cloud Run Jobs execution not fully implemented in this script"
    print_error "Please use the manual method below"
else
    print_warning "Cloud Run Jobs not available, using alternative method..."
fi

# Method 2: Use Backdoor API (recommended)
print_header "Using Backdoor API to Clear Database"

print_status "Step 1: Checking current database statistics..."
STATS_RESPONSE=$(curl -s -H "X-Backdoor-Token: $AGRR_BACKDOOR_TOKEN" "$SERVICE_URL/api/v1/backdoor/db/stats")

if echo "$STATS_RESPONSE" | grep -q '"stats"'; then
    print_status "Current database statistics:"
    echo "$STATS_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$STATS_RESPONSE"
    echo ""
else
    print_error "Failed to get database statistics:"
    echo "$STATS_RESPONSE"
    exit 1
fi

# Final confirmation before clearing
echo -e "${RED}${BOLD}Type 'YES CLEAR NOW' (exactly) to proceed with database clear:${NC}"
read -r final_confirmation

if [ "$final_confirmation" != "YES CLEAR NOW" ]; then
    print_status "Operation cancelled."
    exit 0
fi

print_status "Step 2: Clearing database via backdoor API..."
CLEAR_RESPONSE=$(curl -s -X POST \
  -H "X-Backdoor-Token: $AGRR_BACKDOOR_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"confirmation_token\": \"$AGRR_BACKDOOR_TOKEN\"}" \
  "$SERVICE_URL/api/v1/backdoor/db/clear")

if echo "$CLEAR_RESPONSE" | grep -q '"success":true'; then
    print_status "✅ Database cleared successfully!"
    echo ""
    echo "$CLEAR_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$CLEAR_RESPONSE"
else
    print_error "Failed to clear database:"
    echo "$CLEAR_RESPONSE"
    exit 1
fi

print_header "Complete"
print_warning "⚠️  Database has been cleared. This action is irreversible!"
print_warning "⚠️  Check Litestream backups in GCS bucket if you need to restore: ${GCS_BUCKET:-NOT SET}"
echo ""
