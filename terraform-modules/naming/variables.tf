variable "purpose" {
  description = "VM purpose/role (e.g., web, app, db)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{2,8}$", var.purpose))
    error_message = "Purpose must be lowercase alphanumeric with hyphens, 2-8 characters"
  }
}

variable "environment" {
  description = "Environment: prd, qlt, or tst"
  type        = string

  validation {
    condition     = contains(["prd", "qlt", "tst"], var.environment)
    error_message = "Environment must be: prd, qlt, or tst"
  }
}

variable "instance_number" {
  description = "Instance number (1-99)"
  type        = number
  default     = 1

  validation {
    condition     = var.instance_number >= 1 && var.instance_number <= 99
    error_message = "Instance number must be between 1 and 99"
  }
}

variable "max_name_length" {
  description = "Maximum allowed name length"
  type        = number
  default     = 15

  validation {
    condition     = var.max_name_length > 0
    error_message = "Max name length must be positive"
  }
}
