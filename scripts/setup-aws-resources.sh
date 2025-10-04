#!/bin/bash

# AWS Resources Setup Script for App Runner Deployment
# 
# This script follows a 3-level permission approach:
#
# Level 0 (Administrator requirement):
#   - User needs policy management permissions (IAM policy create/attach)
#   - If missing, script generates 'agrr-policy-management.json' for admin
#   - Permissions are resource-scoped: arn:aws:iam::*:policy/AGRR-*
#
# Level 1 (Script automatic):
#   - Script creates resource operation policies (AGRR-S3-Policy, AGRR-IAM-Policy, AGRR-AppRunner-Policy)
#   - Policies are resource-scoped (agrr-* buckets, AppRunnerServiceRole* roles)
#   - Attaches policies to current user
#
# Level 2 (Script automatic):
#   - Creates actual AWS resources using Level 1 policies
#   - IAM Role: AppRunnerServiceRole
#   - S3 Buckets: agrr-{account-id}-production, agrr-{account-id}-test
#   - Generates .env.aws configuration
#
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
REGION=${AWS_REGION:-ap-northeast-1}
AWS_PROFILE=${AWS_PROFILE:-default}
ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text 2>/dev/null || echo "")

# Get current IAM user name automatically
if [ -z "${AWS_IAM_USER:-}" ]; then
    CURRENT_USER_ARN=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Arn --output text 2>/dev/null)
    if [[ "$CURRENT_USER_ARN" == *":user/"* ]]; then
        USER_NAME=$(echo "$CURRENT_USER_ARN" | awk -F'/' '{print $NF}')
    elif [[ "$CURRENT_USER_ARN" == *":assumed-role/"* ]]; then
        # For assumed roles, extract the role session name
        USER_NAME=$(echo "$CURRENT_USER_ARN" | awk -F'/' '{print $(NF-1)}')
    else
        USER_NAME="current-user"
    fi
else
    USER_NAME="${AWS_IAM_USER}"
fi

S3_BUCKET_PREFIX="agrr-${ACCOUNT_ID}"
PRODUCTION_BUCKET="${S3_BUCKET_PREFIX}-production"
TEST_BUCKET="${S3_BUCKET_PREFIX}-test"
ECR_REPOSITORY_NAME="agrr"

print_header "AWS Resources Setup for App Runner"
print_status "Region: $REGION"
print_status "AWS Profile: $AWS_PROFILE"
print_status "IAM User: $USER_NAME"
print_status "Account ID: $ACCOUNT_ID"
print_status "Production Bucket: $PRODUCTION_BUCKET"
print_status "Test Bucket: $TEST_BUCKET"

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    print_status "AWS CLI found: $(aws --version)"
    
    # Check AWS credentials
    if [ -z "$ACCOUNT_ID" ]; then
        print_error "AWS credentials not configured for profile '$AWS_PROFILE'. Please run 'aws configure --profile $AWS_PROFILE'"
        exit 1
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        print_error "jq is required for JSON parsing. Please install it first."
        exit 1
    fi
    
    
    print_status "Prerequisites check passed ✓"
}

