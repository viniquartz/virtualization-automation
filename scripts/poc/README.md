# POC Scripts - VMware Automation

Scripts para testes manuais e demonstração local do workflow Terraform para VMware vSphere.

**Nota: Apenas para POC/testes locais. Pipelines CI/CD executam Terraform diretamente.**

## Pré-requisitos

1. **Azure Credentials** (Service Principal) - para backend
2. **vSphere Credentials** - para provisionamento de VMs
3. **Git Repository** - acesso ao repositório
4. **Azure Backend** configurado (Storage Account + Container)
5. **Terraform** >= 1.5.0

## Scripts Disponíveis

| Script | Propósito |
|--------|-----------|
| `azure-login.sh` | Autenticar Azure CLI com Service Principal |
| `configure.sh` | Clonar repositório e configurar backend Terraform |
| `validate-modules.sh` | Validar módulos Terraform |
| `deploy.sh` | Gerar plan e aplicar mudanças |
| `destroy.sh` | Gerar destroy plan e remover recursos |

## Workflow Completo

### 1. Configurar Variáveis de Ambiente

```bash
# Azure credentials (Service Principal) - para backend
export ARM_CLIENT_ID="xxx"
export ARM_CLIENT_SECRET="xxx"
export ARM_SUBSCRIPTION_ID="xxx"
export ARM_TENANT_ID="xxx"

# vSphere credentials
export TF_VAR_vsphere_server="vcenter.example.com"
export TF_VAR_vsphere_user="svc-terraform@vsphere.local"
export TF_VAR_vsphere_password="your-password"
```

### 2. Autenticar no Azure

```bash
bash scripts/poc/azure-login.sh
```

Valida credenciais e autentica Azure CLI (para acesso ao backend).

### 3. Configurar Projeto

```bash
bash scripts/poc/configure.sh OPS-1234 tst https://github.com/yourorg/virtualization-automation.git
```

**Parâmetros:**

- `OPS-1234` - ID do ticket (usado como chave do state: vmware/OPS-1234.tfstate)
- `tst` - Ambiente (tst/qlt/prd)
- `<url>` - URL do repositório Git

**O que faz:**

- Clona repositório do Git
- Configura backend Terraform com Azure Storage
- Executa `terraform init`

**Cria:**

- Diretório `OPS-1234/` com código do projeto
- Arquivo `OPS-1234/backend-config.tfbackend`

### 4. (Opcional) Validar Módulos

```bash
bash scripts/poc/validate-modules.sh https://github.com/yourorg/virtualization-automation.git main
```

Valida todos os módulos Terraform do repositório.

### 5. Deploy

```bash
bash scripts/poc/deploy.sh OPS-1234 tst
```

**O que faz:**

1. Gera plan: `terraform plan -out=tfplan-tst.out`
2. Mostra resumo do plan
3. Solicita confirmação (`yes`)
4. Aplica: `terraform apply tfplan-tst.out`

**Nota: Sempre requer confirmação manual (`yes`)**

### 6. Destroy

```bash
bash scripts/poc/destroy.sh OPS-1234 tst
```

**O que faz:**

1. Lista recursos atuais
2. Gera destroy plan: `terraform plan -destroy -out=tfplan-destroy-tst.out`
3. Mostra resumo
4. Solicita confirmação (`yes`)
5. Aplica: `terraform apply tfplan-destroy-tst.out`

**Nota: Sempre requer confirmação manual (`yes`)**

## Exemplo Completo

```bash
# 1. Configurar credenciais
export ARM_CLIENT_ID="xxx"
export ARM_CLIENT_SECRET="xxx"
export ARM_SUBSCRIPTION_ID="xxx"
export ARM_TENANT_ID="xxx"

export TF_VAR_vsphere_server="vcenter-tst.example.com"
export TF_VAR_vsphere_user="svc-terraform-tst@vsphere.local"
export TF_VAR_vsphere_password="password"

# 2. Autenticar no Azure
bash scripts/poc/azure-login.sh

# 3. Configurar projeto
bash scripts/poc/configure.sh OPS-1234 tst https://github.com/yourorg/virtualization-automation.git

# 4. (Opcional) Validar módulos
bash scripts/poc/validate-modules.sh https://github.com/yourorg/virtualization-automation.git main

# 5. Deploy
bash scripts/poc/deploy.sh OPS-1234 tst
# Responder: yes

# 6. Verificar
cd OPS-1234
terraform output
terraform state list

# 7. Destroy
cd ..
bash scripts/poc/destroy.sh OPS-1234 tst
# Responder: yes
```

## Detalhes dos Scripts

### azure-login.sh

```bash
bash scripts/poc/azure-login.sh
```

**Requer:**

- `ARM_CLIENT_ID`
- `ARM_CLIENT_SECRET`
- `ARM_SUBSCRIPTION_ID`
- `ARM_TENANT_ID`

**Ações:**

- Valida variáveis de ambiente
- Autentica `az login` com Service Principal
- Define subscription padrão

### configure.sh

```bash
bash scripts/poc/configure.sh <ticket-id> <environment> <git-repo-url>
```

**Exemplo:**

```bash
bash scripts/poc/configure.sh OPS-1234 tst https://github.com/yourorg/virtualization-automation.git
```

**Ações:**

1. Clona repositório Git para `<ticket-id>/`
2. Gera `backend-config.tfbackend`
3. Executa `terraform init`

**Cria:**

- `OPS-1234/` - Diretório do projeto
- `OPS-1234/backend-config.tfbackend`
- `OPS-1234/.terraform/`

### validate-modules.sh

```bash
bash scripts/poc/validate-modules.sh <git-repo-url> [tag-or-branch]
```

**Exemplos:**

