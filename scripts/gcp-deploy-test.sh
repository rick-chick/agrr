#!/bin/bash

# Google Cloud Run Deployment Script for Test Environment
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

# Load .env.gcp.test if exists
ENV_GCP_FILE="$PROJECT_ROOT/.env.gcp.test"
if [ -f "$ENV_GCP_FILE" ]; then
    set -a
    source "$ENV_GCP_FILE"
    set +a
else
    print_error ".env.gcp.test not found. Please create it from env.gcp.test.example"
    exit 1
fi

# Required variables
PROJECT_ID=${PROJECT_ID:-}
REGION=${REGION:-asia-northeast1}
SERVICE_NAME=${SERVICE_NAME:-agrr-test}
IMAGE_NAME=${IMAGE_NAME:-agrr-test}
USE_AGRR_DAEMON=${USE_AGRR_DAEMON:-false}

# Get project from gcloud if not set
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
fi

if [ -z "$PROJECT_ID" ]; then
    print_error "PROJECT_ID not set. Set in .env.gcp.test or run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

print_header "Google Cloud Run Deployment (Test Environment)"
print_status "Project ID: $PROJECT_ID"
print_status "Region: $REGION"
print_status "Service Name: $SERVICE_NAME"
print_status "AGRR Daemon Mode: $USE_AGRR_DAEMON"

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI not installed"
        exit 1
    fi
    print_status "gcloud CLI: $(gcloud --version | head -1)"
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker not installed"
        exit 1
    fi
    print_status "Docker: $(docker --version)"
    
    # Check gcloud auth
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
        print_error "Not authenticated. Run: gcloud auth login"
        exit 1
    fi
    print_status "Authenticated: $(gcloud auth list --filter=status:ACTIVE --format='value(account)')"
}

# Build Docker image
build_image() {
    print_header "Building Docker Image" >&2
    
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local image_tag="$REGION-docker.pkg.dev/$PROJECT_ID/agrr/$IMAGE_NAME:$timestamp"
    local image_latest="$REGION-docker.pkg.dev/$PROJECT_ID/agrr/$IMAGE_NAME:latest"
    
    print_status "Building: $image_tag" >&2
    
    cd "$PROJECT_ROOT"
    docker build -f Dockerfile.test -t "$image_tag" -t "$image_latest" . >&2
    
    print_status "Docker image built successfully ✓" >&2
    echo "$image_tag"
}

# Push to Artifact Registry
push_image() {
    print_header "Pushing to Artifact Registry"
    
    local image_tag="$1"
    
    # Configure Docker auth
    print_status "Configuring Docker authentication..."
    gcloud auth configure-docker $REGION-docker.pkg.dev --quiet
    
    # Push image
    print_status "Pushing image: $image_tag"
    docker push "$image_tag"
    
    local latest_tag="$REGION-docker.pkg.dev/$PROJECT_ID/agrr/$IMAGE_NAME:latest"
    print_status "Pushing latest tag..."
    docker push "$latest_tag"
    
    print_status "Image pushed successfully ✓"
}

# Deploy to Cloud Run
deploy_service() {
    print_header "Deploying to Cloud Run (Test Environment)"
    
    local image_tag="$1"
    
    # Create temporary env vars file in YAML format
    local env_file=$(mktemp)
    local timestamp=$(date +%Y%m%d-%H%M%S)
    cat > "$env_file" <<EOF
RAILS_ENV: "production"
RAILS_SERVE_STATIC_FILES: "true"
RAILS_LOG_TO_STDOUT: "true"
RAILS_MASTER_KEY: "$RAILS_MASTER_KEY"
SECRET_KEY_BASE: "$SECRET_KEY_BASE"
GCS_BUCKET: "$GCS_BUCKET"
ALLOWED_HOSTS: "$ALLOWED_HOSTS"
DEPLOY_TIMESTAMP: "$timestamp"
SOLID_QUEUE_IN_PUMA: "false"
USE_AGRR_DAEMON: "$USE_AGRR_DAEMON"
EOF
    
    print_status "Deploying $SERVICE_NAME..."
    
    # Set min-instances based on daemon mode
    local min_instances=0
    if [ "$USE_AGRR_DAEMON" = "true" ]; then
        min_instances=1
        print_status "Daemon mode enabled - setting min-instances=1 for better performance"
    fi
    
    gcloud run deploy $SERVICE_NAME \
        --image "$image_tag" \
        --platform managed \
        --region $REGION \
        --allow-unauthenticated \
        --port 3000 \
        --memory 2Gi \
        --cpu 2 \
        --min-instances $min_instances \
        --max-instances 1 \
        --timeout 600 \
        --service-account cloud-run-agrr@agrr-475323.iam.gserviceaccount.com \
        --env-vars-file="$env_file" \
        --project $PROJECT_ID
    
    rm -f "$env_file"
    
    print_status "Deployment initiated ✓"
    
    # Get service URL
    local service_url=$(gcloud run services describe $SERVICE_NAME --region $REGION --format 'value(status.url)')
    print_status "Service URL: $service_url"
    
    # Test health
    print_status "Testing health endpoint..."
    sleep 5
    if curl -s "$service_url/up" > /dev/null; then
        print_status "Health check passed ✓"
    else
        print_warning "Health check failed (service may still be starting)"
    fi
}

# Main
main() {
    local command=${1:-deploy}
    
    case "$command" in
        deploy)
            check_prerequisites
            local image_tag=$(build_image)
            push_image "$image_tag"
            deploy_service "$image_tag"
            print_header "Deployment Complete ✓"
            ;;
        build)
            check_prerequisites
            build_image
            ;;
        *)
            echo "Usage: $0 [deploy|build]"
            exit 1
            ;;
    esac
}

main "$@"
