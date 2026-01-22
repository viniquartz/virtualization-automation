#!/bin/bash
#
# Script: configure.sh
# Purpose: Clone repository and configure Terraform backend for VMware automation
#
# What it does:
# - Clones Git repository to workspace directory
# - Generates backend configuration file
# - Initializes Terraform with Azure Storage backend
#
# Prerequisites:
# - Azure CLI authenticated (run azure-login.sh first)
# - Git installed
# - Terraform installed
# - vSphere credentials exported
#
# Usage: ./configure.sh <ticket-id> <environment> <git-repo-url>
# Example: ./configure.sh OPS-1234 tst https://github.com/yourorg/virtualization-automation.git
#

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

TICKET_ID=${1}
ENVIRONMENT=${2}
GIT_REPO_URL=${3}

if [ -z "$TICKET_ID" ] || [ -z "$ENVIRONMENT" ] || [ -z "$GIT_REPO_URL" ]; then
    log_error "Missing required parameters"
    echo "Usage: $0 <ticket-id> <environment> <git-repo-url>"
    echo ""
    echo "Examples:"
    echo "  $0 OPS-1234 tst https://github.com/yourorg/virtualization-automation.git"
    echo "  $0 OPS-5678 prd https://github.com/yourorg/virtualization-automation.git"
    exit 1
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(prd|qlt|tst)$ ]]; then
    log_error "Invalid environment: $ENVIRONMENT"
    echo "Valid environments: prd, qlt, tst"
    exit 1
fi

# Validate ticket ID format (alphanumeric with dash)
if [[ ! "$TICKET_ID" =~ ^[A-Z]+-[0-9]+$ ]]; then
    log_warn "Ticket ID format may be invalid: $TICKET_ID"
    log_warn "Expected format: PROJECT-1234 (e.g., OPS-1234, INFRA-567)"
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    log_error "Terraform is not installed"
    exit 1
fi

TERRAFORM_VERSION=$(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)
log_info "Terraform version: v$TERRAFORM_VERSION"

# Check if Git is installed
if ! command -v git &> /dev/null; then
    log_error "Git is not installed"
    exit 1
fi

# Check Azure authentication
if ! az account show &> /dev/null; then
    log_error "Not authenticated to Azure"
    echo ""
    echo "Run azure-login.sh first:"
    echo "  bash scripts/poc/azure-login.sh"
    exit 1
fi

# Check vSphere credentials
log_info "Checking vSphere credentials..."
MISSING_VSPHERE_VARS=()

if [ -z "$TF_VAR_vsphere_server" ]; then
    MISSING_VSPHERE_VARS+=("TF_VAR_vsphere_server")
fi

if [ -z "$TF_VAR_vsphere_user" ]; then
    MISSING_VSPHERE_VARS+=("TF_VAR_vsphere_user")
fi

if [ -z "$TF_VAR_vsphere_password" ]; then
    MISSING_VSPHERE_VARS+=("TF_VAR_vsphere_password")
fi

