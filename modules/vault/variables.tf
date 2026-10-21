variable "compartment_id" { type = string }
variable "tenancy_ocid" { type = string }
variable "region" { type = string }
variable "name_prefix" { type = string }
variable "tags" { type = map(string) }

variable "vault_type" {
  type        = string
  description = "DEFAULT (shared HSM partition) or VIRTUAL_PRIVATE (dedicated, higher cost)."
  default     = "DEFAULT"

  validation {
    condition     = contains(["DEFAULT", "VIRTUAL_PRIVATE"], var.vault_type)
    error_message = "vault_type must be DEFAULT or VIRTUAL_PRIVATE."
  }
}

variable "key_protection_mode" {
  type        = string
  description = "HSM (recommended for production) or SOFTWARE."
  default     = "HSM"

  validation {
    condition     = contains(["HSM", "SOFTWARE"], var.key_protection_mode)
    error_message = "key_protection_mode must be HSM or SOFTWARE."
  }
}

variable "key_rotation_days" {
  type        = number
  description = "Automatic key rotation interval in days (60-365)."
  default     = 90
}

variable "db_password" {
  type        = string
  description = "Existing database admin password to store in Vault. null = generate a strong random one."
  default     = null
  sensitive   = true
}
