#!/bin/bash
#
# Script: validate-modules.sh
# Purpose: Validate all Terraform modules in terraform-modules directory
#
# What it does:
# - Clones terraform modules repository (with specific tag/branch)
# - Validates all modules independently
# - Checks for syntax errors, formatting issues
# - Generates validation report
#
# Prerequisites:
# - Terraform installed
# - Git access to repository
#
# Usage: ./validate-modules.sh <git-repo-url> [tag-or-branch]
# Example: ./validate-modules.sh https://github.com/yourorg/virtualization-automation.git main
#          ./validate-modules.sh https://github.com/yourorg/virtualization-automation.git v1.0.0
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

GIT_REPO_URL=${1}
TAG_OR_BRANCH=${2:-"main"}

if [ -z "$GIT_REPO_URL" ]; then
    log_error "Missing required parameter"
    echo "Usage: $0 <git-repo-url> [tag-or-branch]"
    echo ""
    echo "Examples:"
    echo "  $0 https://github.com/yourorg/virtualization-automation.git main"
    echo "  $0 https://github.com/yourorg/virtualization-automation.git v1.0.0"
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

# ============================================
# Clone Repository
# ============================================

REPO_DIR="terraform-modules-validation"

log_step "Step 1: Cloning repository"

# Remove existing directory if exists
if [ -d "$REPO_DIR" ]; then
    log_info "Removing existing directory..."
    rm -rf "$REPO_DIR"
fi

log_info "Cloning from: $GIT_REPO_URL"
log_info "Checking out: $TAG_OR_BRANCH"

if git clone --branch "$TAG_OR_BRANCH" --depth 1 "$GIT_REPO_URL" "$REPO_DIR" 2>&1; then
    log_info "✓ Repository cloned successfully"
else
    log_error "Failed to clone repository"
    echo ""
    echo "Possible causes:"
    echo "  1. Repository URL is incorrect"
    echo "  2. Branch/tag does not exist"
    echo "  3. No access to repository"
    echo "  4. Network connectivity issues"
    exit 1
fi

# ============================================
# Discover Modules
# ============================================

log_step "Step 2: Discovering modules"

cd "$REPO_DIR"

# Find all module directories in terraform-modules/
MODULES=""
if [ -d "terraform-modules" ]; then
    # Find directories containing main.tf
    MODULES=$(find terraform-modules -type f -name "main.tf" -exec dirname {} \; | sort -u)
fi

if [ -z "$MODULES" ]; then
    log_error "No Terraform modules found in repository"
    echo ""
    echo "Expected structure:"
    echo "  terraform-modules/"
    echo "  ├── naming/"
    echo "  │   └── main.tf"
    echo "  ├── linux/"
    echo "  │   └── main.tf"
    echo "  └── windows/"
    echo "      └── main.tf"
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
WARNING_MODULES=()
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
    
    cd "$MODULE_PATH" || continue
    
    HAS_WARNINGS=false
    HAS_ERRORS=false
    
    # Check 1: Terraform fmt
    log_info "  [1/4] Checking format..."
    if terraform fmt -check -recursive > /dev/null 2>&1; then
        echo -e "    ${GREEN}✓${NC} Format check passed"
    else
        echo -e "    ${YELLOW}⚠${NC} Format check failed (not critical)"
        log_warn "  Module has formatting issues, run: terraform fmt"
        HAS_WARNINGS=true
    fi
    
    # Check 2: Check for README.md
    log_info "  [2/4] Checking documentation..."
    if [ -f "README.md" ]; then
        echo -e "    ${GREEN}✓${NC} README.md found"
    else
        echo -e "    ${YELLOW}⚠${NC} README.md not found (recommended)"
        HAS_WARNINGS=true
    fi
    
    # Check 3: Terraform init
    log_info "  [3/4] Initializing module..."
    if terraform init -backend=false > /dev/null 2>&1; then
        echo -e "    ${GREEN}✓${NC} Initialization successful"
    else
        echo -e "    ${RED}✗${NC} Initialization failed"
        log_error "  Failed to initialize module"
        FAILED_MODULES+=("$MODULE_PATH - Init failed")
        HAS_ERRORS=true
        cd - > /dev/null
        cd "$REPO_DIR"
        continue
    fi
    
    # Check 4: Terraform validate
    log_info "  [4/4] Validating configuration..."
    if terraform validate > /dev/null 2>&1; then
        echo -e "    ${GREEN}✓${NC} Validation successful"
    else
        echo -e "    ${RED}✗${NC} Validation failed"
        log_error "  Module validation failed"
        terraform validate
        FAILED_MODULES+=("$MODULE_PATH - Validation failed")
        HAS_ERRORS=true
    fi
    
    # Categorize module
    if [ "$HAS_ERRORS" = true ]; then
        # Already added to FAILED_MODULES
        :
    elif [ "$HAS_WARNINGS" = true ]; then
        WARNING_MODULES+=("$MODULE_PATH")
    else
        PASSED_MODULES+=("$MODULE_PATH")
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
echo "Repository: $GIT_REPO_URL"
echo "Tag/Branch: $TAG_OR_BRANCH"
echo "Terraform:  v$TERRAFORM_VERSION"
echo "Date:       $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "Summary:"
echo "  Total modules:     $TOTAL_MODULES"
echo "  Passed:            ${#PASSED_MODULES[@]}"
echo "  Passed (warnings): ${#WARNING_MODULES[@]}"
echo "  Failed:            ${#FAILED_MODULES[@]}"
echo ""

if [ ${#PASSED_MODULES[@]} -gt 0 ]; then
    echo -e "${GREEN}✓ Passed Modules (No Issues):${NC}"
    for module in "${PASSED_MODULES[@]}"; do
        echo "  ✓ $module"
    done
    echo ""
fi

if [ ${#WARNING_MODULES[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠ Passed Modules (With Warnings):${NC}"
    for module in "${WARNING_MODULES[@]}"; do
        echo "  ⚠ $module"
    done
    echo ""
fi

if [ ${#FAILED_MODULES[@]} -gt 0 ]; then
    echo -e "${RED}✗ Failed Modules:${NC}"
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
    if [ ${#WARNING_MODULES[@]} -eq 0 ]; then
        log_info "All modules validated successfully! 🎉"
    else
        log_info "All modules validated successfully (with ${#WARNING_MODULES[@]} warnings)"
    fi
    exit 0
else
    echo ""
    log_error "Validation failed for ${#FAILED_MODULES[@]} module(s)"
    exit 1
fi