# Check if user has policy management permissions (Level 1)
check_policy_management_permissions() {
    print_header "Step 1: Checking Policy Management Permissions"
    
    local has_permissions=true
    local missing_permissions=()
    
    print_status "Checking if you can manage IAM policies..."
    
    # Strategy: Try to get an existing AGRR-* policy first
    # If it exists, we likely have the necessary permissions
    # If it doesn't exist, we need to verify we can create policies
    
    local test_policy_arn="arn:aws:iam::${ACCOUNT_ID}:policy/AGRR-S3-Policy"
    local can_get_policy=false
    local can_list_policies=false
    local can_list_user_policies=false
    
    # Test 1: Can we get/check AGRR policies?
    if aws iam get-policy --profile "$AWS_PROFILE" --policy-arn "$test_policy_arn" &>/dev/null; then
        print_status "Found existing AGRR policy, checking management permissions..."
        can_get_policy=true
    fi
    
    # Test 2: Can we list local policies? (needed to check if policies exist)
    if aws iam list-policies --profile "$AWS_PROFILE" --scope Local --max-items 1 &>/dev/null; then
        can_list_policies=true
    else
        missing_permissions+=("iam:ListPolicies (to check existing policies)")
        has_permissions=false
    fi
    
    # Test 3: Can we list policies attached to our user?
    if aws iam list-attached-user-policies --profile "$AWS_PROFILE" --user-name "$USER_NAME" &>/dev/null; then
        can_list_user_policies=true
    else
        missing_permissions+=("iam:ListAttachedUserPolicies for user/${USER_NAME}")
        has_permissions=false
    fi
    
    # Test 4: Try to create a test policy with AGRR- prefix (if we have basic read permissions)
    # This is the most accurate test for CreatePolicy permission on AGRR-* resources
    if [ "$can_list_policies" = true ]; then
        local test_policy_name="AGRR-PermissionTest-$$"
        local test_policy_doc='{"Version":"2012-10-17","Statement":[{"Effect":"Deny","Action":"s3:GetObject","Resource":"arn:aws:s3:::agrr-permission-test/*"}]}'
        
        print_status "Testing CreatePolicy permission on AGRR-* resources..."
        local create_result
        local create_exit_code
        create_result=$(aws iam create-policy \
            --profile "$AWS_PROFILE" \
            --policy-name "$test_policy_name" \
            --policy-document "$test_policy_doc" \
            --description "Temporary test policy for permission verification" 2>&1)
        create_exit_code=$?
        
        if [ $create_exit_code -eq 0 ]; then
            # Success! Clean up immediately
            local created_policy_arn="arn:aws:iam::${ACCOUNT_ID}:policy/${test_policy_name}"
            print_status "CreatePolicy permission verified ✓"
            
            # Try to delete the test policy
            if aws iam delete-policy --profile "$AWS_PROFILE" --policy-arn "$created_policy_arn" &>/dev/null; then
                print_status "Test policy cleaned up ✓"
            else
                print_warning "Created test policy $test_policy_name - please delete manually if needed"
            fi
        else
            # Failed - check why
            if echo "$create_result" | grep -qi "AccessDenied\|UnauthorizedOperation\|not authorized\|no identity-based policy"; then
                missing_permissions+=("iam:CreatePolicy for arn:aws:iam::${ACCOUNT_ID}:policy/AGRR-*")
                has_permissions=false
            elif echo "$create_result" | grep -qi "EntityAlreadyExists"; then
                print_warning "Test policy already exists (previous failed run?) - will continue"
            else
                print_warning "CreatePolicy test inconclusive: $create_result"
            fi
        fi
    fi
    
    # Test 5: Verify AttachUserPolicy permission (without actually attaching)
    # We can't test this without side effects, so we check for existing attached AGRR policies
    if [ "$can_list_user_policies" = true ]; then
        local attached_policies
        attached_policies=$(aws iam list-attached-user-policies \
            --profile "$AWS_PROFILE" \
            --user-name "$USER_NAME" \
            --query 'AttachedPolicies[?contains(PolicyName, `AGRR-`)].PolicyName' \
            --output text 2>/dev/null || true)
        
        if [ -n "$attached_policies" ]; then
            print_status "Found attached AGRR policies: $attached_policies"
        fi
    fi
    
    if [ "$has_permissions" = false ]; then
        show_policy_management_permission_request "${missing_permissions[@]}"
        return 1
    fi
    
    print_status "✅ Policy management permissions verified!"
    return 0
}

