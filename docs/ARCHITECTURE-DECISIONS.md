# Resumo de Decisões de Arquitetura

Este documento resume todas as decisões de arquitetura tomadas durante o desenvolvimento do projeto.

---

## 1️⃣ Sem Templates VMware

**Decisão**: Criar VMs do zero usando apenas `guest_id`, sem clonar templates.

**Motivo**:

- Elimina dependência de templates no vCenter
- Reduz manutenção (não precisa atualizar templates)
- Mais flexível (qualquer guest OS suportado)
- Configuração real via Ansible pós-deploy

**Implementação**:

```hcl
resource "vsphere_virtual_machine" "vm" {
  guest_id = var.guest_id  # rhel9_64Guest, windows2019srvNext_64Guest
  # Sem: data.vsphere_virtual_machine.template
}
```

---

## 2️⃣ Configuração Baseada em CPD

**Decisão**: Toda infraestrutura derivada automaticamente da seleção de CPD.

**Motivo**:

- Garante consistência (recursos corretos por datacenter)
- Simplifica config (usuário define apenas `cpd = "cpd1"`)
- Previne erros (impossível misturar CPDs)

**Implementação**:

```hcl
locals {
  cpd_config = {
    cpd1 = { datacenter = "TAP_CPD1", cluster = "CPD1_ESX7", ... }
    cpd2 = { datacenter = "TAP_CPD2", cluster = "CPD2_ESX7", ... }
  }
}
```

---

## 3️⃣ Instance Number Auto-Calculado

**Decisão**: Instance number NÃO é variável - é calculado automaticamente.

**Motivo**:

- Previne conflitos (mesma instance em CPDs diferentes)
- Garante paridade (CPD1=ímpar, CPD2=par)
- Simplifica replicação (cpd="both" gera pares corretos)

**Fórmula**:

```
CPD1: instance = sequence * 2 - 1  (resulta em ímpar)
CPD2: instance = sequence * 2      (resulta em par)
```

**Exemplos**:

- CPD1 seq=1 → inst=01, seq=2 → inst=03, seq=3 → inst=05
- CPD2 seq=1 → inst=02, seq=2 → inst=04, seq=3 → inst=06

**tfvars**:

```hcl
linux_vm_start_sequence = 1  # Começar na sequência 1
linux_vm_count = 3            # Criar 3 VMs
# Não existe: linux_instance_number
```

---

## 4️⃣ Multi-CPD Deployment

**Decisão**: Suportar criação em ambos CPDs simultaneamente.

**Motivo**:

- High Availability (pares de VMs em datacenters diferentes)
- Disaster Recovery (infra replicada)
- Eficiência (uma execução cria tudo)

**Implementação**:

```hcl
cpd = "both"  # ou "cpd1" ou "cpd2"

locals {
  target_cpds = var.cpd == "both" ? ["cpd1", "cpd2"] : [var.cpd]
}
```

**Resultado com `cpd="both"`, `count=2`, `seq=1`, `purpose="web"`**:

- CPD1: WEBPRD01, WEBPRD03
- CPD2: WEBPRD02, WEBPRD04

---

## 5️⃣ Múltiplas VMs com vm_count

**Decisão**: Criar múltiplas VMs usando count + sequence, não variáveis individuais.

**Motivo**:

- Eficiência (criar 10 VMs sem repetir config)
- Consistência (todas VMs mesma configuração)
- Manutenção (alterar uma vez afeta todas)

**Implementação**:

```hcl
linux_vm_count = 5
linux_vm_start_sequence = 10
# Cria VMs com sequences: 10, 11, 12, 13, 14
```

**Limites**: count 1-10, sequence 1-90

---

## 6️⃣ For_Each (não Count)

**Decisão**: Usar `for_each` em maps, não `count` com índices.

**Motivo**:

- Flexibilidade (adicionar/remover VMs sem recriar outras)
- Identificação significativa (keys: "cpd1-1", "cpd2-3")
- Targeted operations (`terraform destroy -target=...["cpd1-2"]`)
- Evita reordenação (remover VM do meio é seguro)

**Implementação**:

```hcl
linux_vms = {
  "cpd1-1" => { cpd = "cpd1", sequence = 1 }
  "cpd1-2" => { cpd = "cpd1", sequence = 2 }
}

module "linux_vm" {
  for_each = local.linux_vms  # ← Não count
}
```

---

## 7️⃣ Seleção de ESXi Host

**Decisão**: Três opções - DRS automático (padrão), manual, ou auto-select inteligente.

**Motivo**:

- DRS geralmente suficiente
- Casos especiais requerem host específico
- Auto-select maximiza recursos disponíveis

**Opções**:

1. **DRS Automático (padrão)**:

   ```hcl
   vsphere_esx_host = null
   ```

2. **Manual**:

   ```hcl
   vsphere_esx_host = "esxprd109.tapnet.tap.pt"
   ```

3. **Auto-Select via Python**:

   ```bash
   export TF_VAR_vsphere_esx_host=$(bash scripts/auto-select-esx.sh CPD1_ESX7 TAP_CPD1)
   ```

**Script Python**:

