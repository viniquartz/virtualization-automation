# ==============================================================================
# PROJECT VARIABLES
# ==============================================================================

variable "environment" {
  description = "Environment: prd, qlt or tst"
  type        = string

  validation {
    condition     = contains(["prd", "qlt", "tst"], var.environment)
    error_message = "Environment must be: prd, qlt or tst"
  }
}

variable "project_name" {
  description = "Project name (lowercase, numbers and hyphens)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Name must contain only: a-z, 0-9 and -"
  }
}

variable "ticket_id" {
  description = "JIRA ticket ID (e.g., OPS-1234)"
  type        = string

  validation {
    condition     = can(regex("^[A-Z]+-[0-9]+$", var.ticket_id))
    error_message = "Ticket ID must match format: ABC-123"
  }
}

# ==============================================================================
# VSPHERE CONNECTION
# ==============================================================================

variable "cpd" {
  description = "CPD selection: cpd1, cpd2, or both (both creates VMs in both datacenters)"
  type        = string

  validation {
    condition     = contains(["cpd1", "cpd2", "both"], var.cpd)
    error_message = "CPD must be: cpd1, cpd2, or both"
  }
}

variable "vsphere_server" {
  description = "vSphere server address"
  type        = string
}

variable "vsphere_user" {
  description = "vSphere username"
  type        = string
}

variable "vsphere_password" {
  description = "vSphere password"
  type        = string
  sensitive   = true
}

variable "vsphere_allow_unverified_ssl" {
  description = "Allow unverified SSL certificates"
  type        = bool
  default     = true
}

# ==============================================================================
# VSPHERE INFRASTRUCTURE
# ==============================================================================

variable "vsphere_datacenter" {
  description = "vSphere datacenter name (optional, derived from cpd if not set)"
  type        = string
  default     = null
}

variable "vsphere_cluster" {
  description = "vSphere cluster name (optional, derived from cpd if not set)"
  type        = string
  default     = null
}

variable "vsphere_datastore" {
  description = "vSphere datastore name"
  type        = string
  default     = "PS04_ESX2_CPDMIG" # Default from TAP standard
}

variable "vsphere_network" {
  description = "vSphere network/portgroup name (optional, derived from cpd if not set)"
  type        = string
  default     = null
}

variable "vsphere_folder" {
  description = "vSphere VM folder path"
  type        = string
  default     = "TerraformTests" # Default from TAP standard
}

variable "vsphere_resource_pool" {
  description = "Optional vSphere resource pool name"
  type        = string
  default     = null
}

variable "vsphere_esx_host" {
  description = "Optional specific ESXi host for VM placement (e.g., esxprd109.tapnet.tap.pt). If not specified, DRS will automatically select the best host based on available resources."
  type        = string
  default     = null
}

# ==============================================================================
# NETWORK CONFIGURATION
# ==============================================================================

variable "network_domain" {
  description = "DNS domain name"
  type        = string
}

variable "network_ipv4_gateway" {
  description = "IPv4 default gateway"
  type        = string
}

variable "network_ipv4_netmask" {
  description = "IPv4 network prefix length"
  type        = number
  default     = 24
}

variable "network_dns_servers" {
  description = "List of DNS servers"
  type        = list(string)
}

# ==============================================================================
# LINUX VM CONFIGURATION
# ==============================================================================

variable "create_linux_vm" {
  description = "Create Linux VM"
  type        = bool
  default     = true
}

variable "linux_vm_purpose" {
  description = "Linux VM purpose for naming (e.g., web, app, db)"
  type        = string
  default     = "linux"
}

variable "linux_vm_count" {
  description = "Number of Linux VMs to create (1-10)"
  type        = number
  default     = 1

  validation {
    condition     = var.linux_vm_count >= 1 && var.linux_vm_count <= 10
    error_message = "VM count must be between 1 and 10"
  }
}

