data "oci_core_services" "all" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

locals {
  oci_services = data.oci_core_services.all.services[0]
}

resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_id
  display_name   = "${var.name_prefix}-vcn"
  cidr_blocks    = [var.vcn_cidr]
  dns_label      = var.vcn_dns_label
  freeform_tags  = var.tags
}

# No Internet Gateway on purpose: the VCN is fully private.
resource "oci_core_nat_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-nat"
  freeform_tags  = var.tags
}

resource "oci_core_service_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-sgw"
  freeform_tags  = var.tags

  services {
    service_id = local.oci_services.id
  }
}

# Workers and pods: outbound via NAT, OCI services via Service Gateway.
resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-rt-private"
  freeform_tags  = var.tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.this.id
    description       = "Outbound via NAT"
  }

  route_rules {
    destination       = local.oci_services.cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.this.id
    description       = "OCI services via Service Gateway"
  }
}

# API endpoint, load balancer and database subnets: OCI services only.
resource "oci_core_route_table" "endpoint" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-rt-endpoint"
  freeform_tags  = var.tags

  route_rules {
    destination       = local.oci_services.cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.this.id
    description       = "OCI services via Service Gateway"
  }
}

# Empty security list: replaces the permissive VCN default so NSGs are the only thing that opens traffic.
resource "oci_core_security_list" "deny_all" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-sl-empty"
  freeform_tags  = var.tags
}

locals {
  subnets = {
    cp      = { cidr = var.subnet_cidrs["cp"], rt = oci_core_route_table.endpoint.id }
    lb      = { cidr = var.subnet_cidrs["lb"], rt = oci_core_route_table.endpoint.id }
    db      = { cidr = var.subnet_cidrs["db"], rt = oci_core_route_table.endpoint.id }
    workers = { cidr = var.subnet_cidrs["workers"], rt = oci_core_route_table.private.id }
    pods    = { cidr = var.subnet_cidrs["pods"], rt = oci_core_route_table.private.id }
  }
}

resource "oci_core_subnet" "this" {
  for_each = local.subnets

  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  display_name               = "${var.name_prefix}-${each.key}"
  dns_label                  = each.key
  cidr_block                 = each.value.cidr
  route_table_id             = each.value.rt
  security_list_ids          = [oci_core_security_list.deny_all.id]
  prohibit_public_ip_on_vnic = true
  freeform_tags              = var.tags
}
