#!/bin/bash

# Google Cloud Run Deployment Script
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
IMAGE_NAME=${IMAGE_NAME:-agrr}
USE_AGRR_DAEMON=${USE_AGRR_DAEMON:-false}

# Get project from gcloud if not set
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
fi

if [ -z "$PROJECT_ID" ]; then
    print_error "PROJECT_ID not set. Set in .env.gcp or run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

print_header "Google Cloud Run Deployment"
print_status "Project ID: $PROJECT_ID"
print_status "Region: $REGION"
print_status "Service Name: $SERVICE_NAME"
print_status "AGRR Daemon Mode: $USE_AGRR_DAEMON"

# Warn if daemon mode is disabled
if [ "$USE_AGRR_DAEMON" != "true" ]; then
    print_warning "AGRR daemon mode is DISABLED (USE_AGRR_DAEMON=false)"
    print_warning "This means AGRR daemon will NOT start in production"
    print_warning "To enable daemon mode, set USE_AGRR_DAEMON=true in .env.gcp"
fi

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI not installed"
        echo ""
        echo "To install gcloud CLI on Linux:"
        echo "  1. Download the installer:"
        echo "     curl https://sdk.cloud.google.com | bash"
        echo "  2. Restart your shell or run:"
        echo "     exec -l \$SHELL"
        echo "  3. Initialize gcloud:"
        echo "     gcloud init"
        echo ""
        echo "Or install via package manager:"
        echo "  Ubuntu/Debian:"
        echo "    echo \"deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main\" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list"
        echo "    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -"
        echo "    sudo apt-get update && sudo apt-get install google-cloud-cli"
        echo ""
        exit 1
    fi
    print_status "gcloud CLI: $(gcloud --version | head -1)"
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker not installed"
        exit 1
    fi
    print_status "Docker: $(docker --version)"
    
    # Check gcloud auth
    local auth_account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null)
    if [ -z "$auth_account" ]; then
        print_error "Not authenticated. Run: gcloud auth login"
        exit 1
    fi
    print_status "Authenticated: $auth_account"
}

