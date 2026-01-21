# Jenkins Pipelines - VMware Automation

Pipelines Jenkins para automação de infraestrutura VMware vSphere usando Terraform.

## 📋 Pipelines Disponíveis

### 1. terraform-modules-validation-job.groovy

Valida todos os módulos Terraform antes de release/versionamento.

**Quando usar:**
- Antes de criar release/tag de nova versão
- Em Pull Requests que modificam módulos
- Validação periódica de qualidade

**Validações:**
- ✅ Formato Terraform (`terraform fmt -check`)
- ✅ Sintaxe e validação (`terraform validate`)
- ✅ Segurança (Trivy scan)
- ✅ Documentação (README.md, variables, outputs)
- ✅ Qualidade de código

**Parâmetros:**
- `MODULE_REPO_URL` - URL do repositório de módulos
- `GIT_BRANCH` - Branch a validar (default: main)

---

### 2. terraform-validation-job.groovy

Valida projeto Terraform antes de merge.

**Quando usar:**
- Em todos os Pull Requests
- Antes de deploy em qualquer ambiente
- Validação pré-merge obrigatória

**Validações:**
- ✅ Formato Terraform
- ✅ Sintaxe e validação
- ✅ Security scan

**Parâmetros:**
- `GIT_REPO_URL` - URL do repositório
- `GIT_BRANCH` - Branch a validar

---

### 3. terraform-deploy-job.groovy

Deploy de infraestrutura VMware.

**Quando usar:**
- Deploy de novas VMs
- Atualização de infraestrutura existente
- Alterações aprovadas via Jira

**Features:**
- ✅ Validação de código
- ✅ Security scan
- ✅ Configuração automática de backend
- ✅ Plan com revisão
- ✅ Aprovação obrigatória (production)
- ✅ Apply com outputs

**Parâmetros:**
- `TICKET_ID` - ID do ticket Jira (ex: OPS-1234)
- `ENVIRONMENT` - Ambiente (tst/qlt/prd)
- `ACTION` - Ação (plan/apply)
- `GIT_BRANCH` - Branch (default: main)
- `GIT_REPO_URL` - URL do repositório

**Aprovadores:**
- **TST/QLT:** devops-team (timeout: 2h)
- **PRD:** infrastructure-leads (timeout: 4h)

---

### 4. terraform-destroy-job.groovy

Destruição de infraestrutura VMware.

**Quando usar:**
- Decommissionamento de VMs
- Limpeza de ambientes de teste
- Remoção de infraestrutura obsoleta

**Safety Features:**
- 🔒 Checkbox obrigatório de confirmação
- 🔒 Revisão do plano de destruição
- 🔒 Aprovação dupla obrigatória
- 🔒 Pause de 30 segundos antes de destruir
- 🔒 Verificação pós-destruição
- 🔒 Opção de remover state file

**Parâmetros:**
- `TICKET_ID` - ID do ticket Jira
- `ENVIRONMENT` - Ambiente (tst/qlt/prd)
- `GIT_BRANCH` - Branch
- `GIT_REPO_URL` - URL do repositório
- `CONFIRM_DESTROY` - ⚠️ Checkbox de confirmação

**Aprovadores:**
- **TST/QLT:** infrastructure-leads (timeout: 4h)
- **PRD:** c-level-executives,infrastructure-leads (timeout: 8h)

---

## 🔧 Configuração no Jenkins

### Pré-requisitos

**Agent Label:** `terraform-agent`

**Ferramentas instaladas no agent:**
- Terraform >= 1.5.0
- Azure CLI
- Trivy (security scanner)
- Git

### Credentials Necessárias

#### 1. Git Credentials
```
ID: git-credentials
Type: Username with password / SSH Key
```

#### 2. Azure Service Principal (por ambiente)

```
# TST
azure-sp-tst-client-id
azure-sp-tst-client-secret
azure-sp-tst-subscription-id
azure-sp-tst-tenant-id

# QLT
azure-sp-qlt-client-id
azure-sp-qlt-client-secret
azure-sp-qlt-subscription-id
azure-sp-qlt-tenant-id

# PRD
azure-sp-prd-client-id
azure-sp-prd-client-secret
azure-sp-prd-subscription-id
azure-sp-prd-tenant-id
```

#### 3. vSphere Credentials (por ambiente)

```
# TST
vsphere-tst-server      # vcenter-tst.example.com
vsphere-tst-user        # svc-terraform-tst@vsphere.local
vsphere-tst-password    # password

# QLT
vsphere-qlt-server
vsphere-qlt-user
vsphere-qlt-password

# PRD
vsphere-prd-server
vsphere-prd-user
vsphere-prd-password
```

### Criar Jobs no Jenkins

#### Via Interface

1. **New Item** → Nome do job → **Pipeline**
2. Em **Pipeline**:
   - Definition: `Pipeline script`
   - Script: Copiar conteúdo do arquivo `.groovy`
3. Salvar

#### Via Script

