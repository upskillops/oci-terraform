variable "tenancy_ocid" {
  type        = string
  description = "Tenancy OCID (used to look up availability domains)."
}

variable "region" {
  type        = string
  description = "OCI region identifier, e.g. ap-mumbai-1."
}

variable "compartment_ocid" {
  type        = string
  description = "Compartment where all resources are created."
}

variable "name_prefix" {
  type        = string
  description = "Environment prefix for resource names, e.g. uat or prod (lower case, max 12 chars)."
  default     = "prod"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,11}$", var.name_prefix))
    error_message = "name_prefix must start with a letter, use only a-z, 0-9 and '-', and be 2-12 characters."
  }
}

variable "freeform_tags" {
  type        = map(string)
  description = "Extra freeform tags applied to all resources. Keys are case-insensitive in OCI and are lower-cased."
  default     = {}

  validation {
    condition     = length(distinct([for k in keys(var.freeform_tags) : lower(k)])) == length(var.freeform_tags)
    error_message = "freeform_tags contains keys that differ only by case (OCI treats them as duplicates)."
  }
}

# ---------------- Network ----------------
variable "vcn_cidr" {
  type    = string
  default = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vcn_cidr, 0))
    error_message = "vcn_cidr must be a valid CIDR block."
  }
}

variable "vcn_dns_label" {
  type        = string
  description = "VCN DNS label (alphanumeric, max 15 chars)."
  default     = "okeprod"
}

variable "cp_subnet_cidr" {
  type        = string
  description = "Private subnet for the Kubernetes API endpoint (/28 is enough)."
  default     = "10.0.0.0/28"
}

variable "lb_subnet_cidr" {
  type        = string
  description = "Private subnet for internal load balancers."
  default     = "10.0.1.0/24"
}

variable "workers_subnet_cidr" {
  type        = string
  description = "Private subnet for worker nodes."
  default     = "10.0.2.0/24"
}

variable "pods_subnet_cidr" {
  type        = string
  description = "Private subnet for pods (VCN-native pod networking). Size for nodes x max pods."
  default     = "10.0.64.0/18"
}

variable "services_cidr" {
  type        = string
  description = "Kubernetes service CIDR (virtual, must not overlap VCN or on-prem ranges)."
  default     = "10.96.0.0/16"
}

variable "api_endpoint_allowed_cidrs" {
  type        = list(string)
  description = "Extra CIDRs allowed to reach the private API endpoint on 6443 (VPN / FastConnect / peered networks). The API subnet itself (OCI Bastion) is always allowed."
  default     = []
}

variable "lb_allowed_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach internal load balancers."
  default     = ["10.0.0.0/8"]
}

variable "lb_ports" {
  type        = list(number)
  description = "Listener ports allowed into the load balancer NSG."
  default     = [80, 443]
}

# ---------------- Cluster ----------------
variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version, e.g. v1.33.1. Check supported versions in your region."

  validation {
    condition     = can(regex("^v1\\.[0-9]+\\.[0-9]+$", var.kubernetes_version))
    error_message = "kubernetes_version must look like v1.33.1."
  }
}

variable "cluster_type" {
  type        = string
  description = "BASIC_CLUSTER or ENHANCED_CLUSTER."
  default     = "ENHANCED_CLUSTER"

  validation {
    condition     = contains(["BASIC_CLUSTER", "ENHANCED_CLUSTER"], var.cluster_type)
    error_message = "cluster_type must be BASIC_CLUSTER or ENHANCED_CLUSTER."
  }
}

variable "kms_key_id" {
  type        = string
  description = "Optional Vault key OCID to encrypt Kubernetes secrets and node boot/block volumes."
  default     = null
}

variable "max_pods_per_node" {
  type    = number
  default = 31
}

# ---------------- Nodes ----------------
variable "node_pools" {
  type = map(object({
    shape          = optional(string, "VM.Standard.E4.Flex")
    ocpus          = optional(number, 1)
    memory_gbs     = optional(number, 8)
    size           = optional(number, 1) # total nodes, spread across ADs
    boot_volume_gb = optional(number, 50)
    labels         = optional(map(string), {})
  }))
  default = { default = {} }
}

