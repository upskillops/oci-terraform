variable "compartment_id" { type = string }
variable "name_prefix" { type = string }
variable "tags" { type = map(string) }

variable "subnet_ids" {
  type        = map(string)
  description = "Subnets to enable VCN flow logs on, keyed by name."
  default     = {}
}

variable "enable_flow_logs" {
  type    = bool
  default = true
}

variable "flow_log_retention_days" {
  type    = number
  default = 30

  validation {
    condition     = contains([30, 60, 90, 120, 150, 180], var.flow_log_retention_days)
    error_message = "flow_log_retention_days must be one of 30, 60, 90, 120, 150, 180."
  }
}

variable "alert_email" {
  type        = string
  description = "Email for alarm notifications. null = no topic and no alarms."
  default     = null
}

variable "enable_mysql_alarms" {
  type    = bool
  default = false
}

variable "mysql_db_system_id" {
  type    = string
  default = null
}
