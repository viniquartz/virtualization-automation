# ==============================================================================
# LOCAL VARIABLES
# ==============================================================================

locals {
  # CPD-based infrastructure configuration
  cpd_config = {
    cpd1 = {
      datacenter = "TAP_CPD1"
      cluster    = "CPD1_ESX7"
      network    = "AUTOMTNPRD (LAN-CPD1)"
    }
    cpd2 = {
      datacenter = "TAP_CPD2"
      cluster    = "CPD2_ESX7"
      network    = "AUTOMTNPRD (LAN-CPD2)"
    }
  }

  # Determine which CPDs to deploy to
  target_cpds = var.cpd == "both" ? ["cpd1", "cpd2"] : [var.cpd]

  # Create map of all Linux VMs to deploy: {key => {cpd, sequence, instance}}
  linux_vms = var.create_linux_vm ? {
    for item in flatten([
      for cpd in local.target_cpds : [
        for idx in range(var.linux_vm_count) : {
          cpd      = cpd
          sequence = var.linux_vm_start_sequence + idx
          vm_index = idx
        }
      ]
    ]) : "${item.cpd}-${item.sequence}" => item
  } : {}

  # Create map of all Windows VMs to deploy: {key => {cpd, sequence, instance}}
  windows_vms = var.create_windows_vm ? {
    for item in flatten([
      for cpd in local.target_cpds : [
        for idx in range(var.windows_vm_count) : {
          cpd      = cpd
          sequence = var.windows_vm_start_sequence + idx
          vm_index = idx
        }
      ]
    ]) : "${item.cpd}-${item.sequence}" => item
  } : {}

  # Common tags
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    Ticket      = var.ticket_id
    ManagedBy   = "Terraform"
  }
}
