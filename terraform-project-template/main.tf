# ==============================================================================
# VM NAMING
# ==============================================================================

module "linux_naming" {
  source = "../terraform-modules/naming"

  purpose         = var.linux_vm_purpose
  environment     = var.environment
  instance_number = var.linux_instance_number
}

module "windows_naming" {
  source = "../terraform-modules/naming"

  purpose         = var.windows_vm_purpose
  environment     = var.environment
  instance_number = var.windows_instance_number
}

# ==============================================================================
# LINUX VM
# ==============================================================================

module "linux_vm" {
  source = "../terraform-modules/linux"

  # Naming from naming module
  vm_name     = module.linux_naming.vm_name
  vm_hostname = module.linux_naming.hostname

  # Resources
  cpu_count    = var.linux_cpu_count
  memory_mb    = var.linux_memory_mb
  disk_size_gb = var.linux_disk_size_gb

  # vSphere Infrastructure
  datacenter    = var.vsphere_datacenter
  cluster       = var.vsphere_cluster
  datastore     = var.vsphere_datastore
  network       = var.vsphere_network
  template_name = var.linux_template

  # Network Configuration
  domain       = var.network_domain
  ipv4_address = var.linux_ipv4_address
  ipv4_netmask = var.network_ipv4_netmask
  ipv4_gateway = var.network_ipv4_gateway
  dns_servers  = var.network_dns_servers

  # Tags
  tags = local.common_tags

  # Optional configurations
  vm_folder                  = var.linux_vm_folder
  resource_pool              = var.vsphere_resource_pool
  annotation                 = var.linux_annotation
  additional_disks           = var.linux_additional_disks
  wait_for_guest_net_timeout = var.wait_for_guest_net_timeout
  shutdown_wait_timeout      = var.shutdown_wait_timeout
}

# ==============================================================================
# WINDOWS VM
# ==============================================================================

module "windows_vm" {
  source = "../terraform-modules/windows"

  # Naming from naming module
  vm_name     = module.windows_naming.vm_name
  vm_hostname = module.windows_naming.hostname

  # Resources
  cpu_count    = var.windows_cpu_count
  memory_mb    = var.windows_memory_mb
  disk_size_gb = var.windows_disk_size_gb

  # vSphere Infrastructure
  datacenter    = var.vsphere_datacenter
  cluster       = var.vsphere_cluster
  datastore     = var.vsphere_datastore
  network       = var.vsphere_network
  template_name = var.windows_template

  # Network Configuration
  domain       = var.network_domain
  ipv4_address = var.windows_ipv4_address
  ipv4_netmask = var.network_ipv4_netmask
  ipv4_gateway = var.network_ipv4_gateway
  dns_servers  = var.network_dns_servers

  # Windows Specific
  workgroup      = var.windows_workgroup
  admin_password = var.windows_admin_password
  timezone       = var.windows_timezone
  auto_logon     = var.windows_auto_logon

  # Tags
  tags = local.common_tags

  # Optional configurations
  vm_folder                  = var.windows_vm_folder
  resource_pool              = var.vsphere_resource_pool
  annotation                 = var.windows_annotation
  additional_disks           = var.windows_additional_disks
  wait_for_guest_net_timeout = var.wait_for_guest_net_timeout
  shutdown_wait_timeout      = var.shutdown_wait_timeout
}
