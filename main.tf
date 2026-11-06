data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

locals {
  # OCI freeform tag keys are case-insensitive: "Environment" and "environment" count as duplicates.
  # User keys are lower-cased and win over the defaults, so duplicates can never reach the API.
  user_tags            = { for k, v in var.freeform_tags : lower(k) => v }
  tags                 = merge({ managed_by = "terraform", environment = var.name_prefix, workload = "oke" }, local.user_tags)
  availability_domains = data.oci_identity_availability_domains.ads.availability_domains[*].name

  subnet_cidrs = {
    cp      = var.cp_subnet_cidr
    lb      = var.lb_subnet_cidr
    workers = var.workers_subnet_cidr
    pods    = var.pods_subnet_cidr
    db      = var.db_subnet_cidr
  }

  # Vault key (if created) wins over an externally supplied key.
  kms_key_id  = var.create_vault ? module.vault[0].key_id : var.kms_key_id
  create_data = var.kafka.enabled || var.redis.enabled

  # The jump host subnet may reach the API endpoint and MySQL.
  jumphost_cidrs = var.create_jumphost ? [var.jumphost_subnet_cidr] : []

  mysql_admin_password = var.create_vault ? module.vault[0].db_password : try(coalesce(var.mysql_admin_password, random_password.mysql_admin[0].result), null)
}

