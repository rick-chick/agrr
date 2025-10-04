#!/bin/bash

# AWS CLI Deployment Script for App Runner
# Supports both manual deployment and automated CI/CD
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
SERVICE_NAME="agrr-${ENVIRONMENT}"
REGION=${AWS_REGION:-ap-northeast-1}
AWS_PROFILE=${AWS_PROFILE:-default}

# App Runner configuration files
if [ "$ENVIRONMENT" = "aws_test" ]; then
    APPRUNNER_CONFIG="apprunner-test.yaml"
    SERVICE_NAME="agrr-test"
else
    APPRUNNER_CONFIG="apprunner.yaml"
fi

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
    
    local caller_identity=$(aws sts get-caller-identity --profile "$AWS_PROFILE")
    local account_id=$(echo "$caller_identity" | jq -r '.Account')
    local user_arn=$(echo "$caller_identity" | jq -r '.Arn')
    print_status "AWS Account: $account_id"
    print_status "AWS User: $user_arn"
    
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
    print_header "Checking Environment Variables"
    
    local required_vars=("AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY" "AWS_REGION" "AWS_S3_BUCKET")
    
    if [ "$ENVIRONMENT" = "production" ]; then
        required_vars+=("RAILS_MASTER_KEY" "ALLOWED_HOSTS")
    fi
    
    local missing_vars=()
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
        print_status "Example: export AWS_S3_BUCKET=your-bucket-name"
        exit 1
    fi
    
    print_status "All required environment variables are set ✓"
}

# Create or update App Runner service
deploy_service() {
    print_header "Deploying to AWS App Runner"
    
    # Check if service exists
    local service_arn
    if service_arn=$(aws apprunner describe-service --profile "$AWS_PROFILE" --service-arn "arn:aws:apprunner:${REGION}:$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text):service/${SERVICE_NAME}" 2>/dev/null | jq -r '.Service.ServiceArn' 2>/dev/null); then
        print_status "Service exists. Updating existing service..."
        update_service
    else
        print_status "Service does not exist. Creating new service..."
        create_service
    fi
}

# Create new App Runner service
create_service() {
    print_status "Creating new App Runner service: $SERVICE_NAME"
    
    # Validate apprunner config file exists
    if [ ! -f "$PROJECT_ROOT/$APPRUNNER_CONFIG" ]; then
        print_error "App Runner config file not found: $APPRUNNER_CONFIG"
        exit 1
    fi
    
    # Create the service
    local create_result
    if create_result=$(aws apprunner create-service --profile "$AWS_PROFILE" --cli-input-yaml "file://$PROJECT_ROOT/$APPRUNNER_CONFIG" 2>&1); then
        print_status "Service creation initiated successfully ✓"
        
        # Extract service ARN from response
        local service_arn=$(echo "$create_result" | jq -r '.Service.ServiceArn' 2>/dev/null || echo "$create_result" | grep -o 'arn:aws:apprunner:[^[:space:]]*' | head -1)
        
        if [ -n "$service_arn" ]; then
            print_status "Service ARN: $service_arn"
            wait_for_deployment "$service_arn"
        else
            print_warning "Could not extract service ARN. Check AWS console for status."
        fi
    else
        print_error "Failed to create service:"
        echo "$create_result"
        exit 1
    fi
}

# Update existing App Runner service
update_service() {
    print_status "Starting deployment for existing service..."
    
    local service_arn="arn:aws:apprunner:${REGION}:$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text):service/${SERVICE_NAME}"
    
    # Start deployment
    if aws apprunner start-deployment --profile "$AWS_PROFILE" --service-arn "$service_arn" &> /dev/null; then
        print_status "Deployment started successfully ✓"
        wait_for_deployment "$service_arn"
    else
        print_error "Failed to start deployment for service: $service_arn"
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
    
    local service_arn="arn:aws:apprunner:${REGION}:$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text):service/${SERVICE_NAME}"
    
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
    echo "AWS App Runner CLI Deployment Script"
    echo ""
    echo "Usage: $0 [environment] [command]"
    echo ""
    echo "Environments:"
    echo "  aws_test    - Deploy to AWS test environment"
    echo "  production  - Deploy to AWS production environment (default)"
    echo ""
    echo "Commands:"
    echo "  deploy      - Create or update service (default)"
    echo "  list        - List existing services"
    echo "  delete      - Delete service"
    echo "  info        - Show service information"
    echo ""
    echo "Examples:"
    echo "  $0 production deploy     # Deploy to production"
    echo "  $0 aws_test list         # List services"
    echo "  $0 production delete     # Delete production service"
    echo ""
echo "Environment Variables Required:"
echo "  AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, AWS_S3_BUCKET"
echo "  RAILS_MASTER_KEY, ALLOWED_HOSTS (for production)"
echo "  AWS_PROFILE (optional, defaults to 'default')"
}

# Main execution
main() {
    local command=${2:-deploy}
    
    case "$command" in
        "deploy")
            check_prerequisites
            check_environment_variables
            deploy_service
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
            print_service_info "arn:aws:apprunner:${REGION}:$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text):service/${SERVICE_NAME}"
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