variable "node_image_id" {
  type        = string
  description = "Pin the worker image OCID. If null, the newest Oracle Linux 8 OKE image matching the version is used (pin it in production)."
  default     = null
}

variable "node_architecture" {
  type        = string
  description = "CPU architecture of the worker image: x86_64 (E3/E4/E5/Standard3 shapes) or aarch64 (VM.Standard.A1.Flex / A2.Flex)."
  default     = "x86_64"

  validation {
    condition     = contains(["x86_64", "aarch64"], var.node_architecture)
    error_message = "node_architecture must be x86_64 or aarch64."
  }
}

variable "ssh_public_key" {
  type        = string
  description = "Optional SSH public key for worker nodes (nodes are private; reach via OCI Bastion)."
  default     = null
}

# ---------------- Access ----------------
variable "create_bastion" {
  type        = bool
  description = "Create an OCI Bastion service in the API subnet for kubectl access via port forwarding."
  default     = true
}

variable "bastion_client_cidrs" {
  type        = list(string)
  description = "Public CIDRs allowed to open Bastion sessions (max 20, unique). The Bastion is only created when this list is non-empty."
  default     = []

  validation {
    condition     = alltrue([for c in var.bastion_client_cidrs : can(cidrhost(c, 0))]) && length(var.bastion_client_cidrs) == length(distinct(var.bastion_client_cidrs)) && length(var.bastion_client_cidrs) <= 20
    error_message = "bastion_client_cidrs must be up to 20 unique, valid CIDR blocks."
  }

  # The allowlist is for clients connecting from the internet, so use your PUBLIC egress IP (e.g. 198.51.100.7/32).
  validation {
    condition     = alltrue([for c in var.bastion_client_cidrs : !can(regex("^(10\\.|127\\.|0\\.|192\\.168\\.|172\\.(1[6-9]|2[0-9]|3[01])\\.|169\\.254\\.|203\\.0\\.113\\.)", c))])
    error_message = "bastion_client_cidrs must be public IP ranges (not private/reserved/documentation ranges such as 10.x, 192.168.x, 172.16-31.x or 203.0.113.x). Find yours with: curl ifconfig.me"
  }
}

# ---------------- OCI authentication (used by providers.tf) ----------------
variable "oci_auth" {
  type        = string
  description = "ApiKey | SecurityToken | InstancePrincipal | ResourcePrincipal"
  default     = "ApiKey"
}

variable "oci_config_profile" {
  type        = string
  description = "Profile name in ~/.oci/config (only needed for SecurityToken or non-DEFAULT profiles)."
  default     = null
}

variable "user_ocid" {
  type        = string
  description = "API user OCID."
  default     = null
}

variable "fingerprint" {
  type        = string
  description = "Fingerprint of the API key."
  default     = null
}

variable "private_key_path" {
  type        = string
  description = "Absolute path to the PEM API private key (forward slashes on Windows)."
  default     = null
}

variable "private_key_password" {
  type        = string
  description = "Passphrase of the private key, if it has one."
  default     = null
  sensitive   = true
}

# ---------------- Database subnet / access ----------------
variable "db_subnet_cidr" {
  type        = string
  description = "Private subnet for the MySQL HeatWave DB system."
  default     = "10.0.3.0/24"
}

variable "db_allowed_cidrs" {
  type        = list(string)
  description = "Extra CIDRs (VPN / peered networks) allowed to reach MySQL (3306/33060)."
  default     = []
}

# ---------------- Public jump host ----------------
variable "create_jumphost" {
  type        = bool
  description = "Create a public jump host VM (SSH entry point to the private VCN)."
  default     = false
}

variable "jumphost_subnet_cidr" {
  type        = string
  description = "Public subnet for the jump host."
  default     = "10.0.4.0/28"
}

variable "jumphost_allowed_cidrs" {
  type        = list(string)
  description = "Public CIDRs allowed to SSH to the jump host, e.g. [\"198.51.100.7/32\"]."
  default     = []

  validation {
    condition     = alltrue([for c in var.jumphost_allowed_cidrs : can(cidrhost(c, 0))])
    error_message = "jumphost_allowed_cidrs must be valid CIDR blocks."
  }
}