# Build Docker image
build_image() {
    print_header "Building Docker Image" >&2
    
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local image_tag="$REGION-docker.pkg.dev/$PROJECT_ID/agrr/$IMAGE_NAME:$timestamp"
    local image_latest="$REGION-docker.pkg.dev/$PROJECT_ID/agrr/$IMAGE_NAME:latest"
    
    print_status "Building: $image_tag" >&2
    
    cd "$PROJECT_ROOT"
    # Pass Google OAuth credentials as build-args so assets:precompile (build-time) can access them.
    docker build --network=host -f Dockerfile.production \
      --build-arg GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID" \
      --build-arg GOOGLE_CLIENT_SECRET="$GOOGLE_CLIENT_SECRET" \
      -t "$image_tag" -t "$image_latest" . >&2
    
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

# Clean up local Docker images after push
cleanup_local_images() {
    print_header "Cleaning Up Local Docker Images"
    
    local image_tag="$1"
    local latest_tag="$REGION-docker.pkg.dev/$PROJECT_ID/agrr/$IMAGE_NAME:latest"
    
    # Remove timestamped image (keep latest tag)
    print_status "Removing local image: $image_tag"
    docker rmi "$image_tag" 2>/dev/null || print_warning "Failed to remove $image_tag (may already be removed)"
    
    # Optionally remove latest tag as well (since it's already pushed to registry)
    print_status "Removing local latest tag: $latest_tag"
    docker rmi "$latest_tag" 2>/dev/null || print_warning "Failed to remove $latest_tag (may already be removed)"
    
    print_status "Local image cleanup completed ✓"
}

# Deploy to Cloud Run
deploy_service() {
    print_header "Deploying to Cloud Run"
    
    local image_tag="$1"
    
    # Check required environment variables (warn if not set, but allow deployment to proceed)
    if [ -z "$GOOGLE_CLIENT_ID" ] || [ -z "$GOOGLE_CLIENT_SECRET" ]; then
        print_warning "Google OAuth credentials are not set in .env.gcp"
        print_warning "GOOGLE_CLIENT_ID: ${GOOGLE_CLIENT_ID:-NOT SET}"
        print_warning "GOOGLE_CLIENT_SECRET: ${GOOGLE_CLIENT_SECRET:+SET (hidden)}${GOOGLE_CLIENT_SECRET:-NOT SET}"
        print_warning ""
        print_warning "Attempting to use existing values from Cloud Run service..."
        
        # Try to get existing values from Cloud Run
        local existing_client_id=$(gcloud run services describe $SERVICE_NAME --region $REGION --project $PROJECT_ID --format 'value(spec.template.spec.containers[0].env[?(@.name=="GOOGLE_CLIENT_ID")].value)' 2>/dev/null || echo "")
        local existing_client_secret=$(gcloud run services describe $SERVICE_NAME --region $REGION --project $PROJECT_ID --format 'value(spec.template.spec.containers[0].env[?(@.name=="GOOGLE_CLIENT_SECRET")].value)' 2>/dev/null || echo "")
        
        if [ -n "$existing_client_id" ] && [ "$existing_client_id" != "null" ]; then
            GOOGLE_CLIENT_ID="$existing_client_id"
            print_status "Using existing GOOGLE_CLIENT_ID from Cloud Run"
        fi
        
        if [ -n "$existing_client_secret" ] && [ "$existing_client_secret" != "null" ]; then
            GOOGLE_CLIENT_SECRET="$existing_client_secret"
            print_status "Using existing GOOGLE_CLIENT_SECRET from Cloud Run"
        fi
        
        if [ -z "$GOOGLE_CLIENT_ID" ] || [ -z "$GOOGLE_CLIENT_SECRET" ] || [ "$GOOGLE_CLIENT_ID" = "null" ] || [ "$GOOGLE_CLIENT_SECRET" = "null" ]; then
            print_warning "Google OAuth credentials not found. They may be set via Secret Manager or will be set manually."
            print_warning "Continuing deployment without setting GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET."
            print_warning "If needed, set them manually after deployment or use Secret Manager."
            GOOGLE_CLIENT_ID=""
            GOOGLE_CLIENT_SECRET=""
        fi
    fi
    
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
AGRR_BACKDOOR_TOKEN: "$AGRR_BACKDOOR_TOKEN"
SOLID_QUEUE_RESET_ON_DEPLOY: "$SOLID_QUEUE_RESET_ON_DEPLOY"
EOF
    # Only add Google OAuth credentials if they are set
    if [ -n "$GOOGLE_CLIENT_ID" ] && [ -n "$GOOGLE_CLIENT_SECRET" ]; then
        cat >> "$env_file" <<EOF
GOOGLE_CLIENT_ID: "$GOOGLE_CLIENT_ID"
GOOGLE_CLIENT_SECRET: "$GOOGLE_CLIENT_SECRET"
EOF
    fi

    if [ -n "$FRONTEND_URL" ]; then
        cat >> "$env_file" <<EOF
FRONTEND_URL: "$FRONTEND_URL"
EOF
    fi
    
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
    local service_url=$(gcloud run services describe $SERVICE_NAME --region $REGION --project $PROJECT_ID --format 'value(status.url)')
    print_status "Service URL: $service_url"
    
    # Test health
    print_status "Testing health endpoint..."
    sleep 5
    if [ -n "$service_url" ] && curl -s "$service_url/up" > /dev/null; then
        print_status "Health check passed ✓"
    else
        print_warning "Health check failed (service may still be starting)"
    fi
}

# Main
main() {
    local command=${1:-deploy}
    
    case "$command" in
        "deploy")
            check_prerequisites
            image_tag=$(build_image)
            push_image "$image_tag"
            deploy_service "$image_tag"
            cleanup_local_images "$image_tag"
            ;;
        *)
            print_error "Unknown command: $command"
            echo "Usage: $0 [deploy]"
            exit 1
            ;;
    esac
}

main "$@"

