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
  description = "vSphere datacenter name"
  type        = string
}

variable "vsphere_cluster" {
  description = "vSphere cluster name"
  type        = string
}

variable "vsphere_datastore" {
  description = "vSphere datastore name"
  type        = string
}

variable "vsphere_network" {
  description = "vSphere network/portgroup name"
  type        = string
}

variable "vsphere_resource_pool" {
  description = "Optional vSphere resource pool name"
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

variable "linux_vm_purpose" {
  description = "Linux VM purpose for naming (e.g., web, app, db)"
  type        = string
  default     = "linux"
}

variable "linux_instance_number" {
  description = "Linux VM instance number"
  type        = number
  default     = 1
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

variable "linux_template" {
  description = "Linux template name"
  type        = string
}

variable "linux_ipv4_address" {
  description = "Linux VM IPv4 address"
  type        = string
}

variable "linux_vm_folder" {
  description = "Linux VM vSphere folder path"
  type        = string
  default     = null
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

variable "windows_vm_purpose" {
  description = "Windows VM purpose for naming (e.g., web, app, db)"
  type        = string
  default     = "win"
}

variable "windows_instance_number" {
  description = "Windows VM instance number"
  type        = number
  default     = 1
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

variable "windows_template" {
  description = "Windows template name"
  type        = string
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

variable "windows_vm_folder" {
  description = "Windows VM vSphere folder path"
  type        = string
  default     = null
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
