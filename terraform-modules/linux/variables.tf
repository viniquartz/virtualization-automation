# ==============================================================================
# VM CONFIGURATION
# ==============================================================================

variable "vm_name" {
  description = "Name of the virtual machine in vSphere inventory"
  type        = string
}

variable "vm_hostname" {
  description = "Hostname to be configured inside the guest OS"
  type        = string
}

variable "cpu_count" {
  description = "Number of vCPUs to allocate to the VM"
  type        = number
  default     = 2

  validation {
    condition     = var.cpu_count >= var.cpu_min && var.cpu_count <= var.cpu_max
    error_message = "CPU count must be between ${var.cpu_min} and ${var.cpu_max}"
  }
}

variable "memory_mb" {
  description = "Amount of memory in MB to allocate to the VM"
  type        = number
  default     = 4096

  validation {
    condition     = var.memory_mb >= var.memory_min && var.memory_mb <= var.memory_max
    error_message = "Memory must be between ${var.memory_min}MB and ${var.memory_max}MB"
  }
}

variable "disk_size_gb" {
  description = "Size of the primary OS disk in GB"
  type        = number
  default     = 50

  validation {
    condition     = var.disk_size_gb >= var.disk_min
    error_message = "Disk size must be at least ${var.disk_min}GB"
  }
}

# ==============================================================================
# VSPHERE INFRASTRUCTURE
# ==============================================================================

variable "datacenter" {
  description = "vSphere datacenter name where VM will be deployed"
  type        = string
}

variable "cluster" {
  description = "vSphere cluster name where VM will be deployed"
  type        = string
}

variable "esx_host" {
  description = "Optional specific ESXi host for VM placement (e.g., esxprd109.tapnet.tap.pt). If not specified, DRS will select automatically."
  type        = string
  default     = null
}

variable "datastore" {
  description = "vSphere datastore name for VM storage"
  type        = string
}

variable "network" {
  description = "vSphere network/portgroup name for primary NIC"
  type        = string
}

variable "guest_id" {
  description = "Guest OS identifier (e.g., rhel9_64Guest, centos8_64Guest)"
  type        = string
  default     = "rhel9_64Guest"
}

variable "network_adapter_type" {
  description = "Network adapter type (vmxnet3, e1000e, e1000)"
  type        = string
  default     = "vmxnet3"
}

# ==============================================================================
# NETWORK CONFIGURATION
# ==============================================================================

variable "domain" {
  description = "DNS domain name for the VM"
  type        = string
}

variable "ipv4_address" {
  description = "Static IPv4 address for the VM"
  type        = string

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.ipv4_address))
    error_message = "IPv4 address must be in valid format (e.g., 192.168.1.10)"
  }
}

variable "ipv4_netmask" {
  description = "IPv4 network prefix length (e.g., 24 for /24)"
  type        = number
  default     = 24

  validation {
    condition     = var.ipv4_netmask >= 8 && var.ipv4_netmask <= 30
    error_message = "Netmask must be between 8 and 30"
  }
}

variable "ipv4_gateway" {
  description = "IPv4 default gateway address"
  type        = string

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.ipv4_gateway))
    error_message = "Gateway must be in valid IPv4 format"
  }
}

variable "dns_servers" {
  description = "List of DNS server addresses"
  type        = list(string)

  validation {
    condition     = length(var.dns_servers) > 0 && length(var.dns_servers) <= 3
    error_message = "Must provide 1-3 DNS servers"
  }
}

# ==============================================================================
# RESOURCE LIMITS
# ==============================================================================

variable "cpu_min" {
  description = "Minimum allowed CPU count"
  type        = number
  default     = 1
}

variable "cpu_max" {
  description = "Maximum allowed CPU count"
  type        = number
  default     = 32
}

variable "memory_min" {
  description = "Minimum allowed memory in MB"
  type        = number
  default     = 1024
}

variable "memory_max" {
  description = "Maximum allowed memory in MB"
  type        = number
  default     = 131072 # 128GB
}

variable "disk_min" {
  description = "Minimum allowed disk size in GB"
  type        = number
  default     = 20
}

# ==============================================================================
# TAGS
# ==============================================================================

variable "tags" {
  description = "Additional tags/attributes to apply to the VM (merged with common_tags)"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# OPTIONAL CONFIGURATIONS
# ==============================================================================

variable "vm_folder" {
  description = "Optional vSphere folder path for VM organization (e.g., /Datacenter/vm/Linux/Production)"
  type        = string
  default     = null
}

variable "resource_pool" {
  description = "Optional resource pool name within the cluster"
  type        = string
  default     = null
}

variable "annotation" {
  description = "Optional VM annotation/notes visible in vSphere"
  type        = string
  default     = ""
}

variable "additional_disks" {
  description = "List of additional disks to attach to the VM"
  type = list(object({
    label       = string
    size_gb     = number
    unit_number = number
  }))
  default = []

  validation {
    condition     = alltrue([for disk in var.additional_disks : disk.size_gb >= var.disk_min])
    error_message = "All additional disks must be at least ${var.disk_min}GB"
  }
}

variable "enable_disk_thin_provisioning" {
  description = "Enable thin provisioning for VM disks"
  type        = bool
  default     = true
}

variable "wait_for_guest_net_timeout" {
  description = "Timeout in minutes to wait for guest network"
  type        = number
  default     = 5

  validation {
    condition     = var.wait_for_guest_net_timeout >= 0 && var.wait_for_guest_net_timeout <= 30
    error_message = "Timeout must be between 0 and 30 minutes"
  }
}

variable "shutdown_wait_timeout" {
  description = "Timeout in minutes to wait for VM to gracefully shutdown"
  type        = number
  default     = 3

  validation {
    condition     = var.shutdown_wait_timeout >= 1 && var.shutdown_wait_timeout <= 10
    error_message = "Shutdown timeout must be between 1 and 10 minutes"
  }
}
