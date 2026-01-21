#!/bin/bash

# ==============================================================================
# Azure Login Helper
# ==============================================================================
# Simple script to authenticate with Azure and set the correct subscription
#
# Usage:
#   ./azure-login.sh [subscription-id-or-name]
#
# ==============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "ERROR: Azure CLI is not installed"
    echo "Install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi

# Login to Azure
print_info "Logging in to Azure..."
az login

# Set subscription if provided
if [ -n "$1" ]; then
    print_info "Setting subscription: $1"
    az account set --subscription "$1"
fi

# Display current context
print_info "Current Azure context:"
az account show --output table

print_info "Login successful!"
