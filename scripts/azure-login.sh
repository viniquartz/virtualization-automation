#!/bin/bash
#
# Script: azure-login.sh
# Purpose: Authenticate Azure CLI using Service Principal
#
# What it does:
# - Validates required environment variables
# - Authenticates Azure CLI with Service Principal
# - Sets default subscription
#
# Prerequisites:
# - Azure CLI installed
# - Service Principal credentials exported as environment variables
#
# Usage: ./azure-login.sh
#
# Required environment variables:
# - ARM_CLIENT_ID
# - ARM_CLIENT_SECRET
# - ARM_SUBSCRIPTION_ID
# - ARM_TENANT_ID
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

echo "========================================"
echo "Azure CLI Authentication"
echo "========================================"

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    log_error "Azure CLI is not installed"
    echo ""
    echo "Install Azure CLI:"
    echo "  macOS:   brew install azure-cli"
    echo "  Linux:   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
    echo "  Windows: https://aka.ms/installazurecliwindows"
    exit 1
fi

AZURE_CLI_VERSION=$(az version --output json | grep -o '"azure-cli": "[^"]*' | cut -d'"' -f4)
log_info "Azure CLI version: $AZURE_CLI_VERSION"

# Check required environment variables
log_step "Step 1: Validating environment variables"

MISSING_VARS=()

if [ -z "$ARM_CLIENT_ID" ]; then
    MISSING_VARS+=("ARM_CLIENT_ID")
fi

if [ -z "$ARM_CLIENT_SECRET" ]; then
    MISSING_VARS+=("ARM_CLIENT_SECRET")
fi

if [ -z "$ARM_SUBSCRIPTION_ID" ]; then
    MISSING_VARS+=("ARM_SUBSCRIPTION_ID")
fi

if [ -z "$ARM_TENANT_ID" ]; then
    MISSING_VARS+=("ARM_TENANT_ID")
fi

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    log_error "Missing required environment variables"
    echo ""
    echo "Set the following environment variables:"
    for var in "${MISSING_VARS[@]}"; do
        echo "  export $var=\"your-value-here\""
    done
    echo ""
    echo "Example:"
    echo "  export ARM_CLIENT_ID=\"00000000-0000-0000-0000-000000000000\""
    echo "  export ARM_CLIENT_SECRET=\"your-secret\""
    echo "  export ARM_SUBSCRIPTION_ID=\"00000000-0000-0000-0000-000000000000\""
    echo "  export ARM_TENANT_ID=\"00000000-0000-0000-0000-000000000000\""
    exit 1
fi

log_info "✓ All required environment variables are set"
log_info "  Client ID: ${ARM_CLIENT_ID:0:8}..."
log_info "  Subscription ID: ${ARM_SUBSCRIPTION_ID:0:8}..."
log_info "  Tenant ID: ${ARM_TENANT_ID:0:8}..."

# Authenticate with Service Principal
log_step "Step 2: Authenticating with Azure"

if az login \
    --service-principal \
    --username "$ARM_CLIENT_ID" \
    --password "$ARM_CLIENT_SECRET" \
    --tenant "$ARM_TENANT_ID" \
    --output none 2>&1; then
    log_info "✓ Authentication successful"
else
    log_error "Authentication failed"
    echo ""
    echo "Possible causes:"
    echo "  1. Invalid credentials"
    echo "  2. Service Principal expired or disabled"
    echo "  3. Incorrect tenant ID"
    echo "  4. Network connectivity issues"
    exit 1
fi

# Set default subscription
log_step "Step 3: Setting default subscription"

if az account set --subscription "$ARM_SUBSCRIPTION_ID" 2>&1; then
    log_info "✓ Default subscription set"
else
    log_error "Failed to set default subscription"
    exit 1
fi

# Show account information
log_step "Step 4: Verifying account"

ACCOUNT_INFO=$(az account show --output json 2>/dev/null)
ACCOUNT_NAME=$(echo "$ACCOUNT_INFO" | grep -o '"name": "[^"]*' | cut -d'"' -f4)
SUBSCRIPTION_ID=$(echo "$ACCOUNT_INFO" | grep -o '"id": "[^"]*' | cut -d'"' -f4)

echo ""
echo "========================================"
log_info "Azure authentication completed!"
echo "========================================"
echo "Account:      $ACCOUNT_NAME"
echo "Subscription: $SUBSCRIPTION_ID"
echo "Tenant:       $ARM_TENANT_ID"
echo "========================================"
echo ""
log_info "You can now proceed with Terraform operations"
echo ""
echo "Next steps:"
echo "  1. Configure project: bash scripts/poc/configure.sh <ticket-id> <env> <repo-url>"
echo "  2. Deploy: bash scripts/poc/deploy.sh <ticket-id> <env>"
echo "========================================"
