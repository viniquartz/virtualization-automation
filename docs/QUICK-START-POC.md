# 🚀 Quick Start - POC Guide

## Resumo do Projeto

Sistema completo de automação VMware usando Terraform que:

- ✅ Cria VMs **sem templates** (apenas guest_id)
- ✅ **Auto-calcula instance numbers** (CPD1=ímpar, CPD2=par)
- ✅ Suporta **multi-CPD** (cpd1, cpd2, ou both)
- ✅ Cria **múltiplas VMs** de uma vez
- ✅ Nomenclatura padronizada: **PURPOSEENVINSTANCE** (ex: IACTST01)
- ✅ Backend Azure + State remoto
- ✅ Scripts prontos para deploy/destroy

---

## 📋 Preparação Rápida

### 1. Credenciais Azure

```bash
export ARM_CLIENT_ID="..."
export ARM_CLIENT_SECRET="..."
export ARM_TENANT_ID="..."
export ARM_SUBSCRIPTION_ID="..."
bash scripts/azure-login.sh
```

### 2. Credenciais vSphere

```bash
export TF_VAR_vsphere_server="vcenterprd01.tapnet.tap.pt"
export TF_VAR_vsphere_user="vw_terraform@vsphere.local"
export TF_VAR_vsphere_password="***"
```

---

## 🎯 POC - Criar 1 VM em CPD1

### Passo 1: Configurar Workspace

```bash
cd /Users/i573513/Documents/personal/virtualization-automation

# Inicializar (substitua URL pelo seu repo real)
bash scripts/configure.sh OPS-POC-001 tst https://github.com/yourorg/repo.git
```

### Passo 2: Configurar terraform.tfvars

```bash
cd /home/jenkins/OPS-POC-001
cat > environments/tst/terraform.tfvars << 'EOF'
# Projeto
environment  = "tst"
project_name = "poc-automation"
ticket_id    = "OPS-POC-001"

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
network_domain       = "tapnet.tap.pt"
linux_ipv4_address   = "10.190.10.10"
network_ipv4_gateway = "10.190.10.1"
network_ipv4_netmask = 24
network_dns_servers  = ["10.190.1.10", "10.190.1.11"]

# vSphere
vsphere_datastore = "PS04_ESX2_CPDMIG"
vsphere_folder    = "TerraformTests"

# Windows (desabilitado)
create_windows_vm = false
EOF
```

### Passo 3: Deploy

```bash
bash scripts/deploy.sh OPS-POC-001 tst
```

**Esperado**:

- Plan mostra 1 VM a criar
- Nome: **IACTST01**
- Datacenter: TAP_CPD1
- Cluster: CPD1_ESX7
- Confirmar com `yes`

### Passo 4: Validar

```bash
# Ver outputs
terraform output

# Verificar no vCenter:
# - VM existe: IACTST01
# - CPD1: TAP_CPD1
# - Folder: TerraformTests
# - Recursos: 2 vCPU, 4GB RAM, 50GB disk
```

### Passo 5: Cleanup

```bash
bash scripts/destroy.sh OPS-POC-001 tst
```

---

## 🔥 Casos de Uso Avançados

### Criar VMs em Ambos CPDs (HA)

```hcl
cpd = "both"  # ← Cria em CPD1 E CPD2
linux_vm_count = 2
linux_vm_start_sequence = 1

# Resultado:
# CPD1: IACTST01, IACTST03
# CPD2: IACTST02, IACTST04
```

### Criar Múltiplas VMs

```hcl
cpd = "cpd1"
linux_vm_count = 3  # ← 3 VMs
linux_vm_start_sequence = 1

# Resultado:
# IACTST01 (seq=1, inst=01)
# IACTST03 (seq=2, inst=03)
# IACTST05 (seq=3, inst=05)
```

### Adicionar Discos Extras

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

### Seleção Automática de ESXi

```bash
# Antes do deploy
export TF_VAR_vsphere_esx_host=$(bash scripts/auto-select-esx.sh CPD1_ESX7 TAP_CPD1)

# Depois
bash scripts/deploy.sh OPS-POC-001 tst
```

