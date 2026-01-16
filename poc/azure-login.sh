#!/bin/bash
#
# Script: azure-login.sh
# Purpose: Authenticate to Azure using Service Principal (CI/CD)
#
# What it does:
# - Reads credentials from environment variables or Jenkins credentials
# - Authenticates Azure CLI with service principal
# - Sets default subscription
# - Validates authentication
#
# Usage (Jenkins): Called automatically by pipeline
# Usage (Local): ./azure-login.sh (requires env vars)
#
# Required environment variables:
#   ARM_CLIENT_ID       - Service Principal Application ID
#   ARM_CLIENT_SECRET   - Service Principal Password/Secret
#   ARM_SUBSCRIPTION_ID - Azure Subscription ID
#   ARM_TENANT_ID       - Azure AD Tenant ID
#

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

echo "========================================"
echo "Azure Authentication (Service Principal)"
echo "========================================"

# Validate required environment variables
if [ -z "$ARM_CLIENT_ID" ] || [ -z "$ARM_CLIENT_SECRET" ] || [ -z "$ARM_SUBSCRIPTION_ID" ] || [ -z "$ARM_TENANT_ID" ]; then
    log_error "Missing required environment variables"
    echo ""
    echo "Required environment variables:"
    echo "  ARM_CLIENT_ID       - Service Principal Application ID"
    echo "  ARM_CLIENT_SECRET   - Service Principal Password/Secret"
    echo "  ARM_SUBSCRIPTION_ID - Azure Subscription ID"
    echo "  ARM_TENANT_ID       - Azure AD Tenant ID"
    echo ""
    echo "Set in Jenkins:"
    echo "  Configure credentials in Jenkins Credentials Manager"
    echo "  Bind credentials in pipeline using 'withCredentials'"
    echo ""
    echo "Set locally for testing:"
    echo "  export ARM_CLIENT_ID='xxx'"
    echo "  export ARM_CLIENT_SECRET='xxx'"
    echo "  export ARM_SUBSCRIPTION_ID='xxx'"
    echo "  export ARM_TENANT_ID='xxx'"
    exit 1
fi

log_info "Environment variables found"
log_info "Client ID: ${ARM_CLIENT_ID:0:8}..."
log_info "Tenant ID: ${ARM_TENANT_ID:0:8}..."
log_info "Subscription ID: ${ARM_SUBSCRIPTION_ID:0:8}..."

# Login with service principal
log_info "Authenticating to Azure..."
if az login \
    --service-principal \
    --username "$ARM_CLIENT_ID" \
    --password "$ARM_CLIENT_SECRET" \
    --tenant "$ARM_TENANT_ID" \
    --output none 2>/dev/null; then
    log_info "Authentication successful"
else
    log_error "Authentication failed"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Verify service principal credentials are correct"
    echo "  2. Check service principal has not expired"
    echo "  3. Verify service principal has access to subscription"
    echo "  4. Check network connectivity to Azure"
    exit 1
fi

# Set default subscription
log_info "Setting default subscription..."
az account set --subscription "$ARM_SUBSCRIPTION_ID"

# Validate authentication
SUBSCRIPTION_NAME=$(az account show --query 'name' -o tsv)
SUBSCRIPTION_ID=$(az account show --query 'id' -o tsv)

echo ""
log_info "Successfully authenticated to Azure"
echo "========================================"
echo "Subscription: $SUBSCRIPTION_NAME"
echo "Subscription ID: $SUBSCRIPTION_ID"
echo "========================================"

# Export for Terraform
export ARM_CLIENT_ID
export ARM_CLIENT_SECRET
export ARM_SUBSCRIPTION_ID
export ARM_TENANT_ID

log_info "Environment variables exported for Terraform"
