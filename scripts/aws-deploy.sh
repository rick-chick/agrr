#!/bin/bash

# AWS App Runner ECR-based Deployment Script
# Builds Docker images locally, pushes to ECR, and deploys to App Runner
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

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENVIRONMENT=${1:-production}
REGION=${AWS_REGION:-ap-northeast-1}
AWS_PROFILE=${AWS_PROFILE:-default}

# Load .env.aws if exists
ENV_AWS_FILE="$PROJECT_ROOT/.env.aws"
if [ -f "$ENV_AWS_FILE" ]; then
    # Export variables from .env.aws
    set -a
    source "$ENV_AWS_FILE"
    set +a
fi

# Get AWS Account ID (required for resource identification)
ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text 2>/dev/null || echo "${AWS_ACCOUNT_ID:-}")

# Set defaults based on setup-aws-resources.sh outputs
# These match what setup-aws-resources.sh creates
ECR_REPOSITORY_NAME="${ECR_REPOSITORY_NAME:-agrr}"
IAM_ROLE_ARN="${IAM_ROLE_ARN:-arn:aws:iam::${ACCOUNT_ID}:role/AppRunnerServiceRole}"

# Override with environment-specific values
if [ "$ENVIRONMENT" = "aws_test" ]; then
    SERVICE_NAME="${SERVICE_NAME_TEST:-agrr-test}"
    S3_BUCKET="${AWS_S3_BUCKET_TEST:-agrr-${ACCOUNT_ID}-test}"
else
    SERVICE_NAME="${SERVICE_NAME_PRODUCTION:-agrr-production}"
    S3_BUCKET="${AWS_S3_BUCKET:-agrr-${ACCOUNT_ID}-production}"
fi

# Optional environment variables with reasonable defaults
RAILS_MASTER_KEY="${RAILS_MASTER_KEY:-}"
ALLOWED_HOSTS="${ALLOWED_HOSTS:-}"

print_header "AWS App Runner CLI Deployment"
print_status "Environment: $ENVIRONMENT"
print_status "Service Name: $SERVICE_NAME"
print_status "Region: $REGION"
print_status "AWS Profile: $AWS_PROFILE"

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        print_status "Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
    
    print_status "AWS CLI found: $(aws --version)"
    
    # Check AWS credentials
    if ! aws sts get-caller-identity --profile "$AWS_PROFILE" &> /dev/null; then
        print_error "AWS credentials not configured for profile '$AWS_PROFILE'. Please run 'aws configure --profile $AWS_PROFILE'"
        exit 1
    fi
    
    print_status "AWS credentials configured for profile: $AWS_PROFILE"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    print_status "Docker found: $(docker --version)"
    
    # Check jq for JSON parsing
    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed. Some features may not work properly."
        print_status "Install: https://stedolan.github.io/jq/download/"
    else
        print_status "jq found: $(jq --version)"
    fi
}

# Check required environment variables
check_environment_variables() {
    print_header "Checking Configuration"
    
    # Only check for AWS Account ID (absolutely required)
    if [ -z "$ACCOUNT_ID" ]; then
        print_error "Cannot determine AWS Account ID."
        print_error "Please ensure AWS credentials are configured: aws configure --profile $AWS_PROFILE"
        exit 1
    fi
    
    print_status "AWS Account ID: $ACCOUNT_ID"
    print_status "ECR Repository: $ECR_REPOSITORY_NAME"
    print_status "IAM Role: $IAM_ROLE_ARN"
    print_status "S3 Bucket: $S3_BUCKET"
    print_status "Service Name: $SERVICE_NAME"
    
    # Show warnings for optional but recommended variables
    echo ""
    if [ -z "${RAILS_MASTER_KEY}" ]; then
        print_warning "RAILS_MASTER_KEY is not set."
        print_warning "  → Rails application may not start properly."
        print_warning "  → Set it in .env.aws: RAILS_MASTER_KEY=your_key_here"
    else
        print_status "RAILS_MASTER_KEY: *** (set)"
    fi
    
    if [ -z "${ALLOWED_HOSTS}" ]; then
        print_warning "ALLOWED_HOSTS is not set."
        print_warning "  → Set after first deployment using the App Runner URL."
        print_warning "  → Example: ALLOWED_HOSTS=yourapp.awsapprunner.com"
    else
        print_status "ALLOWED_HOSTS: $ALLOWED_HOSTS"
    fi
    
    # Check if .env.aws exists
    if [ ! -f "$ENV_AWS_FILE" ]; then
        echo ""
        print_warning ".env.aws file not found."
        print_warning "Using default resource names based on Account ID."
        print_warning "Run './scripts/setup-aws-resources.sh setup' to create resources and configuration."
    fi
    
    echo ""
    print_status "✓ Configuration check completed"
}

