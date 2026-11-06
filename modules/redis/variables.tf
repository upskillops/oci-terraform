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
  description = "Node 1 starts as primary, the rest as replicas; Sentinel runs on every node. Use 3+ for failover."
  default     = 3
}

variable "ip_offset" {
  type        = number
  description = "Node i gets the fixed private IP cidrhost(subnet_cidr, ip_offset + i)."
  default     = 20
}

variable "image" {
  type    = string
  default = "docker.io/library/redis:8.10.2"
}

variable "master_name" {
  type        = string
  description = "Sentinel master group name that clients use."
  default     = "mymaster"
}

variable "maxmemory" {
  type        = string
  description = "Redis maxmemory, leave headroom for replication buffers and the OS."
  default     = "2gb"
}

variable "shape" { type = string }
variable "ocpus" { type = number }
variable "memory_gbs" { type = number }
variable "boot_volume_gb" { type = number }

variable "mode" {
  type        = string
  description = "\"cluster\" = Redis Cluster (2 instances per VM: master 6379 + replica 6380); \"sentinel\" = primary + replicas + Sentinel."
  default     = "cluster"

  validation {
    condition     = contains(["cluster", "sentinel"], var.mode)
    error_message = "mode must be \"cluster\" or \"sentinel\"."
  }
}
