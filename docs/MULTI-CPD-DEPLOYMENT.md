# Multi-CPD Deployment e Múltiplas VMs

## 📖 Overview

O projeto suporta **deployment em múltiplos CPDs** e **criação de múltiplas VMs** com a mesma configuração, permitindo:

1. ✅ Criar múltiplas VMs em um único CPD
2. ✅ Replicar VMs idênticas em ambos CPDs (high availability)
3. ✅ Controlar quantidade e sequência inicial de VMs
4. ✅ Instance numbers calculados automaticamente baseado no CPD

---

## 🎯 Modos de Deployment

### **Modo 1: Single CPD**

Deploy apenas em um CPD específico:

```hcl
cpd = "cpd1"  # ou "cpd2"
```

### **Modo 2: Both CPDs (Replicação)**

Deploy nos dois CPDs simultaneamente:

```hcl
cpd = "both"
```

---

## 🔢 Configuração de Quantidade

### **Variáveis de Quantidade**

```hcl
# Linux VMs
linux_vm_count         = 2    # Quantidade de VMs por CPD
linux_vm_start_sequence = 1   # Sequência inicial

# Windows VMs
windows_vm_count         = 3    # Quantidade de VMs por CPD
windows_vm_start_sequence = 1   # Sequência inicial
```

### **Como Funciona:**

- **vm_count**: Quantidade de VMs a criar **por CPD**
- **start_sequence**: Número inicial da sequência (normalmente 1)
- Instance numbers são calculados automaticamente

---

## 📊 Exemplos Práticos

### **Exemplo 1: 1 VM Linux no CPD1**

```hcl
cpd                     = "cpd1"
create_linux_vm         = true
linux_vm_purpose        = "web"
linux_vm_count          = 1
linux_vm_start_sequence = 1
```

**Resultado:**

- ✅ 1 VM criada: **WEBTST01** (CPD1)

---

### **Exemplo 2: 3 VMs Linux no CPD1**

```hcl
cpd                     = "cpd1"
create_linux_vm         = true
linux_vm_purpose        = "app"
linux_vm_count          = 3
linux_vm_start_sequence = 1
```

**Resultado:**

- ✅ 3 VMs criadas no CPD1:
  - **APPTST01** (sequence 1 → instance 01)
  - **APPTST03** (sequence 2 → instance 03)
  - **APPTST05** (sequence 3 → instance 05)

---

### **Exemplo 3: 1 VM replicada em AMBOS CPDs**

```hcl
cpd                     = "both"
create_linux_vm         = true
linux_vm_purpose        = "db"
linux_vm_count          = 1
linux_vm_start_sequence = 1
```

**Resultado:**

- ✅ 2 VMs criadas (1 por CPD):
  - **DBTST01** (CPD1 - sequence 1 → instance 01)
  - **DBTST02** (CPD2 - sequence 1 → instance 02)

---

### **Exemplo 4: 2 VMs replicadas em AMBOS CPDs**

```hcl
cpd                     = "both"
create_linux_vm         = true
linux_vm_purpose        = "iac"
linux_vm_count          = 2
linux_vm_start_sequence = 1
```

**Resultado:**

- ✅ 4 VMs criadas (2 por CPD):
  - **CPD1**: IACTST01, IACTST03
  - **CPD2**: IACTST02, IACTST04

---

### **Exemplo 5: Mix Linux + Windows em AMBOS CPDs**

```hcl
cpd = "both"

# 1 Linux VM
create_linux_vm         = true
linux_vm_purpose        = "web"
linux_vm_count          = 1
linux_vm_start_sequence = 1

# 2 Windows VMs
create_windows_vm         = true
windows_vm_purpose        = "app"
windows_vm_count          = 2
windows_vm_start_sequence = 1
```

**Resultado:**

- ✅ **6 VMs criadas (3 por CPD):**

**CPD1:**

- WEBTST01 (Linux)
- APPTST01 (Windows)
- APPTST03 (Windows)

**CPD2:**

- WEBTST02 (Linux)
- APPTST02 (Windows)
- APPTST04 (Windows)

---

## 🧮 Tabela de Conversão

### **CPD1 (Ímpares)**

| Sequence | Instance | Exemplo     |
|----------|----------|-------------|
| 1        | 01       | IACTST01    |
| 2        | 03       | IACTST03    |
| 3        | 05       | IACTST05    |
| 4        | 07       | IACTST07    |
| 5        | 09       | IACTST09    |

### **CPD2 (Pares)**

| Sequence | Instance | Exemplo     |
|----------|----------|-------------|
| 1        | 02       | IACTST02    |
| 2        | 04       | IACTST04    |
| 3        | 06       | IACTST06    |
| 4        | 08       | IACTST08    |
| 5        | 10       | IACTST10    |

---

## 🎛️ Controle de Sequência

### **Start Sequence Customizado**

Se você já tem VMs e quer começar de um número específico:

```hcl
cpd                     = "cpd1"
linux_vm_count          = 2
linux_vm_start_sequence = 5  # Começa da sequência 5
```

