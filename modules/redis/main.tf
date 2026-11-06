# Self-managed Redis on VMs, two modes:
#   cluster  - Redis Cluster: 3 shards x (master + replica), 2 instances per VM, replicas on other VMs
#   sentinel - node 1 primary, others replicas, Sentinel on every node for automatic failover
# Runs the official redis image under Podman + systemd; AOF persistence on the boot volume.

data "oci_core_images" "ol9" {
  compartment_id           = var.compartment_id
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# Alphanumeric only: it is written into redis.conf / sentinel.conf.
resource "random_password" "redis" {
  length  = 32
  special = false
}

locals {
  ips        = [for i in range(var.node_count) : cidrhost(var.subnet_cidr, var.ip_offset + i)]
  primary_ip = local.ips[0]
  quorum     = floor(var.node_count / 2) + 1

  # Cluster mode: masters on 6379, replicas on 6380 (redis-cli places each replica on another VM).
  cluster_nodes = concat([for ip in local.ips : "${ip}:6379"], [for ip in local.ips : "${ip}:6380"])
}

resource "oci_core_instance" "this" {
  count = var.node_count

  compartment_id      = var.compartment_id
  availability_domain = var.availability_domain
  fault_domain        = "FAULT-DOMAIN-${(count.index % 3) + 1}"
  display_name        = "${var.name_prefix}-redis-${count.index + 1}"
  shape               = var.shape
  freeform_tags       = merge(var.tags, { role = "redis" })

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ol9.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_gb
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    private_ip       = local.ips[count.index]
    assign_public_ip = false
    nsg_ids          = var.nsg_ids
    hostname_label   = "redis-${count.index + 1}"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(var.mode == "cluster" ? templatefile("${path.module}/cloud-init-cluster.yaml", {
      image         = var.image
      ip            = local.ips[count.index]
      password      = random_password.redis.result
      maxmemory     = var.maxmemory
      create        = count.index == 0 # node 1 forms the cluster once all 6 instances answer
      cluster_nodes = join(" ", local.cluster_nodes)
      }) : templatefile("${path.module}/cloud-init.yaml", {
      image       = var.image
      ip          = local.ips[count.index]
      primary_ip  = local.primary_ip
      is_primary  = count.index == 0
      password    = random_password.redis.result
      master_name = var.master_name
      quorum      = local.quorum
      maxmemory   = var.maxmemory
    }))
  }

  # Newer images or cloud-init edits must not rebuild a running node (and drop its data).
  # To switch mode on existing VMs: terraform apply -replace='module.redis[0].oci_core_instance.this[N]'.
  lifecycle {
    ignore_changes = [source_details[0].source_id, metadata["user_data"]]
  }
}
