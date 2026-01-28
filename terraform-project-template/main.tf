# ==============================================================================
# LINUX VM NAMING
# ==============================================================================

module "linux_naming" {
  for_each = local.linux_vms

  source = "git::https://gitlab.tap.pt/digital-infrastructure/virtualizacao/terraform/virtualizacao-terraform-modules.git//naming?ref=v1.0.0"

  purpose         = var.linux_vm_purpose
  environment     = var.environment
  instance_number = each.value.cpd == "cpd1" ? (each.value.sequence * 2 - 1) : (each.value.sequence * 2)
}

# ==============================================================================
# WINDOWS VM NAMING
# ==============================================================================

module "windows_naming" {
  for_each = local.windows_vms

  source = "git::https://gitlab.tap.pt/digital-infrastructure/virtualizacao/terraform/virtualizacao-terraform-modules.git//naming?ref=v1.0.0"

  purpose         = var.windows_vm_purpose
  environment     = var.environment
  instance_number = each.value.cpd == "cpd1" ? (each.value.sequence * 2 - 1) : (each.value.sequence * 2)
}

# ==============================================================================
# LINUX VMs
# ==============================================================================

module "linux_vm" {
  for_each = local.linux_vms

  source = "git::https://gitlab.tap.pt/digital-infrastructure/virtualizacao/terraform/virtualizacao-terraform-modules.git//linux?ref=v1.0.0"

  # Naming from naming module
  vm_name     = module.linux_naming[each.key].vm_name
  vm_hostname = module.linux_naming[each.key].hostname

  # Resources
  cpu_count    = var.linux_cpu_count
  memory_mb    = var.linux_memory_mb
  disk_size_gb = var.linux_disk_size_gb

  # vSphere Infrastructure - derived from CPD
  datacenter = coalesce(var.vsphere_datacenter, local.cpd_config[each.value.cpd].datacenter)
  cluster    = coalesce(var.vsphere_cluster, local.cpd_config[each.value.cpd].cluster)
  datastore  = var.vsphere_datastore
  network    = var.vsphere_network != null ? var.vsphere_network : local.cpd_config[each.value.cpd].network
  guest_id   = var.linux_guest_id
  esx_host   = var.vsphere_esx_host

  # Network Configuration
  domain       = var.network_domain
  ipv4_address = var.linux_ipv4_address
  ipv4_netmask = var.network_ipv4_netmask
  ipv4_gateway = var.network_ipv4_gateway
  dns_servers  = var.network_dns_servers

  # Tags
  tags = merge(local.common_tags, {
    CPD      = upper(each.value.cpd)
    Sequence = each.value.sequence
  })

  # Optional configurations
  vm_folder                  = var.vsphere_folder
  resource_pool              = var.vsphere_resource_pool
  annotation                 = var.linux_annotation
  additional_disks           = var.linux_additional_disks
  wait_for_guest_net_timeout = var.wait_for_guest_net_timeout
  shutdown_wait_timeout      = var.shutdown_wait_timeout
}

# ==============================================================================
# WINDOWS VMs
# ==============================================================================

module "windows_vm" {
  for_each = local.windows_vms

  source = "git::https://gitlab.tap.pt/digital-infrastructure/virtualizacao/terraform/virtualizacao-terraform-modules.git//windows?ref=v1.0.0"

  # Naming from naming module
  vm_name     = module.windows_naming[each.key].vm_name
  vm_hostname = module.windows_naming[each.key].hostname

  # Resources
  cpu_count    = var.windows_cpu_count
  memory_mb    = var.windows_memory_mb
  disk_size_gb = var.windows_disk_size_gb

  # vSphere Infrastructure - derived from CPD
  datacenter = coalesce(var.vsphere_datacenter, local.cpd_config[each.value.cpd].datacenter)
  cluster    = coalesce(var.vsphere_cluster, local.cpd_config[each.value.cpd].cluster)
  datastore  = var.vsphere_datastore
  network    = var.vsphere_network != null ? var.vsphere_network : local.cpd_config[each.value.cpd].network
  guest_id   = var.windows_guest_id
  esx_host   = var.vsphere_esx_host

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
  tags = merge(local.common_tags, {
    CPD      = upper(each.value.cpd)
    Sequence = each.value.sequence
  })

  # Optional configurations
  vm_folder                  = var.vsphere_folder
  resource_pool              = var.vsphere_resource_pool
  annotation                 = var.windows_annotation
  additional_disks           = var.windows_additional_disks
  wait_for_guest_net_timeout = var.wait_for_guest_net_timeout
  shutdown_wait_timeout      = var.shutdown_wait_timeout
}
