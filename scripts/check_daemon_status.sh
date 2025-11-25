#!/bin/bash

# Script to check AGRR daemon status in production GCP environment
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
    print_error ".env.gcp not found. Please create it from env.gcp.example"
    exit 1
fi

# Required variables
PROJECT_ID=${PROJECT_ID:-}
REGION=${REGION:-asia-northeast1}
SERVICE_NAME=${SERVICE_NAME:-agrr-production}

# Get project from gcloud if not set
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
fi

if [ -z "$PROJECT_ID" ]; then
    print_error "PROJECT_ID not set. Set in .env.gcp or run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

print_header "AGRR Daemon Status Check - Production GCP"
print_status "Project ID: $PROJECT_ID"
print_status "Region: $REGION"
print_status "Service Name: $SERVICE_NAME"

# Check prerequisites
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI not installed"
    exit 1
fi

# Check authentication
auth_account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null)
if [ -z "$auth_account" ]; then
    print_error "Not authenticated. Run: gcloud auth login"
    exit 1
fi
print_status "Authenticated: $auth_account"

# 1. Check environment variable
print_header "1. Checking Environment Variables"
ENV_VARS=$(gcloud run services describe $SERVICE_NAME \
    --region $REGION \
    --project $PROJECT_ID \
    --format json 2>/dev/null)

USE_AGRR_DAEMON_ENV=$(echo "$ENV_VARS" | jq -r '.spec.template.spec.containers[0].env[]? | select(.name=="USE_AGRR_DAEMON") | .value' 2>/dev/null || echo "")

if [ -z "$USE_AGRR_DAEMON_ENV" ]; then
    print_warning "USE_AGRR_DAEMON environment variable not found in Cloud Run service"
    print_warning "This means daemon mode is likely DISABLED"
    print_status "All environment variables:"
    echo "$ENV_VARS" | jq -r '.spec.template.spec.containers[0].env[]? | "  \(.name)=\(.value)"' 2>/dev/null | grep -i "daemon\|agrr" || echo "  (No daemon-related variables found)"
else
    if [ "$USE_AGRR_DAEMON_ENV" = "true" ]; then
        print_status "✓ USE_AGRR_DAEMON is set to 'true' (daemon should be enabled)"
    else
        print_warning "USE_AGRR_DAEMON is set to '$USE_AGRR_DAEMON_ENV' (daemon is DISABLED)"
    fi
fi

# 2. Check recent logs for daemon startup messages
print_header "2. Checking Recent Logs for Daemon Startup"
print_status "Fetching recent logs (last 200 lines)..."

LOG_OUTPUT=$(gcloud logging read \
    "resource.type=cloud_run_revision AND resource.labels.service_name=$SERVICE_NAME" \
    --limit 200 \
    --format json \
    --project $PROJECT_ID 2>/dev/null || echo "[]")

# Extract log messages (handle both textPayload and jsonPayload)
extract_log_message() {
    echo "$1" | jq -r '.textPayload // .jsonPayload.message // .jsonPayload.textPayload // ""' 2>/dev/null || echo ""
}

# Check for daemon-related log messages
DAEMON_STARTED=$(echo "$LOG_OUTPUT" | jq -r '.[] | select(.textPayload // .jsonPayload.message // .jsonPayload.textPayload | test("agrr daemon started|Starting agrr daemon|✓ agrr daemon"; "i")) | .timestamp + " - " + (.textPayload // .jsonPayload.message // .jsonPayload.textPayload // "")' 2>/dev/null | head -3 || echo "")
DAEMON_SKIPPED=$(echo "$LOG_OUTPUT" | jq -r '.[] | select(.textPayload // .jsonPayload.message // .jsonPayload.textPayload | test("Skipping agrr daemon|USE_AGRR_DAEMON not set"; "i")) | .timestamp + " - " + (.textPayload // .jsonPayload.message // .jsonPayload.textPayload // "")' 2>/dev/null | head -3 || echo "")
DAEMON_FAILED=$(echo "$LOG_OUTPUT" | jq -r '.[] | select(.textPayload // .jsonPayload.message // .jsonPayload.textPayload | test("daemon start failed|agrr binary not found|⚠ agrr"; "i")) | .timestamp + " - " + (.textPayload // .jsonPayload.message // .jsonPayload.textPayload // "")' 2>/dev/null | head -3 || echo "")
STEP3_LOGS=$(echo "$LOG_OUTPUT" | jq -r '.[] | select(.textPayload // .jsonPayload.message // .jsonPayload.textPayload | test("Step 3"; "i")) | .timestamp + " - " + (.textPayload // .jsonPayload.message // .jsonPayload.textPayload // "")' 2>/dev/null | head -5 || echo "")

if [ -n "$DAEMON_STARTED" ]; then
    print_status "✓ Found daemon startup message(s) in logs:"
    echo "$DAEMON_STARTED" | while read line; do
        echo "  $line"
    done
elif [ -n "$DAEMON_SKIPPED" ]; then
    print_warning "Found daemon skip message(s) in logs:"
    echo "$DAEMON_SKIPPED" | while read line; do
        echo "  $line"
    done
elif [ -n "$DAEMON_FAILED" ]; then
    print_error "Found daemon failure message(s) in logs:"
    echo "$DAEMON_FAILED" | while read line; do
        echo "  $line"
    done
