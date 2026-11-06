# No secrets in this file. Secrets come from TF_VAR_* environment variables.
# wibmooci tenancy (auth via the DEFAULT profile in ~/.oci/config)
tenancy_ocid       = "ocid1.tenancy.oc1..aaaaaaaa7a4hivu7qw5lrjcd2ophdjigokg7ta4qycs66ptquj2lhlp5xhba"
compartment_ocid   = "ocid1.tenancy.oc1..aaaaaaaa7a4hivu7qw5lrjcd2ophdjigokg7ta4qycs66ptquj2lhlp5xhba" # root compartment
region             = "ap-mumbai-1"
name_prefix        = "uat"
vcn_dns_label      = "okeuat"
kubernetes_version = "v1.37.0" # a version supported in your region

# Network
vcn_cidr         = "10.0.0.0/16"
lb_allowed_cidrs = ["10.0.0.0/8"]

# Access (PUBLIC IP of your workstation, e.g. ["198.51.100.7/32"]; [] = no Bastion)
create_bastion       = false
bastion_client_cidrs = []

# Public load balancer subnet + NSG (Istio ingress gateway)
create_public_lb    = true
public_lb_ports     = [22, 80, 443] # 22 = GitLab SSH (git clone over SSH)
reserved_public_ips = ["gitlab"]

# Public jump host (SSH from the allowed IPs; kubectl via: ssh -D 1080 opc@<ip>)
create_jumphost         = true
jumphost_allowed_cidrs  = ["202.78.236.218/32", "122.183.38.181/32"] # Mac, other server
jumphost_ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDPlTqJAnp/97kT8i9s7t1wZfLuwy17vM02Wsic8SJi2ZJg5lZ7chtD1RiriwUnJMF5M3iBAXc2vr/O62wls+diynGRpk3D65R0YoOTeSeIVsdTo0PZ1lw1/vQ7GA0/bL4QqwigtAkPSOj0OKfklP3Owo2NGy/sNUQNZsz3k06sdIbmVHRV0upPAMHTk0zdSLtQqf93GtxYM4jwV5WkOFMNDGxhBzoKOYx1H2fgQJpMVTxepG3g4AtxinmHHOc256Wl0X9uIwEzB1FwTCEeXplgwtPRtRZHVv4+J1JjX3PYCv3qQWwuf+nIHflKbwK70e/0HsJ07mVwgWXblzwYf8JLI/+bNHgemOQk9JwhlB9xdoVm24UOj0mcOjKHpVa3pw+hc0RGgJRwbSwNixLWvciTg0/OFrMuu1pRvdvOWgZHWjIp7JRi7einfxkLD12h/u1iWD4CyMXv1g4Ls015JrNz8riLNBdg4D7+U35TubEjWro21NK/gp5ESkLe1QKjWdE= amitchaturvedi@Amits-MacBook-Air.local"

# Nodes (minimum footprint)
node_architecture = "x86_64"
node_pools = {
  general = { shape = "VM.Standard.E4.Flex", ocpus = 5, memory_gbs = 16, size = 3, boot_volume_gb = 50 }
}

# Storage
buckets = {
  data    = {}
  backups = {}
}

# GitLab object storage (S3-compatible API): buckets uat-gitlab-<name> + dedicated access key
gitlab_buckets = [
  "registry", "lfs", "artifacts", "uploads", "packages", "mr-diffs",
  "terraform-state", "ci-secure-files", "dependency-proxy", "backups", "tmp",
]
gitlab_s3_user_email = "amit.chaturvedi+gitlab-s3@wibmo.com"

# OCI Container Registry (private repositories)
container_repositories = [
  "accosa2-config-management",
  "acs2-alert-management",
  "acs2-api",
  "acs2-customer-data-api",
  "acs2-datastore-api",
  "acs2-expiry-service",
  "acs2-issuer-config-api",
  "acs2-job-scheduler",
  "acs2-ui",
  "oob-service",
  "otp-engine",
]

# Self-managed Kafka (3 x KRaft broker+controller) and Redis Cluster on VMs
kafka = { enabled = true }
# Redis Cluster: 3 masters (6379) + 3 replicas (6380) on 3 VMs; 1gb per instance on the 4 GB VMs
redis = { enabled = true, mode = "cluster", maxmemory = "1gb" }

# Security / observability
create_vault     = false
enable_flow_logs = true
alert_email      = null

# MySQL HeatWave (password: export TF_VAR_mysql_admin_password='...')
create_mysql              = true
mysql_shape_name          = "MySQL.4" # verify: oci mysql shape list --compartment-id <ocid> --availability-domain <AD>
mysql_data_storage_gb     = 50
mysql_is_highly_available = false
mysql_enable_heatwave     = false
mysql_deletion_protection = false
