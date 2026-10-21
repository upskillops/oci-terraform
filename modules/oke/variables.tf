variable "compartment_id" { type = string }
variable "name_prefix" { type = string }
variable "tags" { type = map(string) }
variable "vcn_id" { type = string }

variable "subnet_ids" {
  type        = map(string)
  description = "Subnet OCIDs keyed by cp, lb, workers, pods."
}

variable "nsg_ids" {
  type        = map(string)
  description = "NSG OCIDs keyed by cp, workers, pods."
}

variable "availability_domains" { type = list(string) }
variable "kubernetes_version" { type = string }
variable "cluster_type" { type = string }
variable "services_cidr" { type = string }

variable "kms_key_id" {
  type    = string
  default = null
}

variable "max_pods_per_node" { type = number }

variable "node_pools" {
  type = map(object({
    shape          = optional(string, "VM.Standard.E4.Flex")
    ocpus          = optional(number, 1)
    memory_gbs     = optional(number, 8)
    size           = optional(number, 1)
    boot_volume_gb = optional(number, 50)
    labels         = optional(map(string), {})
  }))
}

variable "node_image_id" {
  type    = string
  default = null
}

variable "node_architecture" {
  type    = string
  default = "x86_64"
}

variable "ssh_public_key" {
  type    = string
  default = null
}

variable "create_bastion" {
  type    = bool
  default = true
}

variable "bastion_client_cidrs" {
  type    = list(string)
  default = []
}
