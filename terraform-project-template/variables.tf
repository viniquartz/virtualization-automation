# vSphere Connection
variable "vsphere_server" {
  type = string
}

variable "vsphere_user" {
  type = string
}

variable "vsphere_password" {
  type      = string
  sensitive = true
}

variable "vsphere_allow_unverified_ssl" {
  type    = bool
  default = true
}

# vSphere Infrastructure
variable "vsphere_datacenter" {
  type = string
}

variable "vsphere_cluster" {
  type = string
}

variable "vsphere_datastore" {
  type = string
}

variable "vsphere_network" {
  type = string
}

# Network Configuration
variable "network_domain" {
  type = string
}

variable "network_ipv4_gateway" {
  type = string
}

variable "network_ipv4_netmask" {
  type    = number
  default = 24
}

variable "network_dns_servers" {
  type = list(string)
}

# Linux VM Configuration
variable "linux_vm_name" {
  type = string
}

variable "linux_vm_hostname" {
  type = string
}

variable "linux_cpu_count" {
  type    = number
  default = 2
}

variable "linux_memory_mb" {
  type    = number
  default = 4096
}

variable "linux_disk_size_gb" {
  type    = number
  default = 50
}

variable "linux_template" {
  type = string
}

variable "linux_ipv4_address" {
  type = string
}

# Windows VM Configuration
variable "windows_vm_name" {
  type = string
}

variable "windows_vm_hostname" {
  type = string
}

variable "windows_cpu_count" {
  type    = number
  default = 4
}

variable "windows_memory_mb" {
  type    = number
  default = 8192
}

variable "windows_disk_size_gb" {
  type    = number
  default = 100
}

variable "windows_template" {
  type = string
}

variable "windows_ipv4_address" {
  type = string
}

variable "windows_workgroup" {
  type    = string
  default = "WORKGROUP"
}

variable "windows_admin_password" {
  type      = string
  sensitive = true
}

variable "windows_timezone" {
  type    = number
  default = 65
}
