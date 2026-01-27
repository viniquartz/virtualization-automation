#!/bin/bash
#
# Script: destroy.sh
# Purpose: Destroy VMware infrastructure provisioned by Terraform
#
# What it does:
# - Changes to project workspace directory
# - Generates Terraform destroy plan to file
# - Reviews resources to be destroyed
# - Destroys infrastructure after confirmation
#
# Usage: ./destroy.sh <ticket-id> <environment>
# Example: ./destroy.sh OPS-1234 tst
#          ./destroy.sh OPS-5678 prd
#
# Prerequisites: Infrastructure must be deployed
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
    echo "Project may not be configured or already destroyed."
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

log_info "✓ vSphere credentials configured"
log_info "  Server: $TF_VAR_vsphere_server"
log_info "  User:   $TF_VAR_vsphere_user"

DESTROY_PLAN_FILE="tfplan-destroy-${ENVIRONMENT}.out"

echo "========================================"
echo "Terraform Destroy Workflow"
echo "========================================"
echo "Ticket ID:   $TICKET_ID"
echo "Environment: $ENVIRONMENT"
echo "Workspace:   $(pwd)"
echo "Variables:   $TFVARS_FILE"
echo "Plan output: $DESTROY_PLAN_FILE"
echo "vCenter:     $TF_VAR_vsphere_server"
echo "========================================"
echo ""
log_warn "WARNING: This will DESTROY all VMware infrastructure!"
echo ""

# Step 1: Show current state
echo ""
log_step "[STEP 1/4] Current infrastructure state"
log_info "Resources currently managed:"
echo ""

if terraform state list 2>/dev/null; then
    RESOURCE_COUNT=$(terraform state list 2>/dev/null | wc -l | tr -d ' ')
    echo ""
    log_warn "$RESOURCE_COUNT resources will be destroyed"
else
    log_warn "No state file found or no resources"
fi

# Step 2: Generate destroy plan
echo ""
log_step "[STEP 2/4] Generating destroy plan..."
log_info "Running terraform plan -destroy..."

if terraform plan -destroy \
    -var-file="$TFVARS_FILE" \
    -out="$DESTROY_PLAN_FILE"; then
    log_info "✓ Destroy plan generated successfully"
else
    log_error "Failed to generate destroy plan"
    echo ""
    echo "Possible causes:"
    echo "  1. Invalid vSphere credentials"
    echo "  2. vCenter not accessible"
    echo "  3. State file issues"
    exit 1
fi

# Step 3: Show plan summary
echo ""
log_step "[STEP 3/4] Destroy Plan Summary"
echo ""
terraform show -no-color "$DESTROY_PLAN_FILE" | grep -E "Plan:|No changes" || true

# Show resources to be destroyed
echo ""
echo "Resources to be destroyed:"
terraform show -no-color "$DESTROY_PLAN_FILE" | grep -E "^  # " | head -20 || echo "  (See full plan above)"

echo ""

# Step 4: Confirm and destroy
echo ""
log_step "[STEP 4/4] Destroy infrastructure"
log_warn "DANGER: This will permanently delete all VMware resources!"
log_warn "Review the destroy plan above carefully"
echo ""
read -p "Type 'yes' to confirm destruction: " -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    log_warn "Destruction cancelled by user"
    log_info "Destroy plan file saved: $DESTROY_PLAN_FILE"
    log_info "To destroy later: terraform apply $DESTROY_PLAN_FILE"
    exit 0
fi

log_info "Applying destroy plan..."
if terraform apply "$DESTROY_PLAN_FILE"; then
    log_info "✓ Infrastructure destroyed successfully"
    
    # Clean up plan file after successful destroy
    rm -f "$DESTROY_PLAN_FILE"
    log_info "Destroy plan file removed: $DESTROY_PLAN_FILE"
else
    log_error "Failed to destroy infrastructure"
    log_info "Destroy plan file preserved: $DESTROY_PLAN_FILE"
    exit 1
fi

# Verify destruction
echo ""
log_info "Verifying destruction..."
REMAINING_RESOURCES=$(terraform state list 2>/dev/null | wc -l | tr -d ' ')

if [ "$REMAINING_RESOURCES" -eq 0 ]; then
    log_info "✓ All resources destroyed successfully"
else
    log_warn "$REMAINING_RESOURCES resources remain in state"
    terraform state list
fi

# Completion
# Azure backend configuration
STORAGE_ACCOUNT_NAME="azrprdiac01weust01"
CONTAINER_NAME="terraform-state-${ENVIRONMENT}"
STATE_KEY="vmware/${TICKET_ID}.tfstate"
echo ""
echo "========================================"
log_info "Infrastructure destroyed successfully!"
echo "========================================"
echo "Ticket ID:   $TICKET_ID"
echo "Environment: $ENVIRONMENT"
echo "vCenter:     $TF_VAR_vsphere_server"
echo ""
log_info "State file remains in Azure Storage for audit purposes."
echo ""
echo "State file:"
echo "  Storage:   $STORAGE_ACCOUNT_NAME"
echo "  Container: $CONTAINER_NAME"
echo "  Key:       $STATE_KEY"
echo ""
echo "To clean up workspace directory:"
echo "  cd .."
echo "  rm -rf $WORKSPACE_DIR"
echo "========================================"
