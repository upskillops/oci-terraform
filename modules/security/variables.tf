variable "compartment_id" { type = string }
variable "name_prefix" { type = string }
variable "tags" { type = map(string) }
variable "vcn_id" { type = string }
variable "oci_services_cidr" { type = string }
variable "cp_subnet_cidr" { type = string }

variable "api_endpoint_allowed_cidrs" {
  type    = list(string)
  default = []
}

variable "lb_allowed_cidrs" {
  type    = list(string)
  default = []
}

variable "lb_ports" {
  type    = list(number)
  default = [80, 443]
}

variable "mysql_ports" {
  type        = list(number)
  description = "MySQL classic (3306) and X protocol (33060) ports."
  default     = [3306, 33060]
}

variable "db_allowed_cidrs" {
  type        = list(string)
  description = "Extra CIDRs (VPN / peered networks) allowed to reach the database NSG."
  default     = []
}