if [ ${#MISSING_VSPHERE_VARS[@]} -gt 0 ]; then
    log_warn "vSphere credentials not set (required for deployment)"
    echo ""
    echo "Set the following environment variables before deploying:"
    for var in "${MISSING_VSPHERE_VARS[@]}"; do
        echo "  export $var=\"your-value-here\""
    done
    echo ""
    echo "Example:"
    echo "  export TF_VAR_vsphere_server=\"vcenter-tst.example.com\""
    echo "  export TF_VAR_vsphere_user=\"svc-terraform@vsphere.local\""
    echo "  export TF_VAR_vsphere_password=\"your-password\""
    echo ""
    log_info "Continuing with configuration (you can set these later)..."
fi

WORKSPACE_DIR="$TICKET_ID"
BACKEND_CONFIG_FILE="$WORKSPACE_DIR/backend-config.tfbackend"

# Azure backend configuration
STORAGE_ACCOUNT_NAME="azrprdiac01weust01"
RESOURCE_GROUP_NAME="azr-prd-iac01-weu-rg"
CONTAINER_NAME="terraform-state-${ENVIRONMENT}"
STATE_KEY="vmware/${TICKET_ID}.tfstate"

echo "========================================"
echo "Terraform Project Configuration"
echo "========================================"
echo "Ticket ID:    $TICKET_ID"
echo "Environment:  $ENVIRONMENT"
echo "Repository:   $GIT_REPO_URL"
echo "Workspace:    $(pwd)/$WORKSPACE_DIR"
echo ""
echo "Backend Configuration:"
echo "  Storage:    $STORAGE_ACCOUNT_NAME"
echo "  Container:  $CONTAINER_NAME"
echo "  State Key:  $STATE_KEY"
echo "========================================"

# ============================================
# Step 1: Clone Repository
# ============================================

log_step "[STEP 1/4] Cloning repository"

# Remove existing directory if exists
if [ -d "$WORKSPACE_DIR" ]; then
    log_warn "Workspace directory already exists: $WORKSPACE_DIR"
    read -p "Remove existing directory? (yes/no): " -r
    echo
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Removing existing directory..."
        rm -rf "$WORKSPACE_DIR"
    else
        log_error "Cannot proceed with existing directory"
        exit 1
    fi
fi

log_info "Cloning repository..."
if git clone "$GIT_REPO_URL" "$WORKSPACE_DIR" 2>&1; then
    log_info "✓ Repository cloned successfully"
else
    log_error "Failed to clone repository"
    echo ""
    echo "Possible causes:"
    echo "  1. Repository URL is incorrect"
    echo "  2. No access to repository (check SSH keys or credentials)"
    echo "  3. Network connectivity issues"
    exit 1
fi

# ============================================
# Step 2: Copy Template
# ============================================

log_step "[STEP 2/4] Setting up project structure"

cd "$WORKSPACE_DIR" || exit 1

# Check if terraform-project-template exists
if [ ! -d "terraform-project-template" ]; then
    log_error "terraform-project-template directory not found in repository"
    exit 1
fi

# Copy template files to root
log_info "Copying template files..."
cp terraform-project-template/*.tf ./ 2>/dev/null || true
cp -r terraform-project-template/environments ./ 2>/dev/null || true
cp -r terraform-project-template/terraform-modules ./ 2>/dev/null || true

# Verify required files
REQUIRED_FILES=("main.tf" "variables.tf" "provider.tf" "backend.tf")
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        log_error "Required file not found: $file"
        exit 1
    fi
done

log_info "✓ Project structure created"

# ============================================
# Step 3: Generate Backend Configuration
# ============================================

log_step "[STEP 3/4] Generating backend configuration"

cat > "$BACKEND_CONFIG_FILE" <<EOF
# Generated by configure.sh
# Date: $(date '+%Y-%m-%d %H:%M:%S')
# Ticket: $TICKET_ID
# Environment: $ENVIRONMENT

resource_group_name  = "$RESOURCE_GROUP_NAME"
storage_account_name = "$STORAGE_ACCOUNT_NAME"
container_name       = "$CONTAINER_NAME"
key                  = "$STATE_KEY"
EOF

log_info "✓ Backend configuration file created: $BACKEND_CONFIG_FILE"

# ============================================
# Step 4: Initialize Terraform
# ============================================

log_step "[STEP 4/4] Initializing Terraform"

log_info "Running terraform init..."

if terraform init -backend-config="$BACKEND_CONFIG_FILE" -upgrade; then
    log_info "✓ Terraform initialized successfully"
else
    log_error "Terraform initialization failed"
    echo ""
    echo "Possible causes:"
    echo "  1. Backend storage account not accessible"
    echo "  2. Container does not exist"
    echo "  3. Insufficient permissions"
    echo ""
    echo "Verify backend:"
    echo "  az storage account show \\"
    echo "    --name $STORAGE_ACCOUNT_NAME \\"
    echo "    --resource-group $RESOURCE_GROUP_NAME"
    exit 1
fi

# ============================================
# Completion
# ============================================

cd ..

echo ""
echo "========================================"
log_info "Configuration completed successfully!"
echo "========================================"
echo "Ticket ID:   $TICKET_ID"
echo "Environment: $ENVIRONMENT"
echo "Workspace:   $(pwd)/$WORKSPACE_DIR"
echo ""
echo "State file location:"
echo "  Storage:   $STORAGE_ACCOUNT_NAME"
echo "  Container: $CONTAINER_NAME"
echo "  Key:       $STATE_KEY"
echo ""
echo "Next steps:"
echo "  1. Review variables: cd $WORKSPACE_DIR && cat environments/$ENVIRONMENT/terraform.tfvars"
echo "  2. Set vSphere credentials (if not already set):"
echo "     export TF_VAR_vsphere_server=\"vcenter.example.com\""
echo "     export TF_VAR_vsphere_user=\"svc-terraform@vsphere.local\""
echo "     export TF_VAR_vsphere_password=\"your-password\""
echo "  3. Deploy: bash scripts/poc/deploy.sh $TICKET_ID $ENVIRONMENT"
echo "========================================"
