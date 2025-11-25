#!/bin/bash

# Cleanup old Docker images
# Keeps the latest image and removes old timestamped images

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

print_header "Docker Image Cleanup"

# Get latest image ID (the one tagged as 'latest')
LATEST_IMAGE_ID=$(docker images --format "{{.ID}}" asia-northeast1-docker.pkg.dev/agrr-475323/agrr/agrr:latest 2>/dev/null | head -1)

if [ -z "$LATEST_IMAGE_ID" ]; then
    print_warning "No latest image found. Skipping cleanup."
    exit 0
fi

print_status "Latest image ID: $LATEST_IMAGE_ID"
echo ""

# Find all agrr images except the latest one
print_status "Finding old images to remove..."

OLD_IMAGES=$(docker images --format "{{.ID}} {{.Repository}}:{{.Tag}}" | grep "asia-northeast1-docker.pkg.dev/agrr-475323/agrr/agrr" | grep -v "$LATEST_IMAGE_ID" | awk '{print $1}' | sort -u)

if [ -z "$OLD_IMAGES" ]; then
    print_status "No old images found to remove."
else
    echo "Old images to be removed:"
    docker images --format "  {{.Repository}}:{{.Tag}} ({{.ID}})" | grep "asia-northeast1-docker.pkg.dev/agrr-475323/agrr/agrr" | grep -v "$LATEST_IMAGE_ID"
    echo ""
    
    # Calculate space to be freed
    SPACE_TO_FREE=$(docker images --format "{{.Size}}" | grep -E "asia-northeast1-docker.pkg.dev/agrr-475323/agrr/agrr" | grep -v "$LATEST_IMAGE_ID" | awk '{sum+=$1} END {print sum}' || echo "0")
    
    print_warning "This will remove old images. Latest image will be kept."
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Removing old images..."
        
        for IMAGE_ID in $OLD_IMAGES; do
            print_status "Removing image: $IMAGE_ID"
            docker rmi "$IMAGE_ID" 2>/dev/null || print_warning "Failed to remove $IMAGE_ID (may be in use)"
        done
        
        print_status "✅ Cleanup complete!"
    else
        print_status "Cleanup cancelled."
    fi
fi

# Also clean up unused local images
print_header "Cleaning Up Unused Local Images"

UNUSED_IMAGES=$(docker images --format "{{.ID}} {{.Repository}}:{{.Tag}}" | grep -E "^agrr-" | awk '{print $1}' | sort -u)

if [ -z "$UNUSED_IMAGES" ]; then
    print_status "No unused local images found."
else
    echo "Unused local images:"
    docker images --format "  {{.Repository}}:{{.Tag}} ({{.ID}})" | grep -E "^agrr-"
    echo ""
    
    read -p "Remove unused local images? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for IMAGE_ID in $UNUSED_IMAGES; do
            print_status "Removing: $IMAGE_ID"
            docker rmi "$IMAGE_ID" 2>/dev/null || print_warning "Failed to remove $IMAGE_ID (may be in use)"
        done
    fi
fi

# Clean up dangling images
print_header "Cleaning Up Dangling Images"

DANGLING_COUNT=$(docker images -f "dangling=true" -q | wc -l)

if [ "$DANGLING_COUNT" -gt 0 ]; then
    print_status "Found $DANGLING_COUNT dangling images"
    read -p "Remove dangling images? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker image prune -f
        print_status "✅ Dangling images removed"
    fi
else
    print_status "No dangling images found"
fi

print_header "Cleanup Summary"
docker system df
