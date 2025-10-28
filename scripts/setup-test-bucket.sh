#!/bin/bash

# Setup script for test environment GCS bucket
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

PROJECT_ID=agrr-475323
BUCKET_NAME=agrr-test-db
REGION=asia-northeast1
SERVICE_ACCOUNT=cloud-run-agrr@agrr-475323.iam.gserviceaccount.com

print_header "GCS Bucket Setup for Test Environment"

# Check if bucket exists
if gsutil ls -b gs://$BUCKET_NAME &>/dev/null; then
    print_status "Bucket already exists: gs://$BUCKET_NAME"
else
    print_warning "Bucket does not exist. Please create it manually with proper permissions."
    echo ""
    echo "Run the following command with a user account that has Storage Admin role:"
    echo ""
    echo "  gsutil mb -l $REGION gs://$BUCKET_NAME"
    echo ""
    echo "Then set the bucket policy:"
    echo ""
    echo "  gsutil iam ch serviceAccount:$SERVICE_ACCOUNT:objectAdmin gs://$BUCKET_NAME"
    echo ""
    exit 1
fi

# Check permissions
print_status "Checking bucket permissions..."
if gsutil iam get gs://$BUCKET_NAME 2>/dev/null | grep -q "$SERVICE_ACCOUNT"; then
    print_status "✓ Service account has access to the bucket"
else
    print_warning "Service account may not have proper permissions"
    echo ""
    echo "To grant permissions, run:"
    echo "  gsutil iam ch serviceAccount:$SERVICE_ACCOUNT:objectAdmin gs://$BUCKET_NAME"
    echo ""
fi

# Set lifecycle policy
print_status "Setting lifecycle policy (optional - 30 days retention)..."
cat > /tmp/lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {"age": 30}
      }
    ]
  }
}
EOF

if gsutil lifecycle set /tmp/lifecycle.json gs://$BUCKET_NAME 2>/dev/null; then
    print_status "✓ Lifecycle policy set"
else
    print_warning "Failed to set lifecycle policy (may not have permissions)"
fi
rm -f /tmp/lifecycle.json

print_header "Setup Complete"
print_status "Bucket: gs://$BUCKET_NAME"
print_status "Region: $REGION"
print_status "Service Account: $SERVICE_ACCOUNT"
