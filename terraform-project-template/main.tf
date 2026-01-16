# Linux VM Example
module "linux_vm" {
  source = "../terraform-modules/linux"
  
  vm_name      = var.linux_vm_name
  vm_hostname  = var.linux_vm_hostname
  cpu_count    = var.linux_cpu_count
  memory_mb    = var.linux_memory_mb
  disk_size_gb = var.linux_disk_size_gb
  
  datacenter    = var.vsphere_datacenter
  cluster       = var.vsphere_cluster
  datastore     = var.vsphere_datastore
  network       = var.vsphere_network
  template_name = var.linux_template
  
  domain       = var.network_domain
  ipv4_address = var.linux_ipv4_address
  ipv4_netmask = var.network_ipv4_netmask
  ipv4_gateway = var.network_ipv4_gateway
  dns_servers  = var.network_dns_servers
}

# Windows VM Example
module "windows_vm" {
  source = "../terraform-modules/windows"
  
  vm_name      = var.windows_vm_name
  vm_hostname  = var.windows_vm_hostname
  cpu_count    = var.windows_cpu_count
  memory_mb    = var.windows_memory_mb
  disk_size_gb = var.windows_disk_size_gb
  
  datacenter    = var.vsphere_datacenter
  cluster       = var.vsphere_cluster
  datastore     = var.vsphere_datastore
  network       = var.vsphere_network
  template_name = var.windows_template
  
  ipv4_address   = var.windows_ipv4_address
  ipv4_netmask   = var.network_ipv4_netmask
  ipv4_gateway   = var.network_ipv4_gateway
  dns_servers    = var.network_dns_servers
  workgroup      = var.windows_workgroup
  admin_password = var.windows_admin_password
  timezone       = var.windows_timezone
}
