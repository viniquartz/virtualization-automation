terraform {
  required_version = ">= 1.5.0"
}

# ==============================================================================
# NAMING CONVENTION
# Pattern: <purpose><environment><instance>
# Max length: 15 characters
# Example: webprd01, appqlt02
# CPD1: odd instance numbers (01, 03, 05...)
# CPD2: even instance numbers (02, 04, 06...)
# ==============================================================================

locals {
  # Validate total length
  vm_name_length = length("${upper(var.purpose)}${upper(var.environment)}${format("%02d", var.instance_number)}")

  # Generate VM name (uppercase, no hyphens)
  vm_name = "${upper(var.purpose)}${upper(var.environment)}${format("%02d", var.instance_number)}"

  # Generate hostname (lowercase for DNS compatibility)
  hostname = lower(local.vm_name)
}

# Validation check
resource "null_resource" "validate_name_length" {
  count = local.vm_name_length > var.max_name_length ? 1 : 0

  provisioner "local-exec" {
    command = "echo 'ERROR: VM name ${local.vm_name} exceeds ${var.max_name_length} characters (${local.vm_name_length})' && exit 1"
  }
}
