# Self-managed Apache Kafka (KRaft, no ZooKeeper): every node is broker + controller.
# Runs the official apache/kafka image under Podman + systemd; data on the boot volume.

data "oci_core_images" "ol9" {
  compartment_id           = var.compartment_id
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# Kafka cluster ID: a base64url-encoded UUID, exactly what `kafka-storage random-uuid` produces.
resource "random_id" "cluster" {
  byte_length = 16
}

locals {
  ips    = [for i in range(var.node_count) : cidrhost(var.subnet_cidr, var.ip_offset + i)]
  voters = join(",", [for i, ip in local.ips : "${i + 1}@${ip}:9093"])
  # Replication settings need at least 3 nodes; a single node falls back to 1.
  rf      = min(3, var.node_count)
  min_isr = max(1, local.rf - 1)
}

resource "oci_core_instance" "this" {
  count = var.node_count

  compartment_id      = var.compartment_id
  availability_domain = var.availability_domain
  fault_domain        = "FAULT-DOMAIN-${(count.index % 3) + 1}"
  display_name        = "${var.name_prefix}-kafka-${count.index + 1}"
  shape               = var.shape
  freeform_tags       = merge(var.tags, { role = "kafka" })

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
    hostname_label   = "kafka-${count.index + 1}"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
      image      = var.image
      node_id    = count.index + 1
      ip         = local.ips[count.index]
      voters     = local.voters
      cluster_id = random_id.cluster.b64_url
      rf         = local.rf
      min_isr    = local.min_isr
      heap       = var.heap
    }))
  }

  # Newer images or cloud-init edits must not rebuild a running broker (and wipe its data).
  lifecycle {
    ignore_changes = [source_details[0].source_id, metadata["user_data"]]
  }
}