else
    print_warning "No daemon-related messages found in recent logs"
    if [ -n "$STEP3_LOGS" ]; then
        print_status "Found Step 3 logs (daemon startup step):"
        echo "$STEP3_LOGS" | while read line; do
            echo "  $line"
        done
    else
        print_warning "No Step 3 logs found either - daemon may not be starting"
        print_status "Showing recent startup logs:"
        echo "$LOG_OUTPUT" | jq -r '.[] | select(.textPayload // .jsonPayload.message // .jsonPayload.textPayload | test("Starting Rails|Step [0-9]"; "i")) | .timestamp + " - " + (.textPayload // .jsonPayload.message // .jsonPayload.textPayload // "")' 2>/dev/null | head -10 || echo "  (No relevant logs found)"
    fi
fi

# 3. Get service URL and check via backdoor API
print_header "3. Checking Daemon Status via Backdoor API"
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME \
    --region $REGION \
    --project $PROJECT_ID \
    --format 'value(status.url)' 2>/dev/null || echo "")

if [ -z "$SERVICE_URL" ]; then
    print_error "Could not get service URL"
else
    print_status "Service URL: $SERVICE_URL"
    
    # Check if backdoor token is available
    if [ -z "$AGRR_BACKDOOR_TOKEN" ]; then
        print_warning "AGRR_BACKDOOR_TOKEN not set in .env.gcp - cannot check via API"
        print_warning "To enable API check, set AGRR_BACKDOOR_TOKEN in .env.gcp"
    else
        print_status "Checking daemon status via backdoor API..."
        
        API_RESPONSE=$(curl -s -w "\n%{http_code}" \
            -H "X-Backdoor-Token: $AGRR_BACKDOOR_TOKEN" \
            "$SERVICE_URL/api/v1/backdoor/status" 2>/dev/null || echo "")
        
        HTTP_CODE=$(echo "$API_RESPONSE" | tail -1)
        API_BODY=$(echo "$API_RESPONSE" | head -n -1)
        
        if [ "$HTTP_CODE" = "200" ]; then
            DAEMON_RUNNING=$(echo "$API_BODY" | jq -r '.daemon.running' 2>/dev/null || echo "unknown")
            BINARY_EXISTS=$(echo "$API_BODY" | jq -r '.binary.exists' 2>/dev/null || echo "unknown")
            SERVICE_AVAILABLE=$(echo "$API_BODY" | jq -r '.service_available' 2>/dev/null || echo "unknown")
            
            if [ "$DAEMON_RUNNING" = "true" ]; then
                print_status "✓ Daemon is RUNNING"
                DAEMON_PID=$(echo "$API_BODY" | jq -r '.process.pid' 2>/dev/null || echo "unknown")
                MEMORY_MB=$(echo "$API_BODY" | jq -r '.process.memory_mb' 2>/dev/null || echo "unknown")
                UPTIME=$(echo "$API_BODY" | jq -r '.process.uptime' 2>/dev/null || echo "unknown")
                
                if [ "$DAEMON_PID" != "unknown" ] && [ "$DAEMON_PID" != "null" ]; then
                    echo "  PID: $DAEMON_PID"
                fi
                if [ "$MEMORY_MB" != "unknown" ] && [ "$MEMORY_MB" != "null" ]; then
                    echo "  Memory: ${MEMORY_MB} MB"
                fi
                if [ "$UPTIME" != "unknown" ] && [ "$UPTIME" != "null" ]; then
                    echo "  Uptime: $UPTIME"
                fi
            elif [ "$DAEMON_RUNNING" = "false" ]; then
                print_error "✗ Daemon is NOT RUNNING"
                if [ "$BINARY_EXISTS" = "false" ]; then
                    print_warning "  agrr binary not found - daemon cannot start"
                fi
            else
                print_warning "Could not determine daemon status from API response"
            fi
            
            if [ "$SERVICE_AVAILABLE" = "true" ]; then
                print_status "✓ AGRR service is available"
            elif [ "$SERVICE_AVAILABLE" = "false" ]; then
                print_warning "AGRR service is not available"
            fi
        elif [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
            print_error "Authentication failed - check AGRR_BACKDOOR_TOKEN"
        elif [ "$HTTP_CODE" = "503" ]; then
            print_warning "Backdoor API is disabled - AGRR_BACKDOOR_TOKEN not set in production"
        else
            print_warning "API check failed (HTTP $HTTP_CODE)"
            echo "Response: $API_BODY"
        fi
    fi
fi

# 4. Summary
print_header "Summary"
if [ "$USE_AGRR_DAEMON_ENV" = "true" ]; then
    if [ -n "$DAEMON_STARTED" ] || [ "$DAEMON_RUNNING" = "true" ]; then
        print_status "✓ Daemon is configured and appears to be running"
    else
        print_warning "⚠ Daemon is configured but may not be running"
        print_warning "  Check logs for errors: gcloud logging read \"resource.type=cloud_run_revision AND resource.labels.service_name=$SERVICE_NAME\" --limit 100 --project $PROJECT_ID"
    fi
else
    print_warning "⚠ Daemon is NOT configured (USE_AGRR_DAEMON != true)"
    print_warning "  To enable daemon, set USE_AGRR_DAEMON=true in .env.gcp and redeploy"
fi

print_status "Done"
