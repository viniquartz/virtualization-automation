# ==============================================================================
# BASIC VM INFORMATION
# ==============================================================================

output "vm_id" {
  description = "vSphere VM managed object reference ID"
  value       = vsphere_virtual_machine.vm.id
}

output "vm_name" {
  description = "VM name in vSphere inventory"
  value       = vsphere_virtual_machine.vm.name
}

output "vm_uuid" {
  description = "VM universally unique identifier"
  value       = vsphere_virtual_machine.vm.uuid
}

# ==============================================================================
# NETWORK INFORMATION
# ==============================================================================

output "vm_ip" {
  description = "VM primary IP address"
  value       = vsphere_virtual_machine.vm.default_ip_address
}

output "vm_guest_ip_addresses" {
  description = "List of all guest IP addresses"
  value       = vsphere_virtual_machine.vm.guest_ip_addresses
}

output "vm_hostname" {
  description = "VM guest hostname"
  value       = var.vm_hostname
}

# ==============================================================================
# VM STATE
# ==============================================================================

output "vm_power_state" {
  description = "VM power state"
  value       = vsphere_virtual_machine.vm.power_state
}

output "vmware_tools_status" {
  description = "VMware Tools running status"
  value       = vsphere_virtual_machine.vm.vmware_tools_status
}

# ==============================================================================
# RESOURCE INFORMATION
# ==============================================================================

output "vm_cpu_count" {
  description = "Number of vCPUs allocated"
  value       = vsphere_virtual_machine.vm.num_cpus
}

output "vm_memory_mb" {
  description = "Memory allocated in MB"
  value       = vsphere_virtual_machine.vm.memory
}

output "vm_disk_size_gb" {
  description = "Primary disk size in GB"
  value       = var.disk_size_gb
}

# ==============================================================================
# VSPHERE PLACEMENT
# ==============================================================================

output "vm_moid" {
  description = "VM managed object ID"
  value       = vsphere_virtual_machine.vm.moid
}

output "vm_datastore" {
  description = "Datastore where VM is located"
  value       = var.datastore
}

output "vm_folder" {
  description = "vSphere folder path"
  value       = var.vm_folder
}

# ==============================================================================
# TAGS
# ==============================================================================

output "vm_tags" {
  description = "Tags applied to the VM"
  value       = local.all_tags
}