# Build Docker image
build_docker_image() {
    print_header "Building Docker Image"
    
    local image_tag="$1"
    
    print_status "Building image: $image_tag"
    print_status "Using Dockerfile: Dockerfile.production"
    
    cd "$PROJECT_ROOT"
    
    if docker build -f Dockerfile.production -t "$image_tag" .; then
        print_status "Docker image built successfully ✓"
    else
        print_error "Docker build failed"
        exit 1
    fi
}

# Push Docker image to ECR
push_to_ecr() {
    print_header "Pushing Image to ECR"
    
    local ecr_repository="$1"
    local image_tag="$2"
    
    # Login to ECR
    print_status "Logging in to ECR..."
    if aws ecr get-login-password --profile "$AWS_PROFILE" --region "$REGION" | \
       docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"; then
        print_status "ECR login successful ✓"
    else
        print_error "ECR login failed"
        exit 1
    fi
    
    # Tag the image for ECR
    local ecr_image_uri="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ecr_repository}:${image_tag}"
    local ecr_image_latest="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ecr_repository}:latest"
    
    print_status "Tagging image: $ecr_image_uri"
    docker tag "agrr:${image_tag}" "$ecr_image_uri"
    docker tag "agrr:${image_tag}" "$ecr_image_latest"
    
    # Push the image
    print_status "Pushing image to ECR..."
    if docker push "$ecr_image_uri" && docker push "$ecr_image_latest"; then
        print_status "Image pushed successfully ✓"
        print_status "Image URI: $ecr_image_uri"
        echo "$ecr_image_uri"
    else
        print_error "Failed to push image to ECR"
        exit 1
    fi
}

# Create or update App Runner service
deploy_service() {
    print_header "Deploying to AWS App Runner"
    
    local ecr_image_uri="$1"
    
    # Check if service exists
    local service_arn="arn:aws:apprunner:${REGION}:${ACCOUNT_ID}:service/${SERVICE_NAME}"
    
    if aws apprunner describe-service --profile "$AWS_PROFILE" --service-arn "$service_arn" &>/dev/null; then
        print_status "Service exists. Updating existing service..."
        update_service "$ecr_image_uri" "$service_arn"
    else
        print_status "Service does not exist. Creating new service..."
        create_service "$ecr_image_uri"
    fi
}

