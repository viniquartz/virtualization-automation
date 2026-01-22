# ==============================================================================
# TEST ENVIRONMENT CONFIGURATION
# ==============================================================================

environment  = "tst"
project_name = "vmware-test"
ticket_id    = "OPS-1234"

# ==============================================================================
# VSPHERE CONNECTION
# ==============================================================================

vsphere_server               = "vcenter-test.example.com"
vsphere_user                 = "svc-terraform-tst@vsphere.local"
vsphere_password             = "change-me"
vsphere_allow_unverified_ssl = true

# ==============================================================================
# VSPHERE INFRASTRUCTURE
# ==============================================================================

vsphere_datacenter = "DC-TST"
vsphere_cluster    = "Cluster-TST"
vsphere_datastore  = "datastore-tst-01"
vsphere_network    = "VLAN-TST-100"

# ==============================================================================
# NETWORK CONFIGURATION
# ==============================================================================

network_domain       = "test.example.com"
network_ipv4_gateway = "10.10.100.1"
network_ipv4_netmask = 24
network_dns_servers  = ["10.10.1.10", "10.10.1.11"]

# ==============================================================================
# LINUX VM CONFIGURATION
# ==============================================================================

create_linux_vm          = true
linux_vm_purpose         = "web"
linux_instance_number    = 1
linux_cpu_count      = 2
linux_memory_mb      = 4096
linux_disk_size_gb   = 50
linux_template       = "rhel9-template"
linux_ipv4_address   = "10.10.100.10"

# ==============================================================================
# WINDOWS VM CONFIGURATION
# ==============================================================================

create_windows_vm         = true
windows_vm_purpose        = "app"
windows_instance_number   = 1
windows_cpu_count       = 4
windows_memory_mb       = 8192
windows_disk_size_gb    = 100
windows_template        = "win2022-template"
windows_ipv4_address    = "10.10.100.20"
windows_workgroup       = "WORKGROUP"
windows_admin_password  = "ChangeMe123!@#Test"
windows_timezone        = 65
