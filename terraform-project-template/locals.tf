# ==============================================================================
# LOCAL VARIABLES
# ==============================================================================

locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Ticket      = var.ticket_id
  }
}
