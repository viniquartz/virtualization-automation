# Terraform Project Template

Template base para projetos Terraform de automação VMware.

## Estrutura

```
terraform-project-template/
├── environments/           # Configurações por ambiente (commitadas)
│   ├── tst/
│   │   └── terraform.tfvars
│   ├── qlt/
│   │   └── terraform.tfvars
│   └── prd/
│       └── terraform.tfvars
├── main.tf                # Módulos e recursos
├── variables.tf           # Variáveis do projeto
├── outputs.tf            # Outputs do projeto
├── provider.tf           # Configuração vSphere provider
├── locals.tf             # Variáveis locais e tags
└── .gitignore            # backend.tf não é commitado (gerado dinamicamente)
```

## Features

- Backend Azure Storage (gerado dinamicamente)
- Provider vSphere configurado
- Módulos Linux e Windows VM
- Naming convention automático
- VMs opcionais com count (create_linux_vm, create_windows_vm)
- Configurações por ambiente commitadas

## Como Usar

### 1. Via Scripts (Local)

```bash
# Autenticar com Service Principal
export ARM_CLIENT_ID="xxx"
export ARM_CLIENT_SECRET="xxx"
export ARM_SUBSCRIPTION_ID="xxx"
export ARM_TENANT_ID="xxx"
bash scripts/azure-login.sh

# Configurar projeto (clona, cria backend, init)
bash scripts/configure.sh OPS-1234 tst https://github.com/yourorg/repo.git

# Deploy
bash scripts/deploy.sh OPS-1234 tst
```

### 2. Via Jenkins (CI/CD)

Pipelines disponíveis:
- `terraform-deploy-job` - Deploy de infraestrutura
- `terraform-destroy-job` - Destruição de infraestrutura

As pipelines geram automaticamente:
- `backend.tf` - Configuração do backend
- `backend-config.tfbackend` - Parâmetros do backend

## Backend Dinâmico

O backend **não é commitado**. É gerado dinamicamente por:

**Scripts locais:**
```bash
cat > backend.tf << 'EOF'
terraform {
  backend "azurerm" {}
}
EOF

cat > backend-config.tfbackend << EOF
resource_group_name  = "azr-prd-iac01-weu-rg"
storage_account_name = "azrprdiac01weust01"
container_name       = "terraform-state-tst"
key                  = "vmware/OPS-1234.tfstate"
EOF
```

**Pipelines Jenkins:**
- Backend criado automaticamente na stage "Terraform Init"
- State key: `vmware/<TICKET_ID>.tfstate`
- Container por ambiente: `terraform-state-{tst|qlt|prd}`

## Variáveis de Ambiente

### Configuração vSphere (obrigatória)

```bash
export TF_VAR_vsphere_server="vcenter.example.com"
export TF_VAR_vsphere_user="svc-terraform@vsphere.local"
export TF_VAR_vsphere_password="password"
```

### Criação Opcional de VMs

No `terraform.tfvars` de cada ambiente:

```hcl
create_linux_vm   = true   # false para não criar
create_windows_vm = false  # false para não criar
```

## Customização

### Adicionar Mais VMs

Duplicar módulos em `main.tf`:

```hcl
module "linux_vm_02" {
  count  = var.create_linux_vm_02 ? 1 : 0
  source = "./terraform-modules/linux"
  # ... configurações
}
```
├── backend.tf                  # Backend configuration
├── providers.tf                # vSphere provider
├── locals.tf                   # Local variables and tags
├── main.tf                     # Module calls
├── variables.tf                # Variable definitions
├── outputs.tf                  # Output definitions
├── terraform.tfvars.example    # Example values (deprecated - use environments/)
├── environments/               # Environment-specific configurations
│   ├── tst/                   # Test environment
│   │   └── terraform.tfvars
│   ├── qlt/                   # Quality environment
│   │   └── terraform.tfvars
│   ├── prd/                   # Production environment
│   │   └── terraform.tfvars
│   └── README.md              # Environment documentation
├── .gitignore                  # Git ignore rules
└── README.md                   # This file
```

## Backend Configuration

Default setup for Azure Storage:

- **Resource Group**: azr-prd-iac01-weu-rg
- **Storage Account**: azrprdiac01weust01
- **Containers**:
  - terraform-state-prd
  - terraform-state-qlt
  - terraform-state-tst
- **Key Pattern**: vmware/TICKET.tfstate

## Variables

See [variables.tf](variables.tf) for complete list of variables.

Required variables:

- vSphere connection details
- Infrastructure (datacenter, cluster, datastore, network)
- VM specifications
- Network configuration

## Outputs

See [outputs.tf](outputs.tf) for available outputs.

Default outputs:

- VM IDs
- VM names
- VM IP addresses
- VM UUIDs
