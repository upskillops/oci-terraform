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
  kms_key_id = var.create_vault ? module.vault[0].key_id : var.kms_key_id
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
}

module "jumphost" {
  count  = var.create_jumphost ? 1 : 0
  source = "./modules/jumphost"

  compartment_id      = var.compartment_ocid
  name_prefix         = var.name_prefix
  tags                = local.tags
  vcn_id              = module.network.vcn_id
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
  depends_on = [module.security, module.vault]
}

module "storage" {
  source = "./modules/storage"

  compartment_id           = var.compartment_ocid
  tenancy_ocid             = var.tenancy_ocid
  name_prefix              = var.name_prefix
  tags                     = local.tags
  buckets                  = var.buckets
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
