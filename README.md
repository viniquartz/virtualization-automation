# VMware Virtualization Automation

Automação de infraestrutura VMware vSphere usando Terraform com backend Azure Storage.

## 🚀 Features

- ✅ **Módulos Terraform Reusáveis** para Linux e Windows
- ✅ **Naming Convention Automático** (< purpose>-<env>-<instance>)
- ✅ **Backend Azure Storage** com configuração por ambiente
- ✅ **Validações de Recursos** (CPU, memória, disco)
- ✅ **Gerenciamento de Tags** com merge automático
- ✅ **Configurações Opcionais** (discos adicionais, folders, resource pools)
- ✅ **Outputs Detalhados** (IPs, estado, recursos)
- ✅ **Scripts de Automação** usando Service Principal (modelo Jenkins)
- ✅ **Ambientes Segregados** (tst/qlt/prd) com tfvars dedicados
- ✅ **Jenkins Pipelines** para CI/CD (validation, deploy, destroy)

## 📁 Estrutura do Projeto

```
virtualization-automation/
├── terraform-modules/
│   ├── naming/                # Módulo de naming convention
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── linux/                 # Módulo Linux VMs
│   │   ├── main.tf           # Resources com tags, validations
│   │   ├── variables.tf      # Variáveis com descriptions
│   │   ├── outputs.tf        # Outputs detalhados
│   │   └── README.md
│   └── windows/               # Módulo Windows VMs
│       ├── main.tf           # Resources com tags, validations
│       ├── variables.tf      # Variáveis com descriptions
│       ├── outputs.tf        # Outputs detalhados
│       └── README.md
│
├── terraform-project-template/
│   ├── environments/          # Configurações por ambiente
│   │   ├── tst/
│   │   │   ├── terraform.tfvars
│   │   │   └── backend-tst.tfbackend
│   │   ├── qlt/
│   │   │   ├── terraform.tfvars
│   │   │   └── backend-qlt.tfbackend
│   │   └── prd/
│   │       ├── terraform.tfvars
│   │       └── backend-prd.tfbackend
│   ├── providers.tf          # vSphere provider
│   ├── backend.tf            # Azure Storage backend
│   ├── locals.tf             # common_tags
│   ├── variables.tf          # Variáveis completas
│   ├── main.tf               # Chamadas de módulos
│   ├── outputs.tf            # Outputs
│   └── README.md
│
├── scripts/                   # Scripts para testes locais (Service Principal)
│   ├── azure-login.sh        # Login Azure com Service Principal
│   ├── configure.sh          # Clone repo e setup Terraform backend
│   ├── deploy.sh             # Deploy de infraestrutura
│   ├── destroy.sh            # Destruição de infraestrutura
│   ├── validate-modules.sh   # Validação de módulos
│   └── README.md             # Documentação dos scripts
│
├── pipelines/                 # Jenkins CI/CD pipelines
│   ├── terraform-modules-validation-job.groovy
│   ├── terraform-validation-job.groovy
│   ├── terraform-deploy-job.groovy
│   ├── terraform-destroy-job.groovy
│   └── README.md            # Documentação das pipelines
│
├── ansible/                   # Playbooks Ansible
│   ├── ansible.cfg
│   ├── inventory/
│   ├── playbooks/
│   └── templates/
│
└── docs/
    └── WORKFLOW.md           # Workflow completo
```

## 🎯 Quick Start

### 1. Preparar Ambiente

```bash
# Clone o repositório
git clone <repo-url>
cd virtualization-automation

# Login no Azure
./scripts/azure-login.sh

# Verificar acesso ao vCenter
ping vcenter.example.com
```

### 2. Criar Novo Projeto

```bash
# Copiar template
cp -r terraform-project-template my-vmware-project
cd my-vmware-project

# Escolher ambiente
export ENV=tst  # ou qlt, prd
```

### 3. Configurar Backend

```bash
# Configurar backend do Azure Storage
../scripts/configure-backend.sh $ENV ABC-123

# Isso irá:
# - Validar autenticação Azure
# - Verificar/criar container no Storage Account
# - Inicializar Terraform com backend correto
```

### 4. Personalizar Variáveis

Editar `environments/tst/terraform.tfvars`:

```hcl
# Naming
linux_vm_purpose      = "web"    # Resulta em: web-tst-01
linux_instance_number = 1
windows_vm_purpose    = "app"    # Resulta em: app-tst-01

# Resources
linux_cpu_count    = 2
linux_memory_mb    = 4096
windows_cpu_count  = 4
windows_memory_mb  = 8192

# vSphere
vsphere_server     = "vcenter.example.com"
vsphere_datacenter = "DC-TST"
vsphere_cluster    = "Cluster-TST"
```

### 5. Deploy

```bash
# Plan
terraform plan -var-file=environments/tst/terraform.tfvars

# Apply
terraform apply -var-file=environments/tst/terraform.tfvars

# Destroy quando necessário
terraform destroy -var-file=environments/tst/terraform.tfvars
```

## 📋 Naming Convention

O módulo `naming` gera nomes padronizados automaticamente:

**Pattern:** `<purpose>-<environment>-<instance>`

**Exemplos:**

- `web-tst-01` - Web server em teste
- `app-prd-05` - Application server em produção #5
- `db-qlt-02` - Database server em qualidade #2

