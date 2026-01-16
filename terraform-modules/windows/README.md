# Terraform Module - Windows VM

Module for creating Windows VMs on VMware vSphere.

## Usage

```hcl
module "windows_vm" {
  source = "./terraform-modules/windows"
  
  vm_name      = "windows-vm-01"
  vm_hostname  = "windows-vm-01"
  cpu_count    = 4
  memory_mb    = 8192
  disk_size_gb = 100
  
  datacenter    = "DC01"
  cluster       = "Cluster01"
  datastore     = "datastore1"
  network       = "VM Network"
  template_name = "win2022-template"
  
  ipv4_address   = "192.168.1.101"
  ipv4_netmask   = 24
  ipv4_gateway   = "192.168.1.1"
  dns_servers    = ["192.168.1.10", "192.168.1.11"]
  
  workgroup      = "WORKGROUP"
  admin_password = "P@ssw0rd123!"
  timezone       = 65
}
```

## Variables

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| vm_name | string | Sim | - | Nome da VM no vCenter |
| vm_hostname | string | Sim | - | Computer name do Windows |
| cpu_count | number | Nao | 2 | Numero de vCPUs |
| memory_mb | number | Nao | 8192 | Memoria em MB |
| disk_size_gb | number | Nao | 100 | Tamanho do disco em GB |
| datacenter | string | Sim | - | Nome do datacenter |
| cluster | string | Sim | - | Nome do cluster |
| datastore | string | Sim | - | Nome do datastore |
| network | string | Sim | - | Nome da rede |
| template_name | string | Sim | - | Nome do template Windows |
| ipv4_address | string | Sim | - | Endereco IP |
| ipv4_netmask | number | Nao | 24 | Mascara de rede |
| ipv4_gateway | string | Sim | - | Gateway padrao |
| dns_servers | list(string) | Sim | - | Servidores DNS |
| workgroup | string | Nao | WORKGROUP | Workgroup do Windows |
| admin_password | string | Sim | - | Senha do Administrator |
| timezone | number | Nao | 65 | Timezone (65 = UTC-03:00 Brasilia) |

## Outputs

| Nome | Descricao |
|------|-----------|
| vm_id | VM ID in vSphere |
| vm_name | VM name |
| vm_ip | VM IP address |
| vm_uuid | VM UUID |

## Common Timezones

| Code | Timezone |
|------|----------|
| 65 | (UTC-03:00) Brasilia |
| 35 | (UTC) Dublin, Edinburgh, Lisbon, London |
| 110 | (UTC+01:00) Amsterdam, Berlin, Rome, Paris |

Full list: <https://docs.microsoft.com/en-us/previous-versions/windows/embedded/ms912391>

## Requirements

- Terraform >= 1.5
- Provider vsphere ~> 2.6
- Windows template configured in vSphere
- Template must support customization (VMware Tools installed)
- Sysprep configured in template
