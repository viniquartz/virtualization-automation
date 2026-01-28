# Seleção Automática de ESXi Host

## 📖 Overview

O sistema suporta **três métodos** para selecionar o ESXi host onde as VMs serão criadas:

1. ✅ **Automático via DRS** (recomendado): vSphere DRS seleciona automaticamente
2. ✅ **Seleção Manual**: Especificar host ESXi específico
3. ✅ **Seleção Automática por Recursos**: Script consulta e seleciona host com mais recursos disponíveis

---

## 🎯 Método 1: DRS Automático (Recomendado)

### **Como Funciona**

Se você **não especificar** um host ESXi, o vSphere DRS (Distributed Resource Scheduler) automaticamente seleciona o melhor host baseado em:

- ✅ Recursos disponíveis (CPU, memória)
- ✅ Balanceamento de carga
- ✅ Regras de afinidade/anti-afinidade
- ✅ Políticas do cluster

### **Configuração**

Simplesmente **não defina** a variável `vsphere_esx_host`:

```hcl
# terraform.tfvars
# vsphere_esx_host não definido - DRS decide automaticamente
```

### **Vantagens**

- ✅ Totalmente automatizado
- ✅ Considera regras e políticas do cluster
- ✅ Sem dependências externas
- ✅ Rebalanceamento automático com vMotion

---

## 🎯 Método 2: Seleção Manual

### **Quando Usar**

- Requisitos específicos de compliance
- Testes em host específico
- Hardware dedicado (GPU, storage local)
- Isolamento de workloads

### **Configuração**

Especifique o FQDN do host ESXi:

```hcl
# terraform.tfvars
vsphere_esx_host = "esxprd109.tapnet.tap.pt"
```

### **Como Descobrir Hosts Disponíveis**

```bash
# Usando govc (VMware CLI)
govc find / -type h

# Usando PowerCLI
Get-VMHost | Select Name, ConnectionState, MemoryTotalGB, NumCpu
```

---

## 🎯 Método 3: Seleção Automática por Recursos

### **Como Funciona**

O script Python consulta todos os hosts ESXi no cluster e seleciona aquele com **mais recursos disponíveis** baseado em critérios configuráveis:

- **CPU**: Mais MHz disponíveis
- **Memory**: Mais MB disponíveis
- **Balanced** (padrão): Média de CPU e memória disponíveis

### **Pré-requisitos**

```bash
# Instalar biblioteca Python
pip3 install pyvmomi

# Exportar credenciais vSphere (já configuradas para Terraform)
export TF_VAR_vsphere_server="vcenterprd01.tapnet.tap.pt"
export TF_VAR_vsphere_user="vw_terraform@vsphere.local"
export TF_VAR_vsphere_password="your-password"
```

### **Uso Interativo**

```bash
# Seleção balanceada (CPU + memória)
python3 scripts/select-best-esx-host.py \
    --datacenter TAP_CPD1 \
    --cluster CPD1_ESX7

# Priorizar CPU disponível
python3 scripts/select-best-esx-host.py \
    --datacenter TAP_CPD1 \
    --cluster CPD1_ESX7 \
    --metric cpu

# Priorizar memória disponível
python3 scripts/select-best-esx-host.py \
    --datacenter TAP_CPD1 \
    --cluster CPD1_ESX7 \
    --metric memory

# Modo verbose (mostra todos os hosts)
python3 scripts/select-best-esx-host.py \
    --datacenter TAP_CPD1 \
    --cluster CPD1_ESX7 \
    --metric balanced \
    --verbose

# Output JSON (para parsing)
python3 scripts/select-best-esx-host.py \
    --datacenter TAP_CPD1 \
    --cluster CPD1_ESX7 \
    --format json
```

### **Uso com Terraform**

#### **Opção A: Export Manual**

```bash
# Selecionar e exportar
export TF_VAR_vsphere_esx_host=$(python3 scripts/select-best-esx-host.py \
    --datacenter TAP_CPD1 \
    --cluster CPD1_ESX7 \
    --metric balanced)

# Deploy
bash scripts/deploy.sh OPS-1234 tst
```

#### **Opção B: Script Wrapper**

```bash
# Usar wrapper bash (mais simples)
export TF_VAR_vsphere_esx_host=$(bash scripts/auto-select-esx.sh CPD1_ESX7 TAP_CPD1)

# Deploy
bash scripts/deploy.sh OPS-1234 tst
```

#### **Opção C: No terraform.tfvars**

```hcl
# NÃO funciona diretamente no .tfvars (não executa comandos)
# Precisa ser exportado antes do terraform plan/apply
```

---

## 📊 Exemplo de Output Verbose

```bash
$ python3 scripts/select-best-esx-host.py \
    --datacenter TAP_CPD1 \
    --cluster CPD1_ESX7 \
    --metric balanced \
    --verbose

=== All Hosts ===

Host: esxprd107.tapnet.tap.pt
  CPU Available: 23450 MHz (45.2%)
  Memory Available: 128000 MB (62.5%)
  VMs: 12
  Balanced Score: 53.9%

Host: esxprd108.tapnet.tap.pt
  CPU Available: 31200 MHz (60.1%)
  Memory Available: 156000 MB (76.2%)
  VMs: 8
  Balanced Score: 68.2%

Host: esxprd109.tapnet.tap.pt
  CPU Available: 28900 MHz (55.6%)
  Memory Available: 142000 MB (69.3%)
  VMs: 10
  Balanced Score: 62.5%

=== Selected Best Host: esxprd108.tapnet.tap.pt ===

esxprd108.tapnet.tap.pt
```

---

## 🔄 Workflow Completo

### **Deploy com Seleção Automática**

