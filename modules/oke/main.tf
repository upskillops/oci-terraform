resource "oci_containerengine_cluster" "this" {
  compartment_id     = var.compartment_id
  name               = "${var.name_prefix}-oke"
  kubernetes_version = var.kubernetes_version
  type               = var.cluster_type
  vcn_id             = var.vcn_id
  kms_key_id         = var.kms_key_id
  freeform_tags      = var.tags

  cluster_pod_network_options {
    cni_type = "OCI_VCN_IP_NATIVE"
  }

  # Private API endpoint: no public IP.
  endpoint_config {
    is_public_ip_enabled = false
    subnet_id            = var.subnet_ids["cp"]
    nsg_ids              = [var.nsg_ids["cp"]]
  }

  options {
    service_lb_subnet_ids = [var.subnet_ids["lb"]]

    kubernetes_network_config {
      services_cidr = var.services_cidr
    }

    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }

    persistent_volume_config {
      freeform_tags = var.tags
    }

    service_lb_config {
      freeform_tags = var.tags
    }
  }
}

# ---- Worker image selection ----
data "oci_containerengine_node_pool_option" "this" {
  node_pool_option_id = oci_containerengine_cluster.this.id
  compartment_id      = var.compartment_id
}

locals {
  k8s_semver = trimprefix(var.kubernetes_version, "v")
  arch_part  = var.node_architecture == "aarch64" ? "aarch64-" : ""

  matching_images = {
    for s in data.oci_containerengine_node_pool_option.this.sources : s.source_name => s.image_id
    if can(regex("^Oracle-Linux-8\\.[0-9]+-${local.arch_part}[0-9.]+-[0-9]+-OKE-${local.k8s_semver}-[0-9]+$", s.source_name))
  }

  auto_image_id = try(local.matching_images[reverse(sort(keys(local.matching_images)))[0]], null)
  node_image_id = coalesce(var.node_image_id, local.auto_image_id)
}

resource "oci_containerengine_node_pool" "this" {
  for_each = var.node_pools

  compartment_id     = var.compartment_id
  cluster_id         = oci_containerengine_cluster.this.id
  name               = "${var.name_prefix}-${each.key}"
  kubernetes_version = var.kubernetes_version
  node_shape         = each.value.shape
  ssh_public_key     = var.ssh_public_key
  freeform_tags      = var.tags

  dynamic "node_shape_config" {
    for_each = endswith(each.value.shape, ".Flex") ? [1] : []
    content {
      ocpus         = each.value.ocpus
      memory_in_gbs = each.value.memory_gbs
    }
  }

  node_source_details {
    source_type             = "IMAGE"
    image_id                = local.node_image_id
    boot_volume_size_in_gbs = each.value.boot_volume_gb
  }

  node_config_details {
    size                                = each.value.size
    kms_key_id                          = var.kms_key_id
    is_pv_encryption_in_transit_enabled = true
    nsg_ids                             = [var.nsg_ids["workers"]]
    freeform_tags                       = var.tags

    dynamic "placement_configs" {
      for_each = var.availability_domains
      content {
        availability_domain = placement_configs.value
        subnet_id           = var.subnet_ids["workers"]
      }
    }

    node_pool_pod_network_option_details {
      cni_type          = "OCI_VCN_IP_NATIVE"
      max_pods_per_node = var.max_pods_per_node
      pod_subnet_ids    = [var.subnet_ids["pods"]]
      pod_nsg_ids       = [var.nsg_ids["pods"]]
    }
  }

  dynamic "initial_node_labels" {
    for_each = each.value.labels
    content {
      key   = initial_node_labels.key
      value = initial_node_labels.value
    }
  }

  node_eviction_node_pool_settings {
    eviction_grace_duration              = "PT1H" # OCI normalises 60 minutes to PT1H
    is_force_delete_after_grace_duration = false
  }

  node_pool_cycling_details {
    is_node_cycling_enabled = true
    maximum_surge           = "1"
    maximum_unavailable     = "0"
  }
}

# ---- Optional OCI Bastion for kubectl access to the private endpoint ----
resource "oci_bastion_bastion" "this" {
  count = var.create_bastion && length(var.bastion_client_cidrs) > 0 ? 1 : 0

  compartment_id               = var.compartment_id
  bastion_type                 = "STANDARD"
  name                         = "${replace(var.name_prefix, "-", "")}bastion"
  target_subnet_id             = var.subnet_ids["cp"]
  client_cidr_block_allow_list = var.bastion_client_cidrs
  max_session_ttl_in_seconds   = 10800
  freeform_tags                = var.tags
}
