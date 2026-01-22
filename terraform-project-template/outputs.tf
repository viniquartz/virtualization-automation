# Linux VM Outputs
output "linux_vm_id" {
  description = "Linux VM ID"
  value       = var.create_linux_vm ? module.linux_vm[0].vm_id : null
}

output "linux_vm_name" {
  description = "Linux VM name"
  value       = var.create_linux_vm ? module.linux_vm[0].vm_name : null
}

output "linux_vm_ip" {
  description = "Linux VM IP address"
  value       = var.create_linux_vm ? module.linux_vm[0].vm_ip : null
}

output "linux_vm_uuid" {
  description = "Linux VM UUID"
  value       = var.create_linux_vm ? module.linux_vm[0].vm_uuid : null
}

# Windows VM Outputs
output "windows_vm_id" {
  description = "Windows VM ID"
  value       = var.create_windows_vm ? module.windows_vm[0].vm_id : null
}

output "windows_vm_name" {
  description = "Windows VM name"
  value       = var.create_windows_vm ? module.windows_vm[0].vm_name : null
}

output "windows_vm_ip" {
  description = "Windows VM IP address"
  value       = var.create_windows_vm ? module.windows_vm[0].vm_ip : null
}

output "windows_vm_uuid" {
  description = "Windows VM UUID"
  value       = var.create_windows_vm ? module.windows_vm[0].vm_uuid : null
}