# Check if resource operation policies are already attached (Level 2)
check_resource_policies_exist() {
    print_header "Step 2: Checking Resource Operation Policies"
    
    local policies_needed=()
    local policy_arn
    
    # Check if AGRR-S3-Policy exists and is attached
    policy_arn="arn:aws:iam::${ACCOUNT_ID}:policy/AGRR-S3-Policy"
    if ! aws iam get-policy --profile "$AWS_PROFILE" --policy-arn "$policy_arn" &>/dev/null; then
        policies_needed+=("AGRR-S3-Policy")
    fi
    
    # Check if AGRR-IAM-Policy exists and is attached
    policy_arn="arn:aws:iam::${ACCOUNT_ID}:policy/AGRR-IAM-Policy"
    if ! aws iam get-policy --profile "$AWS_PROFILE" --policy-arn "$policy_arn" &>/dev/null; then
        policies_needed+=("AGRR-IAM-Policy")
    fi
    
    # Check if AGRR-AppRunner-Policy exists and is attached
    policy_arn="arn:aws:iam::${ACCOUNT_ID}:policy/AGRR-AppRunner-Policy"
    if ! aws iam get-policy --profile "$AWS_PROFILE" --policy-arn "$policy_arn" &>/dev/null; then
        policies_needed+=("AGRR-AppRunner-Policy")
    fi
    
    # Check if AGRR-ECR-Policy exists and is attached
    policy_arn="arn:aws:iam::${ACCOUNT_ID}:policy/AGRR-ECR-Policy"
    if ! aws iam get-policy --profile "$AWS_PROFILE" --policy-arn "$policy_arn" &>/dev/null; then
        policies_needed+=("AGRR-ECR-Policy")
    fi
    
    if [ ${#policies_needed[@]} -gt 0 ]; then
        print_warning "Resource operation policies need to be created: ${policies_needed[*]}"
        return 1
    fi
    
    print_status "✅ All resource operation policies exist!"
    return 0
}

# Show policy management permission request (Level 0)
show_policy_management_permission_request() {
    local missing_perms=("$@")
    
    print_header "⚠️  PERMISSION REQUEST REQUIRED"
    echo ""
    print_error "This script needs permission to manage IAM policies."
    echo ""
    print_warning "Please ask your AWS administrator to attach the following policy to: ${USER_NAME}"
    echo ""
    echo "========================================"
    echo "Policy Name: AGRR-PolicyManagement"
    echo "Purpose: Allow this script to create resource operation policies"
    echo "========================================"
    echo ""
    cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ManageAGRRPolicies",
            "Effect": "Allow",
            "Action": [
                "iam:CreatePolicy",
                "iam:GetPolicy",
                "iam:DeletePolicy"
            ],
            "Resource": "arn:aws:iam::${ACCOUNT_ID}:policy/AGRR-*"
        },
        {
            "Sid": "ListPolicies",
            "Effect": "Allow",
            "Action": "iam:ListPolicies",
            "Resource": "*"
        },
        {
            "Sid": "AttachPoliciesToSelf",
            "Effect": "Allow",
            "Action": [
                "iam:AttachUserPolicy",
                "iam:ListAttachedUserPolicies"
            ],
            "Resource": "arn:aws:iam::${ACCOUNT_ID}:user/${USER_NAME}"
        }
    ]
}
EOF
    echo ""
    echo "========================================"
    echo ""
    
    # Save policy to file
    local policy_file="scripts/agrr-policy-management.json"
    cat > "$policy_file" <<POLICY_EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ManageAGRRPolicies",
            "Effect": "Allow",
            "Action": [
                "iam:CreatePolicy",
                "iam:GetPolicy",
                "iam:DeletePolicy"
            ],
            "Resource": "arn:aws:iam::${ACCOUNT_ID}:policy/AGRR-*"
        },
        {
            "Sid": "ListPolicies",
            "Effect": "Allow",
            "Action": "iam:ListPolicies",
            "Resource": "*"
        },
        {
            "Sid": "AttachPoliciesToSelf",
            "Effect": "Allow",
            "Action": [
                "iam:AttachUserPolicy",
                "iam:ListAttachedUserPolicies"
            ],
            "Resource": "arn:aws:iam::${ACCOUNT_ID}:user/${USER_NAME}"
        }
    ]
}
POLICY_EOF
    
    print_status "✅ Policy saved to: $policy_file"
    echo ""
    
    print_warning "How to apply this policy (ask your AWS administrator):"
    echo ""
    echo "Option 1: Using AWS CLI:"
    echo ""
    echo "  # Create the policy"
    echo "  aws iam create-policy \\"
    echo "    --policy-name AGRR-PolicyManagement \\"
    echo "    --policy-document file://$policy_file"
    echo ""
    echo "  # Attach the policy to your user"
    echo "  aws iam attach-user-policy \\"
    echo "    --user-name ${USER_NAME} \\"
    echo "    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/AGRR-PolicyManagement"
    echo ""
    echo "Option 2: Using AWS Console:"
    echo "  1. Go to IAM -> Policies -> Create policy"
    echo "  2. Copy and paste the JSON from $policy_file"
    echo "  3. Name it 'AGRR-PolicyManagement' and create"
    echo "  4. Go to IAM -> Users -> ${USER_NAME}"
    echo "  5. Attach the AGRR-PolicyManagement policy"
    echo ""
    echo "After the administrator applies this policy:"
    echo "  - Wait 1-2 minutes for permissions to propagate"
    echo "  - Run this script again"
    echo "  - The script will then automatically create resource operation policies"
    echo ""
    if [ ${#missing_perms[@]} -gt 0 ]; then
        print_status "Detected missing permissions:"
        for perm in "${missing_perms[@]}"; do
            echo "  - $perm"
        done
        echo ""
    fi
    
    exit 1
}

# Create S3 bucket
create_s3_bucket() {
    local bucket_name="$1"
    local environment="$2"
    
    print_status "Creating S3 bucket: $bucket_name"
    
    # Check if bucket already exists
    if aws s3api head-bucket --profile "$AWS_PROFILE" --bucket "$bucket_name" 2>/dev/null; then
        print_warning "Bucket $bucket_name already exists"
        return 0
    fi
    
    # Create bucket
    if [ "$REGION" = "us-east-1" ]; then
        # us-east-1 doesn't need LocationConstraint
        aws s3api create-bucket --profile "$AWS_PROFILE" --bucket "$bucket_name"
    else
        aws s3api create-bucket \
            --profile "$AWS_PROFILE" \
            --bucket "$bucket_name" \
            --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION"
    fi
    
    # Configure bucket for web hosting and CORS
    aws s3api put-bucket-cors --profile "$AWS_PROFILE" --bucket "$bucket_name" --cors-configuration '{
        "CORSRules": [
            {
                "AllowedHeaders": ["*"],
                "AllowedMethods": ["GET", "POST", "PUT", "DELETE", "HEAD"],
                "AllowedOrigins": ["*"],
                "ExposeHeaders": ["ETag"],
                "MaxAgeSeconds": 3000
            }
        ]
    }'
    
    # Block public access (recommended for security)
    aws s3api put-public-access-block \
        --profile "$AWS_PROFILE" \
        --bucket "$bucket_name" \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    
    print_status "S3 bucket $bucket_name created successfully ✓"
    
    # Create bucket policy for App Runner access
    create_s3_bucket_policy "$bucket_name" "$environment"
}