# Create new App Runner service
create_service() {
    local ecr_image_uri="$1"
    
    print_status "Creating new App Runner service: $SERVICE_NAME"
    print_status "Using ECR image: $ecr_image_uri"
    
    # Build environment variables JSON with defaults
    local env_vars='[
        {"Name":"RAILS_ENV","Value":"'$ENVIRONMENT'"},
        {"Name":"RAILS_SERVE_STATIC_FILES","Value":"true"},
        {"Name":"RAILS_LOG_TO_STDOUT","Value":"true"},
        {"Name":"AWS_REGION","Value":"'$REGION'"},
        {"Name":"AWS_S3_BUCKET","Value":"'$S3_BUCKET'"}
    ]'
    
    # Add optional environment variables if they are set
    if [ -n "${RAILS_MASTER_KEY}" ]; then
        env_vars=$(echo "$env_vars" | jq '. += [{"Name":"RAILS_MASTER_KEY","Value":"'${RAILS_MASTER_KEY}'"}]')
    fi
    if [ -n "${ALLOWED_HOSTS}" ]; then
        env_vars=$(echo "$env_vars" | jq '. += [{"Name":"ALLOWED_HOSTS","Value":"'${ALLOWED_HOSTS}'"}]')
    fi
    if [ "$ENVIRONMENT" = "aws_test" ]; then
        env_vars=$(echo "$env_vars" | jq '. += [{"Name":"RAILS_LOG_LEVEL","Value":"debug"}]')
    fi
    
    print_status "Environment variables configured:"
    echo "$env_vars" | jq -r '.[] | "  - \(.Name): \(if .Name == "RAILS_MASTER_KEY" then "***" else .Value end)"'
    
    # Create the service with ECR image
    local create_result
    if create_result=$(aws apprunner create-service \
        --profile "$AWS_PROFILE" \
        --region "$REGION" \
        --service-name "$SERVICE_NAME" \
        --source-configuration '{
            "ImageRepository": {
                "ImageIdentifier": "'$ecr_image_uri'",
                "ImageRepositoryType": "ECR",
                "ImageConfiguration": {
                    "Port": "3000",
                    "RuntimeEnvironmentVariables": '$env_vars'
                }
            },
            "AutoDeploymentsEnabled": false
        }' \
        --instance-configuration '{
            "Cpu": "1024",
            "Memory": "2048",
            "InstanceRoleArn": "'$IAM_ROLE_ARN'"
        }' 2>&1); then
        
        print_status "Service creation initiated successfully ✓"
        
        # Extract service ARN from response
        local service_arn=$(echo "$create_result" | jq -r '.Service.ServiceArn' 2>/dev/null)
        
        if [ -n "$service_arn" ] && [ "$service_arn" != "null" ]; then
            print_status "Service ARN: $service_arn"
            wait_for_deployment "$service_arn"
        else
            print_warning "Could not extract service ARN. Check AWS console for status."
            echo "$create_result" | jq '.' 2>/dev/null || echo "$create_result"
        fi
    else
        print_error "Failed to create service:"
        echo "$create_result" | jq '.' 2>/dev/null || echo "$create_result"
        exit 1
    fi
}

# Update existing App Runner service
update_service() {
    local ecr_image_uri="$1"
    local service_arn="$2"
    
    print_status "Updating existing service: $SERVICE_NAME"
    print_status "Using ECR image: $ecr_image_uri"
    
    # Build environment variables JSON with defaults
    local env_vars='[
        {"Name":"RAILS_ENV","Value":"'$ENVIRONMENT'"},
        {"Name":"RAILS_SERVE_STATIC_FILES","Value":"true"},
        {"Name":"RAILS_LOG_TO_STDOUT","Value":"true"},
        {"Name":"AWS_REGION","Value":"'$REGION'"},
        {"Name":"AWS_S3_BUCKET","Value":"'$S3_BUCKET'"}
    ]'
    
    # Add optional environment variables if they are set
    if [ -n "${RAILS_MASTER_KEY}" ]; then
        env_vars=$(echo "$env_vars" | jq '. += [{"Name":"RAILS_MASTER_KEY","Value":"'${RAILS_MASTER_KEY}'"}]')
    fi
    if [ -n "${ALLOWED_HOSTS}" ]; then
        env_vars=$(echo "$env_vars" | jq '. += [{"Name":"ALLOWED_HOSTS","Value":"'${ALLOWED_HOSTS}'"}]')
    fi
    if [ "$ENVIRONMENT" = "aws_test" ]; then
        env_vars=$(echo "$env_vars" | jq '. += [{"Name":"RAILS_LOG_LEVEL","Value":"debug"}]')
    fi
    
    print_status "Environment variables configured:"
    echo "$env_vars" | jq -r '.[] | "  - \(.Name): \(if .Name == "RAILS_MASTER_KEY" then "***" else .Value end)"'
    
    # Update the service
    local update_result
    if update_result=$(aws apprunner update-service \
        --profile "$AWS_PROFILE" \
        --region "$REGION" \
        --service-arn "$service_arn" \
        --source-configuration '{
            "ImageRepository": {
                "ImageIdentifier": "'$ecr_image_uri'",
                "ImageRepositoryType": "ECR",
                "ImageConfiguration": {
                    "Port": "3000",
                    "RuntimeEnvironmentVariables": '$env_vars'
                }
            },
            "AutoDeploymentsEnabled": false
        }' \
        --instance-configuration '{
            "Cpu": "1024",
            "Memory": "2048",
            "InstanceRoleArn": "'$IAM_ROLE_ARN'"
        }' 2>&1); then
        
        print_status "Service update initiated successfully ✓"
        wait_for_deployment "$service_arn"
    else
        print_error "Failed to update service:"
        echo "$update_result" | jq '.' 2>/dev/null || echo "$update_result"
        exit 1
    fi
}

