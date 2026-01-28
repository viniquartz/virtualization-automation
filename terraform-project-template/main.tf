# ==============================================================================
# LOCALS - CPD CONFIGURATION AND MULTI-CPD LOGIC
# ==============================================================================

locals {
  # CPD-based infrastructure configuration
  cpd_config = {
    cpd1 = {
      datacenter = "TAP_CPD1"
      cluster    = "CPD1_ESX7"
      network    = "AUTOMTNPRD (LAN-CPD1)"
    }
    cpd2 = {
      datacenter = "TAP_CPD2"
      cluster    = "CPD2_ESX7"
      network    = "AUTOMTNPRD (LAN-CPD2)"
    }
  }

  # Determine which CPDs to deploy to
  target_cpds = var.cpd == "both" ? ["cpd1", "cpd2"] : [var.cpd]

  # Create map of all Linux VMs to deploy: {key => {cpd, sequence, instance}}
  linux_vms = var.create_linux_vm ? {
    for item in flatten([
      for cpd in local.target_cpds : [
        for idx in range(var.linux_vm_count) : {
          cpd      = cpd
          sequence = var.linux_vm_start_sequence + idx
          vm_index = idx
        }
      ]
    ]) : "${item.cpd}-${item.sequence}" => item
  } : {}

  # Create map of all Windows VMs to deploy: {key => {cpd, sequence, instance}}
  windows_vms = var.create_windows_vm ? {
    for item in flatten([
      for cpd in local.target_cpds : [
        for idx in range(var.windows_vm_count) : {
          cpd      = cpd
          sequence = var.windows_vm_start_sequence + idx
          vm_index = idx
        }
      ]
    ]) : "${item.cpd}-${item.sequence}" => item
  } : {}

  # Common tags
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    Ticket      = var.ticket_id
    ManagedBy   = "Terraform"
  }
}

# ==============================================================================
# LINUX VM NAMING
# ==============================================================================

module "linux_naming" {
  for_each = local.linux_vms

  source = "./terraform-modules/naming"

  purpose         = var.linux_vm_purpose
  environment     = var.environment
  instance_number = each.value.cpd == "cpd1" ? (each.value.sequence * 2 - 1) : (each.value.sequence * 2)
}

# ==============================================================================
# WINDOWS VM NAMING
# ==============================================================================

module "windows_naming" {
  for_each = local.windows_vms

  source = "./terraform-modules/naming"

  purpose         = var.windows_vm_purpose
  environment     = var.environment
  instance_number = each.value.cpd == "cpd1" ? (each.value.sequence * 2 - 1) : (each.value.sequence * 2)
}

# ==============================================================================
# LINUX VMs
# ==============================================================================

module "linux_vm" {
  for_each = local.linux_vms

  source = "./terraform-modules/linux"

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

  source = "./terraform-modules/windows"

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