---

## 📚 Arquitetura - Pontos-Chave

### 1. Sem Templates

VMs criadas com `guest_id` apenas:

- `rhel9_64Guest` para Red Hat 9
- `windows2019srvNext_64Guest` para Windows 2019

### 2. Instance Number Auto-Calculado

```
CPD1: instance = sequence * 2 - 1  (ímpar)
CPD2: instance = sequence * 2      (par)

Exemplos:
cpd1, seq=1 → inst=01
cpd1, seq=2 → inst=03
cpd2, seq=1 → inst=02
cpd2, seq=2 → inst=04
```

### 3. Infraestrutura por CPD

```
CPD1:
  vCenter: vcenterprd01.tapnet.tap.pt
  Datacenter: TAP_CPD1
  Cluster: CPD1_ESX7
  Network: AUTOMTNPRD (LAN-CPD1)

CPD2:
  vCenter: vcenterprd02.tapnet.tap.pt
  Datacenter: TAP_CPD2
  Cluster: CPD2_ESX7
  Network: AUTOMTNPRD (LAN-CPD2)
```

### 4. For_Each (não Count)

- VMs identificadas por keys: `cpd1-1`, `cpd1-2`, `cpd2-1`
- Adicionar/remover VMs não afeta outras
- Destroy targeted: `terraform destroy -target='module.linux_vm["cpd1-2"]'`

---

## ⚠️ Troubleshooting

### "Failed to connect to vCenter"

```bash
# Verificar credenciais
echo $TF_VAR_vsphere_server
echo $TF_VAR_vsphere_user
# (não fazer echo de password)

# Testar conectividade
ping vcenterprd01.tapnet.tap.pt
```

### "VM name exceeds 15 characters"

Reduza `linux_vm_purpose`:

```hcl
linux_vm_purpose = "web"  # ao invés de "webapp"
```

Fórmula: `len(purpose + environment + "NN")` ≤ 15

### "State locked"

Outra execução em andamento. Aguarde ou:

```bash
terraform force-unlock <LOCK_ID>
```

### "No hosts found in cluster"

Verifique nomes (case-sensitive):

- Cluster: `CPD1_ESX7` (não cpd1_esx7)
- Datacenter: `TAP_CPD1` (não tap_cpd1)

---

## 📖 Documentação Completa

Documentos criados:

1. **[PROJECT-OVERVIEW.md](docs/PROJECT-OVERVIEW.md)** - Explicação completa de arquitetura e decisões
2. **[FINAL-REVIEW-CHECKLIST.md](docs/FINAL-REVIEW-CHECKLIST.md)** - Revisão detalhada de todos componentes
3. **[CPD-SELECTION.md](docs/CPD-SELECTION.md)** - Detalhes de seleção CPD
4. **[MULTI-CPD-DEPLOYMENT.md](docs/MULTI-CPD-DEPLOYMENT.md)** - Multi-CPD deployment
5. **[ESX-HOST-SELECTION.md](docs/ESX-HOST-SELECTION.md)** - Seleção de ESXi hosts
6. **[TESTE-TAP.md](docs/TESTE-TAP.md)** - Testes no ambiente TAP
7. **[WORKFLOW.md](docs/WORKFLOW.md)** - Workflow geral

---

## ✅ Status do Projeto

**Componentes**: ✅ 100% Revisados

- Módulos Terraform: naming, linux, windows
- Project template: main.tf, variables.tf, outputs.tf
- Scripts: configure.sh, deploy.sh, destroy.sh, auto-select-esx.sh
- Python: select-best-esx-host.py

**Issues Encontrados**: ✅ 0
**Status**: ✅ **PRONTO PARA POC**

---

## 🎯 Próximo Passo

Execute a POC com o comando:

```bash
bash scripts/configure.sh OPS-POC-001 tst <repo-url>
```

E siga os passos na seção "POC - Criar 1 VM em CPD1" acima.

Boa sorte! 🚀
