# Scripts CI/CD

Scripts otimizados para uso em pipelines de CI/CD (Jenkins, Azure DevOps, GitHub Actions).

## 📋 Scripts Disponíveis

### azure-login.sh

Autenticação Azure usando Service Principal (credenciais não-interativas).

**Uso em Pipelines:**

```bash
# Azure DevOps / GitHub Actions
export ARM_CLIENT_ID="xxx"
export ARM_CLIENT_SECRET="xxx"
export ARM_SUBSCRIPTION_ID="xxx"
export ARM_TENANT_ID="xxx"

./scripts-cicd/azure-login.sh
```

**Variáveis Necessárias:**
- `ARM_CLIENT_ID` - Service Principal Application ID
- `ARM_CLIENT_SECRET` - Service Principal Password/Secret
- `ARM_SUBSCRIPTION_ID` - Azure Subscription ID
- `ARM_TENANT_ID` - Azure AD Tenant ID

### configure.sh

Setup completo do backend e validações para pipelines.

**Uso:**

```bash
./scripts-cicd/configure.sh <environment> <key>
```

**Exemplo:**

```bash
./scripts-cicd/configure.sh tst ABC-123
```

**Features:**
- Validação de variáveis de ambiente
- Configuração automática de backend
- Verificação de conectividade vSphere
- Logs detalhados para CI/CD

### validate-modules.sh

Validação e testes dos módulos Terraform.

**Uso:**

```bash
./scripts-cicd/validate-modules.sh
```

**Validações:**
- `terraform fmt -check` - Formatação
- `terraform validate` - Sintaxe
- `tflint` - Linting (se disponível)
- Estrutura de arquivos

## 🔄 Diferença entre scripts/ e scripts-cicd/

| Aspecto | scripts/ | scripts-cicd/ |
|---------|----------|---------------|
| **Uso** | Local/Desenvolvimento | Pipelines CI/CD |
| **Autenticação** | Interativa (`az login`) | Service Principal |
| **Logs** | Coloridos, simples | Detalhados, timestamped |
| **Validações** | Básicas | Completas |
| **Dependências** | Azure CLI | Azure CLI + variáveis env |

## 🚀 Exemplo de Pipeline

### GitHub Actions

```yaml
name: Deploy VMware Infrastructure

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        
      - name: Azure Login
        env:
          ARM_CLIENT_ID: ${{ secrets.ARM_CLIENT_ID }}
          ARM_CLIENT_SECRET: ${{ secrets.ARM_CLIENT_SECRET }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
          ARM_TENANT_ID: ${{ secrets.ARM_TENANT_ID }}
        run: ./scripts-cicd/azure-login.sh
        
      - name: Validate Modules
        run: ./scripts-cicd/validate-modules.sh
        
      - name: Configure Backend
        run: ./scripts-cicd/configure.sh tst ${{ github.event.number }}
        
      - name: Terraform Plan
        run: terraform plan -var-file=environments/tst/terraform.tfvars
```

### Azure DevOps

```yaml
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

steps:
- task: TerraformInstaller@0
  inputs:
    terraformVersion: '1.5.0'

- bash: |
    ./scripts-cicd/azure-login.sh
  displayName: 'Azure Authentication'
  env:
    ARM_CLIENT_ID: $(ARM_CLIENT_ID)
    ARM_CLIENT_SECRET: $(ARM_CLIENT_SECRET)
    ARM_SUBSCRIPTION_ID: $(ARM_SUBSCRIPTION_ID)
    ARM_TENANT_ID: $(ARM_TENANT_ID)

- bash: |
    ./scripts-cicd/validate-modules.sh
  displayName: 'Validate Terraform Modules'

- bash: |
    ./scripts-cicd/configure.sh tst $(Build.BuildNumber)
  displayName: 'Configure Backend'

- bash: |
    terraform plan -var-file=environments/tst/terraform.tfvars
  displayName: 'Terraform Plan'
```

## 🔐 Configuração de Secrets

### GitHub Actions

Settings → Secrets and variables → Actions → New repository secret

```
ARM_CLIENT_ID
ARM_CLIENT_SECRET
ARM_SUBSCRIPTION_ID
ARM_TENANT_ID
```

### Azure DevOps

Pipelines → Library → Variable groups → New variable group

```
Name: azure-credentials
Variables:
  - ARM_CLIENT_ID (secret)
  - ARM_CLIENT_SECRET (secret)
  - ARM_SUBSCRIPTION_ID
  - ARM_TENANT_ID
```

## 📝 Notas

- Scripts otimizados para ambientes não-interativos
- Logs incluem timestamps para troubleshooting
- Validações fail-fast para feedback rápido
- Compatível com principais plataformas CI/CD
