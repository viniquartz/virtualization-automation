# ==============================================================================
# TEST ENVIRONMENT CONFIGURATION (TAP CPD1)
# ==============================================================================

environment  = "tst"
project_name = "terraform-test"
ticket_id    = "OPS-1234"

# ==============================================================================
# CPD SELECTION
# Options: "cpd1", "cpd2", or "both"
# - cpd1: Deploy only to CPD1 (odd instances)
# - cpd2: Deploy only to CPD2 (even instances)
# - both: Deploy to BOTH CPD1 and CPD2 (replication)
# ==============================================================================

cpd = "cpd1" # Change to "cpd2" or "both" as needed

# ==============================================================================
# VSPHERE CONNECTION
# NOTE: Credentials are passed via environment variables:
#   export TF_VAR_vsphere_server="vcenterprd01.tapnet.tap.pt"
#   export TF_VAR_vsphere_user="vw_terraform@vsphere.local"
#   export TF_VAR_vsphere_password="your-password"
# ==============================================================================

# These values override environment variables if set
# vsphere_server               = "vcenterprd01.tapnet.tap.pt"
# vsphere_user                 = "vw_terraform@vsphere.local"
# vsphere_password             = "CHANGE-ME"
vsphere_allow_unverified_ssl = true

# ==============================================================================
# VSPHERE INFRASTRUCTURE - OPTIONAL OVERRIDES
# If not set, values are automatically derived from cpd selection:
#   cpd1: TAP_CPD1 / CPD1_ESX7 / AUTOMTNPRD (LAN-CPD1)
#   cpd2: TAP_CPD2 / CPD2_ESX7 / AUTOMTNPRD (LAN-CPD2)
# ==============================================================================

# vsphere_datacenter = "TAP_CPD1"  # Optional override
# vsphere_cluster    = "CPD1_ESX7" # Optional override
vsphere_datastore = "PS04_ESX2_CPDMIG" # Default: PS04_ESX2_CPDMIG
# vsphere_network    = "AUTOMTNPRD (LAN-CPD1)"  # Optional override
vsphere_folder = "TerraformTests" # Default: TerraformTests

# ESXi Host Selection (Optional)
# If not specified, DRS automatically selects host with most resources
# To manually specify: vsphere_esx_host = "esxprd109.tapnet.tap.pt"
# To auto-select best host, use: export TF_VAR_vsphere_esx_host=$(bash scripts/auto-select-esx.sh CPD1_ESX7 TAP_CPD1)
# vsphere_esx_host = "esxprd109.tapnet.tap.pt"

# ==============================================================================
# NETWORK CONFIGURATION (TODO: Configure later)
# ==============================================================================

# network_domain       = "tapnet.tap.pt"
# network_ipv4_gateway = "10.x.x.1"
# network_ipv4_netmask = 24
# network_dns_servers  = ["10.x.x.10", "10.x.x.11"]

# ==============================================================================
# LINUX VM CONFIGURATION
# 
# Focus: CPU, Memory, Disk only
# Network and IP configuration will be done later
#
# Examples:
# - Single VM in CPD1:
#   cpd=cpd1, linux_vm_count=1, start_sequence=1 → IACTST01
# 
# - Two VMs in CPD1:
#   cpd=cpd1, linux_vm_count=2, start_sequence=1 → IACTST01, IACTST03
# 
# - Single VM replicated in both CPDs:
#   cpd=both, linux_vm_count=1, start_sequence=1 → IACTST01 (CPD1) + IACTST02 (CPD2)
# ==============================================================================

create_linux_vm         = true
linux_vm_purpose        = "iac" # 3 chars: iac, web, app, db, srv
linux_vm_count          = 1     # Number of VMs to create per CPD
linux_vm_start_sequence = 1     # Starting sequence (1, 2, 3...)

# RESOURCES - Configure here
linux_cpu_count    = 1    # CPU cores (1-32)
linux_memory_mb    = 2048 # RAM in MB (1024-131072)
linux_disk_size_gb = 16   # Disk in GB (min 10GB)

linux_guest_id = "rhel9_64Guest" # No template - create from scratch

# Network (TODO: Configure later)
# linux_ipv4_address = "10.x.x.10"

# Additional Disks (Optional)
# Example:
# linux_additional_disks = [
#   {
#     label       = "data"
#     size_gb     = 100
#     unit_number = 1
#   },
#   {
#     label       = "logs"
#     size_gb     = 50
#     unit_number = 2
#   }
# ]

# ==============================================================================
# WINDOWS VM CONFIGURATION
# 
# Focus: CPU, Memory, Disk only
# Network and IP configuration will be done later
#
# Examples:
# - Single VM in CPD2:
#   cpd=cpd2, windows_vm_count=1, start_sequence=1 → SRVTST02
# 
# - Three VMs in CPD1:
#   cpd=cpd1, windows_vm_count=3, start_sequence=1 → SRVTST01, SRVTST03, SRVTST05
# ==============================================================================

create_windows_vm         = false # Disabled for initial test
windows_vm_purpose        = "srv" # 3 chars: srv, app, db, web
windows_vm_count          = 1     # Number of VMs to create per CPD
windows_vm_start_sequence = 1     # Starting sequence (1, 2, 3...)

# RESOURCES - Configure here
windows_cpu_count    = 4    # CPU cores (1-32)
windows_memory_mb    = 8192 # RAM in MB (2048-131072)
windows_disk_size_gb = 100  # Disk in GB (min 40GB for Windows)

windows_guest_id       = "windows2019srvNext_64Guest" # No template - create from scratch
windows_workgroup      = "WORKGROUP"
windows_admin_password = "ChangeMe123!@#Test"
windows_timezone       = 65

# Network (TODO: Configure later)
# windows_ipv4_address = "10.x.x.20"