```bash
bash scripts/poc/validate-modules.sh https://github.com/yourorg/virtualization-automation.git main
bash scripts/poc/validate-modules.sh https://github.com/yourorg/virtualization-automation.git v1.0.0
```

**Ações:**

- Clona repositório de módulos
- Descobre todos os módulos
- Valida cada módulo:
  - `terraform fmt -check`
  - `terraform init`
  - `terraform validate`
- Gera relatório de validação

### deploy.sh

```bash
bash scripts/poc/deploy.sh <ticket-id> <environment>
```

**Exemplo:**

```bash
bash scripts/poc/deploy.sh OPS-1234 tst
```

**Ações:**

1. Muda para diretório `<ticket-id>/`
2. Executa `terraform plan -var-file=environments/<env>/terraform.tfvars -out=tfplan-<env>.out`
3. Mostra resumo do plan
4. Solicita confirmação: `Do you want to apply these changes? (yes/no):`
5. Executa `terraform apply tfplan-<env>.out`
6. Remove arquivo de plan após sucesso

**Nota: Sem flag --auto-approve, sempre requer `yes` manual**

### destroy.sh

```bash
bash scripts/poc/destroy.sh <ticket-id> <environment>
```

**Exemplo:**

```bash
bash scripts/poc/destroy.sh OPS-1234 tst
```

**Ações:**

1. Muda para diretório `<ticket-id>/`
2. Lista recursos: `terraform state list`
3. Executa `terraform plan -destroy -var-file=... -out=tfplan-destroy-<env>.out`
4. Mostra resumo
5. Solicita confirmação: `Type 'yes' to confirm destruction:`
6. Executa `terraform apply tfplan-destroy-<env>.out`
7. Remove arquivo de plan após sucesso

**Nota: Sem flag --auto-approve, sempre requer `yes` manual**

## Notas Importantes

1. **Ticket ID**: Usado como chave do state file no Azure Storage (`vmware/<ticket-id>.tfstate`)
2. **Confirmação manual**: Deploy e Destroy sempre requerem confirmação
3. **Arquivos de plan**: Salvos como `tfplan-<env>.out` e `tfplan-destroy-<env>.out`
4. **CI/CD**: Pipelines Jenkins não usam esses scripts, executam Terraform diretamente
5. **State file**: Permanece no Azure Storage após destroy (para auditoria)
6. **vSphere**: Credenciais passadas via variáveis de ambiente `TF_VAR_*`

## Arquivos Temporários

Scripts criam e usam:
- `backend-config.tfbackend`
- `.terraform/`
- `.terraform.lock.hcl`
- `tfplan-*.out`

## Diferenças entre Scripts POC e Pipelines Jenkins

| Aspecto | Scripts POC | Pipelines Jenkins |
|---------|-------------|-------------------|
| Execução | Manual | Automatizada |
| Autenticação | Service Principal (manual) | Credentials do Jenkins |
| Aprovação | Prompt no console | Jenkins approval gate |
| Backend config | Gerado por script | Gerado pela pipeline |
| Notificações | Nenhuma | Teams/Slack |
| Security scan | Manual (se necessário) | Automatizado (Trivy) |
| Artifacts | Arquivos locais | Arquivados no Jenkins |
| State key | vmware/{ticket}.tfstate | vmware/{ticket}.tfstate |

## Troubleshooting

### Erro: Not authenticated to Azure

**Sintoma:** `Not authenticated to Azure`

**Solução:**
```bash
bash scripts/poc/azure-login.sh
```

### Erro: Backend not found

**Sintoma:** `Resource group 'azr-prd-iac01-weu-rg' not found`

**Solução:**
Verificar se o backend Azure foi criado:
```bash
az storage account show --name azrprdiac01weust01 --resource-group azr-prd-iac01-weu-rg
```

### Erro: vSphere authentication failed

**Sintoma:** `Error: Failed to connect to vSphere`

**Solução:**
Verificar credenciais vSphere:
```bash
# Testar conectividade
ping vcenter-tst.example.com

# Verificar variáveis
echo $TF_VAR_vsphere_server
echo $TF_VAR_vsphere_user
```

### Erro: State locked

**Sintoma:** `Error acquiring the state lock`

**Solução:**
```bash
# Aguardar liberação do lock ou forçar unlock
cd OPS-1234
terraform force-unlock <lock-id>
```

### Erro: Module not found

**Sintoma:** `Module not found: terraform-modules/linux`

**Solução:**
Verificar se módulos estão no repositório correto:
```bash
ls -la terraform-modules/
```

## Segurança

### Para POC/Testes
- Use service principal dedicado para testes
- Limite escopo à subscription de teste
- Use credenciais de curta duração
- Nunca commit credenciais no git

### Armazenamento de Credenciais
- ❌ Nunca hardcode credenciais nos scripts
- ❌ Nunca commit credenciais no repositório
- ✅ Use variáveis de ambiente
- ✅ Use Azure Key Vault (futuro)

## Próximos Passos

Após validação do POC:
1. Migrar workflow para pipelines Jenkins (já criadas)
2. Configurar credentials no Jenkins
3. Configurar approval gates
4. Habilitar notificações (Teams/Slack)
5. Arquivar scripts POC para referência

## Observações

- Scripts são para **fins de demonstração apenas**
- Deployments de produção usam pipelines Jenkins
- Scripts assumem backend já configurado
- Todos os scripts usam bash (compatível com macOS/Linux/WSL)
- Usuários Windows: Use Git Bash ou WSL

## Documentação Relacionada

- [Documentação das Pipelines](../../pipelines/README.md)
- [Módulos Terraform](../../terraform-modules/README.md)
- [Template de Projeto](../../terraform-project-template/README.md)
- [Workflow Completo](../../docs/WORKFLOW.md)