variable "linux_vm_start_sequence" {
  description = "Starting sequence number for Linux VMs (default: 1)"
  type        = number
  default     = 1

  validation {
    condition     = var.linux_vm_start_sequence >= 1 && var.linux_vm_start_sequence <= 90
    error_message = "Start sequence must be between 1 and 90"
  }
}

variable "linux_cpu_count" {
  description = "Linux VM vCPU count"
  type        = number
  default     = 2
}

variable "linux_memory_mb" {
  description = "Linux VM memory in MB"
  type        = number
  default     = 4096
}

variable "linux_disk_size_gb" {
  description = "Linux VM primary disk size in GB"
  type        = number
  default     = 50
}

variable "linux_guest_id" {
  description = "Linux guest OS identifier (e.g., rhel9_64Guest, centos8_64Guest)"
  type        = string
  default     = "rhel9_64Guest"
}

variable "linux_ipv4_address" {
  description = "Linux VM IPv4 address"
  type        = string
}

variable "linux_annotation" {
  description = "Linux VM annotation"
  type        = string
  default     = ""
}

variable "linux_additional_disks" {
  description = "Additional disks for Linux VM"
  type = list(object({
    label       = string
    size_gb     = number
    unit_number = number
  }))
  default = []
}

# ==============================================================================
# WINDOWS VM CONFIGURATION
# ==============================================================================

variable "create_windows_vm" {
  description = "Create Windows VM"
  type        = bool
  default     = true
}

variable "windows_vm_purpose" {
  description = "Windows VM purpose for naming (e.g., web, app, db)"
  type        = string
  default     = "win"
}

variable "windows_vm_count" {
  description = "Number of Windows VMs to create (1-10)"
  type        = number
  default     = 1

  validation {
    condition     = var.windows_vm_count >= 1 && var.windows_vm_count <= 10
    error_message = "VM count must be between 1 and 10"
  }
}

variable "windows_vm_start_sequence" {
  description = "Starting sequence number for Windows VMs (default: 1)"
  type        = number
  default     = 1

  validation {
    condition     = var.windows_vm_start_sequence >= 1 && var.windows_vm_start_sequence <= 90
    error_message = "Start sequence must be between 1 and 90"
  }
}

variable "windows_cpu_count" {
  description = "Windows VM vCPU count"
  type        = number
  default     = 4
}

variable "windows_memory_mb" {
  description = "Windows VM memory in MB"
  type        = number
  default     = 8192
}

variable "windows_disk_size_gb" {
  description = "Windows VM primary disk size in GB"
  type        = number
  default     = 100
}

variable "windows_guest_id" {
  description = "Windows guest OS identifier (e.g., windows2019srvNext_64Guest, windows2022srvNext_64Guest)"
  type        = string
  default     = "windows2019srvNext_64Guest"
}

variable "windows_ipv4_address" {
  description = "Windows VM IPv4 address"
  type        = string
}

variable "windows_workgroup" {
  description = "Windows workgroup name"
  type        = string
  default     = "WORKGROUP"
}

variable "windows_admin_password" {
  description = "Windows Administrator password"
  type        = string
  sensitive   = true
}

variable "windows_timezone" {
  description = "Windows timezone ID"
  type        = number
  default     = 65
}

variable "windows_auto_logon" {
  description = "Enable Windows auto-logon"
  type        = bool
  default     = false
}

variable "windows_annotation" {
  description = "Windows VM annotation"
  type        = string
  default     = ""
}

variable "windows_additional_disks" {
  description = "Additional disks for Windows VM"
  type = list(object({
    label       = string
    size_gb     = number
    unit_number = number
  }))
  default = []
}

# ==============================================================================
# TIMEOUTS AND ADVANCED OPTIONS
# ==============================================================================

variable "wait_for_guest_net_timeout" {
  description = "Timeout in minutes to wait for guest network"
  type        = number
  default     = 5
}

variable "shutdown_wait_timeout" {
  description = "Timeout in minutes to wait for VM shutdown"
  type        = number
  default     = 3
}