variable "jumphost_ssh_public_key" {
  type        = string
  description = "SSH public key for the jump host opc user."
  default     = null
}

variable "jumphost_shape" {
  type    = string
  default = "VM.Standard.E4.Flex"
}

variable "jumphost_ocpus" {
  type    = number
  default = 1
}

variable "jumphost_memory_gbs" {
  type    = number
  default = 4
}

# ---------------- Object Storage ----------------
variable "buckets" {
  type = map(object({
    storage_tier = optional(string, "Standard")
    versioning   = optional(string, "Enabled")
  }))
  description = "Object Storage buckets keyed by short name; created as <name_prefix>-<key>."
  default     = { data = {} }
}

variable "storage_workload_service_account" {
  type        = string
  description = "Kubernetes service account that may read/write the buckets via OKE workload identity. null = create no IAM policy (needs ENHANCED cluster and permission to create policies)."
  default     = null
}

variable "storage_workload_namespace" {
  type    = string
  default = "default"
}

# ---------------- MySQL HeatWave ----------------
variable "create_mysql" {
  type    = bool
  default = true
}

variable "mysql_shape_name" {
  type        = string
  description = "DB system shape. Check valid ones: oci mysql shape list --compartment-id <ocid> --availability-domain <AD>. HeatWave needs a shape that supports it."
  default     = "MySQL.4"
}

variable "mysql_version" {
  type    = string
  default = null
}

variable "mysql_admin_username" {
  type    = string
  default = "admin"
}

variable "mysql_admin_password" {
  type        = string
  description = "Admin password (8-32 chars, upper, lower, digit, special). Set via: export TF_VAR_mysql_admin_password=..."
  default     = null
  sensitive   = true

  validation {
    condition = var.mysql_admin_password == null || (
      length(var.mysql_admin_password) >= 8 && length(var.mysql_admin_password) <= 32 &&
      can(regex("[A-Z]", var.mysql_admin_password)) && can(regex("[a-z]", var.mysql_admin_password)) &&
      can(regex("[0-9]", var.mysql_admin_password)) && can(regex("[^A-Za-z0-9]", var.mysql_admin_password))
    )
    error_message = "Password must be 8-32 characters with upper case, lower case, a digit and a special character."
  }
}

variable "mysql_data_storage_gb" {
  type    = number
  default = 50
}

variable "mysql_is_highly_available" {
  type    = bool
  default = false
}

variable "mysql_backup_retention_days" {
  type    = number
  default = 7
}

variable "mysql_backup_window_start_time" {
  type    = string
  default = null
}

variable "mysql_maintenance_window_start_time" {
  type    = string
  default = null
}

variable "mysql_deletion_protection" {
  type        = bool
  description = "true keeps a final backup and blocks deletion. Set false before terraform destroy."
  default     = true
}

variable "mysql_enable_heatwave" {
  type        = bool
  description = "Attach a HeatWave cluster (billed hourly; consumes trial credits)."
  default     = true
}

variable "mysql_heatwave_shape_name" {
  type    = string
  default = "MySQL.HeatWave.VM.Standard"
}

variable "mysql_heatwave_cluster_size" {
  type    = number
  default = 1
}

# ---------------- Encryption / secrets (Vault) ----------------
variable "create_vault" {
  type        = bool
  description = "Create an OCI Vault + AES key (used for OKE secrets, volumes, buckets) and store a generated MySQL admin password in it. Enable on FIRST deployment: changing the key later replaces the cluster."
  default     = false
}

variable "vault_type" {
  type    = string
  default = "DEFAULT"
}

variable "vault_key_protection_mode" {
  type    = string
  default = "HSM"
}

variable "vault_key_rotation_days" {
  type    = number
  default = 90
}

# ---------------- Observability ----------------
variable "enable_flow_logs" {
  type        = bool
  description = "Enable VCN flow logs on all subnets."
  default     = true
}

variable "flow_log_retention_days" {
  type    = number
  default = 30
}

variable "alert_email" {
  type        = string
  description = "Email for alarm notifications (MySQL CPU/memory/disk). null = no alarms."
  default     = null
}
