variable "compartment_id" { type = string }
variable "name_prefix" { type = string }
variable "tags" { type = map(string) }
variable "vcn_cidr" { type = string }
variable "vcn_dns_label" { type = string }

variable "subnet_cidrs" {
  type        = map(string)
  description = "CIDRs for the private subnets. Required keys: cp, lb, workers, pods, db."
}