# Create S3 bucket policy for App Runner
create_s3_bucket_policy() {
    local bucket_name="$1"
    local environment="$2"
    
    print_status "Creating S3 bucket policy for $bucket_name"
    
    local policy_document=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowAppRunnerAccess",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${ACCOUNT_ID}:root"
            },
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::${bucket_name}",
                "arn:aws:s3:::${bucket_name}/*"
            ]
        }
    ]
}
EOF
)
    
    aws s3api put-bucket-policy --profile "$AWS_PROFILE" --bucket "$bucket_name" --policy "$policy_document"
    
    print_status "S3 bucket policy created ✓"
}

# Create ECR repository
create_ecr_repository() {
    local repository_name="$1"
    
    print_status "Creating ECR repository: $repository_name"
    
    # Check if repository already exists
    if aws ecr describe-repositories --profile "$AWS_PROFILE" --region "$REGION" --repository-names "$repository_name" &>/dev/null; then
        print_warning "ECR repository $repository_name already exists"
        return 0
    fi
    
    # Create repository
    local create_result
    if create_result=$(aws ecr create-repository \
        --profile "$AWS_PROFILE" \
        --region "$REGION" \
        --repository-name "$repository_name" \
        --image-scanning-configuration scanOnPush=true \
        --encryption-configuration encryptionType=AES256 2>&1); then
        print_status "ECR repository created successfully ✓"
        
        # Set lifecycle policy to keep only recent images
        local lifecycle_policy='{
            "rules": [
                {
                    "rulePriority": 1,
                    "description": "Keep last 10 images",
                    "selection": {
                        "tagStatus": "any",
                        "countType": "imageCountMoreThan",
                        "countNumber": 10
                    },
                    "action": {
                        "type": "expire"
                    }
                }
            ]
        }'
        
        if aws ecr put-lifecycle-policy \
            --profile "$AWS_PROFILE" \
            --region "$REGION" \
            --repository-name "$repository_name" \
            --lifecycle-policy-text "$lifecycle_policy" &>/dev/null; then
            print_status "ECR lifecycle policy configured ✓"
        fi
    else
        if echo "$create_result" | grep -q "RepositoryAlreadyExistsException"; then
            print_warning "ECR repository $repository_name already exists"
        else
            print_error "Failed to create ECR repository: $create_result"
            return 1
        fi
    fi
    
    local repository_uri="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${repository_name}"
    print_status "ECR repository URI: $repository_uri"
}

