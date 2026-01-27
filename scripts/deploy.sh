#!/bin/bash
#
# Script: deploy.sh
# Purpose: Generate Terraform plan and apply changes for VMware infrastructure
#
# What it does:
# - Changes to project workspace directory
# - Generates Terraform execution plan to file
# - Reviews plan output
# - Applies plan after user confirmation
#
# Usage: ./deploy.sh <ticket-id> <environment>
# Example: ./deploy.sh OPS-1234 tst
#          ./deploy.sh OPS-5678 prd
#
# Prerequisites: 
# - Run configure.sh first
# - vSphere credentials exported
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

if [ -z "$TICKET_ID" ] || [ -z "$ENVIRONMENT" ]; then
    log_error "Missing required parameters"
    echo "Usage: $0 <ticket-id> <environment>"
    echo ""
    echo "Examples:"
    echo "  $0 OPS-1234 tst"
    echo "  $0 OPS-5678 qlt"
    echo "  $0 INFRA-999 prd"
    exit 1
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(prd|qlt|tst)$ ]]; then
    log_error "Invalid environment: $ENVIRONMENT"
    echo "Valid environments: prd, qlt, tst"
    exit 1
fi

WORKSPACE_DIR="/home/jenkins/$TICKET_ID"

# Check if workspace directory exists
if [ ! -d "$WORKSPACE_DIR" ]; then
    log_error "Workspace directory not found: $WORKSPACE_DIR"
    echo ""
    echo "Run configure.sh first:"
    echo "  bash scripts/configure.sh $TICKET_ID $ENVIRONMENT <git-repo-url>"
    exit 1
fi

# Change to workspace directory
cd "$WORKSPACE_DIR" || {
    log_error "Failed to change to workspace directory: $WORKSPACE_DIR"
    exit 1
}

# Check if main.tf exists
if [ ! -f "main.tf" ]; then
    log_error "main.tf not found in workspace directory"
    exit 1
fi

# Check if tfvars exists
TFVARS_FILE="environments/${ENVIRONMENT}/terraform.tfvars"
if [ ! -f "$TFVARS_FILE" ]; then
    log_error "Terraform variables file not found: $TFVARS_FILE"
    exit 1
fi

PLAN_FILE="tfplan-${ENVIRONMENT}.out"

echo "========================================"
echo "Terraform Deploy Workflow"
echo "========================================"
echo "Ticket ID:   $TICKET_ID"
echo "Environment: $ENVIRONMENT"
echo "Workspace:   $(pwd)"
echo "Variables:   $TFVARS_FILE"
echo "Plan output: $PLAN_FILE"
echo "vCenter:     $TF_VAR_vsphere_server"
echo "========================================"

# Step 1: Generate plan
echo ""
log_step "[STEP 1/3] Generating execution plan..."
log_info "Running terraform plan..."

if terraform plan \
    -var-file="$TFVARS_FILE" \
    -out="$PLAN_FILE"; then
    log_info "✓ Plan generated successfully"
else
    log_error "Failed to generate plan"
    echo ""
    echo "Possible causes:"
    echo "  1. Syntax errors in Terraform code"
    echo "  2. Invalid vSphere credentials"
    echo "  3. vCenter not accessible"
    echo "  4. Missing required variables"
    exit 1
fi

# Step 2: Show plan summary
echo ""
log_step "[STEP 2/3] Plan Summary"
echo ""

# Show plan summary
terraform show -no-color "$PLAN_FILE" | grep -E "Plan:|No changes" || true

# Show resource changes
echo ""
echo "Resources to be created/modified:"
terraform show -no-color "$PLAN_FILE" | grep -E "^  # " | head -20 || echo "  (See full plan above)"

echo ""

# Step 3: Confirm and apply
echo ""
log_step "[STEP 3/3] Apply changes"
log_warn "Review the plan above carefully"

echo ""
read -p "Do you want to apply these changes? (yes/no): " -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    log_warn "Deployment cancelled by user"
    log_info "Plan file saved: $PLAN_FILE"
    log_info "To apply later: terraform apply $PLAN_FILE"
    exit 0
fi

log_info "Applying plan..."
if terraform apply "$PLAN_FILE"; then
    log_info "✓ Changes applied successfully"
    
    # Clean up plan file after successful apply
    rm -f "$PLAN_FILE"
    log_info "Plan file removed: $PLAN_FILE"
else
    log_error "Failed to apply changes"
    log_info "Plan file preserved: $PLAN_FILE"
    exit 1
fi

# Show outputs
echo ""
log_info "Retrieving outputs..."
terraform output

# Completion
# Azure backend configuration
STORAGE_ACCOUNT_NAME="azrprdiac01weust01"
CONTAINER_NAME="terraform-state-${ENVIRONMENT}"
STATE_KEY="vmware/${TICKET_ID}.tfstate"
echo ""
echo "========================================"
log_info "Deployment completed successfully!"
echo "========================================"
echo "Ticket ID:   $TICKET_ID"
echo "Environment: $ENVIRONMENT"
echo "vCenter:     $TF_VAR_vsphere_server"
echo ""
echo "State file:"
echo "  Storage:   $STORAGE_ACCOUNT_NAME"
echo "  Container: $CONTAINER_NAME"
echo "  Key:       $STATE_KEY"
echo ""
echo "Useful commands:"
echo "  terraform output                              - View all outputs"
echo "  terraform show                                - Show current state"
echo "  terraform state list                          - List all resources"
echo "  terraform state show <resource>               - Show specific resource"
echo "  bash ../scripts/destroy.sh $TICKET_ID $ENVIRONMENT - Destroy resources"
echo "========================================"