- Consulta hosts via pyvmomi
- Calcula recursos disponíveis (CPU MHz, Memory MB)
- Seleciona por métrica: cpu, memory, balanced

---

## 8️⃣ Discos no VM Resource

**Decisão**: Discos adicionais configurados dentro do resource da VM, não módulo separado.

**Motivo**:

- Limitação do provider (não suporta `vsphere_virtual_disk` separado)
- Vinculação obrigatória (discos devem estar no bloco `vsphere_virtual_machine`)

**Implementação**:

```hcl
resource "vsphere_virtual_machine" "vm" {
  disk { ... }  # Primário
  
  dynamic "disk" {
    for_each = var.additional_disks
    content { ... }
  }
}
```

**Config**:

```hcl
linux_additional_disks = [
  { label = "data", size_gb = 100, unit_number = 1 },
  { label = "logs", size_gb = 50, unit_number = 2 }
]
```

**Não criamos presets**: Config manual mais flexível.

---

## 9️⃣ Nomenclatura

**Decisão**: `<PURPOSE><ENVIRONMENT><INSTANCE>` sem hífens, uppercase.

**Motivo**:

- Limite NetBIOS (15 caracteres)
- Consistência Linux/Windows
- Uppercase facilita identificação
- Paridade visual (CPD1=ímpar, CPD2=par)

**Formato**:

- PURPOSE: 2-6 chars (web, app, db, iac)
- ENVIRONMENT: 3 chars (prd, qlt, tst)
- INSTANCE: 2 digits (01-99)

**Exemplos**: IACTST01, WEBPRD02, DBQLT03

**Hostname**: Lowercase para DNS (iactst01.tapnet.tap.pt)

---

## 🔟 Backend Azure Storage

**Decisão**: State remoto no Azure Storage Account.

**Motivo**:

- Colaboração (múltiplos usuários)
- State locking (previne execuções simultâneas)
- Backup e durabilidade
- Auditoria (histórico de mudanças)

**Config**:

```hcl
backend "azurerm" {
  storage_account_name = "azrprdiac01weust01"
  container_name       = "terraform-states"
  key                  = "vmware/OPS-1234.tfstate"
  use_azuread_auth     = true
}
```

**Isolamento**: Um state file por ticket.

---

## 1️⃣1️⃣ Credenciais via Env Vars

**Decisão**: Credenciais vSphere APENAS via variáveis de ambiente.

**Motivo**:

- Segurança (evita Git)
- Compliance
- Rotação fácil
- CI/CD ready

**Obrigatórias**:

```bash
export TF_VAR_vsphere_server="vcenterprd01.tapnet.tap.pt"
export TF_VAR_vsphere_user="vw_terraform@vsphere.local"
export TF_VAR_vsphere_password="***"
```

**Validação**: Scripts verificam antes de executar.

---

## Infraestrutura TAP

### vCenters

- CPD1: vcenterprd01.tapnet.tap.pt
- CPD2: vcenterprd02.tapnet.tap.pt

### Defaults

- Datastore: PS04_ESX2_CPDMIG
- Folder: TerraformTests
- Network adapter: vmxnet3

### CPD1

- Datacenter: TAP_CPD1
- Cluster: CPD1_ESX7
- Network: AUTOMTNPRD (LAN-CPD1)

### CPD2

- Datacenter: TAP_CPD2
- Cluster: CPD2_ESX7
- Network: AUTOMTNPRD (LAN-CPD2)

---

## Fluxo de Trabalho

```
1. azure-login.sh     → Autenticar Azure
2. configure.sh       → Clonar repo + init Terraform
3. Editar tfvars      → Configurar VMs
4. Exportar TF_VAR_*  → Credenciais vSphere
5. deploy.sh          → Plan + Apply
6. Validar            → Verificar VMs no vCenter
7. destroy.sh         → Limpar (se necessário)
```

---

## Exemplo Completo - POC

**terraform.tfvars**:

```hcl
environment  = "tst"
project_name = "poc"
ticket_id    = "OPS-POC-001"

cpd                     = "cpd1"
create_linux_vm         = true
linux_vm_purpose        = "iac"
linux_vm_count          = 1
linux_vm_start_sequence = 1
linux_cpu_count         = 2
linux_memory_mb         = 4096
linux_disk_size_gb      = 50
linux_guest_id          = "rhel9_64Guest"

network_domain       = "tapnet.tap.pt"
linux_ipv4_address   = "10.190.10.10"
network_ipv4_gateway = "10.190.10.1"
network_ipv4_netmask = 24
network_dns_servers  = ["10.190.1.10", "10.190.1.11"]

vsphere_datastore = "PS04_ESX2_CPDMIG"
vsphere_folder    = "TerraformTests"

create_windows_vm = false
```

**Resultado**: VM `IACTST01` no CPD1 (TAP_CPD1, CPD1_ESX7).

---

## Status Final

✅ **Todas decisões implementadas e validadas**
✅ **Módulos prontos**: naming, linux, windows
✅ **Scripts prontos**: configure, deploy, destroy, auto-select-esx
✅ **Documentação completa**: 7 documentos
✅ **Pronto para POC**

---

**Autor**: Automação TAP  
**Data**: 2024  
**Status**: ✅ PRONTO PARA PRODUÇÃO
