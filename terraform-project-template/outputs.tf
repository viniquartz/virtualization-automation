# ==============================================================================
# LINUX VMs OUTPUTS
# ==============================================================================

output "linux_vms" {
  description = "Linux VMs details"
  value = {
    for key, vm in module.linux_vm : key => {
      vm_id       = vm.vm_id
      vm_name     = vm.vm_name
      vm_ip       = vm.vm_ip
      vm_uuid     = vm.vm_uuid
      vm_hostname = vm.vm_hostname
      cpd         = local.linux_vms[key].cpd
      sequence    = local.linux_vms[key].sequence
    }
  }
}

output "linux_vm_count" {
  description = "Total number of Linux VMs created"
  value       = length(module.linux_vm)
}

# ==============================================================================
# WINDOWS VMs OUTPUTS
# ==============================================================================

output "windows_vms" {
  description = "Windows VMs details"
  value = {
    for key, vm in module.windows_vm : key => {
      vm_id       = vm.vm_id
      vm_name     = vm.vm_name
      vm_ip       = vm.vm_ip
      vm_uuid     = vm.vm_uuid
      vm_hostname = vm.vm_hostname
      cpd         = local.windows_vms[key].cpd
      sequence    = local.windows_vms[key].sequence
    }
  }
}

output "windows_vm_count" {
  description = "Total number of Windows VMs created"
  value       = length(module.windows_vm)
}

# ==============================================================================
# SUMMARY OUTPUT
# ==============================================================================

output "deployment_summary" {
  description = "Deployment summary"
  value = {
    environment   = var.environment
    ticket_id     = var.ticket_id
    cpd_selection = var.cpd
    linux_vms     = length(module.linux_vm)
    windows_vms   = length(module.windows_vm)
    total_vms     = length(module.linux_vm) + length(module.windows_vm)
  }
}
