# Terraform Project Template

Ready-to-use Terraform project template for VMware VM automation.

## Features

- Pre-configured Azure Storage backend
- vSphere provider setup
- Linux and Windows VM module examples
- Complete variable definitions

## Quick Start

### 1. Copy Template

```bash
cp -r terraform-project-template my-project
cd my-project
```

### 2. Configure Backend

Edit `backend.tf` with your Azure Storage Account details or create a backend config file:

```hcl
# backend-prod.tfbackend
resource_group_name  = "azr-prd-iac01-weu-rg"
storage_account_name = "azrprdiac01weust01"
container_name       = "terraform-state-prd"
key                  = "vmware/PROJECT-123.tfstate"
use_azuread_auth     = true
```

### 3. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars
```

Update with your environment details.

### 4. Initialize and Deploy

```bash
# With backend config file
terraform init -backend-config="backend-prod.tfbackend"

# Or with inline backend config
terraform init

# Deploy
terraform plan
terraform apply
```

### 5. Destroy

```bash
terraform destroy
```

## Customization

### Use Only Linux Module

Comment out or remove the `windows_vm` module block in `main.tf`.

### Use Only Windows Module

Comment out or remove the `linux_vm` module block in `main.tf`.

### Add More VMs

Duplicate module blocks with different names and variables:

```hcl
module "linux_vm_02" {
  source = "../terraform-modules/linux"
  
  vm_name      = "linux-vm-02"
  vm_hostname  = "linux-vm-02"
  # ... other variables
}
```

## Structure

```
terraform-project-template/
├── backend.tf                  # Backend configuration
├── provider.tf                 # vSphere provider
├── main.tf                     # Module calls
├── variables.tf                # Variable definitions
├── outputs.tf                  # Output definitions
├── terraform.tfvars.example    # Example values
├── .gitignore                  # Git ignore rules
└── README.md                   # This file
```

## Backend Configuration

Default setup for Azure Storage:

- **Resource Group**: azr-prd-iac01-weu-rg
- **Storage Account**: azrprdiac01weust01
- **Containers**:
  - terraform-state-prd
  - terraform-state-qlt
  - terraform-state-tst
- **Key Pattern**: vmware/TICKET.tfstate

## Variables

See [variables.tf](variables.tf) for complete list of variables.

Required variables:
- vSphere connection details
- Infrastructure (datacenter, cluster, datastore, network)
- VM specifications
- Network configuration

## Outputs

See [outputs.tf](outputs.tf) for available outputs.

Default outputs:
- VM IDs
- VM names
- VM IP addresses
- VM UUIDs