# Create S3 policy (Level 2: Resource Operation Policy)
create_s3_policy() {
    local policy_name="AGRR-S3-Policy"
    local policy_document='{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ManageAGRRBuckets",
            "Effect": "Allow",
            "Action": [
                "s3:CreateBucket",
                "s3:DeleteBucket",
                "s3:GetBucketLocation",
                "s3:GetBucketPolicy",
                "s3:PutBucketPolicy",
                "s3:DeleteBucketPolicy",
                "s3:GetBucketCors",
                "s3:PutBucketCors",
                "s3:GetBucketPublicAccessBlock",
                "s3:PutBucketPublicAccessBlock",
                "s3:GetBucketVersioning",
                "s3:PutBucketVersioning",
                "s3:ListBucket",
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::agrr-*",
                "arn:aws:s3:::agrr-*/*"
            ]
        },
        {
            "Sid": "ListAllBuckets",
            "Effect": "Allow",
            "Action": "s3:ListAllMyBuckets",
            "Resource": "*"
        }
    ]
}'
    
    local policy_arn="arn:aws:iam::${ACCOUNT_ID}:policy/${policy_name}"
    
    if ! aws iam get-policy --profile "$AWS_PROFILE" --policy-arn "$policy_arn" &> /dev/null; then
        print_status "Creating S3 policy: $policy_name"
        aws iam create-policy \
            --profile "$AWS_PROFILE" \
            --policy-name "$policy_name" \
            --policy-document "$policy_document" \
            --description "S3 bucket management for AGRR application (agrr-* buckets only)"
    else
        print_status "S3 policy already exists: $policy_name"
    fi
    
    print_status "Attaching S3 policy to user: $USER_NAME"
    aws iam attach-user-policy \
        --profile "$AWS_PROFILE" \
        --user-name "$USER_NAME" \
        --policy-arn "$policy_arn"
    
    print_status "✅ S3 policy configured"
}

# Create IAM policy (Level 2: Resource Operation Policy)
create_iam_policy() {
    local policy_name="AGRR-IAM-Policy"
    local policy_document='{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ManageAppRunnerRole",
            "Effect": "Allow",
            "Action": [
                "iam:CreateRole",
                "iam:GetRole",
                "iam:DeleteRole",
                "iam:PutRolePolicy",
                "iam:DeleteRolePolicy",
                "iam:PassRole",
                "iam:ListRolePolicies",
                "iam:GetRolePolicy"
            ],
            "Resource": "arn:aws:iam::'${ACCOUNT_ID}':role/AppRunnerServiceRole*"
        }
    ]
}'
    
    local policy_arn="arn:aws:iam::${ACCOUNT_ID}:policy/${policy_name}"
    
    if ! aws iam get-policy --profile "$AWS_PROFILE" --policy-arn "$policy_arn" &> /dev/null; then
        print_status "Creating IAM policy: $policy_name"
        aws iam create-policy \
            --profile "$AWS_PROFILE" \
            --policy-name "$policy_name" \
            --policy-document "$policy_document" \
            --description "IAM role management for AGRR AppRunner service (AppRunnerServiceRole* only)"
    else
        print_status "IAM policy already exists: $policy_name"
    fi
    
    print_status "Attaching IAM policy to user: $USER_NAME"
    aws iam attach-user-policy \
        --profile "$AWS_PROFILE" \
        --user-name "$USER_NAME" \
        --policy-arn "$policy_arn"
    
    print_status "✅ IAM policy configured"
}