# Without a Vault or TF_VAR_mysql_admin_password, generate the MySQL admin password.
# Read it with: terraform output -raw mysql_admin_password
resource "random_password" "mysql_admin" {
  count = var.create_mysql && !var.create_vault && var.mysql_admin_password == null ? 1 : 0

  length           = 24
  special          = true
  override_special = "!#%*-_+="
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

# Modules are self-managed. For versioned releases from your own Git repo, replace the local path, e.g.:
#   source = "git::https://github.com/<org>/terraform-oci-platform.git//modules/network?ref=network-v1.0.0"

module "vault" {
  count  = var.create_vault ? 1 : 0
  source = "./modules/vault"

  compartment_id      = var.compartment_ocid
  tenancy_ocid        = var.tenancy_ocid
  region              = var.region
  name_prefix         = var.name_prefix
  tags                = local.tags
  vault_type          = var.vault_type
  key_protection_mode = var.vault_key_protection_mode
  key_rotation_days   = var.vault_key_rotation_days
  db_password         = var.mysql_admin_password
}

module "network" {
  source = "./modules/network"

  compartment_id = var.compartment_ocid
  name_prefix    = var.name_prefix
  tags           = local.tags
  vcn_cidr       = var.vcn_cidr
  vcn_dns_label  = var.vcn_dns_label
  subnet_cidrs   = local.subnet_cidrs

  create_internet_gateway = var.create_jumphost || var.create_public_lb
  data_subnet_cidr        = local.create_data ? var.data_subnet_cidr : null
  public_lb_subnet_cidr   = var.create_public_lb ? var.public_lb_subnet_cidr : null
}

module "security" {
  source = "./modules/security"

  compartment_id             = var.compartment_ocid
  name_prefix                = var.name_prefix
  tags                       = local.tags
  vcn_id                     = module.network.vcn_id
  oci_services_cidr          = module.network.oci_services_cidr
  cp_subnet_cidr             = var.cp_subnet_cidr
  api_endpoint_allowed_cidrs = concat(var.api_endpoint_allowed_cidrs, local.jumphost_cidrs)
  lb_allowed_cidrs           = var.lb_allowed_cidrs
  lb_ports                   = var.lb_ports
  db_allowed_cidrs           = concat(var.db_allowed_cidrs, local.jumphost_cidrs)
  create_public_lb           = var.create_public_lb
  public_lb_allowed_cidrs    = var.public_lb_allowed_cidrs
  public_lb_ports            = var.public_lb_ports
  create_data_nsg            = local.create_data
  data_admin_cidrs           = local.jumphost_cidrs
  redis_ports                = var.redis.mode == "cluster" ? [6379, 6380] : [6379, 26379]
}

# Stable public IPs for LoadBalancer Services: survive LB re-creation, so DNS and certificates stay valid.
resource "oci_core_public_ip" "reserved" {
  for_each = toset(var.reserved_public_ips)

  compartment_id = var.compartment_ocid
  lifetime       = "RESERVED"
  display_name   = "${var.name_prefix}-${each.key}"
  freeform_tags  = local.tags

  # The OKE cloud controller attaches the IP to the load balancer it creates.
  lifecycle {
    ignore_changes = [private_ip_id]
  }
}

# Private OCI Container Registry repositories: <region-key>.ocir.io/<namespace>/<name>
resource "oci_artifacts_container_repository" "this" {
  for_each = toset(var.container_repositories)

  compartment_id = var.compartment_ocid
  display_name   = each.value
  is_public      = false
  is_immutable   = false
  freeform_tags  = local.tags
}

# ---------------- Self-managed Kafka / Redis ----------------
locals {
  data_ssh_key = coalesce(var.data_ssh_public_key, var.jumphost_ssh_public_key, "")
}

module "kafka" {
  count  = var.kafka.enabled ? 1 : 0
  source = "./modules/kafka"

  compartment_id      = var.compartment_ocid
  name_prefix         = var.name_prefix
  tags                = local.tags
  availability_domain = local.availability_domains[0]
  subnet_id           = module.network.data_subnet_id
  subnet_cidr         = var.data_subnet_cidr
  nsg_ids             = [module.security.nsg_ids["data"]]
  ssh_public_key      = local.data_ssh_key
  node_count          = var.kafka.node_count
  image               = var.kafka.image
  shape               = var.kafka.shape
  ocpus               = var.kafka.ocpus
  memory_gbs          = var.kafka.memory_gbs
  boot_volume_gb      = var.kafka.boot_volume_gb
  heap                = var.kafka.heap
}

module "redis" {
  count  = var.redis.enabled ? 1 : 0
  source = "./modules/redis"

  compartment_id      = var.compartment_ocid
  name_prefix         = var.name_prefix
  tags                = local.tags
  availability_domain = local.availability_domains[0]
  subnet_id           = module.network.data_subnet_id
  subnet_cidr         = var.data_subnet_cidr
  nsg_ids             = [module.security.nsg_ids["data"]]
  ssh_public_key      = local.data_ssh_key
  node_count          = var.redis.node_count
  image               = var.redis.image
  shape               = var.redis.shape
  ocpus               = var.redis.ocpus
  memory_gbs          = var.redis.memory_gbs
  boot_volume_gb      = var.redis.boot_volume_gb
  maxmemory           = var.redis.maxmemory
  mode                = var.redis.mode
}

module "jumphost" {
  count  = var.create_jumphost ? 1 : 0
  source = "./modules/jumphost"

  compartment_id      = var.compartment_ocid
  name_prefix         = var.name_prefix
  tags                = local.tags
  vcn_id              = module.network.vcn_id
  route_table_id      = module.network.public_route_table_id
  availability_domain = local.availability_domains[0]
  subnet_cidr         = var.jumphost_subnet_cidr
  allowed_cidrs       = var.jumphost_allowed_cidrs
  ssh_public_key      = var.jumphost_ssh_public_key
  shape               = var.jumphost_shape
  ocpus               = var.jumphost_ocpus
  memory_gbs          = var.jumphost_memory_gbs
  kubernetes_version  = var.kubernetes_version
}

module "oke" {
  source = "./modules/oke"

  compartment_id       = var.compartment_ocid
  name_prefix          = var.name_prefix
  tags                 = local.tags
  vcn_id               = module.network.vcn_id
  subnet_ids           = module.network.subnet_ids
  nsg_ids              = module.security.nsg_ids
  availability_domains = local.availability_domains
  kubernetes_version   = var.kubernetes_version
  cluster_type         = var.cluster_type
  services_cidr        = var.services_cidr
  kms_key_id           = local.kms_key_id
  max_pods_per_node    = var.max_pods_per_node
  node_pools           = var.node_pools
  node_image_id        = var.node_image_id
  node_architecture    = var.node_architecture
  ssh_public_key       = var.ssh_public_key
  create_bastion       = var.create_bastion
  bastion_client_cidrs = var.bastion_client_cidrs

  # NSG rules and the KMS service policy must exist before nodes bootstrap.
  prerequisites = {
    nsg_rules  = module.security.rule_ids
    kms_policy = try(module.vault[0].kms_policy_id, null)
  }
}

locals {
  # GitLab buckets: unversioned (registry layers / CI artifacts churn), merged into the storage module buckets.
  gitlab_buckets = { for b in var.gitlab_buckets : "gitlab-${b}" => { versioning = "Disabled" } }
}

module "gitlab_s3" {
  count  = length(var.gitlab_buckets) > 0 ? 1 : 0
  source = "./modules/s3user"

  tenancy_ocid   = var.tenancy_ocid
  compartment_id = var.compartment_ocid
  name           = "${var.name_prefix}-gitlab-s3"
  email          = var.gitlab_s3_user_email
  bucket_names   = [for k in keys(local.gitlab_buckets) : "${var.name_prefix}-${k}"]
  tags           = local.tags
}

module "storage" {
  source = "./modules/storage"

  compartment_id           = var.compartment_ocid
  tenancy_ocid             = var.tenancy_ocid
  name_prefix              = var.name_prefix
  tags                     = local.tags
  buckets                  = merge(var.buckets, local.gitlab_buckets)
  kms_key_id               = local.kms_key_id
  cluster_id               = module.oke.cluster_id
  workload_namespace       = var.storage_workload_namespace
  workload_service_account = var.storage_workload_service_account

  depends_on = [module.vault]
}

module "mysql" {
  count  = var.create_mysql ? 1 : 0
  source = "./modules/mysql"

  compartment_id                = var.compartment_ocid
  tenancy_ocid                  = var.tenancy_ocid
  name_prefix                   = var.name_prefix
  tags                          = local.tags
  availability_domain           = local.availability_domains[0]
  subnet_id                     = module.network.subnet_ids["db"]
  nsg_ids                       = [module.security.nsg_ids["db"]]
  shape_name                    = var.mysql_shape_name
  mysql_version                 = var.mysql_version
  admin_username                = var.mysql_admin_username
  admin_password                = local.mysql_admin_password
  data_storage_size_gb          = var.mysql_data_storage_gb
  is_highly_available           = var.mysql_is_highly_available
  backup_retention_days         = var.mysql_backup_retention_days
  backup_window_start_time      = var.mysql_backup_window_start_time
  maintenance_window_start_time = var.mysql_maintenance_window_start_time
  deletion_protection           = var.mysql_deletion_protection
  enable_heatwave               = var.mysql_enable_heatwave
  heatwave_shape_name           = var.mysql_heatwave_shape_name
  heatwave_cluster_size         = var.mysql_heatwave_cluster_size

  depends_on = [module.security]
}

module "observability" {
  source = "./modules/observability"

  compartment_id          = var.compartment_ocid
  name_prefix             = var.name_prefix
  tags                    = local.tags
  subnet_ids              = module.network.subnet_ids
  enable_flow_logs        = var.enable_flow_logs
  flow_log_retention_days = var.flow_log_retention_days
  alert_email             = var.alert_email
  enable_mysql_alarms     = var.create_mysql
  mysql_db_system_id      = try(module.mysql[0].db_system_id, null)
}
