terraform {
  required_version = ">= 1.5.0"
}

# ==============================================================================
# NAMING CONVENTION
# Pattern: <purpose><environment><instance>
# Max length: 15 characters
# Example: web-tst-01, app-prd-03
# ==============================================================================

locals {
  # Validate total length
  vm_name_length = length("${var.purpose}-${var.environment}-${format("%02d", var.instance_number)}")

  # Generate VM name
  vm_name = "${var.purpose}-${var.environment}-${format("%02d", var.instance_number)}"

  # Generate hostname (same as VM name for consistency)
  hostname = local.vm_name
}

# Validation check
resource "null_resource" "validate_name_length" {
  count = local.vm_name_length > var.max_name_length ? 1 : 0

  provisioner "local-exec" {
    command = "echo 'ERROR: VM name ${local.vm_name} exceeds ${var.max_name_length} characters (${local.vm_name_length})' && exit 1"
  }
}