```groovy
// Exemplo: criar job de deploy
pipelineJob('vmware-terraform-deploy') {
    description('Deploy VMware infrastructure with Terraform')
    
    parameters {
        stringParam('TICKET_ID', '', 'Jira ticket ID')
        choiceParam('ENVIRONMENT', ['tst', 'qlt', 'prd'], 'Target environment')
        choiceParam('ACTION', ['plan', 'apply'], 'Terraform action')
        stringParam('GIT_BRANCH', 'main', 'Repository branch')
        stringParam('GIT_REPO_URL', 'https://github.com/your-org/virtualization-automation.git', 'Git repository URL')
    }
    
    definition {
        cps {
            script(readFileFromWorkspace('pipelines/terraform-deploy-job.groovy'))
            sandbox(true)
        }
    }
}
```

---

## 🔄 Workflow Completo

### 1. Desenvolvimento

```bash
# Criar branch de feature
git checkout -b feature/OPS-1234-new-vms

# Fazer alterações
# ...

# Commit e push
git add .
git commit -m "feat: adicionar novas VMs conforme OPS-1234"
git push origin feature/OPS-1234-new-vms
```

### 2. Pull Request

- Criar PR no GitHub/GitLab
- **Pipeline automática:** `terraform-validation-job`
- Aguardar aprovação do PR
- Merge para main

### 3. Deploy em TST

```
Job: vmware-terraform-deploy
├── TICKET_ID: OPS-1234
├── ENVIRONMENT: tst
├── ACTION: plan
└── GIT_BRANCH: main

Resultado: Revisar plan
```

```
Job: vmware-terraform-deploy
├── TICKET_ID: OPS-1234
├── ENVIRONMENT: tst
├── ACTION: apply
└── GIT_BRANCH: main

Aprovação: devops-team
Resultado: VMs criadas em TST
```

### 4. Validação e Promoção

- Testar em TST
- Aprovar no Jira
- Deploy em QLT (repetir processo)
- Deploy em PRD (com aprovação adicional)

### 5. Decommissionamento

```
Job: vmware-terraform-destroy
├── TICKET_ID: OPS-1234
├── ENVIRONMENT: tst
├── CONFIRM_DESTROY: ✓
└── GIT_BRANCH: main

Aprovação 1: Checkbox confirmação
Aprovação 2: infrastructure-leads
Resultado: VMs removidas
```

---

## 📊 Integração com Jira

### Nomear Branches

```
feature/OPS-1234-description
bugfix/OPS-5678-description
hotfix/OPS-9012-description
```

### Ticket ID como Parâmetro

- Usado como chave do state file: `vmware/OPS-1234.tfstate`
- Rastreabilidade completa
- Link automático nos logs

---

## 🔐 Segurança

### Scans Automáticos

- **Trivy:** Vulnerabilidades em configuração Terraform
- **Severity:** MEDIUM, HIGH, CRITICAL
- **Output:** SARIF + JUnit XML

### Aprovações

| Ambiente | Deploy | Destroy |
|----------|--------|---------|
| TST | devops-team (2h) | infrastructure-leads (4h) |
| QLT | devops-team (2h) | infrastructure-leads (4h) |
| PRD | infrastructure-leads (4h) | c-level + infra-leads (8h) |

### State File Protection

- Backend Azure Storage com RBAC
- Encryption at rest
- Versionamento habilitado
- Soft delete configurado

---

## 📈 Monitoramento

### Artifacts Salvos

- Terraform plans (JSON)
- Security scan reports (SARIF, XML)
- Terraform outputs (JSON)

### Build Status

Todos os jobs publicam:
- JUnit test results (security scans)
- Artifacts para download
- Build logs detalhados

---

## 🐛 Troubleshooting

### Erro: "Backend initialization failed"

**Causa:** Credenciais Azure incorretas ou expiradas

**Solução:**
```bash
# Verificar credenciais no Jenkins
Jenkins > Credentials > System > Global credentials

# Testar manualmente
az login --service-principal \
  --username $ARM_CLIENT_ID \
  --password $ARM_CLIENT_SECRET \
  --tenant $ARM_TENANT_ID
```

### Erro: "vSphere authentication failed"

**Causa:** Credenciais vSphere incorretas ou servidor inacessível

**Solução:**
```bash
# Verificar conectividade
ping vcenter-tst.example.com

# Testar credenciais
export VSPHERE_SERVER="vcenter-tst.example.com"
export VSPHERE_USER="svc-terraform-tst@vsphere.local"
export VSPHERE_PASSWORD="password"

terraform plan
```

### Erro: "Terraform validation failed"

**Causa:** Código Terraform inválido

**Solução:**
```bash
# Formatar código
terraform fmt -recursive

# Validar localmente
terraform init -backend=false
terraform validate
```

---

## 📚 Referências

- [Terraform VMware vSphere Provider](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs)
- [Azure Storage Backend](https://www.terraform.io/docs/language/settings/backends/azurerm.html)
- [Trivy Security Scanner](https://aquasecurity.github.io/trivy/)
- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)

---

## 🆘 Suporte

**Equipe DevOps:**
- Slack: #devops-vmware
- Email: devops@example.com
- Confluence: [VMware Automation Wiki]

**Escalação:**
- L1: DevOps Team
- L2: Infrastructure Leads
- L3: Principal Engineers