# Wait for deployment to complete
wait_for_deployment() {
    local service_arn="$1"
    print_header "Waiting for Deployment to Complete"
    
    print_status "Monitoring deployment status..."
    print_warning "This may take several minutes. Press Ctrl+C to stop monitoring."
    
    local max_attempts=60  # 10 minutes with 10-second intervals
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        local service_status
        if service_status=$(aws apprunner describe-service --profile "$AWS_PROFILE" --service-arn "$service_arn" 2>/dev/null); then
            local status=$(echo "$service_status" | jq -r '.Service.Status' 2>/dev/null)
            local operation_summary=$(echo "$service_status" | jq -r '.Service.OperationSummary' 2>/dev/null)
            
            case "$status" in
                "RUNNING")
                    print_status "Deployment completed successfully! ✓"
                    print_service_info "$service_arn"
                    return 0
                    ;;
                "CREATE_FAILED"|"UPDATE_FAILED"|"DELETE_FAILED")
                    print_error "Deployment failed with status: $status"
                    print_error "Operation Summary: $operation_summary"
                    return 1
                    ;;
                "CREATE_IN_PROGRESS"|"UPDATE_IN_PROGRESS"|"DELETE_IN_PROGRESS")
                    print_status "Deployment in progress... ($status)"
                    ;;
                *)
                    print_status "Current status: $status"
                    ;;
            esac
        else
            print_warning "Could not retrieve service status"
        fi
        
        sleep 10
        attempt=$((attempt + 1))
    done
    
    print_warning "Deployment monitoring timed out. Check AWS console for status."
    print_service_info "$service_arn"
}

# Print service information
print_service_info() {
    local service_arn="$1"
    
    print_header "Service Information"
    
    if service_info=$(aws apprunner describe-service --profile "$AWS_PROFILE" --service-arn "$service_arn" 2>/dev/null); then
        local service_url=$(echo "$service_info" | jq -r '.Service.ServiceUrl' 2>/dev/null)
        local status=$(echo "$service_info" | jq -r '.Service.Status' 2>/dev/null)
        
        echo "Service Name: $SERVICE_NAME"
        echo "Service ARN: $service_arn"
        echo "Service URL: $service_url"
        echo "Status: $status"
        echo ""
        
        if [ -n "$service_url" ] && [ "$service_url" != "null" ]; then
            print_status "🚀 Your application is available at: $service_url"
            
            # Test health endpoint
            print_status "Testing health endpoint..."
            if curl -s -f "$service_url/api/v1/health" > /dev/null 2>&1; then
                print_status "Health check passed ✓"
            else
                print_warning "Health check failed. Application may still be starting up."
            fi
        fi
    else
        print_error "Could not retrieve service information"
    fi
}

# List existing services
list_services() {
    print_header "Existing App Runner Services"
    
    local services
    if services=$(aws apprunner list-services --profile "$AWS_PROFILE" --region "$REGION" 2>/dev/null); then
        echo "$services" | jq -r '.ServiceSummaryList[] | "\(.ServiceName) - \(.Status) - \(.ServiceUrl // "N/A")"' 2>/dev/null || echo "$services"
    else
        print_error "Failed to list services"
        exit 1
    fi
}

