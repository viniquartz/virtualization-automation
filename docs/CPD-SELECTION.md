# Seleção de CPD e Instance Number Automático

## 📖 Overview

O projeto suporta **seleção automática de CPD** (Centro de Processamento de Dados), que configura automaticamente a infraestrutura vSphere e calcula o instance number baseado na paridade.

## 🎯 Como Funciona

### **Seleção de CPD**

Ao definir a variável `cpd`, o sistema automaticamente configura:

```hcl
cpd = "cpd1"  # ou "cpd2"
```

#### **CPD1** (vcenterprd01.tapnet.tap.pt)

- **Datacenter**: `TAP_CPD1`
- **Cluster**: `CPD1_ESX7`
- **Network**: `AUTOMTNPRD (LAN-CPD1)`
- **Instance Numbers**: **Ímpares** (01, 03, 05, 07, ...)

#### **CPD2** (vcenterprd02.tapnet.tap.pt)

- **Datacenter**: `TAP_CPD2`
- **Cluster**: `CPD2_ESX7`
- **Network**: `AUTOMTNPRD (LAN-CPD2)`
- **Instance Numbers**: **Pares** (02, 04, 06, 08, ...)

---

## 🔢 Cálculo Automático de Instance Number

O **instance number** é calculado automaticamente baseado em:

- **CPD selecionado** (cpd1 ou cpd2)
- **Sequence number** da VM (1, 2, 3, ...)

### **Fórmula:**

```
CPD1: instance_number = vm_sequence * 2 - 1
CPD2: instance_number = vm_sequence * 2
```

### **Exemplos:**

| VM Sequence | CPD1 Instance | CPD2 Instance | Nome CPD1   | Nome CPD2   |
|-------------|---------------|---------------|-------------|-------------|
| 1           | 01            | 02            | IACTST01    | IACTST02    |
| 2           | 03            | 04            | IACTST03    | IACTST04    |
| 3           | 05            | 06            | IACTST05    | IACTST06    |
| 4           | 07            | 08            | IACTST07    | IACTST08    |

---

## 📝 Configuração no terraform.tfvars

### **Exemplo 1: VM Linux no CPD1**

```hcl
# Seleção de CPD
cpd = "cpd1"

# Linux VM
linux_vm_purpose  = "iac"
linux_vm_sequence = 1    # Resulta em instance 01 → IACTST01
```

### **Exemplo 2: VM Windows no CPD2**

```hcl
# Seleção de CPD
cpd = "cpd2"

# Windows VM
windows_vm_purpose  = "srv"
windows_vm_sequence = 1     # Resulta em instance 02 → SRVTST02
```

### **Exemplo 3: Segunda VM Linux no CPD1**

```hcl
# Seleção de CPD
cpd = "cpd1"

# Linux VM
linux_vm_purpose  = "web"
linux_vm_sequence = 2       # Resulta em instance 03 → WEBTST03
```

---

## 🎛️ Valores Padrão e Overrides

### **Valores Automáticos (baseados no CPD)**

Quando você define `cpd = "cpd1"` ou `cpd = "cpd2"`, os seguintes valores são configurados automaticamente:

```hcl
# Não é necessário definir (valores automáticos):
# vsphere_datacenter = "TAP_CPD1"  # ou TAP_CPD2
# vsphere_cluster    = "CPD1_ESX7" # ou CPD2_ESX7
# vsphere_network    = "AUTOMTNPRD (LAN-CPD1)" # ou LAN-CPD2
```

### **Valores Padrão (TAP Standard)**

```hcl
vsphere_datastore = "PS04_ESX2_CPDMIG"  # Default
vsphere_folder    = "TerraformTests"     # Default
```

### **Override Manual (Opcional)**

Se necessário, você pode sobrescrever qualquer valor:

