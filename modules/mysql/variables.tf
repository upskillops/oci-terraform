variable "compartment_id" { type = string }
variable "name_prefix" { type = string }
variable "tags" { type = map(string) }
variable "availability_domain" { type = string }
variable "subnet_id" { type = string }

variable "nsg_ids" {
  type    = list(string)
  default = []
}

variable "shape_name" {
  type        = string
  description = "DB system shape. List valid ones: oci mysql shape list --compartment-id <ocid> --availability-domain <AD>"
}

variable "mysql_version" {
  type    = string
  default = null
}

variable "admin_username" {
  type    = string
  default = "admin"
}

variable "admin_password" {
  type      = string
  default   = null
  sensitive = true
}

variable "data_storage_size_gb" {
  type    = number
  default = 50
}

variable "is_highly_available" {
  type    = bool
  default = false
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "backup_window_start_time" {
  type        = string
  description = "Daily backup window start, UTC HH:MM (null = service default)."
  default     = null
}

variable "maintenance_window_start_time" {
  type        = string
  description = "Weekly maintenance window, UTC 'ddd hh:mm', e.g. 'sun 03:00' (null = service default)."
  default     = null
}

variable "deletion_protection" {
  type        = bool
  description = "true: delete protection + final backup. Set false before terraform destroy."
  default     = true
}

variable "enable_heatwave" {
  type    = bool
  default = true
}

variable "heatwave_shape_name" {
  type    = string
  default = "MySQL.HeatWave.VM.Standard"
}

variable "heatwave_cluster_size" {
  type    = number
  default = 1
}

variable "tenancy_ocid" { type = string }
