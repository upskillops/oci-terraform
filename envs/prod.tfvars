# No secrets in this file. Secrets come from TF_VAR_* environment variables or Vault.
tenancy_ocid       = "ocid1.tenancy.oc1..REPLACE"
compartment_ocid   = "ocid1.compartment.oc1..REPLACE" # use a dedicated compartment, not the tenancy root
region             = "ap-mumbai-1"
name_prefix        = "prod"
vcn_dns_label      = "okeprod"
kubernetes_version = "v1.33.1"
cluster_type       = "ENHANCED_CLUSTER"

# Network (set non-overlapping ranges if you will peer or connect on-prem)
vcn_cidr                   = "10.10.0.0/16"
cp_subnet_cidr             = "10.10.0.0/28"
lb_subnet_cidr             = "10.10.1.0/24"
workers_subnet_cidr        = "10.10.2.0/24"
db_subnet_cidr             = "10.10.3.0/24"
pods_subnet_cidr           = "10.10.64.0/18"
lb_allowed_cidrs           = ["10.0.0.0/8"]
api_endpoint_allowed_cidrs = [] # VPN / FastConnect ranges
db_allowed_cidrs           = []

# Access
create_bastion       = true
bastion_client_cidrs = [] # PUBLIC egress IPs of admins, e.g. ["198.51.100.7/32"]

# Nodes: pin the image, spread across ADs
node_architecture = "x86_64"
# node_image_id   = "ocid1.image.oc1.ap-mumbai-1.REPLACE"
node_pools = {
  general = { shape = "VM.Standard.E4.Flex", ocpus = 2, memory_gbs = 16, size = 3, boot_volume_gb = 100 }
}

# Storage
buckets = {
  data    = {}
  backups = {}
}
# storage_workload_service_account = "app-sa"
# storage_workload_namespace       = "default"

# Encryption and secrets: MUST be set on the first deployment (the key encrypts the cluster)
create_vault              = true
vault_type                = "DEFAULT"
vault_key_protection_mode = "HSM"
vault_key_rotation_days   = 90

# Observability
enable_flow_logs        = true
flow_log_retention_days = 90
alert_email             = "ops@example.com"

# MySQL HeatWave (with create_vault = true a strong password is generated and stored in Vault)
create_mysql                        = true
mysql_shape_name                    = "MySQL.4" # verify the shape supports HA and HeatWave in your region
mysql_data_storage_gb               = 100
mysql_is_highly_available           = true
mysql_backup_retention_days         = 14
mysql_backup_window_start_time      = "20:30"
mysql_maintenance_window_start_time = "sun 21:30"
mysql_enable_heatwave               = true
mysql_heatwave_cluster_size         = 1
mysql_deletion_protection           = true