```hcl
cpd = "cpd1"

# Override manual (opcional)
vsphere_datacenter = "TAP_CPD1_CUSTOM"
vsphere_cluster    = "CUSTOM_CLUSTER"
vsphere_network    = "CUSTOM_NETWORK"
vsphere_datastore  = "CUSTOM_DATASTORE"
vsphere_folder     = "CustomFolder"
```

---

## 🧪 Exemplos Práticos

### **Cenário 1: Deploy de 2 VMs Linux no CPD1**

**Primeira VM:**

```hcl
cpd                 = "cpd1"
linux_vm_purpose    = "web"
linux_vm_sequence   = 1
# Resultado: WEBTST01
```

**Segunda VM:**

```hcl
cpd                 = "cpd1"
linux_vm_purpose    = "app"
linux_vm_sequence   = 2
# Resultado: APPTST03
```

### **Cenário 2: Deploy de 1 VM Windows no CPD2**

```hcl
cpd                  = "cpd2"
windows_vm_purpose   = "db"
windows_vm_sequence  = 1
# Resultado: DBTST02
```

### **Cenário 3: Deploy em Ambos CPDs (Replicação)**

Para replicar a mesma VM nos dois CPDs, você precisaria executar o Terraform duas vezes com configurações diferentes:

**Deploy CPD1:**

```bash
# environments/tst/terraform.tfvars
cpd = "cpd1"
linux_vm_purpose  = "iac"
linux_vm_sequence = 1
# Resultado: IACTST01 no CPD1
```

**Deploy CPD2:**

```bash
# environments/tst/terraform.tfvars (alterar cpd)
cpd = "cpd2"
linux_vm_purpose  = "iac"
linux_vm_sequence = 1
# Resultado: IACTST02 no CPD2
```

---

## ⚙️ Como o Jenkins Usa CPD

No Jenkins Pipeline, o usuário seleciona o CPD via parâmetro:

```groovy
parameters {
    choice(
        name: 'CPD',
        choices: ['cpd1', 'cpd2', 'both'],
        description: 'Select CPD for deployment'
    )
}

stages {
    stage('Deploy') {
        steps {
            script {
                if (params.CPD == 'both') {
                    // Deploy em ambos CPDs
                    sh "terraform apply -var='cpd=cpd1' ..."
                    sh "terraform apply -var='cpd=cpd2' ..."
                } else {
                    // Deploy em CPD específico
                    sh "terraform apply -var='cpd=${params.CPD}' ..."
                }
            }
        }
    }
}
```

---

## 📊 Resumo

| Aspecto              | CPD1                        | CPD2                        |
|----------------------|-----------------------------|-----------------------------|
| **vCenter**          | vcenterprd01.tapnet.tap.pt  | vcenterprd02.tapnet.tap.pt  |
| **Datacenter**       | TAP_CPD1                    | TAP_CPD2                    |
| **Cluster**          | CPD1_ESX7                   | CPD2_ESX7                   |
| **Network**          | AUTOMTNPRD (LAN-CPD1)       | AUTOMTNPRD (LAN-CPD2)       |
| **Instance Numbers** | Ímpares (01, 03, 05, ...)   | Pares (02, 04, 06, ...)     |
| **Fórmula**          | `sequence * 2 - 1`          | `sequence * 2`              |

---

## ✅ Benefícios

1. ✅ **Automação Total**: Não precisa calcular instance number manualmente
2. ✅ **Menos Erros**: Paridade garantida por código
3. ✅ **Consistência**: Naming convention sempre correto
4. ✅ **Simplicidade**: Apenas define CPD e sequence
5. ✅ **Flexibilidade**: Pode sobrescrever valores se necessário
6. ✅ **Integração Jenkins**: Fácil seleção via parâmetros

---

## 🔗 Referências

- [TESTE-TAP.md](TESTE-TAP.md) - Guia de testes TAP
- [WORKFLOW.md](WORKFLOW.md) - Workflow completo
- [terraform-modules/naming/](../terraform-modules/naming/) - Módulo de naming