# Delete service
delete_service() {
    print_header "Deleting App Runner Service"
    
    local service_arn="arn:aws:apprunner:${REGION}:${ACCOUNT_ID}:service/${SERVICE_NAME}"
    
    print_warning "Are you sure you want to delete service: $SERVICE_NAME?"
    read -p "Type 'yes' to confirm: " confirmation
    
    if [ "$confirmation" = "yes" ]; then
        if aws apprunner delete-service --profile "$AWS_PROFILE" --service-arn "$service_arn"; then
            print_status "Service deletion initiated ✓"
            print_warning "Deletion may take several minutes to complete."
        else
            print_error "Failed to delete service"
            exit 1
        fi
    else
        print_status "Deletion cancelled"
    fi
}

# Show usage
show_usage() {
    echo "AWS App Runner ECR-based Deployment Script"
    echo ""
    echo "Usage: $0 [environment] [command]"
    echo ""
    echo "Environments:"
    echo "  aws_test    - Deploy to AWS test environment"
    echo "  production  - Deploy to AWS production environment (default)"
    echo ""
    echo "Commands:"
    echo "  deploy      - Build Docker image, push to ECR, and deploy to App Runner (default)"
    echo "  list        - List existing App Runner services"
    echo "  delete      - Delete App Runner service"
    echo "  info        - Show service information"
    echo ""
    echo "Examples:"
    echo "  $0 production deploy     # Build, push, and deploy to production"
    echo "  $0 aws_test deploy       # Build, push, and deploy to test environment"
    echo "  $0 production info       # Show production service info"
    echo "  $0 production delete     # Delete production service"
    echo ""
    echo "Prerequisites:"
    echo "  1. Run './scripts/setup-aws-resources.sh setup' first to create:"
    echo "     - IAM roles and policies"
    echo "     - S3 buckets"
    echo "     - ECR repository"
    echo "     - .env.aws configuration file"
    echo ""
    echo "  2. Optional: Set environment variables in .env.aws or shell:"
    echo "     - RAILS_MASTER_KEY (recommended for production)"
    echo "     - ALLOWED_HOSTS (set after first deployment with App Runner URL)"
    echo ""
    echo "Default Values (if not set in .env.aws):"
    echo "  - ECR_REPOSITORY_NAME: agrr"
    echo "  - IAM_ROLE_ARN: arn:aws:iam::\${ACCOUNT_ID}:role/AppRunnerServiceRole"
    echo "  - AWS_S3_BUCKET: agrr-\${ACCOUNT_ID}-production"
    echo "  - AWS_S3_BUCKET_TEST: agrr-\${ACCOUNT_ID}-test"
    echo "  - SERVICE_NAME_PRODUCTION: agrr-production"
    echo "  - SERVICE_NAME_TEST: agrr-test"
    echo ""
    echo "How it works:"
    echo "  1. Loads configuration from .env.aws (or uses defaults)"
    echo "  2. Builds Docker image from Dockerfile.production"
    echo "  3. Pushes image to ECR with timestamp tag"
    echo "  4. Creates or updates App Runner service with the new image"
    echo "  5. Monitors deployment progress"
    echo ""
    echo "Note: This script uses ECR-based deployment, not source code repository."
}

# Main execution
main() {
    local command=${2:-deploy}
    
    case "$command" in
        "deploy")
            check_prerequisites
            check_environment_variables
            
            # Generate image tag based on environment and timestamp
            local timestamp=$(date +%Y%m%d-%H%M%S)
            local image_tag="${ENVIRONMENT}-${timestamp}"
            
            # Build Docker image
            build_docker_image "agrr:${image_tag}"
            
            # Push to ECR
            local ecr_image_uri
            ecr_image_uri=$(push_to_ecr "$ECR_REPOSITORY_NAME" "$image_tag")
            
            # Deploy to App Runner
            deploy_service "$ecr_image_uri"
            ;;
        "list")
            check_prerequisites
            list_services
            ;;
        "delete")
            check_prerequisites
            delete_service
            ;;
        "info")
            check_prerequisites
            local service_arn="arn:aws:apprunner:${REGION}:${ACCOUNT_ID}:service/${SERVICE_NAME}"
            print_service_info "$service_arn"
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            print_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