# Create App Runner policy (Level 2: Resource Operation Policy)
create_apprunner_policy() {
    local policy_name="AGRR-AppRunner-Policy"
    local policy_document='{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ManageAppRunnerServices",
            "Effect": "Allow",
            "Action": [
                "apprunner:CreateService",
                "apprunner:DescribeService",
                "apprunner:UpdateService",
                "apprunner:DeleteService",
                "apprunner:ListServices",
                "apprunner:TagResource",
                "apprunner:UntagResource",
                "apprunner:ListTagsForResource"
            ],
            "Resource": "*"
        }
    ]
}'
    
    local policy_arn="arn:aws:iam::${ACCOUNT_ID}:policy/${policy_name}"
    
    if ! aws iam get-policy --profile "$AWS_PROFILE" --policy-arn "$policy_arn" &> /dev/null; then
        print_status "Creating App Runner policy: $policy_name"
        aws iam create-policy \
            --profile "$AWS_PROFILE" \
            --policy-name "$policy_name" \
            --policy-document "$policy_document" \
            --description "App Runner service management for AGRR application"
    else
        print_status "App Runner policy already exists: $policy_name"
    fi
    
    print_status "Attaching App Runner policy to user: $USER_NAME"
    aws iam attach-user-policy \
        --profile "$AWS_PROFILE" \
        --user-name "$USER_NAME" \
        --policy-arn "$policy_arn"
    
    print_status "✅ App Runner policy configured"
}

# Create ECR policy (Level 2: Resource Operation Policy)
create_ecr_policy() {
    local policy_name="AGRR-ECR-Policy"
    local policy_document='{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ManageECRRepository",
            "Effect": "Allow",
            "Action": [
                "ecr:CreateRepository",
                "ecr:DescribeRepositories",
                "ecr:DeleteRepository",
                "ecr:PutLifecyclePolicy",
                "ecr:GetLifecyclePolicy",
                "ecr:PutImageTagMutability",
                "ecr:PutImageScanningConfiguration"
            ],
            "Resource": "arn:aws:ecr:'${REGION}':'${ACCOUNT_ID}':repository/agrr*"
        },
        {
            "Sid": "PushPullImages",
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:GetRepositoryPolicy",
                "ecr:DescribeRepositories",
                "ecr:ListImages",
                "ecr:DescribeImages",
                "ecr:BatchGetImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:PutImage"
            ],
            "Resource": "*"
        }
    ]
}'
    
    local policy_arn="arn:aws:iam::${ACCOUNT_ID}:policy/${policy_name}"
    
    if ! aws iam get-policy --profile "$AWS_PROFILE" --policy-arn "$policy_arn" &> /dev/null; then
        print_status "Creating ECR policy: $policy_name"
        aws iam create-policy \
            --profile "$AWS_PROFILE" \
            --policy-name "$policy_name" \
            --policy-document "$policy_document" \
            --description "ECR repository management for AGRR application (agrr* repositories only)"
    else
        print_status "ECR policy already exists: $policy_name"
    fi
    
    print_status "Attaching ECR policy to user: $USER_NAME"
    aws iam attach-user-policy \
        --profile "$AWS_PROFILE" \
        --user-name "$USER_NAME" \
        --policy-arn "$policy_arn"
    
    print_status "✅ ECR policy configured"
}