```bash
#!/bin/bash
set -e

# 1. Exportar credenciais vSphere
export TF_VAR_vsphere_server="vcenterprd01.tapnet.tap.pt"
export TF_VAR_vsphere_user="vw_terraform@vsphere.local"
export TF_VAR_vsphere_password="your-password"

# 2. Login Azure (backend)
bash scripts/azure-login.sh

# 3. Selecionar melhor ESXi host automaticamente
echo "Selecionando melhor ESXi host..."
BEST_HOST=$(bash scripts/auto-select-esx.sh CPD1_ESX7 TAP_CPD1)

if [ -n "$BEST_HOST" ]; then
    export TF_VAR_vsphere_esx_host="$BEST_HOST"
    echo "ESXi host selecionado: $BEST_HOST"
else
    echo "Usando seleção automática DRS"
fi

# 4. Configurar projeto
bash scripts/configure.sh OPS-1234 tst https://github.com/org/repo.git

# 5. Deploy
bash scripts/deploy.sh OPS-1234 tst
```

---

## ⚙️ Integração com Jenkins

### **Pipeline com Seleção de Host**

```groovy
pipeline {
    agent any
    
    parameters {
        choice(
            name: 'CPD',
            choices: ['cpd1', 'cpd2', 'both'],
            description: 'Select CPD'
        )
        choice(
            name: 'HOST_SELECTION',
            choices: ['drs', 'auto', 'manual'],
            description: 'ESXi host selection method'
        )
        string(
            name: 'MANUAL_HOST',
            defaultValue: '',
            description: 'Manual host FQDN (only if HOST_SELECTION=manual)'
        )
    }
    
    environment {
        TF_VAR_vsphere_server = credentials('vsphere-server')
        TF_VAR_vsphere_user = credentials('vsphere-user')
        TF_VAR_vsphere_password = credentials('vsphere-password')
    }
    
    stages {
        stage('Select ESXi Host') {
            steps {
                script {
                    if (params.HOST_SELECTION == 'auto') {
                        // Auto-select best host
                        def cluster = params.CPD == 'cpd1' ? 'CPD1_ESX7' : 'CPD2_ESX7'
                        def datacenter = params.CPD == 'cpd1' ? 'TAP_CPD1' : 'TAP_CPD2'
                        
                        def bestHost = sh(
                            script: """
                                bash scripts/auto-select-esx.sh ${cluster} ${datacenter}
                            """,
                            returnStdout: true
                        ).trim()
                        
                        if (bestHost) {
                            env.TF_VAR_vsphere_esx_host = bestHost
                            echo "Selected ESXi host: ${bestHost}"
                        } else {
                            echo "Using DRS automatic selection"
                        }
                    } else if (params.HOST_SELECTION == 'manual' && params.MANUAL_HOST) {
                        env.TF_VAR_vsphere_esx_host = params.MANUAL_HOST
                        echo "Using manual host: ${params.MANUAL_HOST}"
                    } else {
                        echo "Using DRS automatic selection"
                    }
                }
            }
        }
        
        stage('Deploy') {
            steps {
                sh """
                    bash scripts/deploy.sh ${params.TICKET_ID} ${params.ENVIRONMENT}
                """
            }
        }
    }
}
```

---

## 📋 Comparação dos Métodos

| Aspecto              | DRS Automático    | Manual           | Auto por Recursos |
|----------------------|-------------------|------------------|-------------------|
| **Complexidade**     | ✅ Baixa          | ✅ Baixa         | ⚠️ Média          |
| **Dependências**     | ✅ Nenhuma        | ✅ Nenhuma       | ❌ Python/pyvmomi |
| **Precisão**         | ✅ Cluster-aware  | ⚠️ Estático      | ✅ Tempo real     |
| **Flexibilidade**    | ⚠️ Limitada       | ✅ Total         | ✅ Configurável   |
| **Manutenção**       | ✅ Zero           | ⚠️ Manual        | ⚠️ Script updates |
| **Rebalanceamento**  | ✅ vMotion        | ❌ Manual        | ❌ Manual         |

---

## 🚨 Considerações Importantes

### **Quando NÃO Especificar Host**

❌ **Não recomendado especificar host quando:**

- Cluster tem DRS habilitado
- Workload pode ser migrado com vMotion
- Não há requisitos específicos de hardware
- Balanceamento automático é desejado

✅ **Recomendado especificar host quando:**

- Hardware específico necessário (GPU, local storage)
- Compliance ou segregação de dados
- Testes em hardware específico
- Troubleshooting ou isolamento

### **DRS vs Manual**

**DRS (Automático):**

- ✅ Considera todas as regras e políticas do cluster
- ✅ Rebalanceamento automático com vMotion
- ✅ Sem overhead operacional
- ✅ Melhor para produção

**Manual/Auto-Select:**

- ✅ Controle explícito de placement
- ✅ Útil para testes e troubleshooting
- ⚠️ Requer monitoramento manual
- ⚠️ Pode causar desbalanceamento

---

## 🔗 Arquivos Relacionados

- [select-best-esx-host.py](../scripts/select-best-esx-host.py) - Script Python principal
- [auto-select-esx.sh](../scripts/auto-select-esx.sh) - Wrapper bash
- [terraform.tfvars](../terraform-project-template/environments/tst/terraform.tfvars) - Configuração
- [variables.tf](../terraform-project-template/variables.tf) - Variável vsphere_esx_host

---

## 📚 Referências

- [VMware DRS Documentation](https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.resmgmt.doc/GUID-8ACF3502-5314-469F-8CC9-4A9BD5925BC2.html)
- [pyvmomi GitHub](https://github.com/vmware/pyvmomi)
- [Terraform vSphere Provider](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs)
