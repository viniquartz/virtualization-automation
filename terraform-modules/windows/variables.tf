variable "vm_name" {
  type = string
}

variable "vm_hostname" {
  type = string
}

variable "cpu_count" {
  type    = number
  default = 2
}

variable "memory_mb" {
  type    = number
  default = 8192
}

variable "disk_size_gb" {
  type    = number
  default = 100
}

variable "datacenter" {
  type = string
}

variable "cluster" {
  type = string
}

variable "datastore" {
  type = string
}

variable "network" {
  type = string
}

variable "template_name" {
  type = string
}

variable "ipv4_address" {
  type = string
}

variable "ipv4_netmask" {
  type    = number
  default = 24
}

variable "ipv4_gateway" {
  type = string
}

variable "dns_servers" {
  type = list(string)
}

variable "workgroup" {
  type    = string
  default = "WORKGROUP"
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "timezone" {
  type    = number
  default = 65
}
