variable "compartment_id" { type = string }
variable "name_prefix" { type = string }
variable "tags" { type = map(string) }
variable "availability_domain" { type = string }
variable "subnet_id" { type = string }
variable "subnet_cidr" { type = string }
variable "nsg_ids" { type = list(string) }
variable "ssh_public_key" { type = string }

variable "node_count" {
  type        = number
  description = "Kafka nodes (each is broker + KRaft controller). Use an odd number: 3 or 5."
  default     = 3
}

variable "ip_offset" {
  type        = number
  description = "Node i gets the fixed private IP cidrhost(subnet_cidr, ip_offset + i)."
  default     = 10
}

variable "image" {
  type    = string
  default = "docker.io/apache/kafka:4.3.2"
}

variable "shape" { type = string }
variable "ocpus" { type = number }
variable "memory_gbs" { type = number }
variable "boot_volume_gb" { type = number }

variable "heap" {
  type        = string
  description = "JVM heap (-Xmx/-Xms)."
  default     = "2g"
}
