#!/bin/bash
#
# Script: auto-select-esx.sh
# Purpose: Automatically select best ESXi host and export for Terraform
#
# Usage: 
#   source scripts/auto-select-esx.sh CPD1_ESX7 TAP_CPD1
#   or
#   export TF_VAR_vsphere_esx_host=$(bash scripts/auto-select-esx.sh CPD1_ESX7 TAP_CPD1)
#
# Prerequisites:
#   - Python 3 with pyvmomi installed: pip3 install pyvmomi
#   - vSphere credentials exported (TF_VAR_vsphere_*)
#

set -e

CLUSTER=${1:-"CPD1_ESX7"}
DATACENTER=${2:-"TAP_CPD1"}
METRIC=${3:-"balanced"}  # cpu, memory, or balanced

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

# Check if Python script exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/select-best-esx-host.py"

if [ ! -f "$PYTHON_SCRIPT" ]; then
    log_warn "Python script not found: $PYTHON_SCRIPT"
    log_warn "Skipping ESXi host selection - DRS will handle placement"
    echo ""
    exit 0
fi

# Check if pyvmomi is installed
if ! python3 -c "import pyVim" 2>/dev/null; then
    log_warn "pyvmomi not installed. Install with: pip3 install pyvmomi"
    log_warn "Skipping ESXi host selection - DRS will handle placement"
    echo ""
    exit 0
fi

# Check vSphere credentials
if [ -z "$TF_VAR_vsphere_server" ] || [ -z "$TF_VAR_vsphere_user" ] || [ -z "$TF_VAR_vsphere_password" ]; then
    log_warn "vSphere credentials not set. Skipping ESXi host selection."
    echo ""
    exit 0
fi

log_info "Querying ESXi hosts in cluster: $CLUSTER (Datacenter: $DATACENTER)"
log_info "Selection metric: $METRIC"

# Run Python script
BEST_HOST=$(python3 "$PYTHON_SCRIPT" \
    --datacenter "$DATACENTER" \
    --cluster "$CLUSTER" \
    --metric "$METRIC" \
    --format fqdn)

if [ -n "$BEST_HOST" ]; then
    log_info "Selected ESXi host: $BEST_HOST"
    echo "$BEST_HOST"
else
    log_warn "Failed to select ESXi host - DRS will handle placement"
    echo ""
fi
