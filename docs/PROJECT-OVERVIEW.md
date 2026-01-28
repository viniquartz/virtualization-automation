# Projeto de Automação VMware - Visão Geral Completa

## 📋 Índice

1. [Visão Geral do Projeto](#visão-geral-do-projeto)
2. [Decisões de Arquitetura](#decisões-de-arquitetura)
3. [Estrutura do Projeto](#estrutura-do-projeto)
4. [Fluxo de Trabalho](#fluxo-de-trabalho)
5. [Componentes Principais](#componentes-principais)
6. [Configuração e Uso](#configuração-e-uso)
7. [Casos de Uso](#casos-de-uso)

---

## 🎯 Visão Geral do Projeto

Este projeto fornece automação completa para provisionamento de máquinas virtuais (VMs) no ambiente VMware vSphere da TAP, utilizando Terraform, Ansible e scripts shell.

### Características Principais

- ✅ **Criação de VMs sem templates**: VMs são criadas do zero usando apenas `guest_id`
- ✅ **Multi-CPD**: Suporta deployment em CPD1, CPD2 ou ambos simultaneamente
- ✅ **Cálculo automático de instance**: Instance numbers calculados automaticamente (CPD1=ímpar, CPD2=par)
- ✅ **Múltiplas VMs**: Criação de várias VMs de uma vez com configuração consistente
- ✅ **Seleção de ESXi**: Suporta DRS automático, manual ou seleção inteligente por recursos
- ✅ **Nomenclatura padronizada**: `<PURPOSE><ENVIRONMENT><INSTANCE>` (ex: IACTST01, WEBPRD02)
- ✅ **Backend Azure**: State armazenado em Azure Storage Account
- ✅ **Segregação por ambiente**: Configurações isoladas para tst, qlt, prd

---

## 🏗️ Decisões de Arquitetura

### 1. **Sem Templates VMware**

**Decisão**: VMs criadas do zero usando `guest_id` ao invés de clonar templates.

**Razão**:

- **Simplicidade**: Elimina dependência de templates pré-configurados no vCenter
- **Flexibilidade**: Permite criar qualquer tipo de VM sem manter templates atualizados
- **Manutenção reduzida**: Não é necessário gerenciar templates em múltiplos vCenters
- **Provisionamento pós-deploy**: Configuração real acontece via Ansible após criação

**Implementação**:

```hcl
# Sem data source de template
# data "vsphere_virtual_machine" "template" { ... }  ❌

# Apenas guest_id
resource "vsphere_virtual_machine" "vm" {
  guest_id = var.guest_id  # rhel9_64Guest, windows2019srvNext_64Guest
  ...
}
```

**Guest IDs suportados**:

- Linux: `rhel9_64Guest`, `centos8_64Guest`, `ubuntu64Guest`
- Windows: `windows2019srvNext_64Guest`, `windows2022srvNext_64Guest`

---

### 2. **Configuração Baseada em CPD**

**Decisão**: Toda infraestrutura (datacenter, cluster, network) é derivada automaticamente da seleção de CPD.

**Razão**:

- **Consistência**: Garante que recursos corretos sejam usados em cada datacenter
- **Simplicidade**: Usuário só precisa especificar `cpd = "cpd1"` ou `cpd = "cpd2"`
- **Prevenção de erros**: Impossível misturar recursos de CPDs diferentes

**Implementação**:

```hcl
locals {
  cpd_config = {
    cpd1 = {
      datacenter = "TAP_CPD1"
      cluster    = "CPD1_ESX7"
      network    = "AUTOMTNPRD (LAN-CPD1)"
    }
    cpd2 = {
      datacenter = "TAP_CPD2"
      cluster    = "CPD2_ESX7"
      network    = "AUTOMTNPRD (LAN-CPD2)"
    }
  }
}

# Uso no módulo
datacenter = coalesce(var.vsphere_datacenter, local.cpd_config[each.value.cpd].datacenter)
```

**Overrides possíveis**: Variáveis `vsphere_datacenter`, `vsphere_cluster`, `vsphere_network` podem sobrescrever valores padrão.

---

### 3. **Cálculo Automático de Instance Number**

**Decisão**: Instance number NÃO é variável em `terraform.tfvars` - é calculado automaticamente baseado em CPD e sequência.

**Razão**:

- **Prevenção de conflitos**: Impossível criar VMs com mesmo instance number em CPDs diferentes
- **Paridade garantida**: CPD1 sempre ímpar (01, 03, 05...), CPD2 sempre par (02, 04, 06...)
- **Replicação consistente**: Ao usar `cpd = "both"`, mesma sequência gera pares corretos

**Implementação**:

```hcl
# Cálculo da instance number
instance_number = each.value.cpd == "cpd1" ? (each.value.sequence * 2 - 1) : (each.value.sequence * 2)

# Exemplos:
# CPD1, sequence=1 → instance=01
# CPD2, sequence=1 → instance=02
# CPD1, sequence=2 → instance=03
# CPD2, sequence=2 → instance=04
```

**Variáveis no tfvars**:

```hcl
linux_vm_count = 3              # Quantas VMs criar
linux_vm_start_sequence = 1     # Começar na sequência 1
# Resultado: VMs com sequences 1, 2, 3 → instances 01, 03, 05 (CPD1) ou 02, 04, 06 (CPD2)
```

---

### 4. **Multi-CPD Deployment**

**Decisão**: Suporte para criar VMs em ambos CPDs simultaneamente com mesma configuração.

**Razão**:

- **High Availability**: VMs pares para redundância
- **Disaster Recovery**: Infra replicada em dois datacenters
- **Eficiência**: Uma única execução cria tudo

**Implementação**:

```hcl
# Determinar CPDs alvo
locals {
  target_cpds = var.cpd == "both" ? ["cpd1", "cpd2"] : [var.cpd]
}

# Criar mapa de VMs para todos os CPDs
linux_vms = {
  for item in flatten([
    for cpd in local.target_cpds : [
      for idx in range(var.linux_vm_count) : {
        cpd      = cpd
        sequence = var.linux_vm_start_sequence + idx
      }
    ]
  ]) : "${item.cpd}-${item.sequence}" => item
}
```

**Exemplo prático**:

```hcl
cpd = "both"
linux_vm_count = 2
linux_vm_start_sequence = 1
linux_vm_purpose = "web"
environment = "prd"

# Resultado:
# CPD1: WEBPRD01 (sequence=1, instance=01)
# CPD1: WEBPRD03 (sequence=2, instance=03)
# CPD2: WEBPRD02 (sequence=1, instance=02)
# CPD2: WEBPRD04 (sequence=2, instance=04)
```

---

### 5. **Múltiplas VMs com Configuração Consistente**

**Decisão**: Usar `vm_count` e `vm_start_sequence` para criar múltiplas VMs, não variáveis individuais por VM.

**Razão**:

- **Eficiência**: Criar 10 VMs com mesma config sem repetir código
- **Consistência**: Todas VMs compartilham mesmos recursos (CPU, memória, disco)
- **Manutenção**: Alterar config afeta todas VMs simultaneamente

**Implementação**:

```hcl
# Ao invés de:
# linux_instance_1 = {...}
# linux_instance_2 = {...}

# Usar:
linux_vm_count = 5
linux_vm_start_sequence = 10
# Cria VMs com sequences: 10, 11, 12, 13, 14
```

**Limites de validação**:

- `vm_count`: 1 a 10 VMs por execução
- `vm_start_sequence`: 1 a 90 (permite até 90 VMs no total com sequências diferentes)

---

### 6. **For_Each ao invés de Count**

**Decisão**: Usar `for_each` baseado em maps, não `count` baseado em índices.

**Razão**:

- **Flexibilidade**: Adicionar/remover VMs específicas sem afetar outras
- **Identificação**: VMs identificadas por chaves significativas (`cpd1-1`, `cpd2-3`)
- **Mudanças targeted**: `terraform destroy -target=module.linux_vm["cpd1-2"]`
- **Evita reordenação**: Remover VM do meio não recria as seguintes

**Implementação**:

```hcl
# Mapa de VMs
linux_vms = {
  "cpd1-1" => { cpd = "cpd1", sequence = 1, vm_index = 0 }
  "cpd1-2" => { cpd = "cpd1", sequence = 2, vm_index = 1 }
  "cpd2-1" => { cpd = "cpd2", sequence = 1, vm_index = 0 }
}

# For_each no módulo
module "linux_vm" {
  for_each = local.linux_vms
  source   = "./terraform-modules/linux"
  
  vm_name = module.linux_naming[each.key].vm_name
  ...
}
```

---

### 7. **Seleção de ESXi Host**

**Decisão**: Três opções de seleção de host, sendo DRS o padrão.

**Razão**:

- **DRS padrão**: VMware DRS geralmente toma boas decisões
- **Manual quando necessário**: Alguns casos requerem host específico
- **Automático inteligente**: Script Python seleciona host com mais recursos disponíveis

**Opções disponíveis**:

#### Opção 1: DRS Automático (Padrão)

```hcl
vsphere_esx_host = null  # ou não definir
```

VMware DRS escolhe automaticamente baseado em balanceamento de carga.

#### Opção 2: Manual

```hcl
vsphere_esx_host = "esxprd109.tapnet.tap.pt"
```

VM será criada no host especificado.

#### Opção 3: Auto-Select via Script

```bash
export TF_VAR_vsphere_esx_host=$(bash scripts/auto-select-esx.sh CPD1_ESX7 TAP_CPD1)
```

**Script Python** (`select-best-esx-host.py`):

- Conecta ao vCenter via pyvmomi
- Lista todos hosts no cluster
- Filtra: connected, powered on, not in maintenance
- Calcula recursos disponíveis:
  - CPU: Total MHz - Used MHz
  - Memory: Total MB - Used MB
- Seleciona baseado em métrica:
  - `cpu`: Mais CPU disponível
  - `memory`: Mais memória disponível
  - `balanced`: Melhor balanceamento (padrão)

---

### 8. **Gerenciamento de Discos**

**Decisão**: Discos adicionais configurados no resource da VM, não em módulo separado.

**Razão**:

- **Limitação do provider**: vSphere provider não suporta resource `vsphere_virtual_disk` separado
- **Vinculação obrigatória**: Discos devem ser definidos dentro do bloco `vsphere_virtual_machine`
- **Simplicidade**: Configuração centralizada no mesmo resource

**Implementação**:

```hcl
resource "vsphere_virtual_machine" "vm" {
  # Disco primário (obrigatório)
  disk {
    label            = "disk0"
    size             = var.disk_size_gb
    thin_provisioned = true
  }
  
  # Discos adicionais (opcional)
  dynamic "disk" {
    for_each = var.additional_disks
    content {
      label            = disk.value.label
      size             = disk.value.size_gb
      unit_number      = disk.value.unit_number
      thin_provisioned = lookup(disk.value, "thin_provisioned", true)
    }
  }
}
```

**Configuração no tfvars**:

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

**Não criamos presets de disco**: Configuração manual direta é mais flexível e suficiente.

---

### 9. **Convenção de Nomenclatura**

**Decisão**: `<PURPOSE><ENVIRONMENT><INSTANCE>` sem hífens, uppercase.

**Razão**:

- **Limite Windows**: NetBIOS limita a 15 caracteres
- **Consistência**: Mesmo padrão para Linux e Windows
- **Legibilidade**: Uppercase facilita identificação
- **Paridade visual**: CPD1 ímpar, CPD2 par

**Formato**:

```
<PURPOSE> = 2-6 caracteres (web, app, db, iac)
<ENVIRONMENT> = 3 caracteres (prd, qlt, tst)
<INSTANCE> = 2 dígitos (01-99)
```

**Exemplos válidos**:

- `IACTST01` - IAC test, instance 01 (CPD1)
- `WEBPRD02` - Web production, instance 02 (CPD2)
- `DBQLT03` - Database quality, instance 03 (CPD1)
- `APPFEPRD10` - Application FE production, instance 10 (CPD2)

**Hostname**: Versão lowercase para DNS (`iactst01.tapnet.tap.pt`)

**Validação**: Módulo naming verifica limite de 15 caracteres e falha se exceder.

---

### 10. **Backend Azure Storage**

**Decisão**: State armazenado em Azure Storage Account, não local.

**Razão**:

- **Colaboração**: Múltiplos usuários podem executar
- **State locking**: Previne execuções simultâneas
- **Backup**: State protegido em storage durável
- **Auditoria**: Histórico de mudanças no Azure

**Configuração**:

```hcl
# backend.tf (gerado por scripts/configure.sh)
terraform {
  backend "azurerm" {
    storage_account_name = "azrprdiac01weust01"
    container_name       = "terraform-states"
    key                  = "vmware/OPS-1234.tfstate"
    use_azuread_auth     = true
  }
}
```

**Organização**: Um state file por ticket (`vmware/{ticket-id}.tfstate`)

---

### 11. **Credenciais via Variáveis de Ambiente**

**Decisão**: Credenciais vSphere APENAS via variáveis de ambiente, nunca em arquivos.

**Razão**:

- **Segurança**: Evita credenciais em Git
- **Compliance**: Atende requisitos de segurança
- **Flexibilidade**: Fácil rotação de credenciais
- **CI/CD ready**: Jenkins pode injetar via secrets

**Variáveis obrigatórias**:

```bash
export TF_VAR_vsphere_server="vcenterprd01.tapnet.tap.pt"
export TF_VAR_vsphere_user="vw_terraform@vsphere.local"
export TF_VAR_vsphere_password="***"
```

**Validação**: Scripts verificam presença antes de executar Terraform.

---

## 📁 Estrutura do Projeto

```
virtualization-automation/
├── terraform-modules/          # Módulos Terraform reutilizáveis
│   ├── naming/                 # Gera nomes padronizados de VMs
│   │   ├── main.tf            # Lógica de nomenclatura
│   │   ├── variables.tf       # Inputs: purpose, environment, instance
│   │   └── outputs.tf         # Outputs: vm_name, hostname
│   ├── linux/                 # Criação de VMs Linux
│   │   ├── main.tf           # Resource vsphere_virtual_machine
│   │   ├── variables.tf      # Inputs: cpu, memory, disk, network...
│   │   └── outputs.tf        # Outputs: vm_id, vm_name, vm_ip...
│   └── windows/              # Criação de VMs Windows
│       ├── main.tf          # Resource vsphere_virtual_machine
│       ├── variables.tf     # Inputs: cpu, memory, disk, admin_password...
│       └── outputs.tf       # Outputs: vm_id, vm_name, vm_ip...
│
├── terraform-project-template/  # Template para novos projetos
│   ├── main.tf                 # Orquestração multi-CPD
│   ├── variables.tf            # Todas variáveis de config
│   ├── outputs.tf              # Detalhes das VMs criadas
│   ├── provider.tf             # Provider vSphere
│   ├── backend.tf              # Backend Azure (gerado)
│   └── environments/           # Configs por ambiente
│       ├── tst/
│       │   └── terraform.tfvars
│       ├── qlt/
│       │   └── terraform.tfvars
│       └── prd/
│           └── terraform.tfvars
│
├── scripts/                    # Scripts de automação
│   ├── azure-login.sh         # Autenticação Azure (Service Principal)
│   ├── configure.sh           # Inicializar workspace
│   ├── deploy.sh              # Plan e apply
│   ├── destroy.sh             # Destruir infra (com safeguards)
│   ├── auto-select-esx.sh     # Wrapper para seleção de ESXi
│   └── select-best-esx-host.py # Script Python para seleção inteligente
│
├── ansible/                    # Playbooks de configuração
│   ├── playbooks/
│   │   ├── base-config.yml    # Config básica (timezone, chrony, motd)
│   │   ├── domain-join.yml    # Join AD (sssd)
│   │   └── post-deploy.yml    # Config pós-deploy
│   └── templates/
│       ├── chrony.conf.j2
│       ├── sssd.conf.j2
│       └── motd.j2
│
└── docs/                       # Documentação
    ├── WORKFLOW.md            # Workflow geral
    ├── CPD-SELECTION.md       # CPD e infra
    ├── MULTI-CPD-DEPLOYMENT.md # Multi-CPD
    ├── ESX-HOST-SELECTION.md  # Seleção de ESXi
    ├── TESTE-TAP.md          # Testes na TAP
    └── PROJECT-OVERVIEW.md   # Este documento
```

---

## 🔄 Fluxo de Trabalho

### Workflow Completo

```
┌─────────────────────────────────────────────────────────────┐
│ 1. AUTENTICAÇÃO AZURE                                       │
│    bash scripts/azure-login.sh                              │
│    → Autentica Service Principal                            │
│    → Valida acesso ao Storage Account                       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. CONFIGURAÇÃO DO WORKSPACE                                │
│    bash scripts/configure.sh OPS-1234 tst <repo-url>        │
│    → Clona repositório para /home/jenkins/OPS-1234          │
│    → Gera backend.tf dinamicamente                          │
│    → Copia terraform-modules                                │
│    → Executa terraform init                                 │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. CONFIGURAÇÃO DE VARIÁVEIS                                │
│    cd /home/jenkins/OPS-1234                                │
│    vim environments/tst/terraform.tfvars                    │
│    → Define CPD (cpd1, cpd2, both)                          │
│    → Define recursos (CPU, memória, disco)                  │
│    → Define network (IP, gateway, DNS)                      │
│    → Define quantas VMs criar                               │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. EXPORTAR CREDENCIAIS VSPHERE                             │
│    export TF_VAR_vsphere_server="vcenterprd01..."           │
│    export TF_VAR_vsphere_user="vw_terraform@vsphere.local"  │
│    export TF_VAR_vsphere_password="***"                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. (OPCIONAL) SELEÇÃO AUTOMÁTICA DE ESXi                    │
│    export TF_VAR_vsphere_esx_host=$(                        │
│      bash scripts/auto-select-esx.sh CPD1_ESX7 TAP_CPD1     │
│    )                                                         │
│    → Script Python consulta recursos                        │
│    → Seleciona host com mais disponibilidade                │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. DEPLOYMENT                                               │
│    bash scripts/deploy.sh OPS-1234 tst                      │
│    → Gera terraform plan                                    │
│    → Mostra mudanças para revisão                           │
│    → Solicita confirmação                                   │
│    → Executa terraform apply                                │
│    → Exibe outputs (IPs, nomes, IDs)                        │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 7. CONFIGURAÇÃO PÓS-DEPLOY (Ansible)                        │
│    ansible-playbook -i inventory playbooks/post-deploy.yml  │
│    → Configura timezone, chrony, motd                       │
│    → Join domain (sssd)                                     │
│    → Aplica hardening                                       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 8. VALIDAÇÃO                                                │
│    → Verificar VMs no vCenter                               │
│    → Testar conectividade SSH/RDP                           │
│    → Validar nomenclatura                                   │
│    → Verificar recursos (CPU, RAM, disco)                   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 9. (SE NECESSÁRIO) DESTRUIÇÃO                               │
│    bash scripts/destroy.sh OPS-1234 tst                     │
│    → Múltiplas confirmações                                 │
│    → Mostra recursos a destruir                             │
│    → Requer match do ticket-id                              │
│    → Executa terraform destroy                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔧 Componentes Principais

### 1. Módulo Naming

**Responsabilidade**: Gerar nomes padronizados de VMs.

**Inputs**:

- `purpose`: web, app, db, iac (2-6 chars)
- `environment`: prd, qlt, tst
- `instance_number`: 01-99 (calculado, não variável)

**Outputs**:

- `vm_name`: Nome uppercase (ex: WEBPRD01)
- `hostname`: Nome lowercase para DNS (ex: webprd01)

**Lógica**:

```hcl
vm_name = "${upper(var.purpose)}${upper(var.environment)}${format("%02d", var.instance_number)}"
hostname = lower(local.vm_name)
```

**Validação**: Falha se nome exceder 15 caracteres (limite NetBIOS).

---

### 2. Módulo Linux

**Responsabilidade**: Criar VMs Linux sem template.

**Features**:

- ✅ Sem data source de template
- ✅ Usa `guest_id` (rhel9_64Guest)
- ✅ Network adapter configurável (vmxnet3 padrão)
- ✅ Suporte a ESXi host específico
- ✅ Disco primário + discos adicionais
- ✅ Customização de network (IP, gateway, DNS)
- ✅ Tags incluindo CPD e Sequence

**Resource principal**:

```hcl
resource "vsphere_virtual_machine" "vm" {
  name             = var.vm_name
  resource_pool_id = local.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  host_system_id   = var.esx_host != null ? data.vsphere_host.esx[0].id : null
  
  num_cpus = var.cpu_count
  memory   = var.memory_mb
  guest_id = var.guest_id  # rhel9_64Guest
  
  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = var.network_adapter_type
  }
  
  disk {
    label = "disk0"
    size  = var.disk_size_gb
  }
  
  dynamic "disk" {
    for_each = var.additional_disks
    content { ... }
  }
}
```

---

### 3. Módulo Windows

**Responsabilidade**: Criar VMs Windows sem template.

**Features**:

- ✅ Similar ao módulo Linux
- ✅ Usa `windows2019srvNext_64Guest` ou `windows2022srvNext_64Guest`
- ✅ Configuração de admin password
- ✅ Workgroup ou domain join
- ✅ Auto logon opcional
- ✅ Timezone configurável

**Diferenças do Linux**:

- `customize` block diferente (Windows sysprep)
- Variáveis adicionais: `admin_password`, `workgroup`, `timezone`, `auto_logon`

---

### 4. Project Template - Main.tf

**Responsabilidade**: Orquestrar deployment multi-CPD de múltiplas VMs.

**Lógica principal**:

1. **Determinar CPDs alvo**:

```hcl
target_cpds = var.cpd == "both" ? ["cpd1", "cpd2"] : [var.cpd]
```

1. **Criar mapa de VMs**:

```hcl
linux_vms = {
  for item in flatten([
    for cpd in local.target_cpds : [
      for idx in range(var.linux_vm_count) : {
        cpd      = cpd
        sequence = var.linux_vm_start_sequence + idx
        vm_index = idx
      }
    ]
  ]) : "${item.cpd}-${item.sequence}" => item
}
```

1. **Chamar módulo naming para cada VM**:

```hcl
module "linux_naming" {
  for_each = local.linux_vms
  
  instance_number = each.value.cpd == "cpd1" ? 
    (each.value.sequence * 2 - 1) : 
    (each.value.sequence * 2)
}
```

1. **Chamar módulo VM para cada instância**:

```hcl
module "linux_vm" {
  for_each = local.linux_vms
  
  vm_name = module.linux_naming[each.key].vm_name
  datacenter = coalesce(var.vsphere_datacenter, local.cpd_config[each.value.cpd].datacenter)
  ...
}
```

---

### 5. Scripts Shell

#### azure-login.sh

**Propósito**: Autenticar Azure Service Principal.

**Variáveis obrigatórias**:

- `ARM_CLIENT_ID`: Application (client) ID
- `ARM_CLIENT_SECRET`: Client secret
- `ARM_TENANT_ID`: Directory (tenant) ID
- `ARM_SUBSCRIPTION_ID`: Subscription ID

**Execução**:

```bash
bash scripts/azure-login.sh
```

---

#### configure.sh

**Propósito**: Inicializar workspace de projeto.

**Parâmetros**:

```bash
bash scripts/configure.sh <ticket-id> <environment> <git-repo-url>
```

**Ações**:

1. Valida parâmetros
2. Clona repositório Git para `/home/jenkins/{ticket-id}`
3. Gera `backend.tf` com configuração Azure
4. Copia `terraform-modules` do repo
5. Executa `terraform init`

**Exemplo**:

```bash
bash scripts/configure.sh OPS-1234 tst https://github.com/tap/virtualization-automation.git
```

---

#### deploy.sh

**Propósito**: Planejar e aplicar mudanças Terraform.

**Parâmetros**:

```bash
bash scripts/deploy.sh <ticket-id> <environment>
```

**Ações**:

1. Valida credenciais vSphere
2. Muda para workspace directory
3. Gera plan: `terraform plan -var-file=environments/{env}/terraform.tfvars`
4. Mostra plan para revisão
5. Solicita confirmação (yes/no)
6. Aplica: `terraform apply tfplan-{env}.out`
7. Exibe outputs

**Exemplo**:

```bash
bash scripts/deploy.sh OPS-1234 tst
```

---

#### destroy.sh

**Propósito**: Destruir infraestrutura com segurança máxima.

**Parâmetros**:

```bash
bash scripts/destroy.sh <ticket-id> <environment>
```

**Safeguards**:

1. ⚠️ Múltiplas confirmações
2. ⚠️ Mostra recursos a destruir
3. ⚠️ Requer digitação do ticket-id para confirmar
4. ⚠️ Logging de todas ações
5. ⚠️ Não permite destroy em produção sem override

**Exemplo**:

```bash
bash scripts/destroy.sh OPS-1234 tst
# Pergunta: "Are you sure? (yes/no)"
# Mostra recursos
# Pergunta: "Type ticket-id to confirm: "
# Requer: "OPS-1234"
```

---

#### auto-select-esx.sh

**Propósito**: Wrapper Bash para script Python de seleção de ESXi.

**Parâmetros**:

```bash
bash scripts/auto-select-esx.sh <cluster> <datacenter> [metric]
```

**Validações**:

- ✅ Verifica se Python 3 está instalado
- ✅ Verifica se pyvmomi está instalado
- ✅ Verifica credenciais vSphere
- ✅ Fallback gracioso: Retorna vazio (DRS decide) se falhar

**Uso**:

```bash
export TF_VAR_vsphere_esx_host=$(bash scripts/auto-select-esx.sh CPD1_ESX7 TAP_CPD1)
```

---

#### select-best-esx-host.py

**Propósito**: Consultar recursos de ESXi hosts e selecionar o melhor.

**Dependências**: `pip3 install pyvmomi`

**Parâmetros**:

```bash
python3 scripts/select-best-esx-host.py \
  --datacenter TAP_CPD1 \
  --cluster CPD1_ESX7 \
  --metric balanced \
  --format fqdn
```

**Métricas disponíveis**:

- `cpu`: Seleciona host com mais CPU disponível (MHz)
- `memory`: Seleciona host com mais memória disponível (MB)
- `balanced`: Seleciona balanceamento entre CPU e memória (padrão)

**Formatos de saída**:

- `fqdn`: Retorna apenas FQDN do host (ex: esxprd109.tapnet.tap.pt)
- `json`: Retorna JSON com detalhes completos

**Filtros aplicados**:

- ✅ Host must be connected
- ✅ Host must be powered on
- ✅ Host must NOT be in maintenance mode

---

## ⚙️ Configuração e Uso

### Pré-requisitos

1. **Software**:
   - Terraform >= 1.5.0
   - Azure CLI
   - Git
   - Python 3 (para auto-select ESXi)
   - pip3 install pyvmomi (para auto-select ESXi)

2. **Credenciais Azure**:

   ```bash
   export ARM_CLIENT_ID="..."
   export ARM_CLIENT_SECRET="..."
   export ARM_TENANT_ID="..."
   export ARM_SUBSCRIPTION_ID="..."
   ```

3. **Credenciais vSphere**:

   ```bash
   export TF_VAR_vsphere_server="vcenterprd01.tapnet.tap.pt"
   export TF_VAR_vsphere_user="vw_terraform@vsphere.local"
   export TF_VAR_vsphere_password="***"
   ```

---

### Configuração Básica (CPD1, 1 VM Linux)

**terraform.tfvars**:

```hcl
# Projeto
environment    = "tst"
project_name   = "test-automation"
ticket_id      = "OPS-1234"

# CPD
cpd = "cpd1"

# Linux VM
create_linux_vm         = true
linux_vm_purpose        = "iac"
linux_vm_count          = 1
linux_vm_start_sequence = 1
linux_cpu_count         = 2
linux_memory_mb         = 4096
linux_disk_size_gb      = 50
linux_guest_id          = "rhel9_64Guest"

# Network
network_domain      = "tapnet.tap.pt"
linux_ipv4_address  = "10.190.10.10"
network_ipv4_gateway = "10.190.10.1"
network_ipv4_netmask = 24
network_dns_servers  = ["10.190.1.10", "10.190.1.11"]

# vSphere (usa defaults)
vsphere_datastore = "PS04_ESX2_CPDMIG"
vsphere_folder    = "TerraformTests"
```

**Resultado**: Cria VM `IACTST01` no CPD1.

---

### Configuração Multi-CPD (2 VMs em cada CPD)

**terraform.tfvars**:

```hcl
# CPD
cpd = "both"  # ← Multi-CPD

# Linux VM
create_linux_vm         = true
linux_vm_purpose        = "web"
linux_vm_count          = 2  # ← 2 VMs por CPD
linux_vm_start_sequence = 1
# ... resto igual
```

**Resultado**: Cria 4 VMs:

- CPD1: `WEBTST01`, `WEBTST03`
- CPD2: `WEBTST02`, `WEBTST04`

---

### Configuração com Múltiplas VMs e Discos Adicionais

**terraform.tfvars**:

```hcl
# CPD
cpd = "cpd1"

# Linux VM
create_linux_vm         = true
linux_vm_purpose        = "db"
linux_vm_count          = 3  # ← 3 VMs
linux_vm_start_sequence = 5  # ← Começa na sequência 5
linux_cpu_count         = 4
linux_memory_mb         = 8192
linux_disk_size_gb      = 100

# Discos adicionais
linux_additional_disks = [
  {
    label       = "data"
    size_gb     = 500
    unit_number = 1
  },
  {
    label       = "logs"
    size_gb     = 100
    unit_number = 2
  }
]
# ... network config
```

**Resultado**: Cria 3 VMs no CPD1:

- `DBTST09` (sequence 5, instance 09)
- `DBTST11` (sequence 6, instance 11)
- `DBTST13` (sequence 7, instance 13)

Cada uma com:

- Disco primário: 100 GB
- Disco data: 500 GB
- Disco logs: 100 GB

---

### Configuração com ESXi Específico

**terraform.tfvars**:

```hcl
# vSphere
vsphere_esx_host = "esxprd109.tapnet.tap.pt"  # ← Host específico
```

Ou via script antes do deploy:

```bash
export TF_VAR_vsphere_esx_host=$(bash scripts/auto-select-esx.sh CPD1_ESX7 TAP_CPD1)
bash scripts/deploy.sh OPS-1234 tst
```

---

## 📚 Casos de Uso

### Caso 1: Single VM de Teste em CPD1

**Objetivo**: Criar uma VM Linux simples para testes.

**Configuração**:

```hcl
cpd                     = "cpd1"
linux_vm_count          = 1
linux_vm_start_sequence = 1
linux_vm_purpose        = "test"
environment             = "tst"
```

**Execução**:

```bash
bash scripts/configure.sh OPS-1234 tst https://...
export TF_VAR_vsphere_*
bash scripts/deploy.sh OPS-1234 tst
```

**Resultado**: VM `TESTTST01` criada no CPD1.

---

### Caso 2: Par HA Web Servers (CPD1 + CPD2)

**Objetivo**: Criar servidores web redundantes em ambos CPDs.

**Configuração**:

```hcl
cpd                     = "both"  # ← Ambos CPDs
linux_vm_count          = 1       # ← 1 por CPD = 2 total
linux_vm_start_sequence = 1
linux_vm_purpose        = "web"
environment             = "prd"
linux_cpu_count         = 4
linux_memory_mb         = 8192
```

**Execução**: Similar ao Caso 1.

**Resultado**:

- CPD1: `WEBPRD01`
- CPD2: `WEBPRD02`

Par de VMs com mesma configuração em datacenters diferentes.

---

### Caso 3: Cluster Database (3 nodes em CPD1)

**Objetivo**: Criar cluster de banco de dados com 3 nodes.

**Configuração**:

```hcl
cpd                     = "cpd1"
linux_vm_count          = 3       # ← 3 VMs
linux_vm_start_sequence = 1
linux_vm_purpose        = "db"
environment             = "prd"
linux_cpu_count         = 8
linux_memory_mb         = 32768
linux_disk_size_gb      = 200

linux_additional_disks = [
  { label = "data", size_gb = 1000, unit_number = 1 },
  { label = "logs", size_gb = 200, unit_number = 2 },
  { label = "backup", size_gb = 500, unit_number = 3 }
]
```

**Resultado**:

- `DBPRD01` (sequence 1, instance 01)
- `DBPRD03` (sequence 2, instance 03)
- `DBPRD05` (sequence 3, instance 05)

Cada uma com 4 discos (primary + 3 adicionais).

---

### Caso 4: Expansão de Ambiente Existente

**Objetivo**: Adicionar mais VMs a um ambiente existente sem recriar as atuais.

**Estado atual**: Já existem VMs com sequences 1-5.

**Nova configuração**:

```hcl
cpd                     = "cpd1"
linux_vm_count          = 2       # ← Mais 2 VMs
linux_vm_start_sequence = 6       # ← Começa na 6
linux_vm_purpose        = "app"
environment             = "prd"
```

**Resultado**:

- `APPPRD11` (sequence 6, instance 11)
- `APPPRD13` (sequence 7, instance 13)

**Por que for_each é importante aqui**:

- Novas VMs têm keys `cpd1-6` e `cpd1-7`
- VMs existentes (`cpd1-1` a `cpd1-5`) não são afetadas
- Se fosse `count`, adicionar VMs recriaria recursos

---

### Caso 5: Migração entre CPDs

**Objetivo**: Criar réplica em CPD2 de VMs existentes em CPD1.

**Config original (CPD1)**:

```hcl
cpd                     = "cpd1"
linux_vm_count          = 2
linux_vm_start_sequence = 1
```

Resultado: `APPPRD01`, `APPPRD03`

**Nova config (ambos CPDs)**:

```hcl
cpd                     = "both"  # ← Adiciona CPD2
linux_vm_count          = 2
linux_vm_start_sequence = 1
```

Resultado adicional: `APPPRD02`, `APPPRD04` no CPD2

**Importante**: CPD1 VMs não são recriadas (for_each preserva).

---

### Caso 6: Destruição Seletiva

**Objetivo**: Remover VM específica sem afetar outras.

**Comando**:

```bash
cd /home/jenkins/OPS-1234
terraform destroy -target='module.linux_vm["cpd1-3"]'
```

**Resultado**: Apenas VM com sequence 3 no CPD1 é destruída.

**Alternativa**: Modificar tfvars para excluir e re-apply (não recomendado).

---

## 🎓 Resumo Executivo

### O que este projeto resolve?

1. ✅ **Automação completa**: Do clone do repo até VMs configuradas
2. ✅ **Sem templates**: VMs criadas do zero, configuradas via Ansible
3. ✅ **Multi-datacenter**: Suporte nativo para CPD1, CPD2 ou ambos
4. ✅ **Nomenclatura consistente**: Sem conflitos, paridade automática
5. ✅ **Escalabilidade**: Criar 1 ou múltiplas VMs com mesma config
6. ✅ **Flexibilidade**: DRS automático ou seleção manual/inteligente de ESXi
7. ✅ **Segurança**: Credenciais via env vars, state remoto, múltiplas confirmações
8. ✅ **Rastreabilidade**: Um state por ticket, logging completo

### Quando usar?

- ✅ Criar VMs para novos projetos
- ✅ Provisionar ambientes completos (dev, qlt, prd)
- ✅ Replicar configuração entre datacenters
- ✅ Expandir ambientes existentes
- ✅ Testes de automação
- ✅ Disaster recovery (criar réplicas)

### Quando NÃO usar?

- ❌ VMs únicas pontuais (pode usar vCenter UI)
- ❌ Mudanças em VMs existentes não gerenciadas por Terraform
- ❌ Ambientes fora da TAP (requer adaptação)

---

## 🚀 Próximos Passos para POC

1. **Preparação**:

   ```bash
   # Clonar repositório
   git clone https://github.com/tap/virtualization-automation.git
   cd virtualization-automation
   
   # Autenticar Azure
   export ARM_CLIENT_ID="..."
   export ARM_CLIENT_SECRET="..."
   export ARM_TENANT_ID="..."
   export ARM_SUBSCRIPTION_ID="..."
   bash scripts/azure-login.sh
   ```

2. **Configuração**:

   ```bash
   # Inicializar workspace
   bash scripts/configure.sh OPS-POC-001 tst https://github.com/tap/virtualization-automation.git
   
   # Editar variáveis
   cd /home/jenkins/OPS-POC-001
   vim environments/tst/terraform.tfvars
   ```

3. **Deploy**:

   ```bash
   # Exportar credenciais vSphere
   export TF_VAR_vsphere_server="vcenterprd01.tapnet.tap.pt"
   export TF_VAR_vsphere_user="vw_terraform@vsphere.local"
   export TF_VAR_vsphere_password="***"
   
   # Executar deployment
   bash scripts/deploy.sh OPS-POC-001 tst
   ```

4. **Validação**:
   - Verificar VM no vCenter: `IACTST01` existe?
   - Nome está correto?
   - CPD1 ou CPD2 conforme configurado?
   - Recursos (CPU, memória, disco) corretos?
   - Network configurada?

5. **Limpeza**:

   ```bash
   bash scripts/destroy.sh OPS-POC-001 tst
   ```

---

## 📞 Suporte e Troubleshooting

### Erros Comuns

1. **"Failed to authenticate with Azure"**:
   - Verificar variáveis `ARM_*`
   - Re-executar `azure-login.sh`

2. **"Failed to connect to vCenter"**:
   - Verificar variáveis `TF_VAR_vsphere_*`
   - Testar conectividade: `ping vcenterprd01.tapnet.tap.pt`
   - Validar credenciais no vCenter UI

3. **"VM name exceeds 15 characters"**:
   - Reduzir `purpose` (ex: `webapp` → `web`)
   - Verificar: `<PURPOSE><ENV><INSTANCE>` ≤ 15 chars

4. **"No hosts found in cluster"**:
   - Verificar nome do cluster: `CPD1_ESX7` (case-sensitive)
   - Verificar nome do datacenter: `TAP_CPD1`

5. **"State lock timeout"**:
   - Outra execução em andamento
   - Aguardar ou forçar unlock (com cuidado)

---

## 📝 Conclusão

Este projeto fornece uma solução completa, flexível e segura para automação de infraestrutura VMware. As decisões arquiteturais foram tomadas para:

- ✅ **Simplicidade**: Sem templates, auto-cálculo de instâncias
- ✅ **Consistência**: CPD define tudo, nomenclatura padronizada
- ✅ **Eficiência**: Multi-VM, multi-CPD em uma execução
- ✅ **Segurança**: Credenciais via env vars, múltiplas confirmações
- ✅ **Manutenibilidade**: Módulos reutilizáveis, for_each flexível

A POC vai validar todos esses conceitos no ambiente real da TAP.

---

**Documento criado em**: $(date)  
**Versão**: 1.0  
**Autor**: Automação TAP  
**Status**: Pronto para POC
