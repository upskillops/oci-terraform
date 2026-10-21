variable "compartment_id" { type = string }
variable "name_prefix" { type = string }
variable "tags" { type = map(string) }
variable "vcn_id" { type = string }
variable "availability_domain" { type = string }

variable "subnet_cidr" {
  type        = string
  description = "Public subnet for the jump host."
}

variable "allowed_cidrs" {
  type        = list(string)
  description = "Public CIDRs allowed to SSH to the jump host."
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for the opc user."
}

variable "shape" { type = string }
variable "ocpus" { type = number }
variable "memory_gbs" { type = number }

variable "kubernetes_version" {
  type        = string
  description = "Cluster version, used to pick the matching kubectl minor release."
}
