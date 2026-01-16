#!/bin/bash
#
# Script: validate-modules.sh
# Purpose: Validate all Terraform modules in terraform-modules repository
#
# What it does:
# - Clones terraform-modules repository (with specific tag/branch)
# - Validates all modules independently
# - Checks for syntax errors, formatting issues
# - Generates validation report
#
# Prerequisites:
# - GITLAB_TOKEN environment variable set
# - Terraform installed
#
# Usage: ./validate-modules.sh <gitlab-repo-url> [tag-or-branch]
# Example: ./validate-modules.sh https://gitlab.com/yourgroup/terraform-modules.git v1.0.0
#          ./validate-modules.sh https://gitlab.com/yourgroup/terraform-modules.git main
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

GITLAB_REPO_URL=${1}
TAG_OR_BRANCH=${2:-"main"}

if [ -z "$GITLAB_REPO_URL" ]; then
    log_error "Missing required parameter"
    echo "Usage: $0 <gitlab-repo-url> [tag-or-branch]"
    echo ""
    echo "Examples:"
    echo "  $0 https://gitlab.com/yourgroup/terraform-modules.git v1.0.0"
    echo "  $0 https://gitlab.com/yourgroup/terraform-modules.git main"
    exit 1
fi

# Check if GITLAB_TOKEN is set
if [ -z "$GITLAB_TOKEN" ]; then
    log_error "GITLAB_TOKEN environment variable not set"
    echo ""
    echo "Set your GitLab Personal Access Token:"
    echo "  export GITLAB_TOKEN='your-token-here'"
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    log_error "Terraform is not installed"
    exit 1
fi

TERRAFORM_VERSION=$(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)
log_info "Terraform version: v$TERRAFORM_VERSION"

# ============================================
# Clone Repository
# ============================================

REPO_DIR="/home/jenkins/terraform-modules"

log_step "Step 1: Cloning repository"

# Remove existing directory if exists
if [ -d "$REPO_DIR" ]; then
    log_info "Removing existing directory..."
    rm -rf "$REPO_DIR"
fi

# Inject token into URL
AUTHENTICATED_URL=$(echo "$GITLAB_REPO_URL" | sed "s|https://|https://oauth2:${GITLAB_TOKEN}@|")

log_info "Cloning from: $GITLAB_REPO_URL"
log_info "Checking out: $TAG_OR_BRANCH"

if git clone --branch "$TAG_OR_BRANCH" --depth 1 "$AUTHENTICATED_URL" "$REPO_DIR"; then
    log_info "✓ Repository cloned successfully"
    
    # Remove credentials from git config
    cd "$REPO_DIR"
    git remote set-url origin "$GITLAB_REPO_URL"
    cd ..
else
    log_error "Failed to clone repository"
    exit 1
fi

# ============================================
# Discover Modules
# ============================================

log_step "Step 2: Discovering modules"

cd "$REPO_DIR"

# Find all module directories (directories containing *.tf files)
MODULES=$(find modules -type f -name "*.tf" -exec dirname {} \; | sort -u)

if [ -z "$MODULES" ]; then
    log_error "No Terraform modules found in repository"
    exit 1
fi

MODULE_COUNT=$(echo "$MODULES" | wc -l | tr -d ' ')
log_info "Found $MODULE_COUNT modules:"
echo "$MODULES" | while read module; do
    echo "  - $module"
done

# ============================================
# Validate Modules
# ============================================

log_step "Step 3: Validating modules"

FAILED_MODULES=()
PASSED_MODULES=()
TOTAL_MODULES=0

echo ""
echo "========================================"
echo "Starting validation..."
echo "========================================"
echo ""

for MODULE_PATH in $MODULES; do
    TOTAL_MODULES=$((TOTAL_MODULES + 1))
    MODULE_NAME=$(basename "$MODULE_PATH")
    
    echo "----------------------------------------"
    log_info "Validating: $MODULE_PATH"
    echo "----------------------------------------"
    
    cd "$MODULE_PATH"
    
    # Check 1: Terraform fmt
    log_info "  [1/3] Checking format..."
    if terraform fmt -check -recursive > /dev/null 2>&1; then
        echo -e "    ${GREEN}✓${NC} Format check passed"
    else
        echo -e "    ${YELLOW}⚠${NC} Format check failed (not critical)"
        log_warn "  Module has formatting issues, run: terraform fmt"
    fi
    
    # Check 2: Terraform init
    log_info "  [2/3] Initializing module..."
    if terraform init -backend=false > /dev/null 2>&1; then
        echo -e "    ${GREEN}✓${NC} Initialization successful"
    else
        echo -e "    ${RED}✗${NC} Initialization failed"
        log_error "  Failed to initialize module"
        FAILED_MODULES+=("$MODULE_PATH - Init failed")
        cd - > /dev/null
        cd "$REPO_DIR"
        continue
    fi
    
    # Check 3: Terraform validate
    log_info "  [3/3] Validating configuration..."
    if terraform validate > /dev/null 2>&1; then
        echo -e "    ${GREEN}✓${NC} Validation successful"
        PASSED_MODULES+=("$MODULE_PATH")
    else
        echo -e "    ${RED}✗${NC} Validation failed"
        log_error "  Module validation failed"
        terraform validate
        FAILED_MODULES+=("$MODULE_PATH - Validation failed")
    fi
    
    cd - > /dev/null
    cd "$REPO_DIR"
    echo ""
done

# ============================================
# Generate Report
# ============================================

log_step "Step 4: Generating validation report"

echo ""
echo "========================================"
echo "VALIDATION REPORT"
echo "========================================"
echo ""
echo "Repository: $GITLAB_REPO_URL"
echo "Tag/Branch: $TAG_OR_BRANCH"
echo "Terraform:  v$TERRAFORM_VERSION"
echo "Date:       $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "Summary:"
echo "  Total modules:  $TOTAL_MODULES"
echo "  Passed:         ${#PASSED_MODULES[@]}"
echo "  Failed:         ${#FAILED_MODULES[@]}"
echo ""

if [ ${#PASSED_MODULES[@]} -gt 0 ]; then
    echo -e "${GREEN}Passed Modules:${NC}"
    for module in "${PASSED_MODULES[@]}"; do
        echo "  ✓ $module"
    done
    echo ""
fi

if [ ${#FAILED_MODULES[@]} -gt 0 ]; then
    echo -e "${RED}Failed Modules:${NC}"
    for module in "${FAILED_MODULES[@]}"; do
        echo "  ✗ $module"
    done
    echo ""
fi

echo "========================================"

# Cleanup
cd ..
log_info "Cleaning up temporary directory..."
rm -rf "$REPO_DIR"

# Exit with appropriate code
if [ ${#FAILED_MODULES[@]} -eq 0 ]; then
    echo ""
    log_info "All modules validated successfully! 🎉"
    exit 0
else
    echo ""
    log_error "Validation failed for ${#FAILED_MODULES[@]} module(s)"
    exit 1
fi