# Create IAM role for App Runner
create_iam_role() {
    local role_name="AppRunnerServiceRole"
    local role_exists=false
    
    print_status "Creating IAM role: $role_name"
    
    # Check if role already exists
    if aws iam get-role --profile "$AWS_PROFILE" --role-name "$role_name" &>/dev/null; then
        print_status "IAM role $role_name already exists ✓"
        role_exists=true
    else
        # Try to create the role
        if aws iam create-role \
            --profile "$AWS_PROFILE" \
            --role-name "$role_name" \
            --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"tasks.apprunner.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
            &>/dev/null; then
            print_status "IAM role created successfully ✓"
        else
            local create_error
            create_error=$(aws iam create-role \
                --profile "$AWS_PROFILE" \
                --role-name "$role_name" \
                --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"tasks.apprunner.amazonaws.com"},"Action":"sts:AssumeRole"}]}' 2>&1)
            
            if echo "$create_error" | grep -q "EntityAlreadyExists"; then
                print_status "IAM role $role_name already exists ✓"
                role_exists=true
            else
                print_error "Failed to create IAM role: $create_error"
                return 1
            fi
        fi
    fi
    
    # Create and attach policy for S3 and ECR access
    local s3_ecr_policy_document=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "S3Access",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::${S3_BUCKET_PREFIX}-*",
                "arn:aws:s3:::${S3_BUCKET_PREFIX}-*/*"
            ]
        },
        {
            "Sid": "ECRAccess",
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage"
            ],
            "Resource": "*"
        },
        {
            "Sid": "ECRRepositoryAccess",
            "Effect": "Allow",
            "Action": [
                "ecr:DescribeRepositories",
                "ecr:ListImages",
                "ecr:DescribeImages"
            ],
            "Resource": "arn:aws:ecr:${REGION}:${ACCOUNT_ID}:repository/agrr*"
        }
    ]
}
EOF
)
    
    # Check if S3ECRAccessPolicy already exists (or old S3AccessPolicy)
    local policy_name="S3ECRAccessPolicy"
    if [ "$role_exists" = true ]; then
        # Check for new policy name first
        if aws iam get-role-policy --profile "$AWS_PROFILE" --role-name "$role_name" --policy-name "$policy_name" &>/dev/null; then
            print_status "$policy_name already attached to role, updating..."
        # Check for old policy name and migrate
        elif aws iam get-role-policy --profile "$AWS_PROFILE" --role-name "$role_name" --policy-name "S3AccessPolicy" &>/dev/null; then
            print_status "Migrating S3AccessPolicy to S3ECRAccessPolicy..."
            aws iam delete-role-policy --profile "$AWS_PROFILE" --role-name "$role_name" --policy-name "S3AccessPolicy" &>/dev/null || true
        else
            print_status "Attaching $policy_name to existing role..."
        fi
    else
        print_status "Attaching $policy_name to new role..."
    fi
    
    if aws iam put-role-policy \
        --profile "$AWS_PROFILE" \
        --role-name "$role_name" \
        --policy-name "$policy_name" \
        --policy-document "$s3_ecr_policy_document" 2>&1; then
        print_status "S3 and ECR access policy configured ✓"
    else
        print_error "Failed to attach S3ECR policy to role"
        return 1
    fi
}

# Generate environment configuration
generate_env_config() {
    print_header "Generating Environment Configuration"
    
    local env_file=".env.aws"
    
    local ecr_uri="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPOSITORY_NAME}"
    
    cat > "$env_file" <<EOF
# AWS Configuration
AWS_REGION=$REGION
AWS_ACCOUNT_ID=$ACCOUNT_ID
AWS_S3_BUCKET=$PRODUCTION_BUCKET
AWS_S3_BUCKET_TEST=$TEST_BUCKET

# ECR Configuration
ECR_REPOSITORY_NAME=$ECR_REPOSITORY_NAME
ECR_REPOSITORY_URI=$ecr_uri

# App Runner Configuration
SERVICE_NAME_PRODUCTION=agrr-production
SERVICE_NAME_TEST=agrr-test
IAM_ROLE_ARN=arn:aws:iam::${ACCOUNT_ID}:role/AppRunnerServiceRole


# Required for deployment
# RAILS_MASTER_KEY=your_rails_master_key_here
# ALLOWED_HOSTS=your-app-runner-url.awsapprunner.com

# Optional: Custom domain
# CUSTOM_DOMAIN=your-domain.com
EOF
    
    print_status "Environment configuration saved to: $env_file"
    print_warning "Please update the values marked with 'your_*_here' before deployment"
}

