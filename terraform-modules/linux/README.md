# Terraform Module - Linux VM

Module for creating Linux VMs on VMware vSphere.

## Usage

```hcl
module "linux_vm" {
  source = "./terraform-modules/linux"
  
  vm_name      = "linux-vm-01"
  vm_hostname  = "linux-vm-01"
  cpu_count    = 2
  memory_mb    = 4096
  disk_size_gb = 50
  
  datacenter    = "DC01"
  cluster       = "Cluster01"
  datastore     = "datastore1"
  network       = "VM Network"
  template_name = "rhel9-template"
  
  domain       = "example.com"
  ipv4_address = "192.168.1.100"
  ipv4_netmask = 24
  ipv4_gateway = "192.168.1.1"
  dns_servers  = ["192.168.1.10", "192.168.1.11"]
}
```

## Variables

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| vm_name | string | Sim | - | Nome da VM no vCenter |
| vm_hostname | string | Sim | - | Hostname do sistema operacional |
| cpu_count | number | Nao | 2 | Numero de vCPUs |
| memory_mb | number | Nao | 4096 | Memoria em MB |
| disk_size_gb | number | Nao | 50 | Tamanho do disco em GB |
| datacenter | string | Sim | - | Nome do datacenter |
| cluster | string | Sim | - | Nome do cluster |
| datastore | string | Sim | - | Nome do datastore |
| network | string | Sim | - | Nome da rede |
| template_name | string | Sim | - | Nome do template Linux |
| domain | string | Sim | - | Dominio DNS |
| ipv4_address | string | Sim | - | Endereco IP |
| ipv4_netmask | number | Nao | 24 | Mascara de rede |
| ipv4_gateway | string | Sim | - | Gateway padrao |
| dns_servers | list(string) | Sim | - | Servidores DNS |

## Outputs

| Nome | Descricao |
|------|-----------|
| vm_id | VM ID in vSphere |
| vm_name | VM name |
| vm_ip | VM IP address |
| vm_uuid | VM UUID |

## Requirements

- Terraform >= 1.5
- Provider vsphere ~> 2.6
- Linux template configured in vSphere
- Template must support customization (VMware Tools installed)
