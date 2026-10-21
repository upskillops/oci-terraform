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

# Public jump host (SSH from the allowed IPs; kubectl via: ssh -D 1080 opc@<ip>)
create_jumphost         = true
jumphost_allowed_cidrs  = ["202.78.236.218/32"]
jumphost_ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDPlTqJAnp/97kT8i9s7t1wZfLuwy17vM02Wsic8SJi2ZJg5lZ7chtD1RiriwUnJMF5M3iBAXc2vr/O62wls+diynGRpk3D65R0YoOTeSeIVsdTo0PZ1lw1/vQ7GA0/bL4QqwigtAkPSOj0OKfklP3Owo2NGy/sNUQNZsz3k06sdIbmVHRV0upPAMHTk0zdSLtQqf93GtxYM4jwV5WkOFMNDGxhBzoKOYx1H2fgQJpMVTxepG3g4AtxinmHHOc256Wl0X9uIwEzB1FwTCEeXplgwtPRtRZHVv4+J1JjX3PYCv3qQWwuf+nIHflKbwK70e/0HsJ07mVwgWXblzwYf8JLI/+bNHgemOQk9JwhlB9xdoVm24UOj0mcOjKHpVa3pw+hc0RGgJRwbSwNixLWvciTg0/OFrMuu1pRvdvOWgZHWjIp7JRi7einfxkLD12h/u1iWD4CyMXv1g4Ls015JrNz8riLNBdg4D7+U35TubEjWro21NK/gp5ESkLe1QKjWdE= amitchaturvedi@Amits-MacBook-Air.local"

# Nodes (minimum footprint)
node_architecture = "x86_64"
node_pools = {
  general = { shape = "VM.Standard.E4.Flex", ocpus = 1, memory_gbs = 8, size = 3, boot_volume_gb = 50 }
}

# Storage
buckets = {
  data    = {}
  backups = {}
}

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
