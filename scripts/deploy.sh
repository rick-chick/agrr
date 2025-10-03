#!/bin/bash

# Deploy script for AWS App Runner with SQLite + S3
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Check if environment is provided
if [ -z "$1" ]; then
    print_error "Please provide environment (aws_test or production)"
    echo "Usage: $0 <environment>"
    echo ""
    echo "Environments:"
    echo "  aws_test    - Deploy to AWS test environment"
    echo "  production  - Deploy to AWS production environment"
    exit 1
fi

ENVIRONMENT=$1

# Validate environment
if [ "$ENVIRONMENT" != "aws_test" ] && [ "$ENVIRONMENT" != "production" ]; then
    print_error "Invalid environment. Use 'aws_test' or 'production'"
    exit 1
fi

print_header "AWS App Runner Deployment - $ENVIRONMENT"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

print_status "AWS CLI found: $(aws --version)"

# Check Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install it first."
    exit 1
fi

print_status "Docker found: $(docker --version)"

# Check if required environment variables are set
print_status "Checking required environment variables..."

required_vars=("AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY" "AWS_REGION" "AWS_S3_BUCKET")

if [ "$ENVIRONMENT" = "production" ]; then
    required_vars+=("RAILS_MASTER_KEY" "ALLOWED_HOSTS")
fi

missing_vars=()
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -ne 0 ]; then
    print_error "Missing required environment variables:"
    for var in "${missing_vars[@]}"; do
        echo "  - $var"
    done
    echo ""
    print_warning "Set these variables in your environment or .env file"
    exit 1
fi

print_status "All required environment variables are set ✓"

# Build Docker image
print_header "Building Docker Image"
print_status "Building image for $ENVIRONMENT environment..."

docker build -f Dockerfile.production -t agrr-app:$ENVIRONMENT .

if [ $? -eq 0 ]; then
    print_status "Docker image built successfully ✓"
else
    print_error "Docker build failed"
    exit 1
fi

# Test the image locally (optional)
print_status "Testing image locally..."
print_warning "Skipping local test. You can test manually with:"
echo "  docker run -p 3000:3000 -e RAILS_ENV=$ENVIRONMENT agrr-app:$ENVIRONMENT"

# App Runner deployment instructions
print_header "Next Steps for App Runner Deployment"

echo ""
echo "The Docker image has been built locally. To deploy to AWS App Runner:"
echo ""

if [ "$ENVIRONMENT" = "aws_test" ]; then
    echo "1. Push your code to GitHub (or your source repository)"
    echo "2. AWS App Runner will automatically build and deploy using apprunner-test.yaml"
    echo ""
    echo "Or manually create/update the service:"
    echo "  aws apprunner create-service --cli-input-yaml file://apprunner-test.yaml"
    echo ""
    echo "Update existing service:"
    echo "  aws apprunner start-deployment --service-arn <your-test-service-arn>"
else
    echo "1. Push your code to GitHub (or your source repository)"
    echo "2. AWS App Runner will automatically build and deploy using apprunner.yaml"
    echo ""
    echo "Or manually create/update the service:"
    echo "  aws apprunner create-service --cli-input-yaml file://apprunner.yaml"
    echo ""
    echo "Update existing service:"
    echo "  aws apprunner start-deployment --service-arn <your-production-service-arn>"
fi

echo ""
print_header "Important Reminders"
echo ""
echo "✓ Ensure EFS volume is mounted to /app/storage in App Runner"
echo "✓ Verify all environment variables are set in App Runner console"
echo "✓ S3 bucket '$AWS_S3_BUCKET' exists and has proper CORS configuration"
echo "✓ IAM permissions are correctly configured for S3 access"
echo ""

print_status "Deployment preparation completed successfully! 🚀"
