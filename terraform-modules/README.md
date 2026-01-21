# Terraform Modules - VMware

Reusable Terraform modules for VMware vSphere infrastructure.

## Available Modules

### Linux VM Module

Creates Linux virtual machines on VMware vSphere with network customization.

**Location:** `linux/`

**Features:**

- Automated VM provisioning from template
- Static IP configuration
- DNS and domain configuration
- Flexible resource sizing (CPU, memory, disk)

**Usage:**

```hcl
module "linux_vm" {
  source = "./terraform-modules/linux"
  
  vm_name      = "web-server-01"
  vm_hostname  = "web-server-01"
  cpu_count    = 4
  memory_mb    = 8192
  disk_size_gb = 100
  
  datacenter    = "DC01"
  cluster       = "Cluster01"
  datastore     = "datastore1"
  network       = "VM Network"
  template_name = "rhel9-template"
  
  domain       = "example.com"
  ipv4_address = "192.168.1.10"
  ipv4_netmask = 24
  ipv4_gateway = "192.168.1.1"
  dns_servers  = ["192.168.1.2", "192.168.1.3"]
}
```

### Windows VM Module

Creates Windows virtual machines on VMware vSphere with network customization.

**Location:** `windows/`

**Features:**

- Automated VM provisioning from template
- Static IP configuration
- Computer name and workgroup configuration
- Timezone configuration
- Sysprep customization

**Usage:**

```hcl
module "windows_vm" {
  source = "./terraform-modules/windows"
  
  vm_name      = "app-server-01"
  vm_hostname  = "app-server-01"
  cpu_count    = 8
  memory_mb    = 16384
  disk_size_gb = 200
  
  datacenter    = "DC01"
  cluster       = "Cluster01"
  datastore     = "datastore1"
  network       = "VM Network"
  template_name = "win2022-template"
  
  ipv4_address   = "192.168.1.20"
  ipv4_netmask   = 24
  ipv4_gateway   = "192.168.1.1"
  dns_servers    = ["192.168.1.2", "192.168.1.3"]
  
  workgroup      = "WORKGROUP"
  admin_password = "SecureP@ssw0rd!"
  timezone       = 65
}
```

## Module Structure

Each module follows a standard structure:

```
module-name/
├── main.tf          # Resources and data sources
├── variables.tf     # Input variables
├── outputs.tf       # Output values
└── README.md        # Module documentation
```

## Requirements

- **Terraform:** >= 1.5.0
- **Provider:** hashicorp/vsphere ~> 2.6
- **VMware Tools:** Must be installed in templates
- **Templates:** Must support guest customization

## Templates

Modules expect templates to be:

- Pre-configured with VMware Tools
- Ready for guest customization
- Using supported guest OS versions

### Linux Templates

- RHEL 8/9
- Ubuntu 20.04/22.04
- CentOS Stream 8/9

### Windows Templates

- Windows Server 2019
- Windows Server 2022
- Sysprep configured

## Documentation

- [Linux Module README](linux/README.md)
- [Windows Module README](windows/README.md)
