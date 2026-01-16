# VMware Virtualization Automation

VMware VM automation using Terraform, cloud-init and Ansible.

## Structure

```
terraform-modules/
  linux/       # Module for Linux VMs
  windows/     # Module for Windows VMs

terraform-project-template/
  # Base template for new projects
```

## Terraform Modules

### Linux

Module for creating Linux VMs on VMware vSphere.
See full documentation at [terraform-modules/linux/README.md](terraform-modules/linux/README.md)

### Windows

Module for creating Windows VMs on VMware vSphere.
See full documentation at [terraform-modules/windows/README.md](terraform-modules/windows/README.md)

## Project Template

Use `terraform-project-template` as base for new projects.
Includes provider configuration and Azure Storage backend.

## Azure Storage Backend

Default configuration for state files:

- Resource Group: azr-prd-iac01-weu-rg
- Storage Account: azrprdiac01weust01
- Containers: terraform-state-{prd|qlt|tst}
- Key pattern: vmware/TICKET.tfstate
