
# vSphere Connection
vsphere_server               = "vcenter.example.com"
vsphere_user                 = "administrator@vsphere.local"
vsphere_password             = "change-me"
vsphere_allow_unverified_ssl = true

# vSphere Infrastructure
vsphere_datacenter = "DC01"
vsphere_cluster    = "Cluster01"
vsphere_datastore  = "datastore1"
vsphere_network    = "VM Network"

# Network Configuration
network_domain        = "example.com"
network_ipv4_gateway  = "192.168.1.1"
network_ipv4_netmask  = 24
network_dns_servers   = ["192.168.1.10", "192.168.1.11"]

# Linux VM Configuration
linux_vm_name      = "linux-vm-01"
linux_vm_hostname  = "linux-vm-01"
linux_cpu_count    = 2
linux_memory_mb    = 4096
linux_disk_size_gb = 50
linux_template     = "rhel9-template"
linux_ipv4_address = "192.168.1.100"

# Windows VM Configuration
windows_vm_name        = "windows-vm-01"
windows_vm_hostname    = "windows-vm-01"
windows_cpu_count      = 4
windows_memory_mb      = 8192
windows_disk_size_gb   = 100
windows_template       = "win2022-template"
windows_ipv4_address   = "192.168.1.101"
windows_workgroup      = "WORKGROUP"
windows_admin_password = "P@ssw0rd123!"
windows_timezone       = 65
