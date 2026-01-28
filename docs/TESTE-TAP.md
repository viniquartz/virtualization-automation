# Guia de Teste - TAP Infrastructure

## Pré-requisitos

### 1. Credenciais vCenter

```bash
# Exportar credenciais (não commitar!)
export TF_VAR_vsphere_server="vcenterprd01.tapnet.tap.pt"
export TF_VAR_vsphere_user="vw_terraform@vsphere.local"
export TF_VAR_vsphere_password="cmfK!or!wpt!vs!e15gr"
```

### 2. Credenciais Azure (Backend)

```bash
# Service Principal para Azure Storage backend
export ARM_CLIENT_ID="xxx"
export ARM_CLIENT_SECRET="xxx"
export ARM_SUBSCRIPTION_ID="xxx"
export ARM_TENANT_ID="xxx"
```

## Infraestrutura TAP

### VCENTER 01 (CPD1)

- **URL:** vcenterprd01.tapnet.tap.pt
- **Datacenter:** TAP_CPD1
- **Cluster:** CPD1_ESX7
- **Instâncias:** Números ímpares (01, 03, 05, 07...)

### VCENTER 02 (CPD2)

- **URL:** vcenterprd02.tapnet.tap.pt
- **Datacenter:** TAP_CPD2
- **Cluster:** CPD2_ESX7
- **Instâncias:** Números pares (02, 04, 06, 08...)

## Naming Convention

### Padrão: `<PURPOSE><ENVIRONMENT><INSTANCE>`

**Exemplos:**

- `IACTST01` = IAC + TST + 01 (CPD1)
- `WEBPRD02` = WEB + PRD + 02 (CPD2)
- `APPQLT03` = APP + QLT + 03 (CPD1)
- `DBPRD04` = DB + PRD + 04 (CPD2)

**Regras:**

- Máximo 15 caracteres
- SEM hífens
- Uppercase no VMware
- Lowercase no hostname (DNS)
- CPD1 = instâncias ímpares
- CPD2 = instâncias pares

### Purpose Codes (3 chars)

| Code | Description |
|------|-------------|
| IAC | Infrastructure as Code (teste) |
| WEB | Web Server |
| APP | Application Server |
| SRV | General Server |
| DB | Database Server |
| AD | Active Directory |
| DNS | DNS Server |

### Environment Codes (3 chars)

| Code | Environment |
|------|-------------|
| TST | Test |
| QLT | Quality |
| PRD | Production |

## Teste 1: VM Linux no CPD1

### 1. Autenticar no Azure

```bash
cd /path/to/virtualization-automation
bash scripts/azure-login.sh
```

### 2. Configurar Projeto

```bash
# Clone e setup com backend
bash scripts/configure.sh OPS-1234 tst https://github.com/yourorg/virtualization-automation.git
```

### 3. Ajustar Configuração

```bash
cd OPS-1234
vi environments/tst/terraform.tfvars
```

Verificar/ajustar:

```hcl
# Naming: IACTST01 (IAC + TST + 01)
linux_vm_purpose      = "iac"
linux_instance_number = 1  # CPD1 = ímpar

# Resources
linux_cpu_count    = 1
linux_memory_mb    = 2048
linux_disk_size_gb = 16

# vSphere
vsphere_datacenter = "TAP_CPD1"
vsphere_cluster    = "CPD1_ESX7"
vsphere_datastore  = "PS04_ESX2_CPDMIG"
vsphere_network    = "AUTOMTNPRD (LAN-CPD1)"

# Network (ajustar conforme necessário)
linux_ipv4_address   = "10.x.x.10"
network_ipv4_gateway = "10.x.x.1"
network_dns_servers  = ["10.x.x.10", "10.x.x.11"]
```

### 4. Validar e Deploy

```bash
# Validar configuração
terraform validate

# Ver o que será criado
terraform plan -var-file="environments/tst/terraform.tfvars"

# Aplicar (com confirmação)
cd ..
bash scripts/deploy.sh OPS-1234 tst
```

## Teste 2: VM Windows no CPD2

Editar `environments/tst/terraform.tfvars`:

```hcl
# Naming: SRVTST02 (SRV + TST + 02)
create_windows_vm         = true
windows_vm_purpose        = "srv"
windows_instance_number   = 2  # CPD2 = par

# Mudar para CPD2
vsphere_datacenter = "TAP_CPD2"
vsphere_cluster    = "CPD2_ESX7"

# Network
windows_ipv4_address = "10.x.x.20"
```

## Verificação

### Ver recursos criados

```bash
cd OPS-1234
terraform state list
terraform output
```

### Conectar na VM

```bash
# Linux
ssh user@10.x.x.10

# Verificar hostname
hostname  # deve retornar: iactst01
```

### Ver no vCenter

- VM Name: IACTST01
- Folder: TerraformTests (ou padrão)
- Host: esxprdXXX.tapnet.tap.pt
- Network: AUTOMTNPRD (LAN-CPD1)

## Destruir Recursos

```bash
bash scripts/destroy.sh OPS-1234 tst
```

## Troubleshooting

### Erro: vCenter authentication failed

```bash
# Verificar variáveis
echo $TF_VAR_vsphere_server
echo $TF_VAR_vsphere_user
# Não mostrar password: echo $TF_VAR_vsphere_password | wc -c

# Testar conectividade
ping vcenterprd01.tapnet.tap.pt
```

### Erro: Datastore não encontrado

Verificar datastores disponíveis no vCenter e atualizar em `terraform.tfvars`:

```hcl
vsphere_datastore = "PS04_ESX2_CPDMIG"  # ou outro disponível
```

### Erro: Network não encontrada

Verificar networks disponíveis e ajustar:

```hcl
vsphere_network = "AUTOMTNPRD (LAN-CPD1)"
```

### VM com nome errado

Verificar no `terraform.tfvars`:

```hcl
# Purpose: 3 caracteres
linux_vm_purpose = "iac"  # não "test" ou "linux"

# Instance: número correto
linux_instance_number = 1  # ímpar para CPD1
```

## Próximos Passos

1. ✅ Testar criação de VM Linux no CPD1
2. ✅ Testar criação de VM Windows no CPD2
3. 🔄 Criar módulo para discos adicionais
4. 🔄 Implementar lógica para múltiplos CPDs
5. 🔄 Adicionar seleção automática de ESX
6. 🔄 Integrar com cloud-init
7. 🔄 Configurar pipelines Jenkins

## Notas Importantes

- **Credenciais:** NUNCA commitar credenciais! Sempre usar variáveis de ambiente
- **Naming:** Seguir rigorosamente o padrão sem hífens
- **CPD1/CPD2:** Respeitar a regra ímpar/par para distribuição
- **Templates:** Verificar que templates existem no vCenter antes de usar
- **Network:** IPs devem estar livres na rede antes de atribuir