**Regras:**

- Purpose: 2-8 caracteres (lowercase, alphanumeric, hyphens)
- Environment: `tst`, `qlt`, `prd`
- Instance: 1-99
- Limite total: 15 caracteres

## 🏷️ Tags Management

Tags são gerenciadas automaticamente:

```hcl
# locals.tf
common_tags = {
  Environment = var.environment  # tst/qlt/prd
  Project     = var.project_name
  ManagedBy   = "Terraform"
  Ticket      = var.ticket_id
}
```

Tags são merged nos módulos:

- Tags comuns do projeto
- Tags específicas do módulo (Terraform=true, Module=linux/windows)
- Tags customizadas adicionais

## ✅ Validações

### Recursos

```hcl
# CPU: 1-32 vCPUs
cpu_min = 1
cpu_max = 32

# Memória: 1GB-128GB (Linux), 2GB-128GB (Windows)
memory_min = 1024   # Linux
memory_min = 2048   # Windows
memory_max = 131072

# Disco: >= 20GB (Linux), >= 40GB (Windows)
disk_min = 20   # Linux
disk_min = 40   # Windows
```

### Network

```hcl
# IPv4 address validation
ipv4_address = "10.10.100.10"  # Formato válido

# Netmask: /8 a /30
ipv4_netmask = 24

# DNS: 1-3 servidores
dns_servers = ["10.10.1.10", "10.10.1.11"]
```

## 🔧 Configurações Opcionais

### Discos Adicionais

```hcl
linux_additional_disks = [
  {
    label       = "data"
    size_gb     = 100
    unit_number = 1
  },
  {
    label       = "logs"
    size_gb     = 50
    unit_number = 2
  }
]
```

### Organização vSphere

```hcl
# Folder
linux_vm_folder = "/DC-PRD/vm/Linux/Production"

# Resource Pool
vsphere_resource_pool = "Production-Pool"

# Annotation
linux_annotation = "Web server for project XYZ - Ticket ABC-123"
```

### Timeouts

```hcl
wait_for_guest_net_timeout = 5  # minutos
shutdown_wait_timeout      = 3  # minutos
```

## 📦 Backend Configuration

State files no Azure Storage Account:

**Estrutura:**

- **Resource Group:** `azr-prd-iac01-weu-rg`
- **Storage Account:** `azrprdiac01weust01`
- **Containers:**
  - `terraform-state-tst`
  - `terraform-state-qlt`
  - `terraform-state-prd`
- **Key Pattern:** `vmware/<project-or-ticket>.tfstate`

**Inicialização:**

```bash
# Método 1: Script automático
./scripts/configure-backend.sh tst ABC-123

# Método 2: Manual com arquivo .tfbackend
terraform init -backend-config=environments/tst/backend-tst.tfbackend

# Método 3: Inline
terraform init \
  -backend-config="resource_group_name=azr-prd-iac01-weu-rg" \
  -backend-config="storage_account_name=azrprdiac01weust01" \
  -backend-config="container_name=terraform-state-tst" \
  -backend-config="key=vmware/ABC-123.tfstate"
```

## 📚 Módulos

### Naming Module

Gera nomes padronizados para VMs.

📖 **Documentação:** [terraform-modules/naming/README.md](terraform-modules/naming/README.md)

**Features:**

- Pattern: `<purpose>-<env>-<instance>`
- Validação de comprimento (max 15 chars)
- Consistência entre vm_name e hostname

### Linux VM Module

Provisiona VMs Linux no vSphere.

📖 **Documentação:** [terraform-modules/linux/README.md](terraform-modules/linux/README.md)

**Features:**

- Clone de template
- Customização de rede (static IP)
- Discos adicionais
- Tags e custom attributes
- Validações de recursos
- Timeouts configuráveis

### Windows VM Module

Provisiona VMs Windows no vSphere.

📖 **Documentação:** [terraform-modules/windows/README.md](terraform-modules/windows/README.md)

**Features:**

- Clone de template
- Sysprep/customization
- Workgroup ou Domain
- Auto-logon configurável
- Run-once commands
- Discos adicionais
- Tags e custom attributes

## 🔐 Requisitos

- **Terraform:** >= 1.5.0
- **Azure CLI:** Para autenticação no backend
- **vSphere Access:** Credenciais com permissões de criar VMs
- **Azure Storage Access:** Acesso ao Storage Account
- **Templates vSphere:** Templates Linux e Windows configurados

## 📝 Variáveis de Ambiente

```bash
# vSphere
export VSPHERE_SERVER="vcenter.example.com"
export VSPHERE_USER="svc-terraform@vsphere.local"
export VSPHERE_PASSWORD="your-password"

# Ou usar arquivo terraform.tfvars
```

## 🚦 Workflow Completo

Consulte [docs/WORKFLOW.md](docs/WORKFLOW.md) para workflow detalhado incluindo:

- Planejamento de capacidade
- Processo de aprovação
- Deploy multi-ambiente
- Rollback procedures
- Ansible post-configuration

## 🤝 Contribuindo

1. Crie feature branch
2. Implemente mudanças
3. Teste em TST
4. Submeta PR com documentação

## 📄 License

[Especificar licença]

## 👥 Suporte

- **Issues:** [GitHub Issues]
- **Documentação:** [Wiki]
- **Contato:** [Email/Slack]
