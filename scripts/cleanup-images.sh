#!/bin/bash

# Cleanup old Docker images from Artifact Registry
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load .env.gcp
ENV_GCP_FILE="$PROJECT_ROOT/.env.gcp"
if [ -f "$ENV_GCP_FILE" ]; then
    set -a
    source "$ENV_GCP_FILE"
    set +a
fi

PROJECT_ID=${PROJECT_ID:-agrr-475323}
REGION=${REGION:-asia-northeast1}
SERVICE_NAME=${SERVICE_NAME:-agrr-production}

print_status "Getting active revision..."
ACTIVE_IMAGE=$(gcloud run services describe $SERVICE_NAME \
  --region $REGION \
  --project $PROJECT_ID \
  --format 'value(spec.template.spec.containers[0].image)')

print_status "Active image: $ACTIVE_IMAGE"

print_warning "This will delete ALL images except:"
echo "  - latest tag"
echo "  - Currently deployed image"
echo ""

read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

print_status "Fetching all image digests..."
gcloud artifacts docker images list \
  asia-northeast1-docker.pkg.dev/$PROJECT_ID/agrr/agrr \
  --format='value(package)' \
  --project=$PROJECT_ID > /tmp/all_images.txt

DELETED=0
KEPT=0

while IFS= read -r image; do
    # Skip if it's the active image
    if echo "$ACTIVE_IMAGE" | grep -q "$(echo $image | cut -d@ -f2)"; then
        print_status "Keeping active: $image"
        KEPT=$((KEPT + 1))
        continue
    fi
    
    # Skip if it has latest tag
    if echo "$image" | grep -q ":latest"; then
        print_status "Keeping latest: $image"
        KEPT=$((KEPT + 1))
        continue
    fi
    
    # Delete old image
    print_warning "Deleting: $image"
    gcloud artifacts docker images delete "$image" --quiet --project=$PROJECT_ID || true
    DELETED=$((DELETED + 1))
done < /tmp/all_images.txt

rm /tmp/all_images.txt

echo ""
print_status "Cleanup completed!"
echo "  Kept: $KEPT images"
echo "  Deleted: $DELETED images"

