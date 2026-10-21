variable "compartment_id" { type = string }
variable "name_prefix" { type = string }
variable "tags" { type = map(string) }
variable "vcn_cidr" { type = string }
variable "vcn_dns_label" { type = string }

variable "subnet_cidrs" {
  type        = map(string)
  description = "CIDRs for the private subnets. Required keys: cp, lb, workers, pods, db."
}

variable "create_internet_gateway" {
  type        = bool
  description = "Create the VCN's Internet Gateway and public route table (jump host / public load balancers)."
  default     = false
}

variable "public_lb_subnet_cidr" {
  type        = string
  description = "Public subnet for internet-facing load balancers. null = none."
  default     = null
}
