variable "compartment_id" { type = string }
variable "tenancy_ocid" { type = string }
variable "name_prefix" { type = string }
variable "tags" { type = map(string) }

variable "buckets" {
  type = map(object({
    storage_tier = optional(string, "Standard") # Standard | Archive
    versioning   = optional(string, "Enabled")  # Enabled | Suspended | Disabled
  }))
  description = "Object Storage buckets to create, keyed by short name. Final name is <prefix>-<key>."
}

variable "kms_key_id" {
  type        = string
  description = "Optional Vault key. The Object Storage service needs a policy allowing it to use the key."
  default     = null
}

variable "cluster_id" {
  type        = string
  description = "OKE cluster OCID (used in the workload identity policy)."
  default     = null
}

variable "workload_namespace" {
  type        = string
  description = "Kubernetes namespace whose service account may access the buckets."
  default     = "default"
}

variable "workload_service_account" {
  type        = string
  description = "Kubernetes service account allowed to read/write the buckets via OKE workload identity (ENHANCED cluster). null = create no policy."
  default     = null
}