**Resultado:**

- ✅ IACTST09 (sequence 5 → instance 09)
- ✅ IACTST11 (sequence 6 → instance 11)

---

## 📤 Outputs

O Terraform retorna informações detalhadas de todas as VMs criadas:

```hcl
# Output exemplo
linux_vms = {
  "cpd1-1" = {
    vm_name     = "IACTST01"
    vm_ip       = "10.x.x.10"
    vm_uuid     = "421234..."
    cpd         = "cpd1"
    sequence    = 1
  }
  "cpd1-2" = {
    vm_name     = "IACTST03"
    vm_ip       = "10.x.x.11"
    vm_uuid     = "421235..."
    cpd         = "cpd1"
    sequence    = 2
  }
}

deployment_summary = {
  environment   = "tst"
  cpd_selection = "cpd1"
  linux_vms     = 2
  windows_vms   = 0
  total_vms     = 2
}
```

---

## ⚙️ Integração com Jenkins

### **Exemplo de Pipeline Jenkins**

```groovy
parameters {
    choice(
        name: 'CPD',
        choices: ['cpd1', 'cpd2', 'both'],
        description: 'Select CPD for deployment'
    )
    string(
        name: 'LINUX_VM_COUNT',
        defaultValue: '1',
        description: 'Number of Linux VMs to create per CPD'
    )
    string(
        name: 'WINDOWS_VM_COUNT',
        defaultValue: '0',
        description: 'Number of Windows VMs to create per CPD'
    )
}

stages {
    stage('Deploy VMs') {
        steps {
            script {
                sh """
                    terraform apply \
                        -var="cpd=${params.CPD}" \
                        -var="linux_vm_count=${params.LINUX_VM_COUNT}" \
                        -var="windows_vm_count=${params.WINDOWS_VM_COUNT}" \
                        -auto-approve
                """
            }
        }
    }
}
```

### **Cenários Jenkins:**

**Cenário 1: Deploy Single CPD**

- CPD: `cpd1`
- LINUX_VM_COUNT: `3`
- Resultado: 3 VMs no CPD1

**Cenário 2: Replicação HA**

- CPD: `both`
- LINUX_VM_COUNT: `2`
- WINDOWS_VM_COUNT: `1`
- Resultado: 6 VMs total (3 por CPD)

---

## 📋 Casos de Uso

### **1. High Availability (HA)**

```hcl
cpd = "both"
linux_vm_count = 1
# Cria VM idêntica em ambos CPDs para HA
```

### **2. Horizontal Scaling**

```hcl
cpd = "cpd1"
linux_vm_count = 5
# Cria 5 VMs no mesmo CPD para load balancing
```

### **3. Disaster Recovery (DR)**

```hcl
# Production em CPD1
cpd = "cpd1"
linux_vm_count = 2

# DR replica em CPD2 (executar separadamente)
cpd = "cpd2"
linux_vm_count = 2
```

### **4. Multi-Region**

```hcl
cpd = "both"
linux_vm_count = 3
windows_vm_count = 2
# Total: 10 VMs (5 por CPD) para arquitetura multi-região
```

---

## ⚠️ Limitações

### **IP Addressing**

⚠️ **Atenção:** Atualmente, todas as VMs usam o mesmo IP configurado em `linux_ipv4_address` ou `windows_ipv4_address`.

**Recomendação:** Para múltiplas VMs:

- Use DHCP temporariamente
- Ou configure IPs via Cloud-init/Ansible após o deploy

### **Limites**

- Máximo: **10 VMs por tipo por CPD**
- Sequence: 1 a 90 (validado)
- Instance: 01 a 99 (calculado)

---

## 🔗 Estrutura Interna (Terraform)

### **Como o For_Each Funciona**

```hcl
# Cria map de VMs a deployar
locals {
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
}

# Exemplo resultado com cpd=both, count=2:
# {
#   "cpd1-1" = {cpd="cpd1", sequence=1}
#   "cpd1-2" = {cpd="cpd1", sequence=2}
#   "cpd2-1" = {cpd="cpd2", sequence=1}
#   "cpd2-2" = {cpd="cpd2", sequence=2}
# }
```

---

## ✅ Checklist de Deploy

- [ ] Definir `cpd` (cpd1, cpd2, ou both)
- [ ] Configurar `vm_count` (quantas VMs por CPD)
- [ ] Definir `start_sequence` (normalmente 1)
- [ ] Configurar purpose (3 caracteres)
- [ ] Ajustar recursos (CPU, RAM, Disk)
- [ ] Validar network/storage settings
- [ ] Executar `terraform plan` para revisar
- [ ] Aplicar com `terraform apply`
- [ ] Verificar outputs para confirmar VMs criadas

---

## 🔗 Referências

- [CPD Selection Guide](CPD-SELECTION.md) - Detalhes sobre seleção de CPD
- [TESTE-TAP.md](TESTE-TAP.md) - Guia de testes TAP
- [WORKFLOW.md](WORKFLOW.md) - Workflow completo
