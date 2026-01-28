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
# Example: ./configure.sh OPS-1234 tst https://gitlab.tap.pt/digital-infrastructure/virtualizacao/terraform/virtualizacao-terraform-project-template.git
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
GITLAB_REPO_URL=${3}

if [ -z "$TICKET_ID" ] || [ -z "$ENVIRONMENT" ] || [ -z "$GITLAB_REPO_URL" ]; then
    log_error "Missing required parameters"
    echo "Usage: $0 <ticket-id> <environment> <git-repo-url>"
    echo ""
    echo "Examples:"
    echo "  $0 OPS-1234 tst https://gitlab.tap.pt/digital-infrastructure/virtualizacao/terraform/virtualizacao-terraform-project-template.git"
    exit 1
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(prd|qlt|tst)$ ]]; then
    log_error "Invalid environment: $ENVIRONMENT"
    echo "Valid environments: prd, qlt, tst"
    exit 1
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
    echo "  bash scripts/azure-login.sh"
    exit 1
fi

# Verify vSphere credentials
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
    log_error "vSphere credentials not set"
    echo ""
    echo "Set the following environment variables:"
    for var in "${MISSING_VSPHERE_VARS[@]}"; do
        echo "  export $var=\"your-value-here\""
    done
    echo ""
    echo "Example:"
    echo "  export TF_VAR_vsphere_server=\"vcenter-${ENVIRONMENT}.example.com\""
    echo "  export TF_VAR_vsphere_user=\"svc-terraform-${ENVIRONMENT}@vsphere.local\""
    echo "  export TF_VAR_vsphere_password=\"your-password\""
    exit 1
fi

log_info "✓ vSphere credentials configured"
log_info "  Server: $TF_VAR_vsphere_server"
log_info "  User:   $TF_VAR_vsphere_user"

# ============================================
# GitLab Authentication and Clone
# ============================================

log_info "Preparing to clone repository from GitLab"

WORKSPACE_DIR="/home/jenkins/$TICKET_ID"

# Check if GITLAB_TOKEN is set
if [ -z "$GITLAB_TOKEN" ]; then
    log_error "GITLAB_TOKEN environment variable not set"
    echo ""
    echo "Set your GitLab Personal Access Token:"
    echo "  export GITLAB_TOKEN='your-token-here'"
    exit 1
fi

# Check if directory already exists
if [ -d "$WORKSPACE_DIR" ]; then
    log_warn "Directory '$WORKSPACE_DIR' already exists"
    read -p "Remove and re-clone? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$WORKSPACE_DIR"
        log_info "Removed existing directory"
    else
        log_info "Using existing directory"
        cd "$WORKSPACE_DIR"
        git pull origin main || git pull origin master || log_warn "Could not pull latest changes"
        cd ..
    fi
fi

if [ ! -d "$WORKSPACE_DIR" ]; then
    # Inject token into URL for authentication
    AUTHENTICATED_URL=$(echo "$GITLAB_REPO_URL" | sed "s|https://|https://oauth2:${GITLAB_TOKEN}@|")
    
    log_info "Cloning repository..."
    if git clone "$AUTHENTICATED_URL" "$WORKSPACE_DIR"; then
        log_info "✓ Repository cloned successfully to $WORKSPACE_DIR"
        
        # Remove credentials from git config
        cd "$WORKSPACE_DIR"
        git remote set-url origin "$GITLAB_REPO_URL"
        cd ..
    else
        log_error "Failed to clone repository"
        echo ""
        echo "Possible issues:"
        echo "  - Invalid GITLAB_TOKEN"
        echo "  - Repository URL incorrect"
        echo "  - No access to repository"
        exit 1
    fi
fi

# ============================================
# Backend Configuration
# ============================================
# Azure backend configuration
RESOURCE_GROUP_NAME="azr-prd-iac01-weu-rg"
STORAGE_ACCOUNT_NAME="azrprdiac01weust01"
CONTAINER_NAME="terraform-state-${ENVIRONMENT}"
STATE_KEY="vmware/${TICKET_ID}.tfstate"

log_info "Configuring Terraform backend"
log_info "  Project: $PROJECT_NAME"
log_info "  Environment: $ENVIRONMENT"
log_info "  Container: $CONTAINER_NAME"
log_info "  State Key: $STATE_KEY"

# Create backend configuration file
cd "$WORKSPACE_DIR"

cat > backend-config.tfbackend <<EOF
resource_group_name  = "$RESOURCE_GROUP"
storage_account_name = "$STORAGE_ACCOUNT"
container_name       = "$CONTAINER_NAME"
key                  = "$STATE_KEY"
EOF

log_info "✓ Generated backend-config.tfbackend"
# ============================================
# Terraform Initialization
# ============================================

# Configure Git credentials for Terraform module downloads
log_info "Configuring Git credentials for Terraform modules..."
git config --global credential.helper store

# Extract GitLab host from URL
GITLAB_HOST=$(echo "$GITLAB_REPO_URL" | sed -E 's|https?://([^/]+)/.*|\1|')

# Store credentials for Terraform to download modules
echo "https://oauth2:${GITLAB_TOKEN}@${GITLAB_HOST}" > ~/.git-credentials

log_info "Initializing Terraform..."
if terraform init -backend-config=backend-config.tfbackend -reconfigure; then
    # Clean up credentials after successful init
    rm -f ~/.git-credentials
    git config --global --unset credential.helper

    echo ""
    log_info "=========================================="
    log_info "Configuration completed successfully!"
    log_info "=========================================="
    log_info "Ticket ID:   $TICKET_ID"
    log_info "Environment: $ENVIRONMENT"
    log_info "Workspace:   $(pwd)"
    log_info "State:       $STORAGE_ACCOUNT/$CONTAINER_NAME/$STATE_KEY"
    echo ""
    log_info "Next steps:"
    echo "  cd $WORKSPACE_DIR"
    echo "  terraform plan -var-file='environments/$ENVIRONMENT/terraform.tfvars'"
    echo "  terraform apply -var-file='environments/$ENVIRONMENT/terraform.tfvars'"
else
    # Clean up credentials on failure
    rm -f ~/.git-credentials
    git config --global --unset credential.helper

    log_error "Failed to initialize Terraform backend"
    exit 1
fi
