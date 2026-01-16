# Linux VM Outputs
output "linux_vm_id" {
  description = "Linux VM ID"
  value       = module.linux_vm.vm_id
}

output "linux_vm_name" {
  description = "Linux VM name"
  value       = module.linux_vm.vm_name
}

output "linux_vm_ip" {
  description = "Linux VM IP address"
  value       = module.linux_vm.vm_ip
}

output "linux_vm_uuid" {
  description = "Linux VM UUID"
  value       = module.linux_vm.vm_uuid
}

# Windows VM Outputs
output "windows_vm_id" {
  description = "Windows VM ID"
  value       = module.windows_vm.vm_id
}

output "windows_vm_name" {
  description = "Windows VM name"
  value       = module.windows_vm.vm_name
}

output "windows_vm_ip" {
  description = "Windows VM IP address"
  value       = module.windows_vm.vm_ip
}

output "windows_vm_uuid" {
  description = "Windows VM UUID"
  value       = module.windows_vm.vm_uuid
}
