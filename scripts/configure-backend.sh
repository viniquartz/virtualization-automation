#!/bin/bash

# ==============================================================================
# Configure Terraform Backend
# ==============================================================================
# This script configures the Terraform backend for VMware infrastructure
# deployment using Azure Storage Account.
#
# Usage:
#   ./configure-backend.sh <environment> <key>
#
# Examples:
#   ./configure-backend.sh tst ABC-123
#   ./configure-backend.sh prd my-project
#
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check arguments
if [ $# -lt 2 ]; then
    print_error "Missing required arguments"
    echo "Usage: $0 <environment> <key>"
    echo ""
    echo "Environments: tst, qlt, prd"
    echo "Key: Project name or Jira ticket (e.g., ABC-123, my-project)"
    echo ""
    echo "Examples:"
    echo "  $0 tst ABC-123"
    echo "  $0 prd vmware-infra"
    exit 1
fi

ENVIRONMENT=$1
KEY=$2

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(tst|qlt|prd)$ ]]; then
    print_error "Invalid environment: $ENVIRONMENT"
    echo "Valid environments: tst, qlt, prd"
    exit 1
fi

# Backend configuration
RESOURCE_GROUP="azr-prd-iac01-weu-rg"
STORAGE_ACCOUNT="azrprdiac01weust01"
CONTAINER="terraform-state-${ENVIRONMENT}"
STATE_KEY="vmware/${KEY}.tfstate"

print_info "Backend Configuration:"
echo "  Resource Group:   $RESOURCE_GROUP"
echo "  Storage Account:  $STORAGE_ACCOUNT"
echo "  Container:        $CONTAINER"
echo "  State File:       $STATE_KEY"
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed"
    echo "Install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi

# Check if logged in
print_info "Checking Azure authentication..."
if ! az account show &> /dev/null; then
    print_warn "Not logged in to Azure"
    print_info "Running Azure login..."
    az login
fi

SUBSCRIPTION=$(az account show --query name -o tsv)
print_info "Using subscription: $SUBSCRIPTION"

# Verify storage account access
print_info "Verifying storage account access..."
if ! az storage account show \
    --name "$STORAGE_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    print_error "Cannot access storage account: $STORAGE_ACCOUNT"
    exit 1
fi

# Verify container exists
print_info "Verifying container: $CONTAINER..."
if ! az storage container show \
    --name "$CONTAINER" \
    --account-name "$STORAGE_ACCOUNT" \
    --auth-mode login &> /dev/null; then
    print_warn "Container does not exist: $CONTAINER"
    print_info "Creating container..."
    az storage container create \
        --name "$CONTAINER" \
        --account-name "$STORAGE_ACCOUNT" \
        --auth-mode login
fi

# Initialize Terraform
print_info "Initializing Terraform backend..."
terraform init \
    -backend-config="resource_group_name=$RESOURCE_GROUP" \
    -backend-config="storage_account_name=$STORAGE_ACCOUNT" \
    -backend-config="container_name=$CONTAINER" \
    -backend-config="key=$STATE_KEY" \
    -reconfigure

if [ $? -eq 0 ]; then
    print_info "Backend configured successfully!"
    echo ""
    print_info "To deploy, run:"
    echo "  terraform plan -var-file=environments/${ENVIRONMENT}/terraform.tfvars"
    echo "  terraform apply -var-file=environments/${ENVIRONMENT}/terraform.tfvars"
else
    print_error "Backend configuration failed"
    exit 1
fi