# Show usage
show_usage() {
    echo "AWS Resources Setup Script for App Runner"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  setup       - Create all required resources and permissions (default)"
    echo "  help        - Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_PROFILE  - AWS profile to use (default: default)"
    echo "  AWS_IAM_USER - IAM user name to configure (default: auto-detected)"
    echo "  AWS_REGION   - AWS region (default: ap-northeast-1)"
    echo ""
    echo "How it works (3-level approach):"
    echo ""
    echo "  Level 0 (Administrator): Grant policy management permissions"
    echo "    - If you don't have policy management permissions"
    echo "    - Script generates 'agrr-policy-management.json'"
    echo "    - Ask admin to apply it, then re-run this script"
    echo ""
    echo "  Level 1 (This script): Create resource operation policies"
    echo "    - Script creates AGRR-S3-Policy, AGRR-IAM-Policy, AGRR-AppRunner-Policy"
    echo "    - Attaches them to your user"
    echo "    - These policies are resource-scoped (agrr-*, AppRunnerServiceRole*)"
    echo ""
    echo "  Level 2 (This script): Create actual AWS resources"
    echo "    - Creates IAM role (AppRunnerServiceRole)"
    echo "    - Creates S3 buckets (agrr-*-production, agrr-*-test)"
    echo "    - Generates .env.aws configuration file"
    echo ""
    echo "Examples:"
    echo "  $0 setup                      # Run setup with auto-detected user"
    echo "  AWS_IAM_USER=myuser $0 setup  # Use custom IAM user name"
    echo "  AWS_REGION=us-east-1 $0 setup # Use different region"
    echo ""
    echo "Note: If you don't have sufficient permissions, the script will generate"
    echo "      a policy file and show instructions for your AWS administrator."
}

# Setup everything
setup_all() {
    print_header "Setting Up AWS Resources for App Runner"
    
    # Step 2: Create resource operation policies (if not exists) and attach to user
    print_header "Step 2: Setting Up Resource Operation Policies"
    
    if ! check_resource_policies_exist; then
        print_status "Creating resource operation policies..."
        create_s3_policy
        create_iam_policy
        create_apprunner_policy
        create_ecr_policy
        print_status "✅ Resource operation policies created and attached!"
    else
        print_status "All policies already configured"
    fi
    
    # Step 3: Create actual AWS resources
    print_header "Step 3: Creating AWS Resources"
    
    # Create IAM role for App Runner service
    print_status "Creating IAM role for App Runner..."
    create_iam_role
    
    # Create S3 buckets
    print_status "Creating S3 buckets..."
    create_s3_bucket "$PRODUCTION_BUCKET" "production"
    create_s3_bucket "$TEST_BUCKET" "test"
    
    # Create ECR repository
    print_status "Creating ECR repository..."
    create_ecr_repository "$ECR_REPOSITORY_NAME"
    
    # Generate environment configuration
    print_status "Generating environment configuration..."
    generate_env_config
    
    print_header "✅ Setup Complete"
    print_status "All AWS resources created successfully!"
    print_status "📁 Environment configuration: .env.aws"
    print_status ""
    print_status "Created resources:"
    print_status "  - IAM Policies: AGRR-S3-Policy, AGRR-IAM-Policy, AGRR-AppRunner-Policy, AGRR-ECR-Policy"
    print_status "  - IAM Role: AppRunnerServiceRole (with S3 and ECR access)"
    print_status "  - S3 Buckets: $PRODUCTION_BUCKET, $TEST_BUCKET"
    print_status "  - ECR Repository: ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPOSITORY_NAME}"
    print_status ""
    print_status "🚀 Ready for deployment!"
    print_status "   Run: ./scripts/aws-deploy.sh [production|aws_test] deploy"
}

# Main execution
main() {
    local command=${1:-setup}
    
    check_prerequisites
    
    case "$command" in
        "setup"|"")
            # Step 1: Check if we have policy management permissions
            if ! check_policy_management_permissions; then
                exit 1
            fi
            
            # Continue with setup
            setup_all
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
